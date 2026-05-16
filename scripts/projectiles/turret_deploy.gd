extends Area2D

var _life: float = 8.0
var _fire_timer: float = 0.0
var _fire_rate: float = 1.5
var _weapon_data: WeaponData
var _attacker_stats: StatsComponent

func setup(lifetime: float, fire_rate: float, weapon_data: WeaponData, attacker_stats: StatsComponent):
	_life = lifetime
	_fire_rate = fire_rate
	_weapon_data = weapon_data
	_attacker_stats = attacker_stats
	_fire_timer = fire_rate * 0.3

func _process(delta):
	_life -= delta
	_fire_timer -= delta
	if _life <= 0.0:
		queue_free()
		return

	if _fire_timer <= 0.0:
		_fire_timer = _fire_rate
		var enemies = get_overlapping_bodies()
		for body in enemies:
			if body.is_in_group("enemy") and not body.is_dead:
				# 通过 DamageSystem 正确计算暴击、目标闪避和护甲
				var result = DamageSystem.calculate_damage(_weapon_data, _attacker_stats, body.stats)
				if result["dodged"]:
					break
				body.take_damage(result["damage"])
				EventBus.damage_dealt.emit(self, body, result["damage"], result["is_crit"])
				break
