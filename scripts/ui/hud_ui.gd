extends Control

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var material_label: Label = $BottomBar/MaterialLabel

var weapon_slot_icons: Array = []
var weapon_slots_container: HBoxContainer

func _ready():
	EventBus.game_started.connect(_on_game_started)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_timer_updated.connect(_on_timer_updated)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_player_died)
	EventBus.material_collected.connect(_on_material_collected)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.weapon_synthesized.connect(_on_weapon_synthesized)
	EventBus.weapon_purchased.connect(func(_wid, _p): _refresh_weapon_slots())

	_create_weapon_slots()

func _create_weapon_slots():
	weapon_slots_container = HBoxContainer.new()
	weapon_slots_container.name = "WeaponSlots"
	weapon_slots_container.add_theme_constant_override("separation", 4)
	weapon_slots_container.position = Vector2(10, 656)
	add_child(weapon_slots_container)
	for i in range(6):
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.visible = false
		weapon_slots_container.add_child(icon)
		weapon_slot_icons.append(icon)

func _on_game_started():
	_update_hp_bar()
	_refresh_weapon_slots()
	show()

func _on_wave_started(wave_number: int):
	wave_label.text = "Wave: %d/20" % wave_number

func _on_timer_updated(time_left: float):
	timer_label.text = "Time: %.0fs" % time_left

func _on_player_damaged(_amount: int, _new_hp: int):
	_update_hp_bar()

func _on_player_died():
	wave_label.text = "GAME OVER"

func _on_material_collected(_amount: int, total: int):
	material_label.text = str(total)

func _on_weapon_fired(weapon_id: String, _position: Vector2, _direction: Vector2):
	for icon in weapon_slot_icons:
		if icon.visible and icon.get_meta("weapon_id", "") == weapon_id:
			icon.self_modulate = Color(1.5, 1.5, 1.5)
			var tween = create_tween()
			tween.tween_property(icon, "self_modulate", Color.WHITE, 0.15)
			break

func _on_weapon_synthesized(_weapon_id: String, _new_tier: int):
	_refresh_weapon_slots()

func _update_hp_bar():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var stats = player.stats
	var max_hp = stats.get_stat("max_hp")
	hp_bar.max_value = max_hp
	hp_bar.value = stats.hp
	hp_label.text = "%d/%d" % [stats.hp, int(max_hp)]

func _refresh_weapon_slots():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var slot_manager = player.weapon_slots
	if slot_manager == null:
		return

	for i in range(6):
		if i < slot_manager.slots.size() and not slot_manager.slots[i].is_empty():
			var slot = slot_manager.slots[i]
			var wdata = DataManager.get_weapon(slot["weapon_id"])
			if wdata:
				weapon_slot_icons[i].texture = PlaceholderSprites.make_weapon_icon(wdata.weapon_class, slot["tier"])
				weapon_slot_icons[i].set_meta("weapon_id", slot["weapon_id"])
				weapon_slot_icons[i].visible = true
			else:
				weapon_slot_icons[i].visible = false
		else:
			weapon_slot_icons[i].visible = false
