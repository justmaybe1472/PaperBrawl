extends EnemyAI
class_name EnemyAIBoss

enum BossPhase { PHASE1, PHASE2, PHASE3 }
enum ChargeState { NONE, CHARGING, RECOVERING }

var boss_phase: BossPhase = BossPhase.PHASE1
var charge_state: ChargeState = ChargeState.NONE
var charge_state_timer: float = 0.0

var shoot_timer: float = 0.0
var charge_timer: float = 3.0
var summon_timer: float = 4.0

var charge_direction: Vector2 = Vector2.ZERO

const CHARGE_SPEED: float = 350.0
const CHARGE_DURATION: float = 0.8
const CHARGE_RECOVER: float = 0.5
const SHOOT_INTERVAL: float = 1.5
const CHARGE_INTERVAL: float = 3.0
const SUMMON_INTERVAL: float = 4.0

var projectile_scene: PackedScene
var minion_scene: PackedScene

func _ready():
	super._ready()
	projectile_scene = preload("res://scenes/entities/enemy_projectile.tscn")
	minion_scene = preload("res://scenes/entities/enemy_base.tscn")

func get_move_direction() -> Vector2:
	if player_ref == null:
		_find_player()
		if player_ref == null:
			return Vector2.ZERO

	var owner_body = get_owner_body()
	if owner_body == null:
		return Vector2.ZERO

	_update_phase(owner_body)

	var to_player = player_ref.global_position - owner_body.global_position

	match charge_state:
		ChargeState.CHARGING:
			charge_state_timer -= get_process_delta_time()
			if charge_state_timer <= 0.0:
				charge_state = ChargeState.RECOVERING
				charge_state_timer = CHARGE_RECOVER
				chase_speed = 100.0
			return charge_direction
		ChargeState.RECOVERING:
			charge_state_timer -= get_process_delta_time()
			if charge_state_timer <= 0.0:
				charge_state = ChargeState.NONE
				charge_timer = CHARGE_INTERVAL
			return Vector2.ZERO

	match boss_phase:
		BossPhase.PHASE1:
			return _phase1(to_player)
		BossPhase.PHASE2:
			return _phase2(to_player)
		BossPhase.PHASE3:
			return _phase3(to_player, owner_body)

	return to_player.normalized()

func _update_phase(owner_body: CharacterBody2D):
	var enemy_stats = owner_body.get_node_or_null("EnemyStats")
	if enemy_stats == null:
		return
	var hp_ratio = enemy_stats.current_hp / max(enemy_stats.base_hp, 1.0)
	if hp_ratio < 0.3:
		boss_phase = BossPhase.PHASE3
	elif hp_ratio < 0.6:
		boss_phase = BossPhase.PHASE2

func _phase1(to_player: Vector2) -> Vector2:
	charge_timer -= get_process_delta_time()
	if charge_timer <= 0.0 and charge_state == ChargeState.NONE:
		charge_state = ChargeState.CHARGING
		charge_state_timer = CHARGE_DURATION
		charge_direction = to_player.normalized()
		chase_speed = CHARGE_SPEED
	return to_player.normalized()

func _phase2(to_player: Vector2) -> Vector2:
	shoot_timer -= get_process_delta_time()
	if shoot_timer <= 0.0:
		shoot_timer = SHOOT_INTERVAL
		_shoot_spread(to_player.normalized())
	return to_player.normalized()

func _phase3(to_player: Vector2, owner_body: CharacterBody2D) -> Vector2:
	shoot_timer -= get_process_delta_time()
	summon_timer -= get_process_delta_time()

	if shoot_timer <= 0.0:
		shoot_timer = SHOOT_INTERVAL * 0.7
		_shoot_spread(to_player.normalized())

	if summon_timer <= 0.0:
		summon_timer = SUMMON_INTERVAL
		_spawn_minions(owner_body)

	charge_timer -= get_process_delta_time()
	if charge_timer <= 0.0 and charge_state == ChargeState.NONE:
		charge_state = ChargeState.CHARGING
		charge_state_timer = CHARGE_DURATION * 0.6
		charge_direction = to_player.normalized()
		chase_speed = CHARGE_SPEED

	return to_player.normalized()

func _shoot_spread(direction: Vector2):
	var owner_body = get_owner_body()
	if owner_body == null:
		return
	var dmg: int = 8
	if enemy_data:
		dmg = int(enemy_data.base_damage * 0.7)
	for i in range(3):
		var angle_offset = (i - 1) * 0.3
		var dir = direction.rotated(angle_offset)
		var proj = projectile_scene.instantiate()
		proj.global_position = owner_body.global_position
		proj.direction = dir
		proj.damage = dmg
		get_tree().root.add_child(proj)

func _spawn_minions(owner_body: CharacterBody2D):
	var minion_data = DataManager.get_enemy("fast_chaser")
	if minion_data == null:
		minion_data = DataManager.get_enemy("basic_melee")
	if minion_data == null:
		return

	for i in range(2):
		var minion = minion_scene.instantiate()
		var angle = randf() * TAU
		minion.global_position = owner_body.global_position + Vector2(cos(angle), sin(angle)) * 60.0
		var container = get_tree().get_first_node_in_group("enemies_container")
		if container:
			container.add_child(minion)
		else:
			get_tree().root.add_child(minion)
		minion.init(minion_data, GameManager.current_wave)
