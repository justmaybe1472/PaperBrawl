extends EnemyAI
class_name EnemyAISummoner

var summon_timer: float = 0.0
var summon_interval: float = 3.0

func get_move_direction() -> Vector2:
	summon_timer -= get_process_delta_time()
	if summon_timer <= 0.0:
		summon_timer = summon_interval
		_summon_minion()
	return Vector2.ZERO

func _summon_minion():
	var owner_body = get_owner_body()
	if owner_body == null:
		return

	var minion_data = DataManager.get_enemy("basic_melee")
	if minion_data == null:
		return

	var minion = ObjectPool.get_enemy("basic_melee")
	var angle = randf() * TAU
	minion.global_position = owner_body.global_position + Vector2(cos(angle), sin(angle)) * 50.0

	var container = get_tree().get_first_node_in_group("enemies_container")
	if container:
		container.add_child(minion)
	else:
		get_tree().root.add_child(minion)

	minion.init(minion_data, GameManager.current_wave)

	var wave_manager = get_node("/root/WaveManager")
	if wave_manager and wave_manager.has_method("_on_summon"):
		wave_manager._on_summon()
