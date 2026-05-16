class_name PlayerWeaponSlot
extends Node

# 最大武器槽数量，与 HUD 的武器图标数量一致
const MAX_SLOTS: int = 6

var weapon_container: Node2D
var player_stats: StatsComponent
# 武器槽数组，每项为 {weapon_id, tier, node}，空槽为 {}
var slots: Array = []

func init(container: Node2D, stats_comp: StatsComponent):
	weapon_container = container
	player_stats = stats_comp
	slots.clear()

func add_weapon(weapon_id: String) -> bool:
	var weapon_data = DataManager.get_weapon(weapon_id)
	if weapon_data == null:
		return false

	# 聚合检查：同一武器 + 同一品质 → 触发合成升阶
	# 该逻辑优先级最高，因为合成是最高价值操作
	var synth_index = _find_same_weapon_same_tier(weapon_id, weapon_data.tier)
	if synth_index >= 0:
		_synthesize(synth_index, weapon_id, weapon_data)
		return true

	# 检查是否已拥有该武器：如果已有更高品质则拒绝，防止降级
	var existing_index = _find_weapon(weapon_id)
	if existing_index >= 0:
		var existing = slots[existing_index]
		if weapon_data.tier <= existing["tier"]:
			return false  # 不会用低级武器覆盖高级的

	# 优先使用空槽位放置武器
	for i in range(MAX_SLOTS):
		if _is_slot_empty(i):
			_instantiate_weapon(i, weapon_id, weapon_data)
			return true

	# 槽位已满：仅当为已拥有武器的更高品阶时才替换旧槽位
	# 不同类型武器槽满时拒绝购买，防止玩家误操作丢失已有Build
	if existing_index >= 0:
		_remove_weapon_from_slot(existing_index)
		_instantiate_weapon(existing_index, weapon_id, weapon_data)
		return true

	# 完全不同类型的武器且槽已满 → 拒绝并通知UI
	EventBus.weapon_slot_full.emit(weapon_id)
	return false

# 查找同一武器同一品质的槽位——这是合成的前置条件
func _find_same_weapon_same_tier(weapon_id: String, tier: int) -> int:
	for i in range(slots.size()):
		if slots[i]["weapon_id"] == weapon_id and slots[i]["tier"] == tier:
			return i
	return -1

# 查找是否已拥有该武器（不限品质），用于升级判定
func _find_weapon(weapon_id: String) -> int:
	for i in range(slots.size()):
		if slots[i]["weapon_id"] == weapon_id:
			return i
	return -1

# 查找品质最低的槽位，在槽位已满时用于淘汰替换
func _find_lowest_tier_slot() -> int:
	var lowest: int = -1
	var lowest_tier: int = 999
	for i in range(slots.size()):
		if slots[i]["tier"] < lowest_tier:
			lowest_tier = slots[i]["tier"]
			lowest = i
	return lowest

# 判断槽位是否为空，自动补位以支持任意索引访问
func _is_slot_empty(index: int) -> bool:
	while slots.size() <= index:
		slots.append({})
	return slots[index].is_empty()

# 合成：将两个同品质同武器合成为一个更高品质的
func _synthesize(slot_index: int, weapon_id: String, weapon_data: WeaponData):
	var existing = slots[slot_index]
	# 品质+1，但最高不超过4级
	var new_tier = existing["tier"] + 1
	if new_tier > 4:
		new_tier = 4

	# 释放旧武器节点
	var old_node: Node2D = existing["node"]
	if old_node:
		old_node.queue_free()

	# 按新品质重新实例化武器
	var merged_data = _get_tiered_weapon_data(weapon_id, new_tier)
	_instantiate_weapon(slot_index, weapon_id, merged_data)
	EventBus.weapon_synthesized.emit(weapon_id, new_tier)  # 通知 HUD 刷新武器图标

# 根据品质获取武器数据：品质越高，伤害倍率越大（非线性增长）
func _get_tiered_weapon_data(weapon_id: String, tier: int) -> WeaponData:
	var base = DataManager.get_weapon(weapon_id)
	if base == null:
		return null
	var cloned = base.duplicate()
	cloned.tier = tier
	# 品质倍率：1级=1x, 2级=1.5x, 3级=2.2x, 4级=3x
	# 采用非线性增长，鼓励玩家追求合成
	var tier_multipliers = {1: 1.0, 2: 1.5, 3: 2.2, 4: 3.0}
	cloned.base_damage = base.base_damage * tier_multipliers.get(tier, 1.0)
	return cloned

# 武器类型到场景文件的映射表，不同类型使用不同的攻击逻辑
const WEAPON_SCENES: Dictionary = {
	"melee": "res://scenes/entities/weapon_melee.tscn",
	"ranged": "res://scenes/entities/weapon_ranged.tscn",
	"elemental": "res://scenes/entities/weapon_elemental.tscn",
	"engineering": "res://scenes/entities/weapon_engineering.tscn",
	"primitive": "res://scenes/entities/weapon_melee.tscn",  # primitive 复用 melee 场景
}

# 通过武器类型获取对应的场景文件路径，未知类型默认回退到 melee
func _get_weapon_scene(weapon_class: String) -> String:
	return WEAPON_SCENES.get(weapon_class, "res://scenes/entities/weapon_melee.tscn")

# 实例化武器场景节点，绑定属性和统计信息
func _instantiate_weapon(slot_index: int, weapon_id: String, weapon_data: WeaponData):
	var scene_path = _get_weapon_scene(weapon_data.weapon_class)
	var weapon_scene = load(scene_path)
	var weapon = weapon_scene.instantiate()
	weapon.weapon_id = weapon_id
	weapon.player_stats = player_stats  # 武器需要 player_stats 来访问攻速等属性
	weapon_container.add_child(weapon)  # 添加到武器容器，由场景树管理渲染和位置

	# 确保 slots 数组长度足够，空槽用空字典填充
	while slots.size() <= slot_index:
		slots.append({})
	slots[slot_index] = {"weapon_id": weapon_id, "tier": weapon_data.tier, "node": weapon}

# 从槽位移除武器并释放节点资源
func _remove_weapon_from_slot(slot_index: int):
	if slot_index < slots.size():
		var slot = slots[slot_index]
		if not slot.is_empty() and slot["node"]:
			slot["node"].queue_free()  # 安全删除节点，避免内存泄漏
		slots[slot_index] = {}

# 获取当前装备的武器数量
func get_slot_count() -> int:
	var count = 0
	for slot in slots:
		if not slot.is_empty():
			count += 1
	return count

# 检查玩家是否已装备指定武器
func has_weapon(weapon_id: String) -> bool:
	return _find_weapon(weapon_id) >= 0
