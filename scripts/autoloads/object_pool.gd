extends Node

# Pools for each object type
var _enemy_pools: Dictionary = {}       # enemy_type -> Array[EnemyBase]
var _projectile_pool: Array = []        # Array[PlayerProjectile]
var _enemy_projectile_pool: Array = []  # Array[Area2D]
var _pickup_pool: Array = []            # Array[Area2D]

# Preload scenes
var _enemy_scene: PackedScene
var _projectile_scene: PackedScene
var _enemy_projectile_scene: PackedScene
var _pickup_scene: PackedScene

# Stats
var _total_allocated: int = 0
var _total_reused: int = 0

func _ready():
	_enemy_scene = load("res://scenes/entities/enemy_base.tscn")
	_projectile_scene = load("res://scenes/entities/projectile_base.tscn")
	_enemy_projectile_scene = load("res://scenes/entities/enemy_projectile.tscn")
	_pickup_scene = load("res://scenes/entities/pickup.tscn")

func get_enemy(enemy_type: String) -> EnemyBase:
	var enemy: EnemyBase
	var key = enemy_type
	if _enemy_pools.has(key) and not _enemy_pools[key].is_empty():
		enemy = _enemy_pools[key].pop_back()
		_total_reused += 1
	else:
		enemy = _enemy_scene.instantiate()
		_total_allocated += 1

	enemy.is_dead = false
	enemy.visible = true
	enemy.set_process(true)
	enemy.set_physics_process(true)
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	return enemy

func return_enemy(enemy: EnemyBase, enemy_type: String):
	if not is_instance_valid(enemy):
		return
	enemy.visible = false
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if enemy.get_parent():
		enemy.get_parent().remove_child(enemy)
	if not _enemy_pools.has(enemy_type):
		_enemy_pools[enemy_type] = []
	_enemy_pools[enemy_type].append(enemy)

func get_projectile() -> PlayerProjectile:
	var proj: PlayerProjectile
	if not _projectile_pool.is_empty():
		proj = _projectile_pool.pop_back()
		_total_reused += 1
	else:
		proj = _projectile_scene.instantiate()
		# Initialize visuals once for new projectiles
		_init_projectile_visuals(proj)
		_total_allocated += 1

	proj.visible = true
	proj.set_process(true)
	proj.process_mode = Node.PROCESS_MODE_INHERIT
	proj.monitoring = true
	proj.lifetime = 3.0
	return proj

func return_projectile(proj: PlayerProjectile):
	if not is_instance_valid(proj):
		return
	proj.visible = false
	proj.set_process(false)
	proj.process_mode = Node.PROCESS_MODE_DISABLED
	proj.monitoring = false
	if proj.get_parent():
		proj.get_parent().remove_child(proj)
	_projectile_pool.append(proj)

func get_pickup() -> Area2D:
	var pickup: Area2D
	if not _pickup_pool.is_empty():
		pickup = _pickup_pool.pop_back()
		_total_reused += 1
	else:
		pickup = _pickup_scene.instantiate()
		_init_pickup_visuals(pickup)
		_total_allocated += 1

	pickup.visible = true
	pickup.set_process(true)
	pickup.process_mode = Node.PROCESS_MODE_INHERIT
	pickup.monitoring = true
	return pickup

func return_pickup(pickup: Area2D):
	if not is_instance_valid(pickup):
		return
	pickup.visible = false
	pickup.set_process(false)
	pickup.process_mode = Node.PROCESS_MODE_DISABLED
	pickup.monitoring = false
	if pickup.get_parent():
		pickup.get_parent().remove_child(pickup)
	_pickup_pool.append(pickup)

func get_enemy_projectile() -> Area2D:
	var proj: Area2D
	if not _enemy_projectile_pool.is_empty():
		proj = _enemy_projectile_pool.pop_back()
		_total_reused += 1
	else:
		proj = _enemy_projectile_scene.instantiate()
		_init_enemy_projectile_visuals(proj)
		_total_allocated += 1

	proj.visible = true
	proj.set_process(true)
	proj.process_mode = Node.PROCESS_MODE_INHERIT
	proj.monitoring = true
	return proj

func return_enemy_projectile(proj: Area2D):
	if not is_instance_valid(proj):
		return
	proj.visible = false
	proj.set_process(false)
	proj.process_mode = Node.PROCESS_MODE_DISABLED
	proj.monitoring = false
	if proj.get_parent():
		proj.get_parent().remove_child(proj)
	_enemy_projectile_pool.append(proj)

func _init_enemy_projectile_visuals(proj: Area2D):
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.RED, 10.0)
	proj.add_child(sprite)
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 5.0
	proj.add_child(shape)

func _init_projectile_visuals(proj: PlayerProjectile):
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.YELLOW, 8.0)
	proj.add_child(sprite)
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 4.0
	proj.add_child(shape)

func _init_pickup_visuals(pickup: Area2D):
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.GREEN, 12.0)
	pickup.add_child(sprite)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	pickup.add_child(shape)

func get_pool_stats() -> Dictionary:
	return {
		"total_allocated": _total_allocated,
		"total_reused": _total_reused,
		"projectile_pool_size": _projectile_pool.size(),
		"pickup_pool_size": _pickup_pool.size(),
		"enemy_pools": _enemy_pools.keys().map(func(k): return {"type": k, "size": _enemy_pools[k].size()}),
	}

func clear_all():
	for pool in _enemy_pools.values():
		for enemy in pool:
			if is_instance_valid(enemy):
				enemy.queue_free()
	_enemy_pools.clear()
	for proj in _projectile_pool:
		if is_instance_valid(proj):
			proj.queue_free()
	_projectile_pool.clear()
	for proj in _enemy_projectile_pool:
		if is_instance_valid(proj):
			proj.queue_free()
	_enemy_projectile_pool.clear()
	for pickup in _pickup_pool:
		if is_instance_valid(pickup):
			pickup.queue_free()
	_pickup_pool.clear()
	_total_allocated = 0
	_total_reused = 0
