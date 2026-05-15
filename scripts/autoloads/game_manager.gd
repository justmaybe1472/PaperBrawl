extends Node

enum GameState { MAIN_MENU, CHARACTER_SELECT, WAVE_ACTIVE, SHOP, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MAIN_MENU
var current_wave: int = 1
var materials: int = 0
var selected_character_id: String = ""
var is_first_wave: bool = true

func start_run(character_id: String):
	selected_character_id = character_id
	current_wave = 1
	materials = 0
	is_first_wave = true
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
			_auto_advance_from_shop()
		GameState.GAME_OVER:
			EventBus.game_over.emit(current_wave, materials)

func _auto_advance_from_shop():
	await get_tree().create_timer(2.0).timeout
	if current_state == GameState.SHOP:
		next_wave()

func next_wave():
	current_wave += 1
	if current_wave > 3:
		_handle_victory()
	else:
		change_state(GameState.WAVE_ACTIVE)

func _handle_victory():
	change_state(GameState.GAME_OVER)

func add_materials(amount: int):
	materials += amount
	EventBus.material_collected.emit(amount, materials)
