# 所有武器的统一基类，提供冷却计时、属性引用、攻击循环的通用框架
class_name WeaponBase
extends Node2D

# 武器唯一标识，用于从DataManager查询对应的武器数值配置
@export var weapon_id: String = ""
# 武器的数值配置（冷却、伤害、穿透等）
var weapon_data: WeaponData
# 持有玩家属性组件的引用，以供伤害计算和冷却缩减使用
var player_stats: StatsComponent
# 攻击冷却计时器，每次冷却完成后触发一次攻击
var cooldown_timer: Timer

func _ready():
	# 从数据管理器获取武器配置，做数值与逻辑分离
	weapon_data = DataManager.get_weapon(weapon_id)
	if weapon_data == null:
		push_error("Weapon: No weapon data for id: " + weapon_id)
		return
	# 子类覆盖以绘制不同的武器图标
	_create_visual()
	# 初始化冷却系统，使用基于攻速的动态冷却
	_setup_cooldown()

func _create_visual():
	pass

func _setup_cooldown():
	# 动态创建Timer而非使用编辑器节点，以便运行时根据属性变化灵活调整冷却
	cooldown_timer = Timer.new()
	# 一次性计时模式：冷却完成后只触发一次攻击，然后重新开始计时
	cooldown_timer.one_shot = true
	# 根据玩家攻速属性计算实际冷却时间
	cooldown_timer.wait_time = get_effective_cooldown()
	cooldown_timer.timeout.connect(_on_cooldown_ready)
	add_child(cooldown_timer)
	# 武器创建后立即开始第一次冷却倒计时
	cooldown_timer.start()

func get_effective_cooldown() -> float:
	# 属性组件尚未获取时，退回原始冷却值（防御性处理）
	if player_stats == null:
		return weapon_data.cooldown
	var attack_speed: float = player_stats.get_stat("attack_speed")
	# 攻速属性以百分比计算冷却缩减：攻速越高，冷却越短
	var effective: float = weapon_data.cooldown / (1.0 + attack_speed / 100.0)
	# 硬上限0.1秒——防止高攻速时攻击频率过高导致性能下降
	return max(effective, 0.1)

func _on_cooldown_ready():
	# 只在波次活跃时允许攻击；非活跃期间重置计时器等待下一波
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		cooldown_timer.start()
		return
	attack()
	# 每次攻击后重新计算冷却时间，以响应攻速属性的实时变化
	cooldown_timer.wait_time = get_effective_cooldown()
	cooldown_timer.start()

func _try_reacquire_stats():
	# 延迟重新获取玩家属性引用——处理对象池复用或场景重载后引用失效的情况
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("StatsComponent"):
		player_stats = player.get_node("StatsComponent")

func attack():
	pass
