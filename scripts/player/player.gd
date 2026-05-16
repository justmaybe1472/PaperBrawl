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
# 特殊效果产生的临时属性 Buff，{source: {stat_name, value, remaining_time}}
var _active_buffs: Dictionary = {}
# 条件被动效果映射，每个条件用 source 唯一追踪
# {source -> {stat_name, value, condition}} 用于进出条件时动态增删
var _active_conditional_sources: Dictionary = {}
# 道具标签套装系统：tag -> 持有数，追踪各标签的道具数量
var _item_tag_counts: Dictionary = {}
# 当前生效的套装加成层级：tag -> tier(2或4)
var _active_tag_bonuses: Dictionary = {}

# 套装加成定义：{tag: {stat, 2: value, 4: value}}
const TAG_SET_BONUSES: Dictionary = {
	"fire":        {"stat": "elemental_damage", 2: 10, 4: 25},
	"armor":       {"stat": "armor",             2: 3,  4: 8},
	"heal":        {"stat": "hp_regen",          2: 2,  4: 5},
	"speed":       {"stat": "speed",             2: 8,  4: 20},
	"crit":        {"stat": "crit_chance",       2: 5,  4: 15},
	"engineering": {"stat": "engineering",       2: 5,  4: 15},
	"luck":        {"stat": "luck",              2: 10, 4: 25},
	"harvest":     {"stat": "harvesting",        2: 15, 4: 35},
}

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
	# 每帧检查条件被动效果（如龙鳞满血增伤），动态应用/移除 Buff
	_process_conditional_effects()

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
	# 检查复活效果（凤凰羽毛）——在真正死亡前给予一次复活机会
	if _try_consume_revive():
		return  # 复活成功，不触发游戏结束
	EventBus.player_died.emit()
	GameManager.change_state(GameManager.GameState.GAME_OVER)

# 尝试消耗一次复活效果，成功返回 true
func _try_consume_revive() -> bool:
	for entry in _active_special_effects:
		var effect: SpecialEffect = entry["effect"]
		if effect.effect_type != ItemData.EffectTrigger.CONSUMABLE:
			continue
		if entry["remaining_uses"] <= 0:
			continue
		var p = effect.params
		if p.get("effect", "") != "revive":
			continue
		# 消耗一次使用次数
		entry["remaining_uses"] -= 1
		# 恢复百分比 HP
		var revive_pct = float(p.get("revive_hp_pct", 50))
		var heal_amount = int(stats.get_stat("max_hp") * revive_pct / 100.0)
		stats.hp = max(1, heal_amount)  # 直接设置 HP，绕过 heal() 上限检查
		# 清除该复活效果（已用完）
		if entry["remaining_uses"] <= 0:
			_active_special_effects.erase(entry)
		return true
	return false

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
	# 追踪标签并重新计算套装加成
	_track_item_tags(item_data.tags)
	_recalculate_tag_bonuses()

func _on_weapon_purchased(weapon_id: String, _price: int):
	# 武器购买逻辑由 weapon_slots 统一管理（合成/替换/新增）
	weapon_slots.add_weapon(weapon_id)

# ---- 道具标签套装系统 ----

# 追踪道具标签的持有数量
func _track_item_tags(tags: Array):
	for tag in tags:
		_item_tag_counts[tag] = _item_tag_counts.get(tag, 0) + 1

# 根据标签持有数重新计算套装加成，按层级（2件/4件）动态增删修饰器
func _recalculate_tag_bonuses():
	for tag in TAG_SET_BONUSES:
		var bonus_def = TAG_SET_BONUSES[tag]
		var count: int = _item_tag_counts.get(tag, 0)
		var stat_name: String = bonus_def["stat"]
		# 确定当前应生效的层级（4件 > 2件 > 无加成）
		var new_tier: int = 0
		if count >= 4:
			new_tier = 4
		elif count >= 2:
			new_tier = 2
		# 与已生效层级比较，无变化则跳过
		var active_tier: int = _active_tag_bonuses.get(tag, 0)
		if new_tier == active_tier:
			continue
		# 移除旧层级加成
		if active_tier > 0:
			var old_source = "tag_bonus:" + tag + ":" + str(active_tier)
			stats.remove_modifiers_from_source(old_source)
		# 应用新层级加成
		if new_tier > 0:
			var new_source = "tag_bonus:" + tag + ":" + str(new_tier)
			stats.add_modifier(stat_name, new_source, float(bonus_def[new_tier]))
		_active_tag_bonuses[tag] = new_tier

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
			# 击杀触发：属性Buff（狂战士戒指/忍者服）+ 直接治疗（吸血獠牙）
			_exec_on_kill(p, context)
		ItemData.EffectTrigger.ON_WAVE_END:
			# 波次结束：百分比回血（医疗包）
			_exec_on_wave_end(p)
		ItemData.EffectTrigger.ON_WAVE_START:
			# 波次开始：预留
			_exec_on_wave_start(p)
		ItemData.EffectTrigger.ON_HIT:
			# 造成伤害：属性Buff（暴击宝石）+ AoE爆炸（等离子盾）
			_exec_on_hit(p, context)
		ItemData.EffectTrigger.CONDITIONAL:
			# 条件被动：由 _process_conditional_effects() 逐帧检查
			pass
		ItemData.EffectTrigger.CONSUMABLE:
			# 一次性消耗：复活（凤凰羽毛）等
			_exec_consumable(p, entry)

# 击杀触发效果：支持属性Buff和直接治疗
func _exec_on_kill(p: Dictionary, _ctx: Dictionary):
	# 属性Buff模式：击杀后临时提升属性（狂战士戒指/忍者服）
	var stat_name = p.get("stat", "")
	var value = float(p.get("value", 0))
	var duration = float(p.get("duration", 0))
	if stat_name != "" and value > 0 and duration > 0:
		_apply_temp_buff(stat_name, value, duration)
	# 直接治疗模式：击杀后立即回复固定HP（吸血獠牙）
	var heal = int(p.get("heal", 0))
	if heal > 0:
		stats.heal(heal)

# 波次结束效果：回复百分比HP（医疗包）
func _exec_on_wave_end(p: Dictionary):
	var heal_pct = float(p.get("heal_pct", 0))
	if heal_pct > 0:
		var heal_amount = int(stats.get_stat("max_hp") * heal_pct / 100.0)
		if heal_amount > 0:
			stats.heal(heal_amount)

func _exec_on_wave_start(p: Dictionary):
	# 波次开始触发：可添加临时Buff
	var stat_name = p.get("stat", "")
	var value = float(p.get("value", 0))
	var duration = float(p.get("duration", 0))
	if stat_name != "" and value > 0 and duration > 0:
		_apply_temp_buff(stat_name, value, duration)

# 造成伤害触发效果：属性Buff（暴击宝石）和 AoE爆炸（等离子盾）
func _exec_on_hit(p: Dictionary, ctx: Dictionary):
	# 属性Buff模式：命中时临时提升属性（暴击宝石）
	var stat_name = p.get("stat", "")
	var value = float(p.get("value", 0))
	var duration = float(p.get("duration", 0))
	if stat_name != "" and value > 0 and duration > 0:
		_apply_temp_buff(stat_name, value, duration)
	# AoE爆炸模式：在玩家位置对周围敌人造成伤害（等离子盾）
	var aoe_pct = float(p.get("aoe_dmg_pct", 0))
	var aoe_radius = float(p.get("aoe_radius", 0))
	if aoe_pct > 0 and aoe_radius > 0:
		_deal_aoe_damage(aoe_pct, aoe_radius)

# 对玩家周围所有敌人造成百分比伤害
func _deal_aoe_damage(dmg_pct: float, radius: float):
	var container = get_tree().get_first_node_in_group("enemies_container")
	if container == null:
		return
	# 用玩家的基础攻击力作为 AoE 伤害基准
	var base_atk = stats.get_stat("damage_pct")
	var aoe_damage = max(1, (100 + base_atk) * dmg_pct / 100.0)
	for enemy_node in container.get_children():
		if not enemy_node is EnemyBase:
			continue
		var enemy: EnemyBase = enemy_node
		if enemy.is_dead:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist > radius:
			continue
		enemy.take_damage(int(aoe_damage))
		EventBus.damage_dealt.emit(self, enemy, int(aoe_damage), false)

func _exec_consumable(p: Dictionary, entry: Dictionary):
	# 消耗品效果：如复活（Phoenix Feather）
	# 复活效果在 _try_consume_revive() 中处理，此处为通用消耗逻辑
	var effect_type = p.get("effect", "")
	if effect_type == "revive":
		return  # 复活由 _die() 调用 _try_consume_revive() 处理
	# 通用消耗品：扣除使用次数
	entry["remaining_uses"] -= 1
	if entry["remaining_uses"] <= 0:
		_active_special_effects.erase(entry)

# ---- 条件被动系统 ----

# 每帧检查 CONDITIONAL 类型效果是否满足条件
func _process_conditional_effects():
	for entry in _active_special_effects:
		var effect: SpecialEffect = entry["effect"]
		if effect.effect_type != ItemData.EffectTrigger.CONDITIONAL:
			continue
		if entry["remaining_uses"] <= 0:
			continue
		var p = effect.params
		var condition = p.get("condition", "")
		var stat_name = p.get("stat", "")
		var value = float(p.get("value", 0))
		if stat_name == "" or value == 0:
			continue
		var source = "conditional_effect:" + entry["item_id"]
		var is_active = _active_conditional_sources.has(source)
		var should_apply = false
		# 根据条件类型判断是否应激活
		match condition:
			"full_hp":
				should_apply = stats.hp >= int(stats.get_stat("max_hp"))
		# 条件满足时应用 Buff，不满足时移除
		if should_apply and not is_active:
			stats.add_modifier(stat_name, source, value)
			_active_conditional_sources[source] = {"stat_name": stat_name, "value": value}
		elif not should_apply and is_active:
			stats.remove_modifiers_from_source(source)
			_active_conditional_sources.erase(source)

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
