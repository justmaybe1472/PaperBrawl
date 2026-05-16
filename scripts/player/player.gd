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

func _ready():
	add_to_group("player")  # 加入 player 分组，供其它节点快速查找
	iframe_timer.timeout.connect(_on_iframe_timeout)
	pickup_radius.body_entered.connect(_on_pickup_entered)
	EventBus.item_purchased.connect(_on_item_purchased)  # 监听商店购买事件
	EventBus.weapon_purchased.connect(_on_weapon_purchased)

	# 动态创建武器槽管理器节点并挂载脚本，避免在场景中手动绑定
	var slot_node = Node.new()
	slot_node.name = "WeaponSlotManager"
	slot_node.set_script(load("res://scripts/player/player_weapon_slot.gd"))
	weapon_slots = slot_node
	add_child(slot_node)

	_initialize_from_data()
	# 优先使用 TestTexture，回退到占位图形
	PlaceholderSprites.apply_test_texture(sprite, "Player_1.png", 32.0)

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

func _on_weapon_purchased(weapon_id: String, _price: int):
	# 武器购买逻辑由 weapon_slots 统一管理（合成/替换/新增）
	weapon_slots.add_weapon(weapon_id)
