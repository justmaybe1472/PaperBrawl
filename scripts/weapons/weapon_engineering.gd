extends WeaponBase
class_name WeaponEngineering

var deployed_nodes: Array = []

const TURRET_SCRIPT = preload("res://scripts/projectiles/turret_deploy.gd")
const MINE_SCRIPT = preload("res://scripts/projectiles/mine_deploy.gd")

func _create_visual():
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color(0.2, 0.8, 0.6), 14)
	sprite.position = Vector2(-25, 0)
	add_child(sprite)

func attack():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if weapon_id == "turret":
		_deploy_turret(player.global_position)
	elif weapon_id == "mine":
		_deploy_mine(player.global_position)
	else:
		_deploy_turret(player.global_position)

	EventBus.weapon_fired.emit(weapon_id, global_position, Vector2.ZERO)
	_cleanup_dead()

func _deploy_turret(pos: Vector2):
	var turret = Area2D.new()
	turret.collision_layer = 3
	turret.collision_mask = 2
	turret.global_position = pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))

	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.CYAN, 16.0)
	turret.add_child(sprite)

	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = weapon_data.range
	turret.add_child(shape)

	turret.set_script(TURRET_SCRIPT)
	var lifetime: float = 8.0 + player_stats.get_stat("engineering") * 0.1
	var fire_rate: float = max(0.3, weapon_data.cooldown / 2.0)
	var turret_damage: float = weapon_data.base_damage * (1.0 + player_stats.get_stat("engineering") / 100.0)
	turret.setup(lifetime, fire_rate, turret_damage, weapon_data.range)

	get_tree().root.add_child(turret)
	deployed_nodes.append(turret)

func _deploy_mine(pos: Vector2):
	var mine = Area2D.new()
	mine.collision_layer = 3
	mine.collision_mask = 2
	mine.global_position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.ORANGE_RED, 12.0)
	mine.add_child(sprite)

	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = weapon_data.range
	mine.add_child(shape)

	mine.set_script(MINE_SCRIPT)
	var mine_damage: float = weapon_data.base_damage * (1.0 + player_stats.get_stat("engineering") / 50.0)
	mine.setup(mine_damage, weapon_data.knockback)

	get_tree().root.add_child(mine)
	deployed_nodes.append(mine)

func _cleanup_dead():
	for i in range(deployed_nodes.size() - 1, -1, -1):
		if not is_instance_valid(deployed_nodes[i]):
			deployed_nodes.remove_at(i)
