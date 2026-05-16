class_name StatsComponent
extends Node

# 角色基础属性（从 CharacterData 读取后不再修改）
var base_stats: Dictionary = {}
# 最终计算后的当前属性（base_stats + 所有修饰器累加结果）
var current_stats: Dictionary = {}
# 统计修饰器注册表，格式：{stat_name: [{source, value}]}
var stat_modifiers: Dictionary = {}

var hp: int = 0
# 小数回血累加器：每帧累加 hp_regen*delta，满1.0时触发实际回血
var regen_accumulator: float = 0.0

func init_from_character(character_data: CharacterData):
	# 深拷贝避免修改 CharacterData 源数据，各角色实例独立
	base_stats = character_data.base_stats.duplicate(true)
	# 应用角色 max_hp_modifier（Tank x1.5 / Speedy x0.75 / Mage x0.85）
	if character_data.max_hp_modifier != 1.0:
		base_stats["max_hp"] = round(base_stats["max_hp"] * character_data.max_hp_modifier)
	current_stats = base_stats.duplicate(true)
	stat_modifiers.clear()
	hp = int(get_stat("max_hp"))  # 初始血量设为最大 HP

func get_stat(stat_name: String) -> float:
	# 返回 current_stats（已包含所有修饰器），默认为 0.0 保证安全
	return current_stats.get(stat_name, 0.0)

func add_modifier(stat_name: String, source: String, value: float):
	# 每个属性独立维护一个修饰器列表，支持同一来源添加多个修饰器
	if not stat_modifiers.has(stat_name):
		stat_modifiers[stat_name] = []
	stat_modifiers[stat_name].append({"source": source, "value": value})
	_recalculate_all()  # 每次添加后立即重算，确保属性始终正确

func remove_modifiers_from_source(source: String):
	# 按来源清除所有修饰器（如道具卖出时），然后重新计算
	for stat_name in stat_modifiers:
		stat_modifiers[stat_name] = stat_modifiers[stat_name].filter(
			func(m): return m["source"] != source
		)
	_recalculate_all()

func _recalculate_all():
	# 从 base_stats 开始，叠加所有活跃修饰器
	current_stats = base_stats.duplicate(true)
	for stat_name in stat_modifiers:
		var total_mod: float = 0.0
		for m in stat_modifiers[stat_name]:
			total_mod += m["value"]
		current_stats[stat_name] = base_stats.get(stat_name, 0.0) + total_mod
	# 闪避硬上限 60%，防止角色变为完全无敌
	current_stats["dodge"] = clamp(current_stats.get("dodge", 0.0), 0.0, 60.0)
	# 攻击速度下限 -80%，防止攻速减到负值导致行为异常
	current_stats["attack_speed"] = max(current_stats.get("attack_speed", 0.0), -80.0)

func take_damage(amount: int) -> int:
	var prev_hp = hp
	hp = max(0, hp - amount)  # 不会扣到负值
	return hp  # 返回扣血后 HP，供 UI 更新

func heal(amount: int):
	# 使用动态的 get_stat("max_hp") 而非 base_stats，确保修饰器对上限的影响也生效
	hp = min(int(get_stat("max_hp")), hp + amount)

func is_dead() -> bool:
	return hp <= 0

func _process(delta):
	# 只在波次进行中执行回血
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	# 已死亡或满血时无需回血，重置累加器防止数值溢出
	if hp <= 0 or hp >= int(get_stat("max_hp")):
		regen_accumulator = 0.0
		return
	# 累加器机制：hp_regen 可能是小数（如 0.5/秒），
	# 每秒累积，累满 1.0 时转化为 1 点实际回血
	var regen = get_stat("hp_regen")
	if regen > 0:
		regen_accumulator += regen * delta
		if regen_accumulator >= 1.0:
			var heal_amount = int(regen_accumulator)
			regen_accumulator -= heal_amount
			heal(heal_amount)
