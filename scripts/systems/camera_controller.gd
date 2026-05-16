extends Camera2D

@export var follow_smoothing: float = 5.0  # 值越大相机越灵敏（lerp更快）
var target: Node2D
var map_bounds: Rect2 = Rect2(0, 0, 1920, 1080)

var _shake_intensity: float = 0.0  # 当前震屏强度
var _shake_decay: float = 5.0  # 震屏衰减速度

func _ready():
	target = get_tree().get_first_node_in_group("player")
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _on_player_damaged(_amount: int, _new_hp: int):
	shake(6.0, 6.0)  # 玩家受伤时震屏强度更高，提升受击反馈

func _on_damage_dealt(_source: Node, _target: Node, _amount: int, is_crit: bool):
	if is_crit:
		shake(3.0, 4.0)  # 暴击时轻微震屏，强化命中手感

func _process(delta):
	if target == null:
		target = get_tree().get_first_node_in_group("player")
		return
	var desired_pos = target.global_position
	# 使用lerp平滑跟随，避免突兀的镜头跳动
	global_position = global_position.lerp(desired_pos, follow_smoothing * delta)
	var viewport_size = get_viewport_rect().size
	# 将相机限制在地图边界内，防止显示到地图外的区域
	global_position.x = clamp(global_position.x, map_bounds.position.x + viewport_size.x / 2, map_bounds.end.x - viewport_size.x / 2)
	global_position.y = clamp(global_position.y, map_bounds.position.y + viewport_size.y / 2, map_bounds.end.y - viewport_size.y / 2)

	# 震屏通过随机偏移offset实现，强度逐帧衰减
	if _shake_intensity > 0.01:
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_shake_intensity = lerp(_shake_intensity, 0.0, _shake_decay * delta)
	else:
		_shake_intensity = 0.0
		offset = Vector2.ZERO

func shake(intensity: float, decay: float = 5.0):
	_shake_intensity = max(_shake_intensity, intensity)  # 取最大值防止小震屏覆盖大震屏
	_shake_decay = decay
