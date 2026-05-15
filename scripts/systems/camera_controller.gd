extends Camera2D

@export var follow_smoothing: float = 5.0
var target: Node2D
var map_bounds: Rect2 = Rect2(0, 0, 1920, 1080)

func _ready():
	target = get_tree().get_first_node_in_group("player")

func _process(delta):
	if target == null:
		target = get_tree().get_first_node_in_group("player")
		return
	var desired_pos = target.global_position
	global_position = global_position.lerp(desired_pos, follow_smoothing * delta)
	var viewport_size = get_viewport_rect().size
	global_position.x = clamp(global_position.x, map_bounds.position.x + viewport_size.x / 2, map_bounds.end.x - viewport_size.x / 2)
	global_position.y = clamp(global_position.y, map_bounds.position.y + viewport_size.y / 2, map_bounds.end.y - viewport_size.y / 2)
