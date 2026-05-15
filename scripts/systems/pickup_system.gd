extends Area2D

var value: int = 1
var attracted: bool = false
var player_ref: Node2D
var attraction_speed: float = 350.0
var pickup_range: float = 80.0

func _ready():
	collision_layer = 5
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)

	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderSprites.make_square_texture(Color.GREEN, 12.0)
	add_child(sprite)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)

func _process(delta):
	if attracted and player_ref:
		var dir = (player_ref.global_position - global_position).normalized()
		global_position += dir * attraction_speed * delta
		if global_position.distance_to(player_ref.global_position) < 10.0:
			_collect()
	else:
		_check_player_proximity()

func _check_player_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) < pickup_range:
		start_attraction(player)

func start_attraction(player: Node2D):
	if not attracted:
		attracted = true
		player_ref = player

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		_collect()

func _collect():
	GameManager.add_materials(value)
	queue_free()
