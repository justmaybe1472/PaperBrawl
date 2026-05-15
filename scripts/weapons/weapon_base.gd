class_name WeaponBase
extends Node2D

@export var weapon_id: String = ""
var weapon_data: WeaponData
var player_stats: StatsComponent
var cooldown_timer: Timer

func _ready():
	weapon_data = DataManager.get_weapon(weapon_id)
	if weapon_data == null:
		push_error("Weapon: No weapon data for id: " + weapon_id)
		return
	_setup_cooldown()

func _setup_cooldown():
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = get_effective_cooldown()
	cooldown_timer.timeout.connect(_on_cooldown_ready)
	add_child(cooldown_timer)
	cooldown_timer.start()

func get_effective_cooldown() -> float:
	if player_stats == null:
		return weapon_data.cooldown
	var attack_speed: float = player_stats.get_stat("attack_speed")
	var effective: float = weapon_data.cooldown / (1.0 + attack_speed / 100.0)
	return max(effective, 0.1)

func _on_cooldown_ready():
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		cooldown_timer.start()
		return
	attack()
	cooldown_timer.wait_time = get_effective_cooldown()
	cooldown_timer.start()

func attack():
	pass
