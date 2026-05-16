extends Node

# 存档管理器：负责本地JSON持久化、解锁判定、难度倍率计算

const SAVE_PATH = "user://save_data.json"  # Godot用户数据目录，跨平台兼容

# 存档默认值：新玩家首次启动时的初始状态
var save_data: Dictionary = {
	"total_materials_earned": 0,   # 累计获得材料（用于解锁判定）
	"total_kills": 0,              # 累计击杀数（驱动角色与武器解锁）
	"total_runs": 0,               # 总对局次数
	"total_wins": 0,               # 通关次数（驱动难度解锁）
	"highest_wave": 0,             # 历史最高波次（驱动波次里程碑解锁）
	"unlocked_characters": ["well_rounded"],  # 已解锁角色列表，默认只有均衡型
	"unlocked_weapons": ["stick", "fist", "pistol", "fireball"],  # 初始武器
	"unlocked_items": [],          # 已解锁道具列表，空数组 = 所有道具可用
	"difficulty_levels": [0]       # 已解锁难度等级
}

func _ready():
	# 游戏启动时加载存档，若无存档则自动创建默认存档
	load_game()

func save_game():
	# 将存档字典序列化为格式化的JSON写入磁盘
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))  # \t 缩进便于手动调试
		file.close()

func load_game():
	# 读取存档：文件不存在时先用默认值创建；存在则逐字段覆盖，避免新增字段丢失
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()  # 首次启动，写入默认存档
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var text = file.get_as_text()
	file.close()
	if text.is_empty():
		return

	# 解析JSON并逐字段合并，确保未来新增的默认字段能正确回填
	var json = JSON.new()
	var error = json.parse(text)
	if error == OK:
		var data = json.data
		if data is Dictionary:
			for key in save_data:
				if data.has(key):
					save_data[key] = data[key]  # 仅覆盖已存在的key，保留默认值框架

func _merge_defaults(source: Dictionary, defaults: Dictionary) -> Dictionary:
	# 递归合并默认值：若存档中缺少某字段则补入，支持嵌套字典
	for key in defaults:
		if not source.has(key):
			source[key] = defaults[key]
		elif source[key] is Dictionary and defaults[key] is Dictionary:
			source[key] = _merge_defaults(source[key], defaults[key])
	return source

# ---- 统计累加与持久化 ----
func add_materials(amount: int):
	# 累加材料并立即存档（仅累加累计值，对局内材料由 GameManager 管理）
	save_data["total_materials_earned"] += amount
	save_game()

func add_kills(count: int):
	# 累加击杀并检查解锁，击杀是角色和武器解锁的主要驱动力
	save_data["total_kills"] += count
	_check_character_unlocks()
	_check_weapon_unlocks()
	save_game()

func record_run_end(wave_reached: int, is_victory: bool):
	# 对局结算：更新总场次、最高波次、胜利次数，然后检查所有解锁条件
	save_data["total_runs"] += 1
	if wave_reached > save_data["highest_wave"]:
		save_data["highest_wave"] = wave_reached  # 只保留最高纪录
	if is_victory:
		save_data["total_wins"] += 1
	# 对局结束后统一检查三类解锁（含胜利/波次里程碑）
	_check_character_unlocks()
	_check_weapon_unlocks()
	_check_item_unlocks()
	save_game()

# ---- 角色解锁 ----
func is_character_unlocked(id: String) -> bool:
	return id in save_data["unlocked_characters"]

func unlock_character(id: String):
	# 去重解锁：已存在则不重复添加
	if id not in save_data["unlocked_characters"]:
		save_data["unlocked_characters"].append(id)
		save_game()

# ---- 武器解锁 ----
func is_weapon_unlocked(id: String) -> bool:
	return id in save_data["unlocked_weapons"]

func unlock_weapon(id: String):
	if id not in save_data["unlocked_weapons"]:
		save_data["unlocked_weapons"].append(id)
		save_game()

# ---- 道具解锁 ----
func is_item_unlocked(id: String) -> bool:
	# 空列表 = 所有道具默认可用，可降低新手的解锁门槛
	# 有内容时仅列表中的可用，实现逐步解锁的成长感
	if save_data["unlocked_items"].is_empty():
		return true
	return id in save_data["unlocked_items"]

func unlock_item(id: String):
	if id not in save_data["unlocked_items"]:
		save_data["unlocked_items"].append(id)
		save_game()

# ---- 难度解锁 ----
func is_difficulty_unlocked(level: int) -> bool:
	return level in save_data["difficulty_levels"]

func unlock_difficulty(level: int):
	if level not in save_data["difficulty_levels"]:
		save_data["difficulty_levels"].append(level)
		save_game()

# ---- 难度倍率 ----
func get_difficulty_multiplier() -> float:
	# 敌人属性倍率：难度越高敌人越强，非线性增长以增加后期挑战性
	var level = GameManager.current_difficulty
	match level:
		0: return 1.0   # 普通：基准值
		1: return 1.3   # 困难：+30%
		2: return 1.8   # 噩梦：+80%
		3: return 2.5   # 地狱：+150%
	return 1.0

func get_material_multiplier() -> float:
	# 材料掉落倍率：高难度给予更多材料作为风险补偿
	var level = GameManager.current_difficulty
	match level:
		0: return 1.0   # 普通：基准值
		1: return 1.2   # 困难：+20%
		2: return 1.4   # 噩梦：+40%
		3: return 1.6   # 地狱：+60%
	return 1.0

# ---- 解锁条件检查 ----
# 每次累加统计数据后调用，用阈值判定是否触发新解锁
func _check_character_unlocks():
	var kills = save_data["total_kills"]
	var highest_wave = save_data["highest_wave"]
	var materials = save_data["total_materials_earned"]
	var wins = save_data["total_wins"]
	# 击杀里程碑 -> 解锁战斗型角色
	if kills >= 50:
		unlock_character("brawler")
		unlock_character("ranger")
	if kills >= 100:
		unlock_character("mage")
		unlock_character("engineer")
	# 波次里程碑 -> 解锁防御型角色
	if highest_wave >= 10:
		unlock_character("tank")
	# 材料里程碑 -> 解锁运气型角色
	if materials >= 200:
		unlock_character("lucky")
	# 低波次鼓励 -> 解锁速度型角色
	if highest_wave >= 5:
		unlock_character("speedy")

	# 胜利次数驱动难度解锁（与角色解锁耦合在同一个检查函数中）
	if wins >= 1 and not is_difficulty_unlocked(1):
		unlock_difficulty(1)
	if wins >= 2 and not is_difficulty_unlocked(2):
		unlock_difficulty(2)

func _check_weapon_unlocks():
	var kills = save_data["total_kills"]
	var highest_wave = save_data["highest_wave"]
	var wins = save_data["total_wins"]
	# 波次里程碑解锁武器 — 鼓励玩家推进到更高波次
	if highest_wave >= 3:
		unlock_weapon("sword")
		unlock_weapon("shotgun")
	if highest_wave >= 6:
		unlock_weapon("bow")
		unlock_weapon("ice_shard")
	if highest_wave >= 10:
		unlock_weapon("mace")
		unlock_weapon("lightning_chain")
	if highest_wave >= 15:
		unlock_weapon("turret")
		unlock_weapon("mine")
	# 击杀解锁 — 提供波次之外的替代解锁路径
	if kills >= 200:
		unlock_weapon("turret")
	# 胜利解锁 — 通关奖励
	if wins >= 1:
		unlock_weapon("mine")

func _check_item_unlocks():
	var wins = save_data["total_wins"]
	var highest_wave = save_data["highest_wave"]
	# 首次通关解锁稀有道具，作为通关的额外奖励
	if wins >= 1:
		unlock_item("dragon_scale")
		unlock_item("phoenix_feather")
	# 高波次解锁终极道具
	if highest_wave >= 15:
		unlock_item("titan_heart")
		unlock_item("plasma_shield")
