extends EnemyAI
class_name EnemyAIShooter

var shoot_timer: float = 0.0
var shoot_interval: float = 2.0
const PREFERRED_DISTANCE: float = 250.0
const TOO_CLOSE: float = 150.0

var projectile_scene: PackedScene

func _ready():
	super._ready()
	projectile_scene = preload("res://scenes/entities/enemy_projectile.tscn")

func get_move_direction() -> Vector2:
	if player_ref == null:
		_find_player()
		if player_ref == null:
			return Vector2.ZERO

	var owner_body = get_owner_body()
	if owner_body == null:
		return Vector2.ZERO

	var to_player = player_ref.global_position - owner_body.global_position
	var dist = to_player.length()

	if dist < TOO_CLOSE:
		return -to_player.normalized()
	elif dist > PREFERRED_DISTANCE:
		return to_player.normalized()
	else:
		_try_shoot(to_player.normalized())
		return Vector2.ZERO

func _try_shoot(direction: Vector2):
	shoot_timer -= get_process_delta_time()
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		_shoot(direction)

func _shoot(direction: Vector2):
	var owner_body = get_owner_body()
	if owner_body == null:
		return
	var proj = projectile_scene.instantiate()
	proj.global_position = owner_body.global_position
	proj.direction = direction
	proj.damage = int(enemy_data.base_damage) if enemy_data else 5
	get_tree().root.add_child(proj)
