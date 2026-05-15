extends CharacterBody2D
class_name Player

@export var move_speed: float = 200.0

@onready var stats: StatsComponent = $StatsComponent
@onready var weapon_container: Node2D = $WeaponContainer
@onready var hurtbox: Area2D = $Hurtbox
@onready var iframe_timer: Timer = $IFrameTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_radius: Area2D = $PickupRadius

var is_invincible: bool = false
var weapon_slots

func _ready():
	add_to_group("player")
	iframe_timer.timeout.connect(_on_iframe_timeout)
	pickup_radius.body_entered.connect(_on_pickup_entered)
	EventBus.item_purchased.connect(_on_item_purchased)
	EventBus.weapon_purchased.connect(_on_weapon_purchased)

	var slot_node = Node.new()
	slot_node.name = "WeaponSlotManager"
	slot_node.set_script(load("res://scripts/player/player_weapon_slot.gd"))
	weapon_slots = slot_node
	add_child(slot_node)

	_initialize_from_data()
	PlaceholderSprites.apply_square_texture(sprite, Color.BLUE, 32.0)

func _initialize_from_data():
	var char_data = DataManager.get_character(GameManager.selected_character_id)
	if char_data == null:
		push_error("Player: No character data for id: " + GameManager.selected_character_id)
		return
	stats.init_from_character(char_data)
	weapon_slots.init(weapon_container, stats)
	weapon_slots.add_weapon(char_data.starting_weapon)

func _equip_starting_weapon(_weapon_id: String):
	pass  # Handled by weapon_slots.add_weapon in _initialize_from_data

func _physics_process(_delta):
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	_handle_movement()
	_check_enemy_contact()

func _handle_movement():
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed_mult = 1.0 + stats.get_stat("speed") / 100.0
	velocity = input_dir * move_speed * speed_mult
	move_and_slide()

func _check_enemy_contact():
	if is_invincible:
		return
	var overlapping = hurtbox.get_overlapping_bodies()
	for body in overlapping:
		if body is EnemyBase:
			var damage = int(body.stats.get_stat("base_damage"))
			_apply_damage(damage)
			break

func _apply_damage(amount: int):
	if is_invincible:
		return
	var new_hp = stats.take_damage(amount)
	EventBus.player_damaged.emit(amount, new_hp)
	_start_iframes()
	if stats.is_dead():
		_die()

func _start_iframes():
	is_invincible = true
	iframe_timer.start()
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(sprite, "modulate:a", 0.3, 0.08)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.08)

func _on_iframe_timeout():
	is_invincible = false
	sprite.modulate.a = 1.0

func _die():
	EventBus.player_died.emit()
	GameManager.change_state(GameManager.GameState.GAME_OVER)

func _on_pickup_entered(body: Node2D):
	if body.has_method("start_attraction"):
		body.start_attraction(self)

func _on_item_purchased(item_id: String, _price: int):
	var item_data = DataManager.get_item(item_id)
	if item_data == null:
		return
	var source = "item:" + item_id
	for stat_name in item_data.stat_modifiers:
		var value = item_data.stat_modifiers[stat_name]
		stats.add_modifier(stat_name, source, value)

func _on_weapon_purchased(weapon_id: String, _price: int):
	weapon_slots.add_weapon(weapon_id)
