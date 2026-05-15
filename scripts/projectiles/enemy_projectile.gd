extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var damage: int = 5
var lifetime: float = 5.0

func _ready():
	body_entered.connect(_on_body_entered)
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.RED, 10.0)
	add_child(sprite)
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = 5.0
	add_child(shape)
	collision_layer = 4
	collision_mask = 1

func _process(delta):
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		body._apply_damage(damage)
		queue_free()
