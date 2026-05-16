# 游戏全局状态机：管理波次流程、材料经济、元进度结算
extends Node

# 六状态枚举覆盖完整游戏循环：菜单→选角→战斗→商店→暂停→结算
enum GameState { MAIN_MENU, CHARACTER_SELECT, WAVE_ACTIVE, SHOP, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MAIN_MENU  # 状态机核心变量，所有模块通过它判断当前游戏阶段
var current_wave: int = 1  # 当前波次（1-20），20波通关
var materials: int = 0  # 当前单局持有材料数，用于商店购买与结算加成
var selected_character_id: String = "well_rounded"  # 玩家所选角色ID，影响初始属性与可用技能
var is_first_wave: bool = true  # 标记是否为本次 run 的首波，首次触发 game_started 信号
var total_kills: int = 0  # 本局累计击杀，结算时写入存档驱动解锁判定
var is_victory: bool = false  # 通关标记以区分胜利和死亡结算，影响结局UI展示
var current_difficulty: int = 0  # 0=普通, 1=困难, 2=噩梦, 3=地狱，驱动敌人属性与材料倍率

func _ready():
	# 监听三个关键事件：商店关闭推进波次、击杀累计用于存档、玩家死亡触发结算
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.enemy_killed.connect(_on_enemy_killed_for_stats)
	EventBus.player_died.connect(_on_player_died)

func start_run(character_id: String):
	# 新一局开始：重置所有对局状态为初始值，确保无残留数据
	selected_character_id = character_id
	current_wave = 1
	materials = 0
	is_first_wave = true
	total_kills = 0
	is_victory = false
	change_state(GameState.WAVE_ACTIVE)

# 集中式状态切换：统一发射对应生命周期事件，所有模块监听 EventBus 响应
func change_state(new_state: GameState):
	current_state = new_state
	match new_state:
		GameState.WAVE_ACTIVE:
			if is_first_wave:
				EventBus.game_started.emit()  # 仅首波时触发一次
				is_first_wave = false
			EventBus.wave_started.emit(current_wave)
		GameState.SHOP:
			# 先结算波次完成（用于解锁判定），再打开商店界面
			EventBus.wave_completed.emit(current_wave)
			EventBus.shop_opened.emit(current_wave)
		GameState.GAME_OVER:
			# 传递波次与材料供结算界面展示，区分胜利/失败由 is_victory 决定
			EventBus.game_over.emit(current_wave, materials)

# 波次递进：到达21波即通关，触发胜利结算而非死亡结算
func next_wave():
	current_wave += 1
	if current_wave > 20:
		_handle_victory()  # 通过全部20波，胜利
	else:
		change_state(GameState.WAVE_ACTIVE)

func add_materials(amount: int):
	# 增加材料并通知UI刷新（amount 为正表示拾取，调用方保证为正值）
	materials += amount
	EventBus.material_collected.emit(amount, materials)

func spend_materials(amount: int) -> bool:
	# 购买校验：余额不足返回 false，调用方据此决定是否允许购买并更新UI
	if materials >= amount:
		materials -= amount
		EventBus.material_collected.emit(-amount, materials)  # 负值表示消费，UI端据此判断动画方向
		return true
	return false

func _on_shop_closed():
	# 商店关闭即推进到下一波
	next_wave()

func _on_enemy_killed_for_stats(_enemy_id: String, _position: Vector2, _is_elite: bool):
	# 累计本局击杀数，用于结算时写入存档驱动解锁判定
	total_kills += 1

func _on_player_died():
	# 玩家死亡 -> 失败结局（is_win=false）
	_end_run(false)

func _handle_victory():
	# 通关全部20波 -> 胜利结局（is_win=true）
	is_victory = true
	_end_run(true)

func _end_run(is_win: bool):
	# 统一结算入口：将本局数据持久化到存档（击杀/材料/波次），然后进入结算状态
	SaveManager.add_kills(total_kills)
	SaveManager.add_materials(materials)
	SaveManager.record_run_end(current_wave, is_win)
	change_state(GameState.GAME_OVER)

func set_difficulty(level: int):
	# 设置难度等级，影响敌人属性倍率与材料掉落倍率
	current_difficulty = level

func get_enemy_stat_multiplier() -> float:
	# 敌人属性倍率：委托给 SaveManager 按难度等级计算
	return SaveManager.get_difficulty_multiplier()

func get_wave_material_multiplier() -> float:
	# 材料掉落倍率：委托给 SaveManager，高难度奖励更多材料
	return SaveManager.get_material_multiplier()
