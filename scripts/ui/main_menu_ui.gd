extends Control

func _ready():
	_build_ui()

func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "Potato Survivor"
	title.position = Vector2(390, 120)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.GOLD)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "土豆幸存者"
	subtitle.position = Vector2(480, 180)
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(subtitle)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "开始游戏"
	start_btn.position = Vector2(490, 280)
	start_btn.size = Vector2(300, 55)
	start_btn.pressed.connect(_on_start_pressed)
	add_child(start_btn)

	# Difficulty label
	var diff_label = Label.new()
	diff_label.text = "难度: " + _difficulty_name(GameManager.current_difficulty)
	diff_label.position = Vector2(540, 350)
	diff_label.add_theme_font_size_override("font_size", 16)
	diff_label.add_theme_color_override("font_color", Color.WHITE)
	diff_label.name = "DiffLabel"
	add_child(diff_label)

	# Difficulty buttons - 左右按钮循环切换难度
	var diff_left = Button.new()
	diff_left.text = "<"
	diff_left.position = Vector2(470, 345)
	diff_left.size = Vector2(40, 30)
	diff_left.pressed.connect(_on_diff_left)
	add_child(diff_left)

	var diff_right = Button.new()
	diff_right.text = ">"
	diff_right.position = Vector2(770, 345)
	diff_right.size = Vector2(40, 30)
	diff_right.pressed.connect(_on_diff_right)
	add_child(diff_right)

	# Quit button
	var quit_btn = Button.new()
	quit_btn.text = "退出"
	quit_btn.position = Vector2(490, 410)
	quit_btn.size = Vector2(300, 45)
	quit_btn.pressed.connect(_on_quit_pressed)
	add_child(quit_btn)

	# Stats display - 展示玩家累计数据，增强成就感
	var stats_label = Label.new()
	stats_label.text = _get_stats_text()
	stats_label.position = Vector2(400, 500)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stats_label.name = "StatsLabel"
	add_child(stats_label)

func _on_start_pressed():
	# 先进入角色选择，而非直接开始游戏
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_diff_left():
	if GameManager.current_difficulty > 0:
		GameManager.current_difficulty -= 1
		_update_diff_label()

func _on_diff_right():
	# 仅当有更高难度已解锁时才允许切换
	var max_diff = 0
	for d in SaveManager.save_data["difficulty_levels"]:
		if d > max_diff:
			max_diff = d
	if GameManager.current_difficulty < max_diff:
		GameManager.current_difficulty += 1
		_update_diff_label()

func _update_diff_label():
	var label = find_child("DiffLabel", true, false)
	if label:
		label.text = "难度: " + _difficulty_name(GameManager.current_difficulty)

func _difficulty_name(level: int) -> String:
	match level:
		0: return "普通"
		1: return "困难"
		2: return "噩梦"
		3: return "地狱"
	return "未知"

func _on_quit_pressed():
	get_tree().quit()

func _get_stats_text() -> String:
	var data = SaveManager.save_data
	return "累计击杀: %d   |   最高波次: %d   |   通关次数: %d" % [data["total_kills"], data["highest_wave"], data["total_wins"]]
