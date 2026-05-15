class_name EnemyAI
extends Node

enum AIState { IDLE, CHASE }

var current_state: AIState = AIState.IDLE

@export var chase_speed: float = 100.0

var player_ref: Node2D

func _ready():
	_find_player()

func _find_player():
	player_ref = get_tree().get_first_node_in_group("player")

func get_move_direction() -> Vector2:
	if player_ref == null:
		_find_player()
		if player_ref == null:
			return Vector2.ZERO

	var owner_body = get_parent() as CharacterBody2D
	if owner_body == null:
		return Vector2.ZERO

	var dir = (player_ref.global_position - owner_body.global_position).normalized()
	return dir
