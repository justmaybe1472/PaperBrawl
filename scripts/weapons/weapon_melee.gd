# 近战武器类型，通过Area2D短暂启用碰撞检测来实现"挥砍"效果
extends WeaponBase
class_name WeaponMelee

# Area2D节点用于检测近战攻击范围内的敌人碰撞
@onready var melee_area: Area2D = $MeleeArea

func _ready():
	# 先执行父类的数据加载和冷却初始化
	super._ready()
	# 连接碰撞信号：当敌人进入攻击区域时触发伤害处理
	melee_area.body_entered.connect(_on_melee_hit)

func _create_visual():
	var sprite = Sprite2D.new()
	PlaceholderSprites.apply_test_texture(sprite, "Weapon_3.png", 40.0)
	# 近战武器放置在玩家前方30像素处，让碰撞区域覆盖攻击范围
	sprite.position = Vector2(30, 0)
	add_child(sprite)

func attack():
	# 防御性获取玩家属性引用——对象池复用场景可能导致引用丢失
	if player_stats == null:
		_try_reacquire_stats()
		if player_stats == null:
			return
	EventBus.weapon_fired.emit(weapon_id, global_position, Vector2.ZERO)
	# 短暂开启碰撞监控，模拟"挥砍"的命中时间窗口
	melee_area.monitoring = true
	# 0.15秒后关闭碰撞检测——这是近战攻击的有效判定帧数
	await get_tree().create_timer(0.15).timeout
	melee_area.monitoring = false

func _on_melee_hit(body: Node2D):
	# 只处理敌人组中的碰撞体，忽略其他物理对象
	if not body.is_in_group("enemy"):
		return
	# 安全转型为EnemyBase，防止非敌人节点进入但未分组的异常情况
	var enemy = body as EnemyBase
	if enemy == null:
		return

	# 通过伤害系统完整计算伤害（含暴击率、护甲削减等）
	var result = DamageSystem.calculate_damage(weapon_data, player_stats, enemy.stats)
	# 敌人闪避时完全不造成伤害
	if result["dodged"]:
		return

	enemy.take_damage(result["damage"])
	# 通知事件总线，供UI或特效系统响应
	EventBus.damage_dealt.emit(self, enemy, result["damage"], result["is_crit"])

	# 吸血机制：基于概率触发，伤害的10%转化为生命值
	var lifesteal = player_stats.get_stat("life_steal")
	if lifesteal > 0 and randf() * 100.0 < lifesteal:
		# 吸血量至少为1点，保证低伤害时也能获得有效回复
		var heal_amount = max(1, int(result["damage"] * 0.1))
		player_stats.heal(heal_amount)

	# 击退效果：方向从武器指向敌人
	if weapon_data.knockback > 0:
		var knockback_dir = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(knockback_dir * weapon_data.knockback)
