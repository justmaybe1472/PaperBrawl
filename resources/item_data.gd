class_name ItemData
extends Resource

# 特殊效果触发时机枚举（与 SpecialEffect.EffectType 保持同步）
enum EffectTrigger {
	ON_KILL,        # 击杀敌人时触发
	ON_HIT,         # 造成伤害时触发
	ON_WAVE_START,  # 波次开始时触发
	ON_WAVE_END,    # 波次结束时触发
	CONDITIONAL,    # 条件被动（每帧检查）
	CONSUMABLE,     # 一次性使用（满足条件后消耗）
}

@export var id: String = ""
@export var display_name: String = ""
@export var rarity: String = "common"
@export var base_price: int = 15
@export var max_stack: int = 0
@export var stat_modifiers: Dictionary = {}
@export var tags: Array[String] = []
@export var description: String = ""
# 特殊效果资源引用（可为空，表示无特殊效果）
@export var special_effect: SpecialEffect
