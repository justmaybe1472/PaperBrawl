extends Node

var characters: Dictionary = {}
var weapons: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var wave_configs: Dictionary = {}

func _ready():
	load_all_resources()

func load_all_resources():
	_load_directory("res://resources/characters/", characters)
	_load_directory("res://resources/weapons/", weapons)
	_load_directory("res://resources/items/", items)
	_load_directory("res://resources/enemies/", enemies)
	_load_wave_configs()

func _load_directory(path: String, target: Dictionary):
	var dir = DirAccess.open(path)
	if dir == null:
		push_warning("DataManager: Cannot open directory: " + path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load(path + file_name)
			if "id" in resource:
				target[resource.id] = resource
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_wave_configs():
	var dir = DirAccess.open("res://resources/waves/")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load("res://resources/waves/" + file_name)
			if "wave_number" in resource:
				wave_configs[resource.wave_number] = resource
		file_name = dir.get_next()
	dir.list_dir_end()

func get_character(id: String) -> Resource:
	return characters.get(id, null)

func get_weapon(id: String) -> Resource:
	return weapons.get(id, null)

func get_item(id: String) -> Resource:
	return items.get(id, null)

func get_enemy(id: String) -> Resource:
	return enemies.get(id, null)

func get_wave_config(wave_number: int) -> Resource:
	return wave_configs.get(wave_number, null)
