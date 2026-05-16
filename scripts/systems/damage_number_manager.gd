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
	var color = Color(1.0, 0.3, 0.3) if is_crit else Color.WHITE
	label.setup(str(amount), color, target.global_position + Vector2(randf_range(-20, 20), -30), is_crit)
