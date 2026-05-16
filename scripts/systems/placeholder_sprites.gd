class_name PlaceholderSprites
extends RefCounted

const TEX_PATH = "res://assets/TestTexture/"
const TEX_SIZE = 216.0  # TestTexture 统一尺寸，所有缩放基于此基准计算

# 加载 TestTexture 并根据目标尺寸返回缩放值
static func load_test_texture(file_name: String) -> ImageTexture:
	var path = TEX_PATH + file_name
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is CompressedTexture2D or res is ImageTexture:
			return res
	return null

static func get_scale_for_size(target_size: float) -> float:
	return target_size / TEX_SIZE  # 比例缩放，保证不同尺寸需求使用同一纹理

# 为 Sprite2D 应用 TestTexture，自动缩放至目标尺寸
static func apply_test_texture(sprite: Sprite2D, file_name: String, target_size: float):
	var tex = load_test_texture(file_name)
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2.ONE * get_scale_for_size(target_size)
		sprite.centered = true

static func make_square_texture(color: Color, size: float) -> ImageTexture:
	var image = Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

static func make_circle_texture(color: Color, radius: int) -> ImageTexture:
	var size = radius * 2
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(size):
		for y in range(size):
			var dx = x - radius + 0.5
			var dy = y - radius + 0.5
			if dx * dx + dy * dy <= (radius - 1) * (radius - 1):
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func make_diamond_texture(color: Color, size: int) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var half = size / 2.0
	for x in range(size):
		for y in range(size):
			if abs(x - half) + abs(y - half) <= half - 1:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func make_triangle_texture(color: Color, size: int) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var half = size / 2.0
	for x in range(size):
		for y in range(size):
			var fy = size - y
			if abs(x - half) * 1.8 <= fy and fy <= size:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func apply_square_texture(sprite: Sprite2D, color: Color, size: float):
	sprite.texture = make_square_texture(color, size)
	sprite.centered = true

static func apply_circle_texture(sprite: Sprite2D, color: Color, radius: int):
	sprite.texture = make_circle_texture(color, radius)
	sprite.centered = true

static func apply_diamond_texture(sprite: Sprite2D, color: Color, size: int):
	sprite.texture = make_diamond_texture(color, size)
	sprite.centered = true

static func make_weapon_icon(weapon_class: String, tier: int) -> ImageTexture:
	var colors = {
		"melee": Color(0.8, 0.5, 0.2),
		"ranged": Color(0.3, 0.6, 1.0),
		"elemental": Color(0.8, 0.2, 0.8),
		"engineering": Color(0.2, 0.8, 0.6),
		"primitive": Color(0.6, 0.6, 0.5),
	}
	var color = colors.get(weapon_class, Color.WHITE)
	var tier_brightness = [0.6, 0.8, 1.0, 1.3]
	color = color * tier_brightness[min(tier - 1, 3)]

	var shapes = {
		"melee": make_diamond_texture,
		"ranged": make_circle_texture,
		"elemental": make_triangle_texture,
		"engineering": make_square_texture,
		"primitive": make_circle_texture,
	}
	var shape_func = shapes.get(weapon_class, make_square_texture)
	if weapon_class == "ranged" or weapon_class == "primitive":
		return shape_func.call(color, 12)
	elif weapon_class == "elemental":
		return shape_func.call(color, 24)
	else:
		return shape_func.call(color, 22)
