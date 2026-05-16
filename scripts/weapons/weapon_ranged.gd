# 远程武器类型，向最近敌人发射弹丸，支持多发散射（霰弹效果）
extends WeaponBase
class_name WeaponRanged

func _create_visual():
	var sprite = Sprite2D.new()
	PlaceholderSprites.apply_test_texture(sprite, "Weapon_1.png", 16.0)
	# 远程武器放置在玩家前方偏上，视觉上区分于近战武器
	sprite.position = Vector2(25, -8)
	add_child(sprite)

func attack():
	# 防御性获取玩家属性引用——对象池复用场景可能导致引用丢失
	if player_stats == null:
		_try_reacquire_stats()
		if player_stats == null:
			return
	# 获取朝向最近敌人的方向，无目标时随机方向
	var target_dir = _get_target_direction()
	var center_pos = global_position

	# 根据projectiles数量发射多发弹丸，实现霰弹/连射效果
	for i in range(weapon_data.projectiles):
		var spread_angle: float = 0.0
		if weapon_data.projectiles > 1:
			# 每发弹丸均匀分布在0.2弧度（约11.5度）宽的扇形内
			spread_angle = (i - (weapon_data.projectiles - 1.0) / 2.0) * 0.2
		# 旋转基础方向向量实现散射
		var dir = target_dir.rotated(spread_angle)
		_spawn_projectile(center_pos, dir)

	EventBus.weapon_fired.emit(weapon_id, global_position, target_dir)

func _get_target_direction() -> Vector2:
	# 优先朝向最近的敌人
	var nearest = _find_nearest_enemy()
	if nearest:
		return (nearest.global_position - global_position).normalized()
	# 无可攻击目标时随机发射方向，保证武器持续有输出（不空置冷却）
	return Vector2(cos(randf() * TAU), sin(randf() * TAU))

func _find_nearest_enemy() -> Node2D:
	# 从敌人容器中获取所有敌人实例
	var container = get_tree().get_first_node_in_group("enemies_container")
	if container == null:
		return null

	var nearest: Node2D = null
	# 使用武器射程作为初始最小距离，超出射程的敌人直接排除
	var min_dist: float = weapon_data.range
	for enemy in container.get_children():
		# 跳过已死亡但尚未从场景中移除的敌人
		if enemy.has_method("is_dead") and enemy.is_dead:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _spawn_projectile(pos: Vector2, dir: Vector2):
	# 从对象池获取弹丸，避免频繁创建和销毁节点的GC开销
	var proj = ObjectPool.get_projectile()
	proj.global_position = pos
	proj.direction = dir
	# 远程弹丸速度较快（350），与元素武器（280）形成差异化
	proj.speed = 350.0
	# 将武器的穿透、弹射、击退属性传递给弹丸
	proj.pierce_left = weapon_data.pierce
	proj.bounce_left = weapon_data.bounce
	proj.knockback = weapon_data.knockback
	proj.weapon_data = weapon_data
	# 传递攻击者的属性引用以供伤害计算
	proj.attacker_stats = player_stats
	# 弹丸添加到场景根节点，使其独立于武器移动
	get_tree().root.add_child(proj)
