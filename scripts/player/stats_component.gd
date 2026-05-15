class_name StatsComponent
extends Node

var base_stats: Dictionary = {}
var current_stats: Dictionary = {}
var stat_modifiers: Dictionary = {}

var hp: int = 0
var regen_accumulator: float = 0.0

func init_from_character(character_data: CharacterData):
	base_stats = character_data.base_stats.duplicate(true)
	current_stats = base_stats.duplicate(true)
	stat_modifiers.clear()
	hp = int(get_stat("max_hp"))

func get_stat(stat_name: String) -> float:
	return current_stats.get(stat_name, 0.0)

func add_modifier(stat_name: String, source: String, value: float):
	if not stat_modifiers.has(stat_name):
		stat_modifiers[stat_name] = []
	stat_modifiers[stat_name].append({"source": source, "value": value})
	_recalculate_all()

func remove_modifiers_from_source(source: String):
	for stat_name in stat_modifiers:
		stat_modifiers[stat_name] = stat_modifiers[stat_name].filter(
			func(m): return m["source"] != source
		)
	_recalculate_all()

func _recalculate_all():
	current_stats = base_stats.duplicate(true)
	for stat_name in stat_modifiers:
		var total_mod: float = 0.0
		for m in stat_modifiers[stat_name]:
			total_mod += m["value"]
		current_stats[stat_name] = base_stats.get(stat_name, 0.0) + total_mod
	current_stats["dodge"] = clamp(current_stats.get("dodge", 0.0), 0.0, 60.0)
	current_stats["attack_speed"] = max(current_stats.get("attack_speed", 0.0), -80.0)

func take_damage(amount: int) -> int:
	var prev_hp = hp
	hp = max(0, hp - amount)
	return hp

func heal(amount: int):
	hp = min(int(get_stat("max_hp")), hp + amount)

func is_dead() -> bool:
	return hp <= 0

func _process(delta):
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	if hp <= 0 or hp >= int(get_stat("max_hp")):
		regen_accumulator = 0.0
		return
	var regen = get_stat("hp_regen")
	if regen > 0:
		regen_accumulator += regen * delta
		if regen_accumulator >= 1.0:
			var heal_amount = int(regen_accumulator)
			regen_accumulator -= heal_amount
			heal(heal_amount)
