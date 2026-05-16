# 敌人属性组件，负责原始属性、波次缩放、难度倍率与查询接口
class_name EnemyStats
extends Node

# 基础属性（缩放前的原始值，由 EnemyData 注入）
var base_hp: float = 10.0
var base_damage: float = 5.0
var base_speed: float = 100.0
# 当前 HP 独立追踪，不与 base_hp 绑定，允许治疗/临时增减
var current_hp: float = 10.0
# 用于波次缩放公式计算（第 N 波的乘数为 1 + 增长率 * (N-1)）
var wave_number: int = 1

# 从 EnemyData 资源加载属性并应用波次缩放，然后在 current_hp 中反映最终结果
func init_from_data(enemy_data: EnemyData, wave: int):
	base_hp = enemy_data.base_hp
	base_damage = enemy_data.base_damage
	base_speed = enemy_data.base_speed
	wave_number = wave
	# 先对 base_* 应用波次缩放，再将缩放后的值赋给 current_hp
	_apply_wave_scaling()
	current_hp = base_hp

# 波次缩放公式：HP +15%/波、伤害 +10%/波、速度 +3%/波（上限 +50%）
func _apply_wave_scaling():
	# wave_number=1 时乘数为 1.0，之后每波递增
	base_hp *= (1.0 + 0.15 * (wave_number - 1))
	base_damage *= (1.0 + 0.10 * (wave_number - 1))
	# 速度有上限保护，防止后期敌人快得不可控
	var original_speed = base_speed
	base_speed *= (1.0 + 0.03 * (wave_number - 1))
	base_speed = min(base_speed, original_speed * 1.5)

	# 全局难度倍率（GameManager 根据玩家表现/设置动态计算），乘以全部属性
	var difficulty_mult = GameManager.get_enemy_stat_multiplier()
	base_hp *= difficulty_mult
	base_damage *= difficulty_mult
	# 速度受难度影响较小（仅 30% 权重），避免高难度下敌人瞬间贴脸
	base_speed *= (1.0 + (difficulty_mult - 1.0) * 0.3)

# 属性查询分发器：外部系统通过字符串名获取对应属性值
func get_stat(stat_name: String) -> float:
	match stat_name:
		"max_hp": return base_hp
		"base_damage": return base_damage
		"base_speed": return base_speed
		# 当前未实现护甲/闪避机制，预留返回 0
		"armor": return 0.0
		"dodge": return 0.0
		_: return 0.0

# 扣血并 clamp 到 0，防止负 HP 导致比较逻辑错乱
func take_damage(amount: int) -> float:
	current_hp = max(0.0, current_hp - amount)
	return current_hp

# 死亡判定：HP <= 0 即为死亡
func is_dead() -> bool:
	return current_hp <= 0.0
