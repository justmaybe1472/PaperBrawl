class_name DamageSystem
extends RefCounted

# 核心伤害计算：根据武器数据、攻击者属性、目标属性，返回包含最终伤害、暴击标志、闪避标志的字典
static func calculate_damage(weapon_data: WeaponData, attacker_stats, target_stats) -> Dictionary:
	var damage: float = weapon_data.base_damage

	# 全局伤害百分比加成 — 所有武器类型通用的倍率加成
	damage *= (1.0 + attacker_stats.get_stat("damage_pct") / 100.0)

	# 根据武器类型应用不同的伤害加成方式 — 近战/远程/元素为固定值叠加，工程为百分比乘算
	match weapon_data.weapon_class:
		"melee":
			damage += attacker_stats.get_stat("melee_damage")
		"ranged":
			damage += attacker_stats.get_stat("ranged_damage")
		"elemental":
			damage += attacker_stats.get_stat("elemental_damage")
		"engineering":
			damage *= (1.0 + attacker_stats.get_stat("engineering") / 100.0)

	# 暴击判定 — 先按暴击率判定，幸运值提供第二次判定机会（幸运/10的概率）
	var is_crit: bool = false
	var crit_roll: float = randf() * 100.0
	var total_crit: float = attacker_stats.get_stat("crit_chance")
	var luck: float = attacker_stats.get_stat("luck")
	if crit_roll < total_crit or (luck > 0 and randf() * 100.0 < luck / 10.0):
		is_crit = true
		damage *= weapon_data.crit_multiplier

	# 目标闪避/护甲计算 — 仅在有 target_stats 时计算，否则跳过（如弹幕预计算）
	if target_stats != null:
		# 闪避判定：投骰子与目标闪避率比较，闪避成功则返回0伤害
		var dodge_roll: float = randf() * 100.0
		if dodge_roll < target_stats.get_stat("dodge"):
			return {"damage": 0, "is_crit": false, "dodged": true}

		# 护甲减伤公式：armor / (armor + 100)，上限90%减伤
		var armor: float = target_stats.get_stat("armor")
		var armor_reduction: float = armor / (armor + 100.0)
		armor_reduction = min(armor_reduction, 0.9)
		damage = damage * (1.0 - armor_reduction)

	# 最终伤害取整，保底1点伤害，确保任何命中都有意义
	var final_damage: float = max(1.0, roundi(damage))

	return {"damage": int(final_damage), "is_crit": is_crit, "dodged": false}
