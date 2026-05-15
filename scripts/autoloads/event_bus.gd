extends Node

# ---- Combat Events ----
signal enemy_killed(enemy_id: String, position: Vector2, is_elite: bool)
signal player_damaged(amount: int, new_hp: int)
signal player_died()
signal damage_dealt(source: Node, target: Node, amount: int, is_crit: bool)

# ---- Wave Events ----
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal wave_timer_updated(time_left: float)
signal all_enemies_cleared()

# ---- Shop Events ----
signal shop_opened(wave_number: int)
signal item_purchased(item_id: String, price: int)
signal weapon_purchased(weapon_id: String, price: int)
signal shop_refreshed()

# ---- Material / Pickup ----
signal material_collected(amount: int, total_materials: int)
signal pickup_collected(pickup_type: String, value: int)

# ---- Game State ----
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over(wave_reached: int, materials_earned: int)

# ---- Weapon ----
signal weapon_fired(weapon_id: String, position: Vector2, direction: Vector2)
signal weapon_synthesized(weapon_id: String, new_tier: int)

# ---- Stat Changes ----
signal stat_changed(stat_name: String, new_value: float)
