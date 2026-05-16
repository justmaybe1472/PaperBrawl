# 波次管理核心：控制刷怪节奏、敌人权重抽取、波次结束判定
extends Node

var wave_timer: float = 0.0  # 波次剩余时间，归零+敌人清零 → 波次结束
var spawn_timer: float = 0.0  # 生成间隔计时器，控制敌人出生频率
var enemies_alive: int = 0  # 场上存活敌人数，用于判断波次结束条件
var enemies_spawned: int = 0  # 已生成总数，达到 enemies_to_spawn 后停止生成
var enemies_to_spawn: int = 0  # 本波敌人总数，从 WaveConfig 读取
var spawn_interval: float = 1.0  # 两次生成之间的间隔秒数
var wave_active: bool = false  # 波次开关，防止非战斗阶段误触发
var current_wave_config: WaveConfig  # 当前波次配置引用

func _ready():
	# 监听波次开始信号以初始化本波参数，监听击杀信号以递减存活计数
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_killed.connect(_on_enemy_killed)

# 波次开始时从 DataManager 拉取配置并初始化所有计时器/计数器
func _on_wave_started(wave_number: int):
	var config = DataManager.get_wave_config(wave_number)
	if config == null:
		push_error("WaveManager: No config for wave " + str(wave_number))
		return

	current_wave_config = config
	wave_timer = config.duration
	enemies_to_spawn = config.total_enemies
	spawn_interval = config.spawn_interval
	enemies_spawned = 0
	enemies_alive = 0
	spawn_timer = 0.0  # 首个敌人立即生成（不做延迟等待）
	wave_active = true

	if config.is_boss_wave:
		_spawn_boss()  # Boss波预先生成Boss，区别于普通流程

func _on_enemy_killed(_enemy_id: String, _position: Vector2, _is_elite: bool):
	# 每击杀一个敌人，存活计数减1，驱动波次结束判定
	enemies_alive -= 1

func _process(delta):
	# 核心循环：仅在波次活跃且游戏处于战斗状态时运行计时与刷怪逻辑
	if not wave_active:
		return
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return

	# 双计时器同时递减：波次总时长 + 刷怪冷却
	wave_timer -= delta
	spawn_timer -= delta

	# 实时广播剩余时间，供UI进度条刷新
	EventBus.wave_timer_updated.emit(max(0.0, wave_timer))

	# 未达刷怪上限且冷却完毕时生成敌人，然后重置间隔计时器
	if enemies_spawned < enemies_to_spawn and spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = spawn_interval

	# 波次结束条件分三种情况：
	# 1. Boss波：必须全部敌人都击杀且刷怪配额用完（Boss必须死）
	# 2. 普通波：时间归零且场上敌人全部清空
	# 3. 容错兜底：时间归零但剩余敌人 ≤ 5，也强制结束（防止卡关）
	if current_wave_config and current_wave_config.is_boss_wave:
		if enemies_alive <= 0 and enemies_spawned >= enemies_to_spawn:
			_end_wave()
	elif wave_timer <= 0.0 and enemies_alive <= 0:
		_end_wave()
	elif wave_timer <= 0.0 and enemies_alive <= 5:
		_end_wave()  # 允许少量残余，时间到即强制结束

func _spawn_enemy():
	var type_id: String = "basic_melee"
	if current_wave_config and not current_wave_config.enemy_types.is_empty():
		type_id = _weighted_random_enemy(current_wave_config.enemy_types)

	var is_elite: bool = false
	if current_wave_config and current_wave_config.elite_chance > 0.0:
		if randf() < current_wave_config.elite_chance:
			type_id = "elite"
			is_elite = true

	var enemy_data = DataManager.get_enemy(type_id)
	if enemy_data == null:
		enemy_data = DataManager.get_enemy("basic_melee")
	if enemy_data == null:
		push_error("WaveManager: No enemy data found")
		return

	# 从对象池获取敌人实例，避免频繁创建销毁的GC开销
	var enemy = ObjectPool.get_enemy(type_id)

	# 敌人在玩家周围360°均匀随机生成，距离800px确保生成于屏幕外
	var player = get_tree().get_first_node_in_group("player")
	var spawn_center = player.global_position if player else Vector2(960, 540)
	var angle = randf() * TAU
	var spawn_distance = 800.0
	enemy.global_position = spawn_center + Vector2(cos(angle), sin(angle)) * spawn_distance

	var container = get_tree().get_first_node_in_group("enemies_container")
	if container:
		container.add_child(enemy)
	else:
		get_tree().root.add_child(enemy)

	enemy.init(enemy_data, GameManager.current_wave)
	if is_elite:
		enemy.set_elite(true)

	enemies_spawned += 1
	enemies_alive += 1

func _weighted_random_enemy(type_weights: Dictionary) -> String:
	# 加权随机抽取：先计算总权重，再按累积区间判定
	# 例如 {"basic": 10, "fast": 5} 则 basic 有 66.6% 概率
	var total_weight: float = 0.0
	for weight in type_weights.values():
		total_weight += weight

	var roll = randf() * total_weight  # 在 [0, total_weight) 之间随机
	var cumulative: float = 0.0
	for type_id in type_weights:
		cumulative += type_weights[type_id]
		if roll <= cumulative:  # 落入当前类型的累积区间即返回
			return type_id

	# 保底：理论上不会走到这里，但作为容错返回第一个类型
	return type_weights.keys()[0]

func _on_summon():
	# 某些敌人（如Boss）会召唤小怪，通过此方法增加存活计数以免波次提前结束
	enemies_alive += 1

func _end_wave():
	# 波次结束：停用波次标志，清理场上的残余敌人并归还对象池，进入商店状态
	wave_active = false
	_clear_remaining_enemies()
	enemies_alive = 0
	GameManager.change_state(GameManager.GameState.SHOP)

func _spawn_boss():
	# Boss生成：读取Boss配置，从对象池获取实例，固定在玩家正上方生成
	var boss_data = DataManager.get_enemy("boss")
	if boss_data == null:
		push_error("WaveManager: No boss enemy data found")
		return

	var boss = ObjectPool.get_enemy("boss")
	var player = get_tree().get_first_node_in_group("player")
	var spawn_center = player.global_position if player else Vector2(960, 540)
	boss.global_position = spawn_center + Vector2(0, -400)  # 玩家正上方400px

	var container = get_tree().get_first_node_in_group("enemies_container")
	if container:
		container.add_child(boss)
	else:
		get_tree().root.add_child(boss)

	boss.init(boss_data, GameManager.current_wave)
	boss.set_elite(true)  # Boss默认视为精英敌人

	enemies_spawned += 1
	enemies_alive += 1

func _clear_remaining_enemies():
	# 波次结束时清理场上残余：EnemyBase 归还对象池复用，其他节点直接释放
	var container = get_tree().get_first_node_in_group("enemies_container")
	if container:
		for child in container.get_children():
			if child is EnemyBase:
				child.is_dead = true  # 标记死亡防止死亡回调被多次触发
				ObjectPool.return_enemy(child, child.enemy_id)
			else:
				child.queue_free()
