extends Control

var _shop_items: Array = []
var _shop_weapons: Array = []
var _refreshed: bool = false
var _refresh_price: int = 0

func _ready():
	EventBus.shop_opened.connect(_on_shop_opened)
	hide()

func _on_shop_opened(wave_number: int):
	_refreshed = false
	_refresh_price = wave_number * 1
	_generate_shop(wave_number)
	_build_ui(wave_number)
	show()

func _generate_shop(wave_number: int):
	var luck: float = 0.0
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("StatsComponent"):
		luck = player.get_node("StatsComponent").get_stat("luck")

	var items_pool = DataManager.items.values()
	if items_pool.is_empty():
		return

	# Rarity weights adjusted by luck
	var rarity_weights = {
		"common": max(5.0, 60.0 - luck * 0.3),
		"uncommon": max(5.0, 25.0 + luck * 0.1),
		"rare": max(5.0, 12.0 + luck * 0.15),
		"legendary": max(1.0, 3.0 + luck * 0.05),
	}

	# Generate 4 unique items
	_shop_items.clear()
	var used_ids = []
	for i in range(4):
		var rarity = _weighted_rarity(rarity_weights)
		var pool = []
		for item in items_pool:
			if item.rarity == rarity and item.id not in used_ids:
				pool.append(item)
		if pool.is_empty():
			for item in items_pool:
				if item.id not in used_ids:
					pool.append(item)
		if pool.is_empty():
			break

		var chosen = pool[randi() % pool.size()]
		used_ids.append(chosen.id)
		var price = int(chosen.base_price * (1.0 + 0.05 * (wave_number - 1)))
		_shop_items.append({"item": chosen, "price": price})

	# Generate 0-2 weapons
	_shop_weapons.clear()
	var weapon_chance = 0.4 * (1.0 + luck / 200.0)
	for i in range(2):
		if randf() < weapon_chance:
			var wpn_pool = DataManager.weapons.values()
			if not wpn_pool.is_empty():
				var chosen = wpn_pool[randi() % wpn_pool.size()]
				_shop_weapons.append({"weapon": chosen, "price": chosen.tier * 30})

func _weighted_rarity(weights: Dictionary) -> String:
	var total: float = 0.0
	for w in weights.values():
		total += w
	var roll = randf() * total
	var cumulative: float = 0.0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll <= cumulative:
			return rarity
	return "common"

func _build_ui(wave_number: int):
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	_clear_children()

	var panel = Panel.new()
	panel.size = Vector2(900, 520)
	panel.position = Vector2(190, 100)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var title = Label.new()
	title.text = "商店 - 波次 " + str(wave_number)
	title.position = Vector2(350, 10)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(title)

	var materials_label = Label.new()
	materials_label.text = "材料: " + str(GameManager.materials)
	materials_label.position = Vector2(20, 450)
	materials_label.add_theme_font_size_override("font_size", 18)
	materials_label.add_theme_color_override("font_color", Color.GREEN)
	materials_label.name = "MaterialLabel"
	panel.add_child(materials_label)

	# Item slots
	for i in range(_shop_items.size()):
		var slot = _shop_items[i]
		var item_data: ItemData = slot["item"]
		var price: int = slot["price"]
		var x = 30 + i * 210

		var name_label = Label.new()
		name_label.text = item_data.display_name
		name_label.position = Vector2(x, 50)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", _rarity_color(item_data.rarity))
		panel.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = item_data.description
		desc_label.position = Vector2(x, 75)
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		panel.add_child(desc_label)

		var price_label = Label.new()
		price_label.text = "$" + str(price)
		price_label.position = Vector2(x, 100)
		price_label.add_theme_font_size_override("font_size", 14)
		price_label.add_theme_color_override("font_color", Color.YELLOW)
		panel.add_child(price_label)

		var buy_btn = Button.new()
		buy_btn.text = "购买"
		buy_btn.position = Vector2(x, 125)
		buy_btn.size = Vector2(60, 30)
		buy_btn.pressed.connect(_on_buy_item.bind(i, buy_btn))
		panel.add_child(buy_btn)

	# Weapon slots
	if not _shop_weapons.is_empty():
		for j in range(_shop_weapons.size()):
			var slot = _shop_weapons[j]
			var weapon_data: WeaponData = slot["weapon"]
			var price: int = slot["price"]
			var x = 30 + j * 210

			var w_label = Label.new()
			w_label.text = "武器: " + weapon_data.display_name
			w_label.position = Vector2(x, 180)
			w_label.add_theme_font_size_override("font_size", 16)
			w_label.add_theme_color_override("font_color", Color.CYAN)
			panel.add_child(w_label)

			var w_price = Label.new()
			w_price.text = "$" + str(price)
			w_price.position = Vector2(x, 205)
			w_price.add_theme_font_size_override("font_size", 14)
			w_price.add_theme_color_override("font_color", Color.YELLOW)
			panel.add_child(w_price)

			var w_buy = Button.new()
			w_buy.text = "购买武器"
			w_buy.position = Vector2(x, 230)
			w_buy.size = Vector2(80, 30)
			w_buy.pressed.connect(_on_buy_weapon.bind(j, w_buy))
			panel.add_child(w_buy)

	# Refresh button
	var refresh_btn = Button.new()
	refresh_btn.text = "刷新 $" + str(_refresh_price)
	refresh_btn.position = Vector2(550, 450)
	refresh_btn.size = Vector2(100, 35)
	refresh_btn.pressed.connect(_on_refresh.bind(refresh_btn))
	panel.add_child(refresh_btn)

	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = "继续"
	continue_btn.position = Vector2(670, 450)
	continue_btn.size = Vector2(100, 35)
	continue_btn.pressed.connect(_on_continue)
	panel.add_child(continue_btn)

func _clear_children():
	for child in get_children():
		child.queue_free()

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color.WHITE
		"uncommon": return Color(0.3, 0.7, 1.0)
		"rare": return Color(0.7, 0.3, 1.0)
		"legendary": return Color(1.0, 0.6, 0.0)
	return Color.WHITE

func _on_buy_item(index: int, btn: Button):
	if index >= _shop_items.size():
		return
	var slot = _shop_items[index]
	var price: int = slot["price"]
	if not GameManager.spend_materials(price):
		return
	var item_data: ItemData = slot["item"]
	EventBus.item_purchased.emit(item_data.id, price)
	btn.disabled = true
	btn.text = "已购买"
	_update_materials_display()

func _on_buy_weapon(index: int, btn: Button):
	if index >= _shop_weapons.size():
		return
	var slot = _shop_weapons[index]
	var price: int = slot["price"]
	if not GameManager.spend_materials(price):
		return
	var weapon_data: WeaponData = slot["weapon"]
	EventBus.weapon_purchased.emit(weapon_data.id, price)
	btn.disabled = true
	btn.text = "已购买"
	_update_materials_display()

func _on_refresh(btn: Button):
	if _refreshed:
		return
	if not GameManager.spend_materials(_refresh_price):
		return
	_refreshed = true
	btn.disabled = true
	EventBus.shop_refreshed.emit()
	_generate_shop(GameManager.current_wave)
	_build_ui(GameManager.current_wave)

func _on_continue():
	hide()
	EventBus.shop_closed.emit()

func _update_materials_display():
	var label = find_child("MaterialLabel", true, false)
	if label:
		label.text = "材料: " + str(GameManager.materials)
