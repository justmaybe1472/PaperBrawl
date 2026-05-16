extends Control

# HUD 绑定场景树中的子节点引用，使用 @onready 确保节点初始化完成
@onready var wave_label: Label = $TopBar/WaveLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var material_label: Label = $BottomBar/MaterialLabel

# 武器图标数组，预创建6个 TextureRect，索引与 PlayerWeaponSlot.slots 一一对应
var weapon_slot_icons: Array = []
# 冷却遮罩数组，每个图标对应一个半透明黑色 ColorRect 覆盖层
var _cooldown_overlays: Array = []
var weapon_slots_container: HBoxContainer

func _ready():
	# 连接游戏事件到 UI 刷新函数，实现数据驱动的界面更新
	EventBus.game_started.connect(_on_game_started)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_timer_updated.connect(_on_timer_updated)
	EventBus.player_damaged.connect(_on_player_damaged)  # 受伤后刷新血条
	EventBus.player_died.connect(_on_player_died)
	EventBus.material_collected.connect(_on_material_collected)  # 拾取材料后更新计数
	EventBus.weapon_fired.connect(_on_weapon_fired)  # 武器开火时图标闪烁
	EventBus.weapon_synthesized.connect(_on_weapon_synthesized)  # 合成后刷新图标
	# 武器购买后刷新槽位，使用 lambda 忽略未使用的回调参数
	EventBus.weapon_purchased.connect(func(_wid, _p): _refresh_weapon_slots())

	_create_weapon_slots()
	# Control 节点默认不调用 _process，手动启用用于更新冷却遮罩
	set_process(true)

# 每帧更新武器冷却遮罩：从武器节点读取冷却计时器，转换为覆盖层高度
func _process(_delta):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var slot_manager = player.weapon_slots
	if slot_manager == null:
		return
	for i in range(6):
		var overlay = _cooldown_overlays[i] as ColorRect
		if i < slot_manager.slots.size() and not slot_manager.slots[i].is_empty():
			var slot = slot_manager.slots[i]
			var weapon_node = slot.get("node")
			if weapon_node and is_instance_valid(weapon_node):
				var timer = weapon_node.get("cooldown_timer")
				if timer and is_instance_valid(timer) and timer.time_left > 0:
					var progress = timer.time_left / max(timer.wait_time, 0.001)
					overlay.size = Vector2(32, 32 * progress)
					overlay.position = Vector2(0, 32 * (1.0 - progress))
					overlay.visible = true
				else:
					overlay.visible = false
			else:
				overlay.visible = false
		else:
			overlay.visible = false

# 动态构建武器槽 UI：6个图标水平排列，带冷却遮罩覆盖层
# 每个槽位 = Control容器(含TextureRect图标 + ColorRect冷却遮罩)
func _create_weapon_slots():
	weapon_slots_container = HBoxContainer.new()
	weapon_slots_container.name = "WeaponSlots"
	weapon_slots_container.add_theme_constant_override("separation", 4)  # 图标间距4像素
	weapon_slots_container.position = Vector2(10, 656)  # 屏幕底部左下角
	add_child(weapon_slots_container)
	for i in range(6):  # 与 MAX_SLOTS 保持一致
		# 每槽位用一个 Control 容器包裹图标和冷却遮罩
		var slot_container = Control.new()
		slot_container.custom_minimum_size = Vector2(32, 32)
		weapon_slots_container.add_child(slot_container)
		# 武器图标
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.visible = false
		slot_container.add_child(icon)
		weapon_slot_icons.append(icon)
		# 冷却遮罩：半透明黑色块从顶部覆盖，高度随冷却进度减少
		var overlay = ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.5)  # 半透明黑色遮罩
		overlay.size = Vector2(32, 32)  # 初始满覆盖
		overlay.position = Vector2(0, 0)
		overlay.visible = false
		slot_container.add_child(overlay)
		_cooldown_overlays.append(overlay)

func _on_game_started():
	_update_hp_bar()  # 游戏开始时初始化血条显示
	_refresh_weapon_slots()  # 加载初始武器图标
	show()

func _on_wave_started(wave_number: int):
	wave_label.text = "Wave: %d/20" % wave_number  # 显示当前波次/总波次

func _on_timer_updated(time_left: float):
	timer_label.text = "Time: %.0fs" % time_left  # 显示整数秒，方便玩家阅读

func _on_player_damaged(_amount: int, _new_hp: int):
	_update_hp_bar()  # 每次受伤刷新血条

func _on_player_died():
	wave_label.text = "GAME OVER"  # 复用波次标签显示游戏结束

func _on_material_collected(_amount: int, total: int):
	material_label.text = str(total)  # 显示累计材料总数

# 武器开火时图标闪烁（白色高亮后0.15秒渐隐），提供视觉反馈
func _on_weapon_fired(weapon_id: String, _position: Vector2, _direction: Vector2):
	for icon in weapon_slot_icons:
		if icon.visible and icon.get_meta("weapon_id", "") == weapon_id:
			icon.self_modulate = Color(1.5, 1.5, 1.5)
			var tween = create_tween()
			tween.tween_property(icon, "self_modulate", Color.WHITE, 0.15)
			break

func _on_weapon_synthesized(weapon_id: String, new_tier: int):
	_refresh_weapon_slots()
	# 合成成功视觉反馈：弹出浮动文字提示品阶提升
	_show_synthesis_feedback(weapon_id, new_tier)

# 从玩家 StatsComponent 拉取实时 HP 数据更新血条和文本
func _update_hp_bar():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var stats = player.stats
	var max_hp = stats.get_stat("max_hp")
	hp_bar.max_value = max_hp
	hp_bar.value = stats.hp
	hp_label.text = "%d/%d" % [stats.hp, int(max_hp)]

# 从 Player 的 weapon_slots 管理器读取并刷新6个武器图标槽
func _refresh_weapon_slots():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var slot_manager = player.weapon_slots
	if slot_manager == null:
		return

	for i in range(6):
		if i < slot_manager.slots.size() and not slot_manager.slots[i].is_empty():
			var slot = slot_manager.slots[i]
			var wdata = DataManager.get_weapon(slot["weapon_id"])
			if wdata:
				# 使用 PlaceholderSprites 生成对应类型和品阶的武器图标
				weapon_slot_icons[i].texture = PlaceholderSprites.make_weapon_icon(wdata.weapon_class, slot["tier"])
				weapon_slot_icons[i].set_meta("weapon_id", slot["weapon_id"])  # 存储ID供开火闪烁匹配
				weapon_slot_icons[i].set_meta("slot_index", i)  # 存储槽位索引供冷却显示
				weapon_slot_icons[i].visible = true
			else:
				weapon_slot_icons[i].visible = false
		else:
			weapon_slot_icons[i].visible = false

# 武器合成成功时弹出浮动提示文字，显示品阶提升信息
func _show_synthesis_feedback(weapon_id: String, new_tier: int):
	var wdata = DataManager.get_weapon(weapon_id)
	var weapon_name = weapon_id
	if wdata:
		weapon_name = wdata.display_name
	# 创建浮动标签，居中显示，向上飘动并渐隐
	var label = Label.new()
	var tier_names = {1: "普通", 2: "精良", 3: "稀有", 4: "传说"}
	var tier_name = tier_names.get(new_tier, "Lv+" + str(new_tier))
	label.text = weapon_name + " 合成成功！品质提升至 " + tier_name
	label.position = Vector2(390, 400)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.GOLD)
	add_child(label)
	# 向上飘动 1.5 秒后淡出销毁
	var tween = create_tween()
	tween.tween_property(label, "position:y", 340, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5).set_delay(0.8)
	tween.finished.connect(label.queue_free)
