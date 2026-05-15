extends Node

const SAVE_PATH = "user://save_data.json"

var save_data: Dictionary = {
	"total_materials_earned": 0,
	"total_kills": 0,
	"total_runs": 0,
	"total_wins": 0,
	"highest_wave": 0,
	"unlocked_characters": ["well_rounded"],
	"unlocked_weapons": ["stick"],
	"unlocked_items": [],
	"difficulty_levels": [0]
}

func _ready():
	load_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var text = file.get_as_text()
	file.close()
	if text.is_empty():
		return

	var json = JSON.new()
	var error = json.parse(text)
	if error == OK:
		var data = json.data
		if data is Dictionary:
			for key in save_data:
				if data.has(key):
					save_data[key] = data[key]

func _merge_defaults(source: Dictionary, defaults: Dictionary) -> Dictionary:
	for key in defaults:
		if not source.has(key):
			source[key] = defaults[key]
		elif source[key] is Dictionary and defaults[key] is Dictionary:
			source[key] = _merge_defaults(source[key], defaults[key])
	return source

func add_materials(amount: int):
	save_data["total_materials_earned"] += amount
	save_game()

func add_kills(count: int):
	save_data["total_kills"] += count
	_check_character_unlocks()
	save_game()

func record_run_end(wave_reached: int, is_victory: bool):
	save_data["total_runs"] += 1
	if wave_reached > save_data["highest_wave"]:
		save_data["highest_wave"] = wave_reached
	if is_victory:
		save_data["total_wins"] += 1
	_check_character_unlocks()
	save_game()

func is_character_unlocked(id: String) -> bool:
	return id in save_data["unlocked_characters"]

func unlock_character(id: String):
	if id not in save_data["unlocked_characters"]:
		save_data["unlocked_characters"].append(id)
		save_game()

func is_weapon_unlocked(id: String) -> bool:
	return id in save_data["unlocked_weapons"]

func unlock_weapon(id: String):
	if id not in save_data["unlocked_weapons"]:
		save_data["unlocked_weapons"].append(id)
		save_game()

func is_item_unlocked(id: String) -> bool:
	return id in save_data["unlocked_items"]

func unlock_item(id: String):
	if id not in save_data["unlocked_items"]:
		save_data["unlocked_items"].append(id)
		save_game()

func is_difficulty_unlocked(level: int) -> bool:
	return level in save_data["difficulty_levels"]

func unlock_difficulty(level: int):
	if level not in save_data["difficulty_levels"]:
		save_data["difficulty_levels"].append(level)
		save_game()

func get_difficulty_multiplier() -> float:
	var level = GameManager.current_difficulty
	match level:
		0: return 1.0
		1: return 1.3
		2: return 1.8
		3: return 2.5
	return 1.0

func get_material_multiplier() -> float:
	var level = GameManager.current_difficulty
	match level:
		0: return 1.0
		1: return 1.2
		2: return 1.4
		3: return 1.6
	return 1.0

func _check_character_unlocks():
	var kills = save_data["total_kills"]
	var highest_wave = save_data["highest_wave"]
	var materials = save_data["total_materials_earned"]
	var wins = save_data["total_wins"]
	if kills >= 50:
		unlock_character("brawler")
		unlock_character("ranger")
	if kills >= 100:
		unlock_character("mage")
		unlock_character("engineer")
	if highest_wave >= 10:
		unlock_character("tank")
	if materials >= 200:
		unlock_character("lucky")
	if highest_wave >= 5:
		unlock_character("speedy")

	if wins >= 1 and not is_difficulty_unlocked(1):
		unlock_difficulty(1)
	if wins >= 2 and not is_difficulty_unlocked(2):
		unlock_difficulty(2)
