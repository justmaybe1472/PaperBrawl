class_name EnemyBase
extends CharacterBody2D

@export var enemy_id: String = "basic_melee"

@onready var stats: EnemyStats = $EnemyStats
@onready var ai: EnemyAI = $AIStateMachine
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var _is_elite: bool = false
var _material_drop: int = 1

const AI_SCRIPTS: Dictionary = {
	"chaser": "res://scripts/enemies/enemy_ai_chaser.gd",
	"charger": "res://scripts/enemies/enemy_ai_charger.gd",
	"shooter": "res://scripts/enemies/enemy_ai_shooter.gd",
	"summoner": "res://scripts/enemies/enemy_ai_summoner.gd",
	"tank": "res://scripts/enemies/enemy_ai_chaser.gd",
	"elite": "res://scripts/enemies/enemy_ai_chaser.gd",
	"boss": "res://scripts/enemies/enemy_ai_boss.gd",
}

const TYPE_COLORS: Dictionary = {
	"chaser": Color.RED,
	"charger": Color.ORANGE,
	"shooter": Color.MAGENTA,
	"summoner": Color.WHITE,
	"tank": Color.DARK_RED,
	"elite": Color.GOLD,
	"boss": Color.CRIMSON,
}

func _ready():
	add_to_group("enemy")

func init(enemy_data: EnemyData, wave_number: int):
	enemy_id = enemy_data.id
	_material_drop = enemy_data.material_drop
	($EnemyStats as EnemyStats).init_from_data(enemy_data, wave_number)

	var type: String = enemy_data.enemy_type
	var ai_script_path: String = AI_SCRIPTS.get(type, "res://scripts/enemies/enemy_ai_chaser.gd")
	var ai_script = load(ai_script_path)
	$AIStateMachine.set_script(ai_script)
	($AIStateMachine as EnemyAI).chase_speed = ($EnemyStats as EnemyStats).base_speed
	($AIStateMachine as EnemyAI).enemy_data = enemy_data

	var color: Color = TYPE_COLORS.get(type, Color.RED)
	var size: float = 28.0
	if type == "tank" or type == "boss":
		size = 40.0
	if type == "elite" or type == "boss":
		size *= 1.15
	PlaceholderSprites.apply_square_texture($Sprite2D, color, size)

	$HealthBar.max_value = ($EnemyStats as EnemyStats).base_hp
	$HealthBar.value = ($EnemyStats as EnemyStats).current_hp

func set_elite(value: bool):
	_is_elite = value
	PlaceholderSprites.apply_square_texture($Sprite2D, Color.GOLD, 32.0)

func _physics_process(delta):
	if is_dead:
		return
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return

	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 500.0)

	var move_dir = ($AIStateMachine as EnemyAI).get_move_direction()
	velocity = move_dir * stats.base_speed + knockback_velocity
	move_and_slide()

func take_damage(amount: int):
	if is_dead:
		return
	stats.take_damage(amount)
	if not is_instance_valid(health_bar):
		return
	health_bar.value = stats.current_hp

	if is_dead:
		return
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead and is_instance_valid(sprite):
		sprite.modulate = Color.WHITE

	if stats.is_dead():
		_die()

func apply_knockback(force: Vector2):
	knockback_velocity = force

func _die():
	if is_dead:
		return
	is_dead = true
	_spawn_drops()
	EventBus.enemy_killed.emit(enemy_id, global_position, _is_elite)
	ObjectPool.return_enemy(self, enemy_id)

func _spawn_drops():
	var wave_config = DataManager.get_wave_config(GameManager.current_wave)
	var multiplier: float = 1.0
	if wave_config:
		multiplier = wave_config.material_multiplier

	multiplier *= GameManager.get_wave_material_multiplier()

	var player = get_tree().get_first_node_in_group("player")
	var harvesting: float = 0.0
	if player and player.has_node("StatsComponent"):
		harvesting = player.get_node("StatsComponent").get_stat("harvesting")
	multiplier *= (1.0 + harvesting / 50.0)

	var amount: int = _material_drop + randi() % 3
	if _is_elite:
		amount *= 3
	amount = max(1, int(amount * multiplier))

	for i in range(amount):
		var pickup = ObjectPool.get_pickup()
		pickup.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		pickup.set("value", 1)
		pickup.set("attracted", false)
		pickup.set("player_ref", null)

		var container = get_tree().get_first_node_in_group("pickups_container")
		if container:
			container.add_child(pickup)
		else:
			get_tree().root.add_child(pickup)
