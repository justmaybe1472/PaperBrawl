# 所有敌人场景的基类，统一管理数据加载、AI 切换、视觉表现和受击/死亡流程
class_name EnemyBase
extends CharacterBody2D

# 敌人唯一标识，被对象池回收和掉落表查询所依赖，不可随意更改
@export var enemy_id: String = "basic_melee"

# 使用 @onready 延迟获取子节点引用，因为场景树在此时尚未构建完毕
@onready var stats: EnemyStats = $EnemyStats
@onready var ai: EnemyAI = $AIStateMachine
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

# 死亡标记：防止 take_damage 的红色闪烁和 _die 在对象回收期间被重复触发
var is_dead: bool = false
# 击退速度叠加层，每帧向零衰减，叠加在 AI 移动速度上形成受击位移
var knockback_velocity: Vector2 = Vector2.ZERO
# 内部精英判定，影响掉落数量倍率和金色外观
var _is_elite: bool = false
# 基础掉落材料数，由 EnemyData 在 init 中写入，作为 _spawn_drops 的基数
var _material_drop: int = 1

# 敌人类型 → AI 脚本路径映射，init 时动态加载到 AIStateMachine 节点实现行为多态
const AI_SCRIPTS: Dictionary = {
	"chaser": "res://scripts/enemies/enemy_ai_chaser.gd",
	"charger": "res://scripts/enemies/enemy_ai_charger.gd",
	"shooter": "res://scripts/enemies/enemy_ai_shooter.gd",
	"summoner": "res://scripts/enemies/enemy_ai_summoner.gd",
	"tank": "res://scripts/enemies/enemy_ai_chaser.gd",
	"elite": "res://scripts/enemies/enemy_ai_chaser.gd",
	"boss": "res://scripts/enemies/enemy_ai_boss.gd",
}

# 敌人类型 → 调制色映射，为不同敌人赋予独特的颜色基调便于玩家一眼区分
const TYPE_COLORS: Dictionary = {
	"chaser": Color.RED,
	"charger": Color.ORANGE,
	"shooter": Color.MAGENTA,
	"summoner": Color.WHITE,
	"tank": Color.DARK_RED,
	"elite": Color.GOLD,
	"boss": Color.CRIMSON,
}

# 将自身加入 "enemy" 组，供投射物、技能范围等外部系统通过组名快速遍历所有敌人
func _ready():
	add_to_group("enemy")

# 初始化入口（由工厂/对象池调用），按 数据→属性→AI→视觉 顺序完成装配
func init(enemy_data: EnemyData, wave_number: int):
	# 记录基础数据，用于后续掉落和对象池回收
	enemy_id = enemy_data.id
	_material_drop = enemy_data.material_drop
	# 先初始化属性组件（含波次缩放），后续 AI 和 UI 依赖此结果
	($EnemyStats as EnemyStats).init_from_data(enemy_data, wave_number)

	# 根据敌人类型动态加载对应的 AI 脚本，实现行为多态
	var type: String = enemy_data.enemy_type
	var ai_script_path: String = AI_SCRIPTS.get(type, "res://scripts/enemies/enemy_ai_chaser.gd")
	var ai_script = load(ai_script_path)
	$AIStateMachine.set_script(ai_script)
	# 将属性数据注入 AI，确保 AI 使用的速度等字段与 Stats 同步
	($AIStateMachine as EnemyAI).chase_speed = ($EnemyStats as EnemyStats).base_speed
	($AIStateMachine as EnemyAI).enemy_data = enemy_data

	# 根据敌人类型分配不同的体型（坦克/Boss 更大）和测试期占位贴图
	var size: float = 28.0
	if type == "tank" or type == "boss":
		size = 40.0
	if type == "elite" or type == "boss":
		size *= 1.15
	# 按敌人类型映射测试期占位贴图
	var tex_map = {"chaser": "Enemy_1.png", "charger": "Enemy_2.png", "shooter": "Enemy_3.png", "summoner": "Enemy_4.png", "tank": "Enemy_4.png", "boss": "Enemy_2.png", "elite": "Enemy_1.png"}
	var tex_name = tex_map.get(type, "Enemy_1.png")
	PlaceholderSprites.apply_test_texture($Sprite2D, tex_name, size)

	# 最后初始化血条 UI，确保与属性组件当前值一致
	$HealthBar.max_value = ($EnemyStats as EnemyStats).base_hp
	$HealthBar.value = ($EnemyStats as EnemyStats).current_hp

# 精英化入口：提升属性并改变外观，生成更强但掉落更多的敌人变体
func set_elite(value: bool):
	_is_elite = value
	if value:
		# 精英敌人属性增益：HP ×2（更耐打）、伤害 ×1.5（更具威胁）、速度 ×1.2（更难逃脱）
		stats.base_hp *= 2.0
		stats.current_hp = stats.base_hp
		stats.base_damage *= 1.5
		stats.base_speed *= 1.2
		($AIStateMachine as EnemyAI).chase_speed = stats.base_speed
		# 体型 +20%，放大视觉体积以匹配精英身份
		sprite.scale = Vector2(1.2, 1.2)
		$HealthBar.max_value = stats.base_hp
		$HealthBar.value = stats.current_hp
		# 金色调制标记精英身份，方便玩家在混战中快速识别高价值目标
		sprite.modulate = Color.GOLD

# 物理帧更新：仅在波次活跃期间执行移动，死亡或非战斗状态时跳过
func _physics_process(delta):
	# 已死亡则跳过移动，防止尸体继续滑动
	if is_dead:
		return
	# 仅在波次活跃期间运行 AI 移动，避免在波间/暂停时敌人自主移动
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return

	# 击退速度逐帧衰减（每秒 500 像素/秒），模拟摩擦力使受击后逐渐停下
	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 500.0)

	# 最终速度 = AI 移动方向 * 基础速度 + 击退剩余速度，两者独立叠加
	var move_dir = ($AIStateMachine as EnemyAI).get_move_direction()
	velocity = move_dir * stats.base_speed + knockback_velocity
	move_and_slide()

# 受击处理：扣血 → 更新血条 → 红色闪烁反馈 → 判定死亡
func take_damage(amount: int):
	# 已死亡则忽略后续伤害，防止重复触发 _die
	if is_dead:
		return
	stats.take_damage(amount)
	# 血条节点可能在死亡/回收后被释放，先做有效性校验
	if not is_instance_valid(health_bar):
		return
	health_bar.value = stats.current_hp

	# 再次检查死亡标记（stats.take_damage 可能已在内部触发 _die 并设置 is_dead）
	if is_dead:
		return
	# 受伤闪红 0.1 秒，提供即时的视觉反馈让玩家感知命中
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	# await 之后必须再次确认未被回收且未死亡，防止访问已释放节点
	if not is_dead and is_instance_valid(sprite):
		sprite.modulate = Color.WHITE

	# 在闪红结束后才判定死亡，这样玩家能看到完整受击反馈
	if stats.is_dead():
		_die()

# 外部施加击退力（由武器/技能的 knockback 事件触发）
func apply_knockback(force: Vector2):
	knockback_velocity = force

# 死亡流程：先产出掉落物再通知外部，最后回收到对象池而非 queue_free
func _die():
	# 双重检查：防止多个伤害源同时触发死亡导致的重复掉落
	if is_dead:
		return
	is_dead = true
	# 生成材料掉落物（必须先于信号发射，监听者可能需要掉落数据）
	_spawn_drops()
	# 通过事件总线广播击杀事件，供经验值、统计数据等系统消费
	EventBus.enemy_killed.emit(enemy_id, global_position, _is_elite)
	# 回收到对象池而非删除节点，避免频繁的 new/delete 开销
	ObjectPool.return_enemy(self, enemy_id)

# 掉落物生成：数量由 基础掉落 + 随机波动 + 精英倍率 + 波次/难度/收获属性 共同决定
func _spawn_drops():
	# 获取当前波次配置中的材料倍率（不同波次可定制掉落丰度）
	var wave_config = DataManager.get_wave_config(GameManager.current_wave)
	var multiplier: float = 1.0
	if wave_config:
		multiplier = wave_config.material_multiplier

	# 叠加全局波次材料倍率（由 GameManager 根据难度等因素计算）
	multiplier *= GameManager.get_wave_material_multiplier()

	# 玩家收获属性（harvesting）：每 50 点提升 100% 掉落，鼓励投入该属性
	var player = get_tree().get_first_node_in_group("player")
	var harvesting: float = 0.0
	if player and player.has_node("StatsComponent"):
		harvesting = player.get_node("StatsComponent").get_stat("harvesting")
	multiplier *= (1.0 + harvesting / 50.0)

	# 基础数量 = 敌人配置固定值 + [0, 2] 随机，多倍率叠加后至少保证 1 个
	var amount: int = _material_drop + randi() % 3
	if _is_elite:
		amount *= 3
	amount = max(1, int(amount * multiplier))

	# 每个掉落物从对象池获取，在敌人尸体附近随机偏移 15 像素范围内散落
	for i in range(amount):
		var pickup = ObjectPool.get_pickup()
		pickup.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		pickup.set("value", 1)
		# 初始状态下未被吸入、未绑定玩家引用
		pickup.set("attracted", false)
		pickup.set("player_ref", null)

		# 优先放入 pickups_container 组节点（便于统一管理），不存在则挂到根节点
		var container = get_tree().get_first_node_in_group("pickups_container")
		if container:
			container.add_child(pickup)
		else:
			get_tree().root.add_child(pickup)
