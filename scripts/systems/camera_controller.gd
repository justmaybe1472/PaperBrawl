extends Camera2D

@export var follow_smoothing: float = 5.0
var target: Node2D
var map_bounds: Rect2 = Rect2(0, 0, 1920, 1080)

var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0

func _ready():
	target = get_tree().get_first_node_in_group("player")
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _on_player_damaged(_amount: int, _new_hp: int):
	shake(6.0, 6.0)

func _on_damage_dealt(_source: Node, _target: Node, _amount: int, is_crit: bool):
	if is_crit:
		shake(3.0, 4.0)

func _process(delta):
	if target == null:
		target = get_tree().get_first_node_in_group("player")
		return
	var desired_pos = target.global_position
	global_position = global_position.lerp(desired_pos, follow_smoothing * delta)
	var viewport_size = get_viewport_rect().size
	global_position.x = clamp(global_position.x, map_bounds.position.x + viewport_size.x / 2, map_bounds.end.x - viewport_size.x / 2)
	global_position.y = clamp(global_position.y, map_bounds.position.y + viewport_size.y / 2, map_bounds.end.y - viewport_size.y / 2)

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
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_decay = decay
