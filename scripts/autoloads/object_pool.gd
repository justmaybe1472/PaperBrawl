extends Node

# 通用对象池：避免频繁 instantiate/free 带来的GC压力，复用高频生成的游戏对象

# 各类型对象池容器
var _enemy_pools: Dictionary = {}       # enemy_type -> Array[EnemyBase]，按敌人类型分池避免错误复用
var _projectile_pool: Array = []        # Array[PlayerProjectile]，玩家弹幕池
var _enemy_projectile_pool: Array = []  # Array[Area2D]，敌方弹幕池
var _pickup_pool: Array = []            # Array[Area2D]，掉落物池

# 预加载场景资源：在 _ready 中一次性加载，避免运行时磁盘IO
var _enemy_scene: PackedScene
var _projectile_scene: PackedScene
var _enemy_projectile_scene: PackedScene
var _pickup_scene: PackedScene

# 池性能统计：用于调试与优化
var _total_allocated: int = 0  # 累计新建实例数
var _total_reused: int = 0     # 累计复用实例数

func _ready():
	# 预加载所有场景模板，后续 instantiate 仅做内存拷贝
	_enemy_scene = load("res://scenes/entities/enemy_base.tscn")
	_projectile_scene = load("res://scenes/entities/projectile_base.tscn")
	_enemy_projectile_scene = load("res://scenes/entities/enemy_projectile.tscn")
	_pickup_scene = load("res://scenes/entities/pickup.tscn")

func get_enemy(enemy_type: String) -> EnemyBase:
	# 从敌人池获取实例：池中有则复用，无则新建
	var enemy: EnemyBase
	var key = enemy_type
	if _enemy_pools.has(key) and not _enemy_pools[key].is_empty():
		enemy = _enemy_pools[key].pop_back()
		_total_reused += 1
	else:
		enemy = _enemy_scene.instantiate()
		_total_allocated += 1

	# 激活节点：恢复可见性、启用处理、继承父节点处理模式
	enemy.is_dead = false
	enemy.visible = true
	enemy.set_process(true)
	enemy.set_physics_process(true)
	enemy.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)  # 延迟设置避免在物理帧内冲突
	return enemy

func return_enemy(enemy: EnemyBase, enemy_type: String):
	# 归还敌人到池：禁用所有处理以节省CPU，从场景树移除，加入对应类型池
	if not is_instance_valid(enemy):
		return
	# 休眠节点：隐藏、停用 _process/_physics_process
	enemy.visible = false
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)  # 完全禁用处理，节省每帧开销
	# 安全从场景树移除（延迟调用避免在遍历期间修改树结构）
	if enemy.get_parent():
		enemy.get_parent().call_deferred("remove_child", enemy)
	# 按类型分池存储
	if not _enemy_pools.has(enemy_type):
		_enemy_pools[enemy_type] = []
	_enemy_pools[enemy_type].append(enemy)

func get_projectile() -> PlayerProjectile:
	# 获取玩家弹幕：复用逻辑同敌人池，首次新建时还需要初始化视觉节点
	var proj: PlayerProjectile
	if not _projectile_pool.is_empty():
		proj = _projectile_pool.pop_back()
		_total_reused += 1
	else:
		proj = _projectile_scene.instantiate()
		_init_projectile_visuals(proj)  # 仅在新建时附加视觉组件
		_total_allocated += 1

	# 激活弹幕：显示、启用处理和碰撞监测
	proj.visible = true
	proj.set_process(true)
	proj.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	proj.set_deferred("monitoring", true)  # 启用 Area2D 碰撞监测
	proj.lifetime = 3.0  # 弹幕存活时间，防止无限飞行
	return proj

func return_projectile(proj: PlayerProjectile):
	# 归还玩家弹幕：停用监测与处理，确保不继续参与碰撞
	if not is_instance_valid(proj):
		return
	proj.visible = false
	proj.set_process(false)
	proj.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	proj.set_deferred("monitoring", false)  # 必须关闭监测，否则池中弹幕会误触发碰撞
	if proj.get_parent():
		proj.get_parent().call_deferred("remove_child", proj)
	_projectile_pool.append(proj)

func get_pickup() -> Area2D:
	# 获取掉落物：模式与弹幕池完全一致
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
	pickup.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	pickup.set_deferred("monitoring", true)
	return pickup

func return_pickup(pickup: Area2D):
	# 归还掉落物
	if not is_instance_valid(pickup):
		return
	pickup.visible = false
	pickup.set_process(false)
	pickup.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	pickup.set_deferred("monitoring", false)
	if pickup.get_parent():
		pickup.get_parent().call_deferred("remove_child", pickup)
	_pickup_pool.append(pickup)

func get_enemy_projectile() -> Area2D:
	# 获取敌方弹幕：逻辑同玩家弹幕，颜色为红色以示区分
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
	proj.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	proj.set_deferred("monitoring", true)
	return proj

func return_enemy_projectile(proj: Area2D):
	# 归还敌方弹幕
	if not is_instance_valid(proj):
		return
	proj.visible = false
	proj.set_process(false)
	proj.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	proj.set_deferred("monitoring", false)
	if proj.get_parent():
		proj.get_parent().call_deferred("remove_child", proj)
	_enemy_projectile_pool.append(proj)

# 以下 _init_*_visuals 仅在新实例化时调用一次，复用对象无需重复添加子节点
func _init_enemy_projectile_visuals(proj: Area2D):
	# 敌方弹幕：红色方形贴图 + 圆形碰撞体（半径5px）
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.RED, 10.0)
	proj.add_child(sprite)
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 5.0
	proj.add_child(shape)

func _init_projectile_visuals(proj: PlayerProjectile):
	# 玩家弹幕：黄色方形贴图 + 圆形碰撞体（半径4px）
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.YELLOW, 8.0)
	proj.add_child(sprite)
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 4.0
	proj.add_child(shape)

func _init_pickup_visuals(pickup: Area2D):
	# 掉落物：绿色方形贴图 + 圆形碰撞体（半径8px）
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.GREEN, 12.0)
	pickup.add_child(sprite)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	pickup.add_child(shape)

func get_pool_stats() -> Dictionary:
	# 返回池使用情况统计，用于调试面板展示复用率
	return {
		"total_allocated": _total_allocated,
		"total_reused": _total_reused,
		"projectile_pool_size": _projectile_pool.size(),
		"pickup_pool_size": _pickup_pool.size(),
		"enemy_pools": _enemy_pools.keys().map(func(k): return {"type": k, "size": _enemy_pools[k].size()}),
	}

func clear_all():
	# 清空所有对象池：释放所有池中节点，通常用于返回主菜单或重置场景
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
