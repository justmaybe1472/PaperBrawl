class_name EnemyBase
extends CharacterBody2D

@export var enemy_id: String = "basic_melee"

@onready var stats: EnemyStats = $EnemyStats
@onready var ai: EnemyAI = $AIStateMachine
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("enemy")

func init(enemy_data: EnemyData, wave_number: int):
	# Use $ directly because @onready vars aren't set until _ready() runs
	($EnemyStats as EnemyStats).init_from_data(enemy_data, wave_number)
	($AIStateMachine as EnemyAI).chase_speed = ($EnemyStats as EnemyStats).base_speed
	PlaceholderSprites.apply_square_texture($Sprite2D, Color.RED, 28.0)
	$HealthBar.max_value = ($EnemyStats as EnemyStats).base_hp
	$HealthBar.value = ($EnemyStats as EnemyStats).current_hp

func _physics_process(delta):
	if is_dead:
		return

	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 500.0)

	var move_dir = ai.get_move_direction()
	velocity = move_dir * stats.base_speed + knockback_velocity
	move_and_slide()

func take_damage(amount: int):
	if is_dead:
		return
	stats.take_damage(amount)
	health_bar.value = stats.current_hp

	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		sprite.modulate = Color.WHITE

	if stats.is_dead():
		_die()

func apply_knockback(force: Vector2):
	knockback_velocity = force

func _die():
	if is_dead:
		return
	is_dead = true
	EventBus.enemy_killed.emit(enemy_id, global_position, false)
	queue_free()
