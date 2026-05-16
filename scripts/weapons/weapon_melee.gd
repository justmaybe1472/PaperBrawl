# 近战武器类型，通过Area2D短暂启用碰撞检测来实现"挥砍"效果
extends WeaponBase
class_name WeaponMelee

# Area2D节点用于检测近战攻击范围内的敌人碰撞
@onready var melee_area: Area2D = $MeleeArea
# 武器精灵引用，用于播放攻击动画
var weapon_sprite: Sprite2D
# 攻击计数器，交替切换挥砍和突刺动画
var _attack_variant: int = 0

func _ready():
	# 先执行父类的数据加载和冷却初始化
	super._ready()
	# 连接碰撞信号：当敌人进入攻击区域时触发伤害处理
	melee_area.body_entered.connect(_on_melee_hit)

func _create_visual():
	weapon_sprite = Sprite2D.new()
	PlaceholderSprites.apply_test_texture(weapon_sprite, "Weapon_3.png", 40.0)
	# 近战武器放置在玩家前方30像素处，让碰撞区域覆盖攻击范围
	weapon_sprite.position = Vector2(30, 0)
	add_child(weapon_sprite)

func attack():
	# 防御性获取玩家属性引用——对象池复用场景可能导致引用丢失
	if player_stats == null:
		_try_reacquire_stats()
		if player_stats == null:
			return
	EventBus.weapon_fired.emit(weapon_id, global_position, Vector2.ZERO)
	# 播放攻击动画：交替挥砍和突刺
	if _attack_variant == 0:
		_play_slash_animation()
	else:
		_play_thrust_animation()
	_attack_variant = (_attack_variant + 1) % 2
	# 短暂开启碰撞监控，模拟"挥砍"的命中时间窗口
	melee_area.monitoring = true
	# 0.15秒后关闭碰撞检测——这是近战攻击的有效判定帧数
	await get_tree().create_timer(0.15).timeout
	melee_area.monitoring = false

# 挥砍动画：武器精灵围绕Z轴快速旋转（模拟横向挥砍）
func _play_slash_animation():
	if weapon_sprite == null:
		return
	var tween = create_tween()
	# 第一阶段：快速旋转到90度（约0.08秒），代表挥砍挥舞
	tween.tween_property(weapon_sprite, "rotation", deg_to_rad(80), 0.08)
	# 第二阶段：稍慢归位（约0.12秒），模拟收刀
	tween.tween_property(weapon_sprite, "rotation", 0.0, 0.12)

# 突刺动画：武器精灵向前突进再收回（模拟刺击）
func _play_thrust_animation():
	if weapon_sprite == null:
		return
	var start_pos = weapon_sprite.position
	var tween = create_tween()
	# 沿武器本地X轴向前突刺15像素
	tween.tween_property(weapon_sprite, "position:x", start_pos.x + 20, 0.06)
	# 收回原位
	tween.tween_property(weapon_sprite, "position:x", start_pos.x, 0.1)

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
