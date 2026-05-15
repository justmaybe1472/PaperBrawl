extends Area2D

var _life: float = 8.0
var _fire_timer: float = 0.0
var _fire_rate: float = 1.5
var _damage: float = 5.0

func setup(lifetime: float, fire_rate: float, damage: float, collision_radius: float):
	_life = lifetime
	_fire_rate = fire_rate
	_damage = damage
	_fire_timer = fire_rate * 0.3

func _process(delta):
	_life -= delta
	_fire_timer -= delta
	if _life <= 0.0:
		queue_free()
		return

	if _fire_timer <= 0.0:
		_fire_timer = _fire_rate
		var enemies = get_overlapping_bodies()
		for body in enemies:
			if body.is_in_group("enemy") and not body.is_dead:
				body.take_damage(int(_damage))
				break
