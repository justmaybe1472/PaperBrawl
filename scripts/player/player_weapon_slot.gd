class_name PlayerWeaponSlot
extends Node

const MAX_SLOTS: int = 6

var weapon_container: Node2D
var player_stats: StatsComponent
var slots: Array = []  # Array[{weapon_id, tier, node}]

func init(container: Node2D, stats_comp: StatsComponent):
	weapon_container = container
	player_stats = stats_comp
	slots.clear()

func add_weapon(weapon_id: String) -> bool:
	var weapon_data = DataManager.get_weapon(weapon_id)
	if weapon_data == null:
		return false

	# Check for synthesis: same weapon + same tier
	var synth_index = _find_same_weapon_same_tier(weapon_id, weapon_data.tier)
	if synth_index >= 0:
		_synthesize(synth_index, weapon_id, weapon_data)
		return true

	# Check for existing weapon (upgrade tier directly)
	# If we already have a higher tier of this weapon, don't downgrade
	var existing_index = _find_weapon(weapon_id)
	if existing_index >= 0:
		var existing = slots[existing_index]
		if weapon_data.tier <= existing["tier"]:
			return false  # Already have same or higher tier

	# Find empty slot
	for i in range(MAX_SLOTS):
		if _is_slot_empty(i):
			_instantiate_weapon(i, weapon_id, weapon_data)
			return true

	# No empty slot - replace lowest tier
	var lowest_index = _find_lowest_tier_slot()
	if lowest_index >= 0:
		_remove_weapon_from_slot(lowest_index)
		_instantiate_weapon(lowest_index, weapon_id, weapon_data)
		return true

	return false

func _find_same_weapon_same_tier(weapon_id: String, tier: int) -> int:
	for i in range(slots.size()):
		if slots[i]["weapon_id"] == weapon_id and slots[i]["tier"] == tier:
			return i
	return -1

func _find_weapon(weapon_id: String) -> int:
	for i in range(slots.size()):
		if slots[i]["weapon_id"] == weapon_id:
			return i
	return -1

func _find_lowest_tier_slot() -> int:
	var lowest: int = -1
	var lowest_tier: int = 999
	for i in range(slots.size()):
		if slots[i]["tier"] < lowest_tier:
			lowest_tier = slots[i]["tier"]
			lowest = i
	return lowest

func _is_slot_empty(index: int) -> bool:
	while slots.size() <= index:
		slots.append({})
	return slots[index].is_empty()

func _synthesize(slot_index: int, weapon_id: String, weapon_data: WeaponData):
	var existing = slots[slot_index]
	var new_tier = existing["tier"] + 1
	if new_tier > 4:
		new_tier = 4

	# Remove the existing weapon
	var old_node: Node2D = existing["node"]
	if old_node:
		old_node.queue_free()

	# Load the merged weapon data - if no specific .tres for this tier, modify existing
	# For synthesis, we keep the same weapon_id but increase tier
	var merged_data = _get_tiered_weapon_data(weapon_id, new_tier)
	_instantiate_weapon(slot_index, weapon_id, merged_data)
	EventBus.weapon_synthesized.emit(weapon_id, new_tier)

func _get_tiered_weapon_data(weapon_id: String, tier: int) -> WeaponData:
	# Try loading tier-specific data, or clone and modify
	var base = DataManager.get_weapon(weapon_id)
	if base == null:
		return null
	var cloned = base.duplicate()
	cloned.tier = tier
	var tier_multipliers = {1: 1.0, 2: 1.5, 3: 2.2, 4: 3.0}
	cloned.base_damage = base.base_damage * tier_multipliers.get(tier, 1.0)
	return cloned

func _instantiate_weapon(slot_index: int, weapon_id: String, weapon_data: WeaponData):
	var weapon_scene = load("res://scenes/entities/weapon_melee.tscn")
	var weapon = weapon_scene.instantiate()
	weapon.weapon_id = weapon_id
	weapon.player_stats = player_stats
	if weapon.has_method("set_weapon_data"):
		weapon.set_weapon_data(weapon_data)
	weapon_container.add_child(weapon)

	while slots.size() <= slot_index:
		slots.append({})
	slots[slot_index] = {"weapon_id": weapon_id, "tier": weapon_data.tier, "node": weapon}

func _remove_weapon_from_slot(slot_index: int):
	if slot_index < slots.size():
		var slot = slots[slot_index]
		if not slot.is_empty() and slot["node"]:
			slot["node"].queue_free()
		slots[slot_index] = {}

func get_slot_count() -> int:
	var count = 0
	for slot in slots:
		if not slot.is_empty():
			count += 1
	return count

func has_weapon(weapon_id: String) -> bool:
	return _find_weapon(weapon_id) >= 0
