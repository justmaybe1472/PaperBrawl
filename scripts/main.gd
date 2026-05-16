# 主场景入口：加载即开始游戏，处理暂停/恢复
extends Node2D

func _ready():
	GameManager.start_run(GameManager.selected_character_id)  # 直接启动本轮游戏

func _input(event):
	# ESC 暂停/恢复：仅允许在战斗与暂停状态间切换，商店中不可暂停
	if event.is_action_pressed("pause"):
		match GameManager.current_state:
			GameManager.GameState.WAVE_ACTIVE:
				EventBus.game_paused.emit()
				GameManager.change_state(GameManager.GameState.PAUSED)
			GameManager.GameState.PAUSED:
				EventBus.game_resumed.emit()
				GameManager.change_state(GameManager.GameState.WAVE_ACTIVE)
