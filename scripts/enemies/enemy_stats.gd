class_name EnemyStats
extends Node

var base_hp: float = 10.0
var base_damage: float = 5.0
var base_speed: float = 100.0
var current_hp: float = 10.0
var wave_number: int = 1

func init_from_data(enemy_data: EnemyData, wave: int):
	base_hp = enemy_data.base_hp
	base_damage = enemy_data.base_damage
	base_speed = enemy_data.base_speed
	wave_number = wave
	_apply_wave_scaling()
	current_hp = base_hp

func _apply_wave_scaling():
	base_hp *= (1.0 + 0.15 * (wave_number - 1))
	base_damage *= (1.0 + 0.10 * (wave_number - 1))
	var original_speed = base_speed
	base_speed *= (1.0 + 0.03 * (wave_number - 1))
	base_speed = min(base_speed, original_speed * 1.5)

	var difficulty_mult = GameManager.get_enemy_stat_multiplier()
	base_hp *= difficulty_mult
	base_damage *= difficulty_mult
	base_speed *= (1.0 + (difficulty_mult - 1.0) * 0.3)

func get_stat(stat_name: String) -> float:
	match stat_name:
		"max_hp": return base_hp
		"base_damage": return base_damage
		"base_speed": return base_speed
		"armor": return 0.0
		"dodge": return 0.0
		_: return 0.0

func take_damage(amount: int) -> float:
	current_hp = max(0.0, current_hp - amount)
	return current_hp

func is_dead() -> bool:
	return current_hp <= 0.0
