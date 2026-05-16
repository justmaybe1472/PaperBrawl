extends Area2D

var value: int = 1
var attracted: bool = false
var player_ref: Node2D
var attraction_speed: float = 350.0  # 磁铁靠近时的飞行速度
var pickup_range: float = 80.0  # 触发磁铁吸引的检测范围

func _ready():
	collision_layer = 5
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)

func _process(delta):
	if attracted and player_ref:
		# 被吸引时平滑飞向玩家，到达后自动收集
		var dir = (player_ref.global_position - global_position).normalized()
		global_position += dir * attraction_speed * delta
		if global_position.distance_to(player_ref.global_position) < 10.0:
			_collect()
	else:
		# 未吸引时持续检测玩家是否进入拾取范围（避免每帧查询所有掉落物使用距离检测）
		_check_player_proximity()

func _check_player_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) < pickup_range:
		start_attraction(player)

func start_attraction(player: Node2D):
	if not attracted:
		attracted = true
		player_ref = player

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		_collect()

func _collect():
	GameManager.add_materials(value)  # 累加到本局材料总数
	ObjectPool.return_pickup(self)  # 回收到对象池，避免频繁创建销毁
