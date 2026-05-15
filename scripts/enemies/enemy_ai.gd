class_name EnemyAI
extends Node

enum AIState { IDLE, CHASE }

var current_state: AIState = AIState.IDLE
var chase_speed: float = 100.0
var player_ref: Node2D
var enemy_data: EnemyData

func _ready():
	_find_player()

func _find_player():
	player_ref = get_tree().get_first_node_in_group("player")

func get_move_direction() -> Vector2:
	return Vector2.ZERO

func get_owner_body() -> CharacterBody2D:
	return get_parent() as CharacterBody2D
