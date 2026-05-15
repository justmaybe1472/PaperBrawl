extends EnemyAI
class_name EnemyAICharger

enum ChargerState { CHASE, WINDUP, CHARGE, STUN }
var charger_state: ChargerState = ChargerState.CHASE
var state_timer: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO

const WINDUP_TIME: float = 0.5
const CHARGE_TIME: float = 0.5
const STUN_TIME: float = 0.3
const CHARGE_SPEED: float = 400.0
const WINDUP_RANGE: float = 200.0

func get_move_direction() -> Vector2:
	if player_ref == null:
		_find_player()
		if player_ref == null:
			return Vector2.ZERO

	var owner_body = get_owner_body()
	if owner_body == null:
		return Vector2.ZERO

	var to_player = player_ref.global_position - owner_body.global_position
	var dist = to_player.length()

	match charger_state:
		ChargerState.CHASE:
			if dist < WINDUP_RANGE:
				charger_state = ChargerState.WINDUP
				state_timer = WINDUP_TIME
				charge_direction = to_player.normalized()
				return Vector2.ZERO
			return to_player.normalized()

		ChargerState.WINDUP:
			state_timer -= get_process_delta_time()
			if state_timer <= 0.0:
				charger_state = ChargerState.CHARGE
				state_timer = CHARGE_TIME
				chase_speed = CHARGE_SPEED
			return Vector2.ZERO

		ChargerState.CHARGE:
			state_timer -= get_process_delta_time()
			if state_timer <= 0.0:
				charger_state = ChargerState.STUN
				state_timer = STUN_TIME
				chase_speed = 60.0
			return charge_direction

		ChargerState.STUN:
			state_timer -= get_process_delta_time()
			if state_timer <= 0.0:
				charger_state = ChargerState.CHASE
			return Vector2.ZERO

	return Vector2.ZERO
