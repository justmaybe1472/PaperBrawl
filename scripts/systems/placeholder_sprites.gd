class_name PlaceholderSprites
extends RefCounted

static func apply_square_texture(sprite: Sprite2D, color: Color, size: float):
	var image = Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	sprite.centered = true
