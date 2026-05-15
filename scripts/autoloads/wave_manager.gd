extends Node

var wave_timer: float = 0.0
var spawn_timer: float = 0.0
var enemies_alive: int = 0
var enemies_spawned: int = 0
var enemies_to_spawn: int = 0
var spawn_interval: float = 1.0
var wave_active: bool = false

var enemy_scene: PackedScene

func _ready():
	enemy_scene = preload("res://scenes/entities/enemy_base.tscn")
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_killed.connect(_on_enemy_killed)

func _on_wave_started(wave_number: int):
	var config = DataManager.get_wave_config(wave_number)
	if config == null:
		push_error("WaveManager: No config for wave " + str(wave_number))
		return

	wave_timer = config.duration
	enemies_to_spawn = config.total_enemies
	spawn_interval = config.spawn_interval
	enemies_spawned = 0
	enemies_alive = 0
	spawn_timer = 0.0
	wave_active = true

func _on_enemy_killed(_enemy_id: String, _position: Vector2, _is_elite: bool):
	enemies_alive -= 1

func _process(delta):
	if not wave_active:
		return
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return

	wave_timer -= delta
	spawn_timer -= delta

	EventBus.wave_timer_updated.emit(max(0.0, wave_timer))

	if enemies_spawned < enemies_to_spawn and spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = spawn_interval
		enemies_spawned += 1
		enemies_alive += 1

	if wave_timer <= 0.0 and enemies_alive <= 0:
		_end_wave()
	elif wave_timer <= 0.0 and enemies_alive <= 5:
		_end_wave()

func _spawn_enemy():
	var enemy_data = DataManager.get_enemy("basic_melee")
	if enemy_data == null:
		push_error("WaveManager: No enemy data for 'basic_melee'")
		return

	var enemy = enemy_scene.instantiate()

	var player = get_tree().get_first_node_in_group("player")
	var spawn_center = player.global_position if player else Vector2(960, 540)
	var angle = randf() * TAU
	var spawn_distance = 800.0
	enemy.global_position = spawn_center + Vector2(cos(angle), sin(angle)) * spawn_distance

	var container = get_tree().get_first_node_in_group("enemies_container")
	if container:
		container.add_child(enemy)
	else:
		get_tree().root.add_child(enemy)

	enemy.init(enemy_data, GameManager.current_wave)

func _end_wave():
	wave_active = false
	GameManager.change_state(GameManager.GameState.SHOP)
