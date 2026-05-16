extends Area2D

var _armed: bool = false
var _arm_timer: float = 0.5
var _weapon_data: WeaponData
var _attacker_stats: StatsComponent
var _knockback: float = 100.0

func setup(weapon_data: WeaponData, attacker_stats: StatsComponent, knockback: float):
	_weapon_data = weapon_data
	_attacker_stats = attacker_stats
	_knockback = knockback

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	if not _armed:
		_arm_timer -= delta
		if _arm_timer <= 0.0:
			_armed = true

func _on_body_entered(body: Node2D):
	if not _armed:
		return
	if body.is_in_group("enemy") and not body.is_dead:
		# 通过 DamageSystem 正确计算暴击、目标闪避和护甲
		var result = DamageSystem.calculate_damage(_weapon_data, _attacker_stats, body.stats)
		if result["dodged"]:
			queue_free()
			return
		body.take_damage(result["damage"])
		EventBus.damage_dealt.emit(self, body, result["damage"], result["is_crit"])
		if _knockback > 0:
			var kb = (body.global_position - global_position).normalized() * _knockback
			body.apply_knockback(kb)
		queue_free()
