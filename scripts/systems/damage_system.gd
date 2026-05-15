class_name DamageSystem
extends RefCounted

static func calculate_damage(weapon_data: WeaponData, attacker_stats, target_stats) -> Dictionary:
	var damage: float = weapon_data.base_damage

	# Global damage %
	damage *= (1.0 + attacker_stats.get_stat("damage_pct") / 100.0)

	# Type-specific damage
	match weapon_data.weapon_class:
		"melee":
			damage += attacker_stats.get_stat("melee_damage")
		"ranged":
			damage += attacker_stats.get_stat("ranged_damage")
		"elemental":
			damage += attacker_stats.get_stat("elemental_damage")
		"engineering":
			damage *= (1.0 + attacker_stats.get_stat("engineering") / 100.0)

	# Crit check
	var is_crit: bool = false
	var crit_roll: float = randf() * 100.0
	var total_crit: float = attacker_stats.get_stat("crit_chance")
	var luck: float = attacker_stats.get_stat("luck")
	if crit_roll < total_crit or (luck > 0 and randf() * 100.0 < luck / 10.0):
		is_crit = true
		damage *= weapon_data.crit_multiplier

	# Target dodge
	var dodge_roll: float = randf() * 100.0
	if dodge_roll < target_stats.get_stat("dodge"):
		return {"damage": 0, "is_crit": false, "dodged": true}

	# Target armor
	var armor: float = target_stats.get_stat("armor")
	var armor_reduction: float = armor / (armor + 100.0)
	armor_reduction = min(armor_reduction, 0.9)

	var final_damage: float = damage * (1.0 - armor_reduction)
	final_damage = max(1.0, roundi(final_damage))

	return {"damage": int(final_damage), "is_crit": is_crit, "dodged": false}
