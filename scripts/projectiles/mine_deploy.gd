extends Area2D

var _armed: bool = false
var _arm_timer: float = 0.5
var _damage: float = 15.0
var _knockback: float = 100.0

func setup(damage: float, knockback: float):
	_damage = damage
	_knockback = knockback

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	if not _armed:
		_arm_timer -= delta
		if _arm_timer <= 0.0:
			_armed = true

func _on_body_entered(body: Node2D):
	if not _armed:
		return
	if body.is_in_group("enemy") and not body.is_dead:
		body.take_damage(int(_damage))
		if _knockback > 0:
			var kb = (body.global_position - global_position).normalized() * _knockback
			body.apply_knockback(kb)
		queue_free()
