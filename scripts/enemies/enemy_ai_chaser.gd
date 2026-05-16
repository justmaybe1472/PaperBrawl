# 追踪型 AI：始终向玩家当前位置直线移动，是最基础的敌人行为模式
extends EnemyAI
class_name EnemyAIChaser

# 重写基类方法，返回指向玩家单位方向向量（归一化后长度=1）
func get_move_direction() -> Vector2:
	# 玩家引用可能因场景切换/对象池回收而失效，先尝试恢复
	if player_ref == null:
		_find_player()
		# 仍为空（玩家死亡/场景卸载），保持静止
		if player_ref == null:
			return Vector2.ZERO

	# 所有者可能在回收过程中变为 null，防御性检查防止崩溃
	var owner_body = get_owner_body()
	if owner_body == null:
		return Vector2.ZERO

	# 归一化方向向量：长度固定为 1，保证速度受 base_speed 精确控制
	return (player_ref.global_position - owner_body.global_position).normalized()
