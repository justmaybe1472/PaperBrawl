class_name PlayerProjectile
extends Area2D

# 弹丸飞行方向，默认向右，发射时由武器逻辑重新赋值
var direction: Vector2 = Vector2.RIGHT
# 飞行速度（像素/秒），发射时可由武器数据覆盖
var speed: float = 300.0
# 基础伤害值，实际伤害在命中时通过 DamageSystem 重新计算
var damage: float = 5.0
# 剩余穿透次数：>0 时命中敌人不销毁，继续飞行
var pierce_left: int = 0
# 剩余弹射次数：穿透耗尽后才触发，自动寻找附近敌人转向
var bounce_left: int = 0
# 击退力度，命中时将敌人沿弹道方向推开
var knockback: float = 50.0
# 弹丸存活时间，超时自动回收进对象池
var lifetime: float = 3.0
# 是否暴击，由 DamageSystem 命中计算后写入
var is_crit: bool = false
# 引用武器配置数据，供命中时 DamageSystem 使用
var weapon_data: WeaponData
# 引用攻击者的属性组件，供命中时计算伤害加成和吸血
var attacker_stats: StatsComponent

func _ready():
	# 连接 Area2D 的 body_entered 信号，检测与物理体的碰撞
	body_entered.connect(_on_body_entered)
	# 设置碰撞层级：layer=3 表示弹丸属于玩家弹幕层，mask=2 表示只检测敌人层
	collision_layer = 3
	collision_mask = 2

func _process(delta):
	# 每帧扣减剩余存活时间
	lifetime -= delta
	# 超时则回收到对象池，避免无限飞行的弹丸泄漏
	if lifetime <= 0.0:
		ObjectPool.return_projectile(self)
		return
	# 沿当前方向匀速移动
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D):
	# 只对 enemy 分组的物体生效，忽略墙壁等其他碰撞
	if not body.is_in_group("enemy"):
		return
	# 安全转换，跳过已死亡的敌人（防止重复命中尸体）
	var enemy = body as EnemyBase
	if enemy == null or enemy.is_dead:
		return

	# 命中时重新调用 DamageSystem 计算最终伤害，传入真实敌人的属性以正确计算闪避和护甲
	var dmg_result = DamageSystem.calculate_damage(weapon_data, attacker_stats, enemy.stats)
	# 若被闪避则直接返回，弹丸继续存活（穿透/弹射不受闪避影响）
	if dmg_result["dodged"]:
		return
	var final_damage: int = dmg_result["damage"]
	var final_is_crit: bool = dmg_result["is_crit"]

	# 对敌人施加伤害并通过全局事件总线通知其他系统（音效、数值显示等）
	enemy.take_damage(final_damage)
	EventBus.damage_dealt.emit(self, enemy, final_damage, final_is_crit)

	# 击退：沿弹丸飞行方向推开敌人，力度由 knockback 决定
	if knockback > 0:
		var kb_dir = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(kb_dir * knockback)

	# 吸血：按攻击者的生命偷取属性概率触发，回复最终伤害的10%
	if attacker_stats:
		var lifesteal = attacker_stats.get_stat("life_steal")
		if lifesteal > 0 and randf() * 100.0 < lifesteal:
			var heal_amount = max(1, int(final_damage * 0.1))
			attacker_stats.heal(heal_amount)

	# 弹丸消亡逻辑：优先穿透 -> 其次弹射 -> 最后回收
	if pierce_left > 0:
		pierce_left -= 1
	elif bounce_left > 0:
		bounce_left -= 1
		# 弹射时寻找范围内最近的敌人并改变飞行方向
		var nearby = _find_nearest_enemy(body.global_position)
		if nearby:
			direction = (nearby.global_position - global_position).normalized()
		else:
			ObjectPool.return_projectile(self)
	else:
		ObjectPool.return_projectile(self)

# 弹射时在500像素范围内寻找最近的存活敌人作为下一目标
func _find_nearest_enemy(pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var min_dist: float = 500.0
	# 通过 enemies_container 分组获取所有敌人，避免全场景遍历
	var container = get_tree().get_first_node_in_group("enemies_container")
	if container == null:
		return null
	for enemy in container.get_children():
		if enemy.is_dead:
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest
