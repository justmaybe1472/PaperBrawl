extends Control

var _character_ids: Array = []
var _selected_index: int = 0

func _ready():
	for id in DataManager.characters:
		_character_ids.append(id)
	_character_ids.sort()  # 排序保证角色列表顺序一致
	_build_ui()

func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "选择角色"
	title.position = Vector2(520, 30)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)

	# Character grid - 4 columns, 根据角色数量自动换行
	var cols = 4
	var start_x = 80
	var start_y = 100
	var cell_w = 280
	var cell_h = 160
	var gap_x = 20
	var gap_y = 20

	for i in range(_character_ids.size()):
		var char_id = _character_ids[i]
		var char_data = DataManager.get_character(char_id)
		if char_data == null:
			continue

		var col = i % cols
		var row = i / cols
		var x = start_x + col * (cell_w + gap_x)
		var y = start_y + row * (cell_h + gap_y)
		var unlocked = SaveManager.is_character_unlocked(char_id)

		_create_character_card(char_data, x, y, cell_w, cell_h, i, unlocked)

	# Confirm button
	var confirm_btn = Button.new()
	confirm_btn.text = "确认选择"
	confirm_btn.position = Vector2(490, 580)
	confirm_btn.size = Vector2(300, 50)
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.name = "ConfirmBtn"
	add_child(confirm_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(490, 640)
	back_btn.size = Vector2(300, 45)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	_update_selection()

func _create_character_card(char_data: CharacterData, x: float, y: float, w: float, h: float, index: int, unlocked: bool):
	var panel = Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(w, h)
	panel.name = "Card_" + char_data.id
	var style = StyleBoxFlat.new()
	if not unlocked:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.8)  # 锁定角色用暗色面板区分
	else:
		style.bg_color = Color(0.1, 0.15, 0.2, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var name_label = Label.new()
	name_label.text = char_data.display_name
	if not unlocked:
		name_label.text += " [锁定]"
	name_label.position = Vector2(10, 5)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.4, 0.4, 0.4))  # 锁定角色名称灰色
	panel.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = char_data.description
	if not unlocked:
		desc_label.text = "解锁条件: " + char_data.unlock_condition  # 锁定角色显示解锁条件而非描述
	desc_label.position = Vector2(10, 32)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(desc_label)

	# Show starting weapon
	var wpn_label = Label.new()
	wpn_label.text = "初始武器: " + _get_weapon_name(char_data.starting_weapon)
	wpn_label.position = Vector2(10, 55)
	wpn_label.add_theme_font_size_override("font_size", 12)
	wpn_label.add_theme_color_override("font_color", Color.CYAN)
	panel.add_child(wpn_label)

	# Show key stats - 仅显示非默认属性，帮助玩家快速比较角色差异
	var stats_text = _get_key_stats_text(char_data)
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(10, 75)
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(stats_label)

	if unlocked:
		panel.gui_input.connect(_on_card_clicked.bind(index))  # 仅已解锁角色可点击

func _get_weapon_name(weapon_id: String) -> String:
	var wpn = DataManager.get_weapon(weapon_id)
	if wpn:
		return wpn.display_name
	return weapon_id

func _get_key_stats_text(char_data: CharacterData) -> String:
	var stats = char_data.base_stats
	var lines: Array[String] = []
	# 只显示非默认的属性值，精简信息展示
	if stats.get("max_hp", 12) != 12:
		lines.append("HP: %d" % int(stats["max_hp"]))
	if stats.get("damage_pct", 0) != 0:
		lines.append("伤害: %+d%%" % int(stats["damage_pct"]))
	if stats.get("melee_damage", 0) != 0:
		lines.append("近战: %+d%%" % int(stats["melee_damage"]))
	if stats.get("ranged_damage", 0) != 0:
		lines.append("远程: %+d%%" % int(stats["ranged_damage"]))
	if stats.get("elemental_damage", 0) != 0:
		lines.append("元素: %+d%%" % int(stats["elemental_damage"]))
	if stats.get("engineering", 0) != 0:
		lines.append("工程: %+d%%" % int(stats["engineering"]))
	if stats.get("attack_speed", 0) != 0:
		lines.append("攻速: %+d%%" % int(stats["attack_speed"]))
	if stats.get("speed", 0) != 0:
		lines.append("速度: %+d%%" % int(stats["speed"]))
	if stats.get("luck", 0) != 0:
		lines.append("幸运: %+d" % int(stats["luck"]))
	return ", ".join(lines) if not lines.is_empty() else "全属性均衡"

func _on_card_clicked(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed:
		_selected_index = index
		_update_selection()  # 高亮当前选中卡片

func _update_selection():
	# 更新所有卡片颜色：选中卡片蓝色高亮，锁定卡片暗灰，其余默认
	for i in range(_character_ids.size()):
		var card = find_child("Card_" + _character_ids[i], true, false)
		if card == null:
			continue
		var style = card.get_theme_stylebox("panel", "Panel")
		if style is StyleBoxFlat:
			if i == _selected_index and SaveManager.is_character_unlocked(_character_ids[i]):
				style.bg_color = Color(0.2, 0.35, 0.6, 0.95)  # 选中高亮
			elif not SaveManager.is_character_unlocked(_character_ids[i]):
				style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
			else:
				style.bg_color = Color(0.1, 0.15, 0.2, 0.9)

func _on_confirm():
	var char_id = _character_ids[_selected_index]
	if not SaveManager.is_character_unlocked(char_id):
		return  # 锁定角色不可确认
	GameManager.selected_character_id = char_id
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
