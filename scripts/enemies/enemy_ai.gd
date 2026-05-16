# 敌人 AI 基类，定义状态机和玩家追踪接口，子类重写 get_move_direction 实现具体行为
class_name EnemyAI
extends Node

# 状态枚举：IDLE（待机/出生过渡）、CHASE（追踪玩家），为未来扩展 PATROL/HIT_STUN 预留空间
enum AIState { IDLE, CHASE }

# 当前状态，子类可在 get_move_direction 中根据状态返回不同方向
var current_state: AIState = AIState.IDLE
# 追踪速度，由 EnemyBase.init 从 Stats 同步写入，确保 AI 和属性一致
var chase_speed: float = 100.0
# 玩家引用缓存：避免每帧执行 get_first_node_in_group，仅在首次或失效时重新查找
var player_ref: Node2D
# 敌人配置数据的引用（由 EnemyBase 注入），子类可据此读取行为参数
var enemy_data: EnemyData

# 初始化时自动查找玩家，减少子类重复代码
func _ready():
	_find_player()

# 懒加载玩家引用：在 get_move_direction 中若为 null 会重新尝试查找
func _find_player():
	player_ref = get_tree().get_first_node_in_group("player")

# 基类默认不移动（返回零向量），子类必须重写以实现具体追踪逻辑
func get_move_direction() -> Vector2:
	return Vector2.ZERO

# 向上获取所属的 CharacterBody2D，供子类在方向计算中使用自身位置
func get_owner_body() -> CharacterBody2D:
	return get_parent() as CharacterBody2D
