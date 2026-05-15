extends CharacterBody2D
class_name Player

@export var move_speed: float = 200.0

@onready var stats: StatsComponent = $StatsComponent
@onready var weapon_container: Node2D = $WeaponContainer
@onready var hurtbox: Area2D = $Hurtbox
@onready var iframe_timer: Timer = $IFrameTimer
@onready var sprite: Sprite2D = $Sprite2D

var is_invincible: bool = false

func _ready():
	add_to_group("player")
	iframe_timer.timeout.connect(_on_iframe_timeout)
	_initialize_from_data()
	PlaceholderSprites.apply_square_texture(sprite, Color.BLUE, 32.0)

func _initialize_from_data():
	var char_data = DataManager.get_character(GameManager.selected_character_id)
	if char_data == null:
		push_error("Player: No character data for id: " + GameManager.selected_character_id)
		return
	stats.init_from_character(char_data)
	_equip_starting_weapon(char_data.starting_weapon)

func _equip_starting_weapon(weapon_id: String):
	var weapon_scene = load("res://scenes/entities/weapon_melee.tscn")
	var weapon = weapon_scene.instantiate()
	weapon.weapon_id = weapon_id
	weapon.player_stats = stats
	weapon_container.add_child(weapon)

func _physics_process(_delta):
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	_handle_movement()

func _handle_movement():
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed_mult = 1.0 + stats.get_stat("speed") / 100.0
	velocity = input_dir * move_speed * speed_mult
	move_and_slide()

	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider is EnemyBase and not is_invincible:
			_take_collision_damage(collider)

func _take_collision_damage(enemy: EnemyBase):
	var damage = int(enemy.stats.get_stat("base_damage"))
	_apply_damage(damage)

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
