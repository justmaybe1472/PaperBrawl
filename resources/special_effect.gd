class_name SpecialEffect
extends Resource

# 道具特殊效果类型枚举：定义效果何时触发
enum EffectType {
	ON_KILL,        # 击杀敌人时触发
	ON_HIT,         # 造成伤害时触发
	ON_WAVE_START,  # 波次开始时触发
	ON_WAVE_END,    # 波次结束时触发
	CONDITIONAL,    # 条件被动（每帧检查）
	CONSUMABLE,     # 一次性使用（满足条件后消耗）
}

# 效果类型，决定由哪个事件驱动此效果
@export var effect_type: EffectType = EffectType.ON_KILL
# 效果参数字典，键值对由子类解释
# 常见键：value（数值）、duration（持续秒数）、stat（目标属性）、pct（百分比）
@export var params: Dictionary = {}
