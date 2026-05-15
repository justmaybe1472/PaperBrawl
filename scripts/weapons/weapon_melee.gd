extends WeaponBase
class_name WeaponMelee

@onready var melee_area: Area2D = $MeleeArea

func _ready():
	super._ready()
	melee_area.body_entered.connect(_on_melee_hit)

func attack():
	EventBus.weapon_fired.emit(weapon_id, global_position, Vector2.ZERO)
	melee_area.monitoring = true
	await get_tree().create_timer(0.15).timeout
	melee_area.monitoring = false

func _on_melee_hit(body: Node2D):
	if not body.is_in_group("enemy"):
		return
	var enemy = body as EnemyBase
	if enemy == null:
		return

	var result = DamageSystem.calculate_damage(weapon_data, player_stats, enemy.stats)
	if result["dodged"]:
		return

	enemy.take_damage(result["damage"])
	EventBus.damage_dealt.emit(self, enemy, result["damage"], result["is_crit"])

	if weapon_data.knockback > 0:
		var knockback_dir = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(knockback_dir * weapon_data.knockback)
