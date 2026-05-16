extends Label

var velocity: Vector2 = Vector2(0, -80.0)
var lifetime: float = 0.8
var gravity: float = 20.0

func _ready():
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 16)
	z_index = 100

func setup(text: String, color: Color, pos: Vector2, is_crit: bool):
	self.text = text
	if is_crit:
		add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		add_theme_font_size_override("font_size", 22)
		velocity = Vector2(0, -120.0)
		lifetime = 1.0
	else:
		add_theme_color_override("font_color", color)
	global_position = pos

func _process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	velocity.y += gravity * delta
	global_position += velocity * delta
	modulate.a = clamp(lifetime / 0.3, 0.0, 1.0)
