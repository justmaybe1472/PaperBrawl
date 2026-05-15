extends Control

func _ready():
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	_build_ui()
	hide()

func _build_ui():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var panel = Panel.new()
	panel.size = Vector2(300, 280)
	panel.position = Vector2(490, 220)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var title = Label.new()
	title.text = "已暂停"
	title.position = Vector2(100, 20)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(title)

	var resume_btn = Button.new()
	resume_btn.text = "继续游戏"
	resume_btn.position = Vector2(50, 80)
	resume_btn.size = Vector2(200, 45)
	resume_btn.pressed.connect(_on_resume_pressed)
	panel.add_child(resume_btn)

	var restart_btn = Button.new()
	restart_btn.text = "重新开始"
	restart_btn.position = Vector2(50, 140)
	restart_btn.size = Vector2(200, 45)
	restart_btn.pressed.connect(_on_restart_pressed)
	panel.add_child(restart_btn)

	var quit_btn = Button.new()
	quit_btn.text = "返回主菜单"
	quit_btn.position = Vector2(50, 200)
	quit_btn.size = Vector2(200, 45)
	quit_btn.pressed.connect(_on_quit_pressed)
	panel.add_child(quit_btn)

func _on_game_paused():
	show()

func _on_game_resumed():
	hide()

func _on_resume_pressed():
	EventBus.game_resumed.emit()
	GameManager.change_state(GameManager.GameState.WAVE_ACTIVE)

func _on_restart_pressed():
	EventBus.game_resumed.emit()
	GameManager.start_run(GameManager.selected_character_id)

func _on_quit_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
