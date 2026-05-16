extends Node

# 游戏静态数据管理：启动时从 resources/ 目录加载所有 .tres 配置，提供 O(1) 查询

# 各类型数据的字典缓存，key=资源id，value=Resource对象
var characters: Dictionary = {}   # 角色配置：属性、技能等
var weapons: Dictionary = {}      # 武器配置：伤害、冷却、弹幕类型等
var items: Dictionary = {}        # 道具配置：效果、价格等
var enemies: Dictionary = {}      # 敌人配置：生命、速度、掉落等
var wave_configs: Dictionary = {} # 波次配置：时长、敌人类型权重、刷怪间隔等

func _ready():
	# 游戏启动时一次性加载所有静态数据到内存
	load_all_resources()

func load_all_resources():
	# 按目录批量加载各类资源，确保所有配置在游戏开始前就绪
	_load_directory("res://resources/characters/", characters)
	_load_directory("res://resources/weapons/", weapons)
	_load_directory("res://resources/items/", items)
	_load_directory("res://resources/enemies/", enemies)
	_load_wave_configs()  # 波次配置 key 为 wave_number，与通用 id 不同，单独处理

func _load_directory(path: String, target: Dictionary):
	# 扫描目录下所有 .tres 文件，以资源自身的 id 属性为 key 存入字典
	var dir = DirAccess.open(path)
	if dir == null:
		push_warning("DataManager: Cannot open directory: " + path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		# 仅加载 .tres 文件（Godot文本资源格式），忽略 .gd/.tscn 等
		if file_name.ends_with(".tres"):
			var resource = load(path + file_name)
			# 确保资源包含 id 字段，防止错误类型混入
			if "id" in resource:
				target[resource.id] = resource
		file_name = dir.get_next()
	dir.list_dir_end()  # 必须调用以释放目录句柄

func _load_wave_configs():
	# 波次配置特殊处理：使用 wave_number 作为索引键，支持按波次号直接查找
	var dir = DirAccess.open("res://resources/waves/")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load("res://resources/waves/" + file_name)
			# 波次配置的键为 wave_number（整数），与通用 id（字符串）不同
			if "wave_number" in resource:
				wave_configs[resource.wave_number] = resource
		file_name = dir.get_next()
	dir.list_dir_end()

# 以下 getter 提供统一的查询接口，找不到时返回 null，由调用方处理容错
func get_character(id: String) -> Resource:
	return characters.get(id, null)

func get_weapon(id: String) -> Resource:
	return weapons.get(id, null)

func get_item(id: String) -> Resource:
	return items.get(id, null)

func get_enemy(id: String) -> Resource:
	return enemies.get(id, null)

func get_wave_config(wave_number: int) -> Resource:
	return wave_configs.get(wave_number, null)
