# 工程武器类型，在地图上部署独立运行的炮台或地雷，拥有自己的生命周期
extends WeaponBase
class_name WeaponEngineering

# 追踪所有已部署的构造物节点，用于在它们销毁后清理引用
var deployed_nodes: Array = []

# 预加载脚本资源，避免每次部署时重复加载的开销
const TURRET_SCRIPT = preload("res://scripts/projectiles/turret_deploy.gd")
const MINE_SCRIPT = preload("res://scripts/projectiles/mine_deploy.gd")

# 武器精灵引用，用于播放部署动画
var weapon_sprite: Sprite2D

func _create_visual():
	weapon_sprite = Sprite2D.new()
	PlaceholderSprites.apply_test_texture(weapon_sprite, "Weapon_4.png", 28.0)
	# 工程武器放置在玩家左侧，与其他武器方向区分（近战右上、远程左上、元素左下）
	weapon_sprite.position = Vector2(-25, 0)
	add_child(weapon_sprite)

func attack():
	# 获取玩家位置以在周围随机部署构造物
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# 根据武器ID分派到不同的部署逻辑（炮台或地雷）
	if weapon_id == "turret":
		_deploy_turret(player.global_position)
	elif weapon_id == "mine":
		_deploy_mine(player.global_position)
	else:
		# 未知ID时默认部署炮台，避免静默失败
		_deploy_turret(player.global_position)

	EventBus.weapon_fired.emit(weapon_id, global_position, Vector2.ZERO)
	# 播放部署动画（武器精灵缩放脉冲）
	_play_deploy_animation()
	# 每次攻击后清理已销毁的构造物引用，防止数组无限增长
	_cleanup_dead()

# 部署动画：武器精灵短暂缩放脉冲（模拟"放置"动作）
func _play_deploy_animation():
	if weapon_sprite == null:
		return
	var tween = create_tween()
	# 先缩小到80%再弹回100%
	tween.tween_property(weapon_sprite, "scale", Vector2(0.8, 0.8), 0.08)
	tween.tween_property(weapon_sprite, "scale", Vector2(1.0, 1.0), 0.12)

func _deploy_turret(pos: Vector2):
	var turret = Area2D.new()
	# layer=4（bit 3）表示玩家方实体，mask=2（bit 1）只检测敌人
	turret.collision_layer = 3
	turret.collision_mask = 2
	# 在玩家周围40像素半径内随机位置部署，避免所有炮台堆叠在一起
	turret.global_position = pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))

	var sprite = Sprite2D.new()
	# 用青色方块作为炮台的临时视觉占位
	sprite.texture = PlaceholderSprites.make_square_texture(Color.CYAN, 16.0)
	turret.add_child(sprite)

	# 炮台的检测范围由武器射程数据决定
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = weapon_data.range
	turret.add_child(shape)

	# 将预加载的炮台脚本附加到此Area2D实例上
	turret.set_script(TURRET_SCRIPT)
	# 工程属性越高炮台持续时间越长（每点+0.1秒），体现属性成长
	var lifetime: float = 8.0 + player_stats.get_stat("engineering") * 0.1
	# 炮台射速是本体武器的一半，避免炮台输出过高
	var fire_rate: float = max(0.3, weapon_data.cooldown / 2.0)
	turret.setup(lifetime, fire_rate, weapon_data, player_stats)

	# 添加到场景根节点使炮台独立于武器运行
	get_tree().root.add_child(turret)
	deployed_nodes.append(turret)
	# 部署动画：从0缩放到1（弹出效果）
	_animate_deployed_entity(sprite)

func _deploy_mine(pos: Vector2):
	var mine = Area2D.new()
	# layer=4、mask=2：地雷检测敌人的碰撞层配置与炮台一致
	mine.collision_layer = 3
	mine.collision_mask = 2
	# 在玩家周围30像素半径内随机放置地雷
	mine.global_position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	var sprite = Sprite2D.new()
	# 用橙红色方块作为地雷的临时视觉占位
	sprite.texture = PlaceholderSprites.make_square_texture(Color.ORANGE_RED, 12.0)
	mine.add_child(sprite)

	# 地雷的触发范围由武器射程数据决定
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = weapon_data.range
	mine.add_child(shape)

	mine.set_script(MINE_SCRIPT)
	# 传入击退值作为最大击退距离
	mine.setup(weapon_data, player_stats, weapon_data.knockback)

	# 添加到场景根节点使地雷独立于武器运行
	get_tree().root.add_child(mine)
	deployed_nodes.append(mine)
	# 部署动画：从0缩放到1（弹出效果）
	_animate_deployed_entity(sprite)

# 部署实体的弹出动画：从0缩放到1（约0.15秒）
func _animate_deployed_entity(entity_sprite: Sprite2D):
	if entity_sprite == null:
		return
	entity_sprite.scale = Vector2(0.01, 0.01)
	var tween = entity_sprite.create_tween()
	tween.tween_property(entity_sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _cleanup_dead():
	# 从后往前遍历删除无效节点引用，防止移除元素时索引错乱
	for i in range(deployed_nodes.size() - 1, -1, -1):
		if not is_instance_valid(deployed_nodes[i]):
			deployed_nodes.remove_at(i)
