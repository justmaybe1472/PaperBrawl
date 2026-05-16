# 元素武器类型，发射较慢的元素弹丸，散射角度更宽、弹速更低
extends WeaponBase
class_name WeaponElemental

# 武器精灵引用，用于播放后坐力动画
var weapon_sprite: Sprite2D

func _create_visual():
	weapon_sprite = Sprite2D.new()
	PlaceholderSprites.apply_test_texture(weapon_sprite, "Weapon_2.png", 32.0)
	# 元素武器放置在玩家前方偏下，与远程武器形成视觉对称
	weapon_sprite.position = Vector2(25, 8)
	add_child(weapon_sprite)

func attack():
	# 防御性获取玩家属性引用——对象池复用场景可能导致引用丢失
	if player_stats == null:
		_try_reacquire_stats()
		if player_stats == null:
			return
	var target_dir = _get_target_direction()
	var center_pos = global_position

	for i in range(weapon_data.projectiles):
		var dir = target_dir
		if weapon_data.projectiles > 1:
			# 0.25弧度（约14.3度）散射角——比远程的0.2更宽，体现元素扩散特性
			var spread = (i - (weapon_data.projectiles - 1.0) / 2.0) * 0.25
			dir = target_dir.rotated(spread)
		_spawn_projectile(center_pos, dir)

	EventBus.weapon_fired.emit(weapon_id, global_position, target_dir)
	# 播放后坐力动画（元素武器的反冲比远程略大——体现魔法施放的"力道"）
	_play_recoil_animation()

# 后坐力动画：武器精灵向后短暂位移再归位
func _play_recoil_animation():
	if weapon_sprite == null:
		return
	var start_pos = weapon_sprite.position
	var tween = create_tween()
	# 沿武器本地X轴负方向后退7像素（比远程-6多1px，体现更强的施法反馈）
	tween.tween_property(weapon_sprite, "position:x", start_pos.x - 7, 0.05)
	# 稍慢归位
	tween.tween_property(weapon_sprite, "position:x", start_pos.x, 0.1)

func _get_target_direction() -> Vector2:
	# 同远程武器：优先朝向最近敌人，无目标时随机方向持续射击
	var nearest = _find_nearest_enemy()
	if nearest:
		return (nearest.global_position - global_position).normalized()
	return Vector2(cos(randf() * TAU), sin(randf() * TAU))

func _find_nearest_enemy() -> Node2D:
	# 同远程武器：在射程内寻找最近的存活敌人
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
	# 从对象池获取弹丸，避免频繁创建和销毁节点的GC开销
	var proj = ObjectPool.get_projectile()
	proj.global_position = pos
	proj.direction = dir
	# 元素弹丸速度较慢（280 vs 远程350），给玩家更多时间看到特效飞行轨迹
	proj.speed = 280.0
	proj.pierce_left = weapon_data.pierce
	proj.bounce_left = weapon_data.bounce
	proj.knockback = weapon_data.knockback
	proj.weapon_data = weapon_data
	proj.attacker_stats = player_stats
	get_tree().root.add_child(proj)
