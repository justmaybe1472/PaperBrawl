extends Control

func _ready():
	EventBus.game_over.connect(_on_game_over)
	hide()

func _on_game_over(wave_reached: int, materials_earned: int):
	_build_ui(wave_reached, materials_earned)
	show()

func _build_ui(wave_reached: int, materials_earned: int):
	for child in get_children():
		child.queue_free()

	var panel = Panel.new()
	panel.size = Vector2(500, 400)
	panel.position = Vector2(390, 160)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var title = Label.new()
	title.text = "通关！" if GameManager.is_victory else "游戏结束"
	title.position = Vector2(150, 30)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GOLD if GameManager.is_victory else Color.RED)
	panel.add_child(title)

	var wave_label = Label.new()
	wave_label.text = "到达波次: " + str(wave_reached) + " / 20"
	wave_label.position = Vector2(130, 100)
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(wave_label)

	var mat_label = Label.new()
	mat_label.text = "获得材料: " + str(materials_earned)
	mat_label.position = Vector2(130, 140)
	mat_label.add_theme_font_size_override("font_size", 20)
	mat_label.add_theme_color_override("font_color", Color.GREEN)
	panel.add_child(mat_label)

	var kills_label = Label.new()
	kills_label.text = "击杀数: " + str(GameManager.total_kills)
	kills_label.position = Vector2(130, 180)
	kills_label.add_theme_font_size_override("font_size", 20)
	kills_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(kills_label)

	var restart_btn = Button.new()
	restart_btn.text = "重新开始"
	restart_btn.position = Vector2(130, 250)
	restart_btn.size = Vector2(240, 45)
	restart_btn.pressed.connect(_on_restart_pressed)
	panel.add_child(restart_btn)

	var quit_btn = Button.new()
	quit_btn.text = "返回主菜单"
	quit_btn.position = Vector2(130, 310)
	quit_btn.size = Vector2(240, 45)
	quit_btn.pressed.connect(_on_quit_pressed)
	panel.add_child(quit_btn)

func _on_restart_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
