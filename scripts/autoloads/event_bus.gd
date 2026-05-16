extends Node

# 全局事件总线：解耦各模块之间的通信，所有模块仅依赖 EventBus 而无需互相引用

# ---- Combat Events ----
# 战斗相关事件，连接战斗逻辑、统计、UI 等模块
signal enemy_killed(enemy_id: String, position: Vector2, is_elite: bool)  # 敌人死亡 -> 触发击杀统计、经验掉落、特效
signal player_damaged(amount: int, new_hp: int)  # 玩家受伤 -> UI血条更新、受伤特效
signal player_died()  # 玩家死亡 -> 触发对局结束流程
signal damage_dealt(source: Node, target: Node, amount: int, is_crit: bool)  # 伤害结算 -> 伤害数字弹出、暴击特效

# ---- Wave Events ----
# 波次生命周期事件，驱动 GameManager 状态机与 UI 进度
signal wave_started(wave_number: int)  # 波次开始 -> WaveManager 初始化刷怪
signal wave_completed(wave_number: int)  # 波次完成 -> 结算奖励、记录波次
signal wave_timer_updated(time_left: float)  # 波次计时更新 -> UI进度条刷新
signal all_enemies_cleared()  # 全部敌人清空 -> 可用于额外奖励触发

# ---- Shop Events ----
# 商店交互事件，连接商店 UI 与 GameManager 资源管理
signal shop_opened(wave_number: int)  # 商店打开 -> UI展示、暂停战斗
signal shop_closed()  # 商店关闭 -> 推进下一波
signal item_purchased(item_id: String, price: int)  # 道具购买 -> 应用效果、扣费
signal weapon_purchased(weapon_id: String, price: int)  # 武器购买 -> 装备武器、扣费
signal shop_refreshed()  # 商店刷新 -> 重新随机商品列表

# ---- Material / Pickup ----
# 资源拾取事件，连接拾取物与 GameManager 材料统计
signal material_collected(amount: int, total_materials: int)  # 材料变化（正为拾取，负为消费）
signal pickup_collected(pickup_type: String, value: int)  # 拾取物收集 -> 触发对应效果（治疗、经验等）

# ---- Game State ----
# 游戏全局状态事件，控制场景切换与 UI 面板显隐
signal game_started()  # 游戏正式开始 -> 隐藏主菜单、初始化HUD
signal game_paused()  # 游戏暂停 -> 冻结所有活动
signal game_resumed()  # 游戏恢复 -> 解冻
signal game_over(wave_reached: int, materials_earned: int)  # 对局结束 -> 展示结算界面

# ---- Weapon ----
# 武器系统事件，连接武器逻辑与视觉/音效反馈
signal weapon_fired(weapon_id: String, position: Vector2, direction: Vector2)  # 武器发射 -> 弹幕生成、音效播放
signal weapon_synthesized(weapon_id: String, new_tier: int)  # 武器合成升级 -> 模型/特效切换
signal weapon_slot_full(weapon_id: String)  # 武器槽已满且类型不匹配 -> UI提示

# ---- Stat Changes ----
# 属性变化事件，用于 UI 实时刷新属性面板
signal stat_changed(stat_name: String, new_value: float)  # 任意属性值变化 -> HUD更新
