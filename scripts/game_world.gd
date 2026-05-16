# 游戏世界场景：组装地图边界、地板、容器组、玩家和辅助系统
extends Node2D

@onready var enemies_container: Node2D = $Enemies  # 所有敌人节点容器，供外部遍历
@onready var pickups_container: Node2D = $Pickups  # 所有掉落物节点容器

func _ready():
	# 注册容器组名，方便外部通过 get_first_node_in_group 查找
	enemies_container.add_to_group("enemies_container")
	pickups_container.add_to_group("pickups_container")
	_create_floor()
	_create_boundaries()
	_spawn_player()
	_create_damage_numbers()

# 动态创建伤害数字层和音频管理器（无需 .tscn 文件）
func _create_damage_numbers():
	var canvas = CanvasLayer.new()
	canvas.name = "DamageNumberLayer"
	canvas.set_script(load("res://scripts/systems/damage_number_manager.gd"))
	add_child(canvas)

	var audio = Node.new()
	audio.name = "AudioManager"
	audio.set_script(load("res://scripts/systems/audio_manager.gd"))
	add_child(audio)

# 创建 1920×1080 深灰纯色地板，z_index=-10 确保在所有实体下方
func _create_floor():
	var image = Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.18, 0.18, 0.18, 1.0))
	var texture = ImageTexture.create_from_image(image)
	var floor_sprite = Sprite2D.new()
	floor_sprite.texture = texture
	floor_sprite.centered = true
	floor_sprite.position = Vector2(960, 540)
	floor_sprite.z_index = -10
	add_child(floor_sprite)

# 四条20px厚的静态矩形墙壁围成地图边界，layer=6 mask=1|2 阻挡玩家和敌人
func _create_boundaries():
	var wall_thickness = 20.0
	var map_w = 1920.0
	var map_h = 1080.0

	var walls = [
		{"pos": Vector2(map_w / 2, -wall_thickness / 2), "size": Vector2(map_w, wall_thickness)},  # 上
		{"pos": Vector2(map_w / 2, map_h + wall_thickness / 2), "size": Vector2(map_w, wall_thickness)},  # 下
		{"pos": Vector2(-wall_thickness / 2, map_h / 2), "size": Vector2(wall_thickness, map_h)},  # 左
		{"pos": Vector2(map_w + wall_thickness / 2, map_h / 2), "size": Vector2(wall_thickness, map_h)},  # 右
	]

	for wall_def in walls:
		var wall = StaticBody2D.new()
		wall.collision_layer = 6  # WorldBoundary 层
		wall.collision_mask = 1 | 2  # 阻挡 Player(1) 和 Enemy(2)
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = wall_def["size"]
		shape.shape = rect
		wall.add_child(shape)
		wall.position = wall_def["pos"]
		add_child(wall)

# 加载玩家场景并放置在地图中央 (960, 540)
func _spawn_player():
	var player_scene = load("res://scenes/entities/player.tscn")
	var player = player_scene.instantiate()
	player.position = Vector2(960, 540)
	add_child(player)
