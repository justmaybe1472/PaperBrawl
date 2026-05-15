extends EnemyAI
class_name EnemyAIChaser

func get_move_direction() -> Vector2:
	if player_ref == null:
		_find_player()
		if player_ref == null:
			return Vector2.ZERO

	var owner_body = get_owner_body()
	if owner_body == null:
		return Vector2.ZERO

	return (player_ref.global_position - owner_body.global_position).normalized()
