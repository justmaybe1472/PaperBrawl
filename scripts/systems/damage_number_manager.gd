extends CanvasLayer

const DAMAGE_NUMBER = preload("res://scripts/systems/damage_number.gd")

func _ready():
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(source: Node, target: Node, amount: int, is_crit: bool):
	if amount <= 0:
		return
	var label = Label.new()
	label.set_script(DAMAGE_NUMBER)
	add_child(label)

	# 将世界坐标转换为屏幕坐标，因为伤害数字是CanvasLayer子节点
	var world_pos = target.global_position + Vector2(randf_range(-20, 20), -30)  # 随机偏移避免重叠
	var canvas_transform = get_viewport().get_canvas_transform()
	var screen_pos = canvas_transform * world_pos

	var color = Color(1.0, 0.3, 0.3) if is_crit else Color.WHITE  # 暴击用红色更醒目
	label.setup(str(amount), color, screen_pos, is_crit)
