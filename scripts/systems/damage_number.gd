extends Label

var velocity: Vector2 = Vector2(0, -80.0)  # 初始向上飘动
var lifetime: float = 0.8  # 总显示时长（秒）
var gravity: float = 20.0  # 模拟减速上升的重力感

func _ready():
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 16)
	z_index = 100  # 确保伤害数字显示在所有游戏对象之上

func setup(text: String, color: Color, pos: Vector2, is_crit: bool):
	self.text = text
	if is_crit:
		# 暴击伤害数字更大、金色、飞更高，视觉上明显区分
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

	velocity.y += gravity * delta  # 重力减速，让数字先快后慢升起
	global_position += velocity * delta
	# 最后0.3秒内逐渐透明消失，避免突兀消失
	modulate.a = clamp(lifetime / 0.3, 0.0, 1.0)
