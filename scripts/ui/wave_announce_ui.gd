extends Control

func _ready():
	EventBus.wave_started.connect(_on_wave_started)
	hide()

func _on_wave_started(wave_number: int):
	_show_announcement(wave_number)

func _show_announcement(wave_number: int):
	_clear_children()  # 清除上一次公告的残留节点

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var label = Label.new()
	label.text = "Wave " + str(wave_number)
	if wave_number == 20:
		label.text = "BOSS - Wave 20"  # 最后一波是Boss战，特殊提示
	label.position = Vector2(440, 300)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.GOLD if wave_number < 20 else Color.RED)  # Boss波用红色警示
	add_child(label)

	var sub = Label.new()
	sub.text = "准备战斗！" if wave_number < 20 else "最终决战！"
	sub.position = Vector2(490, 380)
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color.WHITE)
	add_child(sub)

	show()

	# Tween动画：淡入 -> 停留1.5秒 -> 淡出 -> 隐藏
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): hide(); modulate.a = 1.0)  # 重置alpha供下次使用

func _clear_children():
	for child in get_children():
		child.queue_free()
