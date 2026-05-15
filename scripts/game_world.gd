extends Node2D

@onready var enemies_container: Node2D = $Enemies
@onready var pickups_container: Node2D = $Pickups

func _ready():
	enemies_container.add_to_group("enemies_container")
	pickups_container.add_to_group("pickups_container")
	_create_floor()
	_create_boundaries()
	_spawn_player()

func _create_floor():
	var image = Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.18, 0.18, 0.18, 1.0))
	var texture = ImageTexture.create_from_image(image)
	var floor = Sprite2D.new()
	floor.texture = texture
	floor.centered = true
	floor.position = Vector2(960, 540)
	floor.z_index = -10
	add_child(floor)

func _create_boundaries():
	var wall_thickness = 20.0
	var map_w = 1920.0
	var map_h = 1080.0

	var walls = [
		{"pos": Vector2(map_w / 2, -wall_thickness / 2), "size": Vector2(map_w, wall_thickness)},
		{"pos": Vector2(map_w / 2, map_h + wall_thickness / 2), "size": Vector2(map_w, wall_thickness)},
		{"pos": Vector2(-wall_thickness / 2, map_h / 2), "size": Vector2(wall_thickness, map_h)},
		{"pos": Vector2(map_w + wall_thickness / 2, map_h / 2), "size": Vector2(wall_thickness, map_h)},
	]

	for wall_def in walls:
		var wall = StaticBody2D.new()
		wall.collision_layer = 6
		wall.collision_mask = 1 | 2
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = wall_def["size"]
		shape.shape = rect
		wall.add_child(shape)
		wall.position = wall_def["pos"]
		add_child(wall)

func _spawn_player():
	var player_scene = load("res://scenes/entities/player.tscn")
	var player = player_scene.instantiate()
	player.position = Vector2(960, 540)
	add_child(player)
