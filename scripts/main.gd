extends Node2D

func _ready():
	GameManager.start_run(GameManager.selected_character_id)

func _input(event):
	if event.is_action_pressed("pause"):
		match GameManager.current_state:
			GameManager.GameState.WAVE_ACTIVE:
				EventBus.game_paused.emit()
				GameManager.change_state(GameManager.GameState.PAUSED)
			GameManager.GameState.PAUSED:
				EventBus.game_resumed.emit()
				GameManager.change_state(GameManager.GameState.WAVE_ACTIVE)
