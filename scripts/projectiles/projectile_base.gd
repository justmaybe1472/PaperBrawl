class_name PlayerProjectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 5.0
var pierce_left: int = 0
var bounce_left: int = 0
var knockback: float = 50.0
var lifetime: float = 3.0
var is_crit: bool = false
var weapon_data: WeaponData
var attacker_stats: StatsComponent

func _ready():
	body_entered.connect(_on_body_entered)
	collision_layer = 3
	collision_mask = 2

func _process(delta):
	lifetime -= delta
	if lifetime <= 0.0:
		ObjectPool.return_projectile(self)
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D):
	if not body.is_in_group("enemy"):
		return
	var enemy = body as EnemyBase
	if enemy == null or enemy.is_dead:
		return

	enemy.take_damage(int(damage))
	EventBus.damage_dealt.emit(self, enemy, int(damage), is_crit)

	if knockback > 0:
		var kb_dir = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(kb_dir * knockback)

	if attacker_stats:
		var lifesteal = attacker_stats.get_stat("life_steal")
		if lifesteal > 0 and randf() * 100.0 < lifesteal:
			var heal_amount = max(1, int(damage * 0.1))
			attacker_stats.heal(heal_amount)

	if pierce_left > 0:
		pierce_left -= 1
	elif bounce_left > 0:
		bounce_left -= 1
		var nearby = _find_nearest_enemy(body.global_position)
		if nearby:
			direction = (nearby.global_position - global_position).normalized()
		else:
			ObjectPool.return_projectile(self)
	else:
		ObjectPool.return_projectile(self)

func _find_nearest_enemy(pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var min_dist: float = 500.0
	var container = get_tree().get_first_node_in_group("enemies_container")
	if container == null:
		return null
	for enemy in container.get_children():
		if enemy.is_dead:
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest
