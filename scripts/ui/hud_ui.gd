extends Control

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var material_label: Label = $BottomBar/MaterialLabel

func _ready():
	EventBus.game_started.connect(_on_game_started)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_timer_updated.connect(_on_timer_updated)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_player_died)
	EventBus.material_collected.connect(_on_material_collected)

func _on_game_started():
	_update_hp_bar()
	show()

func _on_wave_started(wave_number: int):
	wave_label.text = "Wave: %d/20" % wave_number

func _on_timer_updated(time_left: float):
	timer_label.text = "Time: %.0fs" % time_left

func _on_player_damaged(_amount: int, _new_hp: int):
	_update_hp_bar()

func _on_player_died():
	wave_label.text = "GAME OVER"

func _on_material_collected(_amount: int, total: int):
	material_label.text = str(total)

func _update_hp_bar():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var stats = player.stats
	var max_hp = stats.get_stat("max_hp")
	hp_bar.max_value = max_hp
	hp_bar.value = stats.hp
	hp_label.text = "%d/%d" % [stats.hp, int(max_hp)]
