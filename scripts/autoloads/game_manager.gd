extends Node

enum GameState { MAIN_MENU, CHARACTER_SELECT, WAVE_ACTIVE, SHOP, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MAIN_MENU
var current_wave: int = 1
var materials: int = 0
var selected_character_id: String = "well_rounded"
var is_first_wave: bool = true
var total_kills: int = 0
var is_victory: bool = false
var current_difficulty: int = 0

func _ready():
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.enemy_killed.connect(_on_enemy_killed_for_stats)
	EventBus.player_died.connect(_on_player_died)

func start_run(character_id: String):
	selected_character_id = character_id
	current_wave = 1
	materials = 0
	is_first_wave = true
	total_kills = 0
	is_victory = false
	change_state(GameState.WAVE_ACTIVE)

func change_state(new_state: GameState):
	current_state = new_state
	match new_state:
		GameState.WAVE_ACTIVE:
			if is_first_wave:
				EventBus.game_started.emit()
				is_first_wave = false
			EventBus.wave_started.emit(current_wave)
		GameState.SHOP:
			EventBus.wave_completed.emit(current_wave)
			EventBus.shop_opened.emit(current_wave)
		GameState.GAME_OVER:
			EventBus.game_over.emit(current_wave, materials)

func next_wave():
	current_wave += 1
	if current_wave > 20:
		_handle_victory()
	else:
		change_state(GameState.WAVE_ACTIVE)

func add_materials(amount: int):
	materials += amount
	EventBus.material_collected.emit(amount, materials)

func spend_materials(amount: int) -> bool:
	if materials >= amount:
		materials -= amount
		EventBus.material_collected.emit(-amount, materials)
		return true
	return false

func _on_shop_closed():
	next_wave()

func _on_enemy_killed_for_stats(_enemy_id: String, _position: Vector2, _is_elite: bool):
	total_kills += 1

func _on_player_died():
	_end_run(false)

func _handle_victory():
	is_victory = true
	_end_run(true)

func _end_run(is_win: bool):
	SaveManager.add_kills(total_kills)
	SaveManager.add_materials(materials)
	SaveManager.record_run_end(current_wave, is_win)
	change_state(GameState.GAME_OVER)

func set_difficulty(level: int):
	current_difficulty = level

func get_enemy_stat_multiplier() -> float:
	return SaveManager.get_difficulty_multiplier()

func get_wave_material_multiplier() -> float:
	return SaveManager.get_material_multiplier()
