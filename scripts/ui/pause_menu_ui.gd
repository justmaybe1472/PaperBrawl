extends Control

var _item_list_container: Control  # 道具列表容器（每次显示时重建）

func _ready():
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	_build_ui()
	hide()

func _build_ui():
	# 半透明遮罩让玩家知道游戏被暂停但世界仍在
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	# 主面板：比之前更大以容纳道具列表
	var panel = Panel.new()
	panel.size = Vector2(420, 520)
	panel.position = Vector2(430, 100)
	panel.name = "PausePanel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var title = Label.new()
	title.text = "已暂停"
	title.position = Vector2(170, 15)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(title)

	# 道具列表标题
	var items_title = Label.new()
	items_title.text = "已持有道具："
	items_title.position = Vector2(20, 50)
	items_title.add_theme_font_size_override("font_size", 16)
	items_title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	panel.add_child(items_title)

	# 道具列表容器 — 每次显示时动态填充
	_item_list_container = Control.new()
	_item_list_container.name = "ItemListContainer"
	_item_list_container.position = Vector2(20, 75)
	_item_list_container.size = Vector2(380, 0)  # 高度动态增长
	panel.add_child(_item_list_container)

	# 按钮区：位于面板底部
	var resume_btn = Button.new()
	resume_btn.text = "继续游戏"
	resume_btn.position = Vector2(35, 430)
	resume_btn.size = Vector2(160, 40)
	resume_btn.pressed.connect(_on_resume_pressed)
	panel.add_child(resume_btn)

	var restart_btn = Button.new()
	restart_btn.text = "重新开始"
	restart_btn.position = Vector2(225, 430)
	restart_btn.size = Vector2(160, 40)
	restart_btn.pressed.connect(_on_restart_pressed)
	panel.add_child(restart_btn)

	var quit_btn = Button.new()
	quit_btn.text = "返回主菜单"
	quit_btn.position = Vector2(110, 480)
	quit_btn.size = Vector2(200, 35)
	quit_btn.pressed.connect(_on_quit_pressed)
	panel.add_child(quit_btn)

func _on_game_paused():
	_refresh_item_list()  # 暂停时重新生成道具列表以反映最新状态
	show()

func _on_game_resumed():
	hide()  # 隐藏而非销毁，保持按钮引用有效

# 从 Player 的 stat_modifiers 和 _item_stack_counts 生成道具列表
func _refresh_item_list():
	# 清空旧列表
	for child in _item_list_container.get_children():
		child.queue_free()

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# 从 stat_modifiers 中提取道具 ID（source 格式为 "item:<id>"）
	var owned_items: Dictionary = {}  # item_id -> {count, modifiers}
	var stats_comp = player.stats
	for stat_name in stats_comp.stat_modifiers:
		for mod in stats_comp.stat_modifiers[stat_name]:
			var source: String = mod.get("source", "")
			if source.begins_with("item:"):
				var item_id = source.substr(5)  # 去掉 "item:" 前缀
				if not owned_items.has(item_id):
					owned_items[item_id] = {"count": 0, "modifiers": []}
				owned_items[item_id]["modifiers"].append({"stat": stat_name, "value": mod["value"]})

	# 从 _item_stack_counts 获取准确堆叠数
	for item_id in owned_items:
		owned_items[item_id]["count"] = player.get_item_stack_count(item_id)

	# 无道具时显示提示
	if owned_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "  暂无道具"
		empty_label.position = Vector2(0, 0)
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_item_list_container.add_child(empty_label)
		return

	# 逐项生成道具信息行：名称 + 稀有度颜色 + 堆叠数 + 属性加成
	var y_offset: float = 0.0
	for item_id in owned_items:
		var info = owned_items[item_id]
		var item_data = DataManager.get_item(item_id)
		var display_name = item_id
		var rarity = "common"
		var description = ""
		if item_data:
			display_name = item_data.display_name
			rarity = item_data.rarity
			description = item_data.description

		# 道具名称（带稀有度颜色）
		var name_label = Label.new()
		name_label.text = display_name + " ×" + str(info["count"])
		name_label.position = Vector2(0, y_offset)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", _rarity_color(rarity))
		_item_list_container.add_child(name_label)
		y_offset += 18

		# 属性加成摘要
		var mod_texts: Array = []
		for mod in info["modifiers"]:
			var stat_name = mod["stat"]
			var value = mod["value"]
			if value is float and value == int(value):
				value = int(value)
			# 百分比属性加 % 后缀
			var pct_stats = ["damage_pct", "attack_speed", "crit_chance", "dodge", "speed", "life_steal"]
			if stat_name in pct_stats:
				mod_texts.append(stat_name + " +" + str(value) + "%")
			else:
				mod_texts.append(stat_name + " +" + str(value))
		var mod_label = Label.new()
		mod_label.text = "  " + ", ".join(mod_texts)
		mod_label.position = Vector2(10, y_offset)
		mod_label.add_theme_font_size_override("font_size", 11)
		mod_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_item_list_container.add_child(mod_label)
		y_offset += 16

		# 特殊效果提示
		if item_data and item_data.special_effect != null:
			var eff_label = Label.new()
			eff_label.text = "  [特殊效果]"
			eff_label.position = Vector2(10, y_offset)
			eff_label.add_theme_font_size_override("font_size", 11)
			eff_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			_item_list_container.add_child(eff_label)
			y_offset += 16

	# 更新容器高度以支持滚动
	_item_list_container.size.y = y_offset

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color.WHITE
		"uncommon": return Color(0.3, 0.7, 1.0)
		"rare": return Color(0.7, 0.3, 1.0)
		"legendary": return Color(1.0, 0.6, 0.0)
	return Color.WHITE

func _on_resume_pressed():
	EventBus.game_resumed.emit()
	GameManager.change_state(GameManager.GameState.WAVE_ACTIVE)  # 恢复波次活跃状态

func _on_restart_pressed():
	EventBus.game_resumed.emit()  # 先发送恢复事件清理暂停状态
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
