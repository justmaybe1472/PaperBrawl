extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var damage: int = 5
var lifetime: float = 5.0

func _ready():
	body_entered.connect(_on_body_entered)
	collision_layer = 4
	collision_mask = 1

func _process(delta):
	lifetime -= delta
	if lifetime <= 0.0:
		ObjectPool.return_enemy_projectile(self)
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		body.apply_damage(damage)
		ObjectPool.return_enemy_projectile(self)
