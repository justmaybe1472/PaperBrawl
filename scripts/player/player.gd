extends CharacterBody2D
class_name Player

@export var move_speed: float = 200.0

@onready var stats: StatsComponent = $StatsComponent
@onready var weapon_container: Node2D = $WeaponContainer
@onready var hurtbox: Area2D = $Hurtbox
@onready var iframe_timer: Timer = $IFrameTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_radius: Area2D = $PickupRadius

var is_invincible: bool = false
var weapon_slots
# 用于追踪每个道具的购买次数，配合 ItemData.max_stack 实现堆叠上限
# item_id -> count，max_stack=0 表示无限制
var _item_stack_counts: Dictionary = {}
# 活跃特殊效果列表，每项为 {effect: SpecialEffect, item_id: String, remaining_uses: int}
# CONSUMABLE 类型用 remaining_uses 追踪剩余使用次数
var _active_special_effects: Array = []
# 特殊效果产生的临时属性 Buff，{stat_name: [{value, remaining_time}]}
var _active_buffs: Dictionary = {}

func _ready():
	add_to_group("player")  # 加入 player 分组，供其它节点快速查找
	iframe_timer.timeout.connect(_on_iframe_timeout)
	pickup_radius.body_entered.connect(_on_pickup_entered)
	EventBus.item_purchased.connect(_on_item_purchased)  # 监听商店购买事件
	EventBus.weapon_purchased.connect(_on_weapon_purchased)
	# 特殊效果事件监听：根据效果类型分别绑定对应信号
	EventBus.enemy_killed.connect(_on_enemy_killed_for_effects)
	EventBus.damage_dealt.connect(_on_damage_dealt_for_effects)
	EventBus.wave_started.connect(_on_wave_started_for_effects)
	EventBus.wave_completed.connect(_on_wave_completed_for_effects)

	# 动态创建武器槽管理器节点并挂载脚本，避免在场景中手动绑定
	var slot_node = Node.new()
	slot_node.name = "WeaponSlotManager"
	slot_node.set_script(load("res://scripts/player/player_weapon_slot.gd"))
	weapon_slots = slot_node
	add_child(slot_node)

	_initialize_from_data()
	# 优先使用 TestTexture，回退到占位图形
	PlaceholderSprites.apply_test_texture(sprite, "Player_1.png", 64.0)

func _initialize_from_data():
	var char_data = DataManager.get_character(GameManager.selected_character_id)
	if char_data == null:
		push_error("Player: No character data for id: " + GameManager.selected_character_id)
		return
	stats.init_from_character(char_data)
	weapon_slots.init(weapon_container, stats)
	weapon_slots.add_weapon(char_data.starting_weapon)

func _equip_starting_weapon(_weapon_id: String):
	pass  # Handled by weapon_slots.add_weapon in _initialize_from_data

func _process(delta):
	# 每帧更新临时 Buff 的剩余时间（不受波次状态影响）
	_process_effect_buffs(delta)

func _physics_process(_delta):
	# 只在波次进行中才处理移动和碰撞，商店阶段不响应
	if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
		return
	_handle_movement()
	_check_enemy_contact()

func _handle_movement():
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# speed 属性以百分比方式加成：speed=50 即 +50% 移速
	var speed_mult = 1.0 + stats.get_stat("speed") / 100.0
	velocity = input_dir * move_speed * speed_mult
	move_and_slide()

func _check_enemy_contact():
	if is_invincible:
		return
	var overlapping = hurtbox.get_overlapping_bodies()
	for body in overlapping:
		if body is EnemyBase:
			var damage = int(body.stats.get_stat("base_damage"))
			apply_damage(damage)
			break  # 每帧只处理一个敌人，防止同时被多个敌人秒杀

func apply_damage(amount: int):
	# 再次检查无敌状态——防御性编程，防止无冷却期间被多次调用
	if is_invincible:
		return
	var new_hp = stats.take_damage(amount)
	EventBus.player_damaged.emit(amount, new_hp)
	_start_iframes()  # 受伤后立刻开启无敌帧，提供短暂保护
	if stats.is_dead():
		_die()

func _start_iframes():
	is_invincible = true
	iframe_timer.start()
	# 闪烁 3 次作为无敌帧视觉反馈，半透明表示无敌状态
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(sprite, "modulate:a", 0.3, 0.08)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.08)

func _on_iframe_timeout():
	is_invincible = false
	sprite.modulate.a = 1.0  # 确保无敌结束时透明度恢复正常，防止闪烁残留

func _die():
	EventBus.player_died.emit()
	GameManager.change_state(GameManager.GameState.GAME_OVER)

func _on_pickup_entered(body: Node2D):
	# 玩家靠近掉落物后，触发磁吸效果自动拾取
	if body.has_method("start_attraction"):
		body.start_attraction(self)

func can_purchase_item(item_id: String) -> bool:
	# 检查道具堆叠上限，max_stack=0 表示无限制
	var item_data = DataManager.get_item(item_id)
	if item_data == null:
		return false
	if item_data.max_stack <= 0:
		return true  # 无堆叠限制的道具可无限购买
	var current = _item_stack_counts.get(item_id, 0)
	return current < item_data.max_stack

func get_item_stack_count(item_id: String) -> int:
	return _item_stack_counts.get(item_id, 0)

func _on_item_purchased(item_id: String, _price: int):
	var item_data = DataManager.get_item(item_id)
	if item_data == null:
		return
	# 再次确认堆叠上限——双重校验防止商店 UI 层绕过
	if not can_purchase_item(item_id):
		return
	# 递增购买次数
	_item_stack_counts[item_id] = _item_stack_counts.get(item_id, 0) + 1
	# source 以 "item:" 前缀标识来源，便于后续按来源移除修饰器
	var source = "item:" + item_id
	for stat_name in item_data.stat_modifiers:
		var value = item_data.stat_modifiers[stat_name]
		stats.add_modifier(stat_name, source, value)
	# 注册特殊效果（如有）
	_register_special_effect(item_id, item_data)

func _on_weapon_purchased(weapon_id: String, _price: int):
	# 武器购买逻辑由 weapon_slots 统一管理（合成/替换/新增）
	weapon_slots.add_weapon(weapon_id)

# ---- 特殊效果系统 ----

# 购买道具时注册其特殊效果到活跃列表
func _register_special_effect(item_id: String, item_data: ItemData):
	if item_data.special_effect == null:
		return
	var effect = item_data.special_effect
	var remaining = 999  # 非消耗品默认无限使用
	if effect.effect_type == ItemData.EffectTrigger.CONSUMABLE:
		remaining = int(effect.params.get("uses", 1))
	_active_special_effects.append({
		"effect": effect,
		"item_id": item_id,
		"remaining_uses": remaining,
	})

# 遍历活跃效果，对匹配的事件类型执行对应逻辑
func _trigger_effects(effect_type: ItemData.EffectTrigger, context: Dictionary = {}):
	for entry in _active_special_effects:
		var effect: SpecialEffect = entry["effect"]
		if effect.effect_type != effect_type:
			continue
		if entry["remaining_uses"] <= 0:
			continue
		_execute_effect(effect, entry, context)

# 执行单个特殊效果，根据参数字典驱动具体行为
func _execute_effect(effect: SpecialEffect, entry: Dictionary, context: Dictionary):
	var p = effect.params
	match effect.effect_type:
		ItemData.EffectTrigger.ON_KILL:
			_exec_on_kill(p, context)
		ItemData.EffectTrigger.ON_WAVE_END:
			_exec_on_wave_end(p)
		ItemData.EffectTrigger.ON_WAVE_START:
			_exec_on_wave_start(p)
		ItemData.EffectTrigger.ON_HIT:
			_exec_on_hit(p, context)
		ItemData.EffectTrigger.CONDITIONAL:
			pass  # 条件被动在 _process 中逐帧检查
		ItemData.EffectTrigger.CONSUMABLE:
			_exec_consumable(p, entry)

# 击杀触发效果示例：狂战士戒指 — 击杀后临时提升伤害
func _exec_on_kill(p: Dictionary, _ctx: Dictionary):
	var stat_name = p.get("stat", "damage_pct")
	var value = float(p.get("value", 0))
	var duration = float(p.get("duration", 0))
	if value > 0 and duration > 0:
		_apply_temp_buff(stat_name, value, duration)

# 波次结束效果示例：医疗包 — 回复一定百分比 HP
func _exec_on_wave_end(p: Dictionary):
	var heal_pct = float(p.get("heal_pct", 0))
	if heal_pct > 0:
		var heal_amount = int(stats.get_stat("max_hp") * heal_pct / 100.0)
		if heal_amount > 0:
			stats.heal(heal_amount)

func _exec_on_wave_start(_p: Dictionary):
	pass  # 预留：波次开始时可触发临时 Buff

func _exec_on_hit(_p: Dictionary, _ctx: Dictionary):
	pass  # 预留：命中触发效果（如吸血加成）

func _exec_consumable(_p: Dictionary, _entry: Dictionary):
	pass  # 预留：消耗品效果

# 临时 Buff 系统：在 duration 秒内为指定属性增加 value 点
func _apply_temp_buff(stat_name: String, value: float, duration: float):
	var source = "temp_buff:" + stat_name + ":" + str(Time.get_ticks_msec())
	stats.add_modifier(stat_name, source, value)
	_active_buffs[source] = {"stat_name": stat_name, "value": value, "remaining_time": duration}

func _on_enemy_killed_for_effects(_enemy_id: String, _position: Vector2, _is_elite: bool):
	_trigger_effects(ItemData.EffectTrigger.ON_KILL)

func _on_damage_dealt_for_effects(_source: Node, _target: Node, _amount: int, _is_crit: bool):
	_trigger_effects(ItemData.EffectTrigger.ON_HIT, {"source": _source, "target": _target, "amount": _amount})

func _on_wave_started_for_effects(_wave_number: int):
	_trigger_effects(ItemData.EffectTrigger.ON_WAVE_START)

func _on_wave_completed_for_effects(_wave_number: int):
	_trigger_effects(ItemData.EffectTrigger.ON_WAVE_END)

# 每帧更新临时 Buff 的剩余时间，过期后自动移除
func _process_effect_buffs(delta: float):
	var expired = []
	for source in _active_buffs:
		var buff = _active_buffs[source]
		buff["remaining_time"] -= delta
		if buff["remaining_time"] <= 0:
			expired.append(source)
	for source in expired:
		stats.remove_modifiers_from_source(source)
		_active_buffs.erase(source)
