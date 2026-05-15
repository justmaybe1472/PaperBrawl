class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var weapon_class: String = "melee"
@export var tier: int = 1
@export var base_damage: float = 8.0
@export var cooldown: float = 1.5
@export var range: float = 150.0
@export var crit_multiplier: float = 2.0
@export var pierce: int = 1
@export var bounce: int = 0
@export var projectiles: int = 1
@export var knockback: float = 100.0
@export var lifesteal_multiplier: float = 1.0
@export var tags: Array[String] = []
