class_name PlaceholderSprites
extends RefCounted

static func make_square_texture(color: Color, size: float) -> ImageTexture:
	var image = Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

static func apply_square_texture(sprite: Sprite2D, color: Color, size: float):
	sprite.texture = make_square_texture(color, size)
	sprite.centered = true
