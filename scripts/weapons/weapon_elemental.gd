extends WeaponBase
class_name WeaponElemental

var projectile_scene: PackedScene

func _ready():
	super._ready()
	projectile_scene = load("res://scenes/entities/projectile_base.tscn")

func attack():
	var target_dir = _get_target_direction()
	var center_pos = global_position

	for i in range(weapon_data.projectiles):
		var dir = target_dir
		if weapon_data.projectiles > 1:
			var spread = (i - (weapon_data.projectiles - 1.0) / 2.0) * 0.25
			dir = target_dir.rotated(spread)
		_spawn_projectile(center_pos, dir)

	EventBus.weapon_fired.emit(weapon_id, global_position, target_dir)

func _get_target_direction() -> Vector2:
	var nearest = _find_nearest_enemy()
	if nearest:
		return (nearest.global_position - global_position).normalized()
	return Vector2(cos(randf() * TAU), sin(randf() * TAU))

func _find_nearest_enemy() -> Node2D:
	var container = get_tree().get_first_node_in_group("enemies_container")
	if container == null:
		return null

	var nearest: Node2D = null
	var min_dist: float = weapon_data.range
	for enemy in container.get_children():
		if enemy.has_method("is_dead") and enemy.is_dead:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _spawn_projectile(pos: Vector2, dir: Vector2):
	var proj = projectile_scene.instantiate()
	proj.global_position = pos
	proj.direction = dir
	proj.speed = 280.0
	proj.pierce_left = weapon_data.pierce
	proj.bounce_left = weapon_data.bounce
	proj.knockback = weapon_data.knockback
	proj.weapon_data = weapon_data
	proj.attacker_stats = player_stats

	var result = DamageSystem.calculate_damage(weapon_data, player_stats, null)
	proj.damage = result["damage"]
	proj.is_crit = result["is_crit"]

	get_tree().root.add_child(proj)
