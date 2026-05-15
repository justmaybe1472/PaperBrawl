# Technical Architecture — Potato Survivor (Godot 4.x 2D)

> **版本**: 1.0 | **最后更新**: 2026-05-15 | **引擎**: Godot 4.x
>
> 本文档是 AI Agent 实现游戏的唯一技术规范。定义了项目结构、架构模式、数据流和开发顺序。
> **所有实现必须严格遵循本文档。**

---

## 目录

1. [项目配置](#1-项目配置)
2. [目录结构](#2-目录结构)
3. [Autoload 全局单例](#3-autoload-全局单例)
4. [场景层级架构](#4-场景层级架构)
5. [实体架构（节点树定义）](#5-实体架构节点树定义)
6. [组件化架构](#6-组件化架构)
7. [数据系统](#7-数据系统)
8. [事件系统（EventBus）](#8-事件系统eventbus)
9. [关键算法实现](#9-关键算法实现)
10. [对象池系统](#10-对象池系统)
11. [UI 架构](#11-ui-架构)
12. [AI Agent 开发路线图](#12-ai-agent-开发路线图)

---

## 1. 项目配置

### 1.1 Godot 项目设置

```ini
# project.godot 关键配置

[application]
config/name="Potato Survivor"
run/main_scene="res://scenes/main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="gl_compatibility"  # 2D 用兼容模式即可

[input]
move_up=W, Up
move_down=S, Down
move_left=A, Left
move_right=D, Right
pause=Esc
confirm=Enter
```

### 1.2 设计分辨率

| 参数 | 值 |
|------|-----|
| 设计分辨率 | 1280 × 720 |
| 地图尺寸 | 1920 × 1080（比屏幕大） |
| 摄像机跟随 | 平滑跟随玩家，带边界限制 |
| 缩放模式 | `canvas_items` + `expand` |

### 1.3 物理层设置

```
Layer 1: Player
Layer 2: Enemy
Layer 3: PlayerProjectile
Layer 4: EnemyProjectile
Layer 5: Pickup
Layer 6: WorldBoundary
```

碰撞检测配置：
- Player ↔ Enemy：检测（触发伤害）
- PlayerProjectile ↔ Enemy：检测（造成伤害）
- EnemyProjectile ↔ Player：检测（造成伤害）
- Pickup ↔ Player：检测（拾取道具/材料）
- 其他组合：不检测

---

## 2. 目录结构

```
potato_survivor/
│
├── project.godot                   # 项目配置文件
├── GDD.md                          # 游戏设计文档
├── ARCHITECTURE.md                 # 本文档
│
├── scenes/                         # 场景文件 (.tscn)
│   ├── main.tscn                   # 主场景（入口）
│   ├── game_world.tscn             # 游戏世界（战斗场景）
│   ├── ui/
│   │   ├── main_menu.tscn          # 主菜单
│   │   ├── character_select.tscn   # 角色选择
│   │   ├── hud.tscn                # 战斗 HUD
│   │   ├── shop.tscn               # 商店界面
│   │   ├── pause_menu.tscn         # 暂停菜单
│   │   ├── game_over.tscn          # 结算界面
│   │   └── wave_announce.tscn      # 波次提示
│   └── entities/
│       ├── player.tscn             # 玩家场景
│       ├── enemy_base.tscn         # 敌人基类场景
│       ├── projectile.tscn         # 子弹基类场景
│       └── pickup.tscn             # 掉落物基类场景
│
├── scripts/                        # GDScript (.gd)
│   ├── autoloads/                  # 全局单例
│   │   ├── game_manager.gd
│   │   ├── data_manager.gd
│   │   ├── event_bus.gd
│   │   ├── save_manager.gd
│   │   ├── object_pool.gd
│   │   └── wave_manager.gd
│   │
│   ├── player/
│   │   ├── player.gd               # 玩家控制器
│   │   ├── player_stats.gd         # 玩家属性组件
│   │   └── player_weapon_slot.gd   # 武器槽管理
│   │
│   ├── enemies/
│   │   ├── enemy_base.gd           # 敌人基类
│   │   ├── enemy_stats.gd          # 敌人属性
│   │   ├── enemy_ai.gd             # 敌人 AI 状态机
│   │   ├── enemy_spawner.gd        # 敌人生成器
│   │   ├── enemy_chaser.gd         # 追踪型敌人
│   │   ├── enemy_charger.gd        # 冲刺型敌人
│   │   ├── enemy_shooter.gd        # 远程型敌人
│   │   ├── enemy_summoner.gd       # 召唤型敌人
│   │   └── enemy_boss.gd           # Boss 敌人
│   │
│   ├── weapons/
│   │   ├── weapon_base.gd          # 武器基类
│   │   ├── weapon_melee.gd         # 近战武器
│   │   ├── weapon_ranged.gd        # 远程武器
│   │   ├── weapon_elemental.gd     # 元素武器
│   │   └── weapon_engineering.gd   # 工程武器
│   │
│   ├── projectiles/
│   │   ├── projectile_base.gd      # 子弹基类
│   │   └── projectile_types/       # 特殊子弹行为
│   │       ├── bullet.gd
│   │       ├── fireball.gd
│   │       ├── lightning.gd
│   │       └── mine.gd
│   │
│   ├── items/
│   │   └── item_manager.gd         # 道具/库存管理
│   │
│   ├── systems/
│   │   ├── damage_system.gd        # 伤害计算
│   │   ├── pickup_system.gd        # 掉落与拾取
│   │   └── camera_controller.gd    # 摄像机
│   │
│   └── ui/
│       ├── main_menu_ui.gd
│       ├── character_select_ui.gd
│       ├── hud_ui.gd
│       ├── shop_ui.gd
│       ├── pause_menu_ui.gd
│       └── game_over_ui.gd
│
├── resources/                      # .tres 数据资源文件
│   ├── characters/
│   │   ├── well_rounded.tres
│   │   ├── brawler.tres
│   │   ├── ranger.tres
│   │   └── ...
│   ├── weapons/
│   │   ├── stick.tres
│   │   ├── pistol.tres
│   │   ├── sword.tres
│   │   └── ...
│   ├── items/
│   │   ├── medkit.tres
│   │   ├── armor_plate.tres
│   │   └── ...
│   ├── enemies/
│   │   ├── basic_melee.tres
│   │   ├── fast_chaser.tres
│   │   └── ...
│   └── waves/
│       └── wave_config.tres        # 波次配置表
│
├── assets/                         # 原始资源文件
│   ├── sprites/                    # 精灵图
│   ├── sounds/                     # 音效
│   ├── music/                      # 音乐
│   ├── fonts/                      # 字体
│   └── shaders/                    # 着色器
│
└── addons/                         # 插件（如有）
```

---

## 3. Autoload 全局单例

在 `project.godot` 中按以下顺序注册（顺序决定初始化顺序）：

```ini
[autoload]

EventBus="*res://scripts/autoloads/event_bus.gd"
DataManager="*res://scripts/autoloads/data_manager.gd"
SaveManager="*res://scripts/autoloads/save_manager.gd"
ObjectPool="*res://scripts/autoloads/object_pool.gd"
GameManager="*res://scripts/autoloads/game_manager.gd"
WaveManager="*res://scripts/autoloads/wave_manager.gd"
```

### 3.1 EventBus — 全局信号总线

**职责**：解耦所有系统间的通信。任何节点不得直接调用其他系统的函数，必须通过 EventBus 发送信号。

```gdscript
# event_bus.gd
extends Node

# ---- 战斗事件 ----
signal enemy_killed(enemy_id: String, position: Vector2, is_elite: bool)
signal player_damaged(amount: int, new_hp: int)
signal player_died()
signal damage_dealt(source: Node, target: Node, amount: int, is_crit: bool)

# ---- 波次事件 ----
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal wave_timer_updated(time_left: float)
signal all_enemies_cleared()

# ---- 商店事件 ----
signal shop_opened(wave_number: int)
signal item_purchased(item_id: String, price: int)
signal weapon_purchased(weapon_id: String, price: int)
signal shop_refreshed()

# ---- 材料/拾取 ----
signal material_collected(amount: int, total_materials: int)
signal pickup_collected(pickup_type: String, value: int)

# ---- 游戏状态 ----
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over(wave_reached: int, materials_earned: int)

# ---- 武器 ----
signal weapon_fired(weapon_id: String, position: Vector2, direction: Vector2)
signal weapon_synthesized(weapon_id: String, new_tier: int)

# ---- 属性变化 ----
signal stat_changed(stat_name: String, new_value: float)
```

### 3.2 DataManager — 数据加载器

**职责**：加载、缓存和提供所有 `.tres` 数据资源。

```gdscript
# data_manager.gd
extends Node

# 数据缓存字典
var characters: Dictionary = {}    # character_id -> CharacterData
var weapons: Dictionary = {}       # weapon_id -> WeaponData
var items: Dictionary = {}         # item_id -> ItemData
var enemies: Dictionary = {}       # enemy_id -> EnemyData
var wave_configs: Dictionary = {}  # wave_number -> WaveConfig

func _ready():
    load_all_resources()

func load_all_resources():
    # 遍历 resources/ 目录下所有 .tres 文件，按类型加载到对应字典
    _load_directory("res://resources/characters/", characters)
    _load_directory("res://resources/weapons/", weapons)
    _load_directory("res://resources/items/", items)
    _load_directory("res://resources/enemies/", enemies)
```

### 3.3 SaveManager — 存档管理

**职责**：元进度的读取、保存。使用 `ConfigFile` 或自定义 JSON。

```gdscript
# save_manager.gd
extends Node

const SAVE_PATH = "user://save_data.json"

var save_data: Dictionary = {
    "total_materials_earned": 0,
    "total_kills": 0,
    "total_runs": 0,
    "total_wins": 0,
    "highest_wave": 0,
    "unlocked_characters": ["well_rounded"],
    "unlocked_weapons": ["stick"],
    "unlocked_items": [],
    "difficulty_levels": []
}

func save_game():
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "\t"))

func load_game():
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        save_data = JSON.parse_string(file.get_as_text())

func is_character_unlocked(id: String) -> bool:
    return id in save_data["unlocked_characters"]

func unlock_character(id: String):
    if id not in save_data["unlocked_characters"]:
        save_data["unlocked_characters"].append(id)
        save_game()
```

### 3.4 GameManager — 游戏状态机

**职责**：管理游戏整体状态，协调波次、商店、结算的切换。

```gdscript
# game_manager.gd
extends Node

enum GameState {
    MAIN_MENU,
    CHARACTER_SELECT,
    WAVE_ACTIVE,
    SHOP,
    PAUSED,
    GAME_OVER
}

var current_state: GameState = GameState.MAIN_MENU
var current_wave: int = 1
var materials: int = 0
var selected_character_id: String

func start_run(character_id: String):
    selected_character_id = character_id
    current_wave = 1
    materials = 0
    change_state(GameState.WAVE_ACTIVE)

func change_state(new_state: GameState):
    current_state = new_state
    match new_state:
        GameState.WAVE_ACTIVE:
            EventBus.game_started.emit()
            EventBus.wave_started.emit(current_wave)
        GameState.SHOP:
            EventBus.wave_completed.emit(current_wave)
            EventBus.shop_opened.emit(current_wave)
        GameState.GAME_OVER:
            EventBus.game_over.emit(current_wave, materials)

func next_wave():
    current_wave += 1
    if current_wave > 20:
        # 通关！
        _handle_victory()
    else:
        change_state(GameState.WAVE_ACTIVE)
```

### 3.5 WaveManager — 波次管理器

**职责**：根据 GDD §8 的波次配置表，控制敌人生成节奏。

```gdscript
# wave_manager.gd
extends Node

var wave_timer: float = 0.0
var wave_duration: float = 20.0
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var spawn_interval: float = 1.0
var spawn_timer: float = 0.0
var enemies_alive: int = 0

func start_wave(wave_number: int):
    var config = DataManager.wave_configs[wave_number]
    wave_duration = config.duration
    enemies_to_spawn = config.enemy_count
    enemies_spawned = 0
    enemies_alive = 0
    wave_timer = wave_duration
    spawn_interval = wave_duration / enemies_to_spawn

func _process(delta):
    if GameManager.current_state != GameManager.GameState.WAVE_ACTIVE:
        return

    wave_timer -= delta
    spawn_timer -= delta

    EventBus.wave_timer_updated.emit(wave_timer)

    if enemies_spawned < enemies_to_spawn and spawn_timer <= 0:
        _spawn_enemy()
        spawn_timer = spawn_interval

    if wave_timer <= 0 and enemies_alive <= 5:
        # 波次结束
        GameManager.change_state(GameManager.GameState.SHOP)

func _spawn_enemy():
    # 见 §9.3
    pass
```

### 3.6 ObjectPool — 对象池

**职责**：复用子弹、敌人、特效节点，避免频繁创建/销毁。详见 [§10](#10-对象池系统)。

---

## 4. 场景层级架构

### 4.1 主场景树

```
Main (Node2D)
│
├── GameWorld (Node2D)                    # 游戏世界容器
│   ├── TileMap                           # 地图背景
│   ├── Player (见 §5.1)                  # 玩家节点
│   ├── Enemies (Node2D)                  # 敌人容器
│   │   ├── Enemy_1
│   │   ├── Enemy_2
│   │   └── ...
│   ├── Projectiles (Node2D)              # 子弹容器
│   │   ├── Bullet_1
│   │   └── ...
│   ├── Pickups (Node2D)                  # 掉落物容器
│   │   ├── Pickup_1
│   │   └── ...
│   ├── Effects (Node2D)                  # 特效容器
│   └── Camera2D                          # 跟随玩家的摄像机
│
└── UI (CanvasLayer)                      # UI 层（独立 CanvasLayer）
    ├── HUD (见 §5.5)
    ├── ShopUI (初始隐藏)
    ├── PauseMenu (初始隐藏)
    ├── GameOverUI (初始隐藏)
    └── WaveAnnounce (初始隐藏)
```

### 4.2 场景切换流

```
MainMenu ──→ CharacterSelect ──→ Main.tscn (加载 GameWorld)
                                       │
          ┌────────────────────────────┘
          ▼
    GameWorld 内部状态切换：
      WAVE_ACTIVE ⇄ SHOP ⇄ PAUSED → GAME_OVER
                                          │
                                          ▼
                                    MainMenu (返回)
```

> **推荐做法**：使用单一主场景 + 状态机切换，而非频繁 `change_scene_to_file()`。性能更好，状态管理更简单。

---

## 5. 实体架构（节点树定义）

> **重要**：以下是每个实体的精确节点树结构。AI Agent 创建场景时必须严格按此结构。

### 5.1 Player（玩家）

```
Player (CharacterBody2D)
├── Sprite2D                         # 玩家精灵
├── CollisionShape2D                 # CircleShape2D, radius=20
├── Hurtbox (Area2D)                 # 受伤判定区域
│   └── CollisionShape2D             # CircleShape2D, radius=22
├── WeaponContainer (Node2D)         # 武器挂载点
│   ├── Weapon_1 (见 §5.3 武器节点)
│   ├── Weapon_2
│   └── ...（最多 6 个）
├── PickupRadius (Area2D)            # 拾取范围
│   └── CollisionShape2D             # CircleShape2D, radius 动态调整
├── AnimationPlayer                  # 动画（走路、受击）
├── IFrameTimer (Timer)              # 无敌帧计时器
│
└── Attached Script: player.gd
    ├── PlayerStats (Node, 通过 player_stats.gd 脚本)
    └── PlayerWeaponSlot (Node, 通过 player_weapon_slot.gd 脚本)
```

### 5.2 Enemy（敌人基类）

```
Enemy (CharacterBody2D)
├── Sprite2D                         # 敌人精灵
├── CollisionShape2D                 # 碰撞体（因敌人类型而异）
├── Hitbox (Area2D)                  # 受击判定
│   └── CollisionShape2D
├── HealthBar (ProgressBar)          # 血条
├── AnimationPlayer
├── AIStateMachine (Node)            # 通过 enemy_ai.gd 脚本
│
└── Attached Script: enemy_base.gd
    └── EnemyStats (Node, 通过 enemy_stats.gd 脚本)
```

### 5.3 Weapon（武器 — 挂载在 Player.WeaponContainer 下）

```
Weapon (Node2D)
├── AttackPoint (Marker2D)           # 攻击起始点 / 子弹生成点
├── CooldownTimer (Timer)            # 冷却计时器
│
└── Attached Script: weapon_base.gd（子类覆盖 attack()）
```

不同武器类型的子节点差异：

**近战武器额外节点：**
```
├── MeleeArea (Area2D)               # 近战判定区域
│   └── CollisionShape2D
└── MeleeSprite (Sprite2D)           # 武器挥动动画精灵
```

**远程/元素武器额外节点：**
```
├── MuzzleFlash (Sprite2D)           # 枪口闪光（可选）
```

**工程武器额外节点：**
```
└── DeployPoint (Marker2D)           # 部署位置
```

### 5.4 Projectile（子弹/弹丸）

```
Projectile (Area2D)
├── Sprite2D                         # 子弹精灵
├── CollisionShape2D
├── Trail (Line2D / CPUParticles2D)  # 拖尾特效（可选）
│
└── Attached Script: projectile_base.gd
    # 属性：damage, speed, direction, pierce_left, bounce_left, knockback
```

### 5.5 HUD（战斗界面）

```
HUD (Control)
├── TopBar (HBoxContainer)
│   ├── WaveLabel (Label)            # "波次: 5/20"
│   └── TimerLabel (Label)           # "剩余: 18s"
│
├── HPBar (ProgressBar)              # 生命值条
├── HPLabel (Label)                  # "85/100"
│
├── BottomBar (HBoxContainer)
│   ├── MaterialIcon (TextureRect)
│   ├── MaterialLabel (Label)        # "42"
│   ├── Separator
│   └── WeaponSlots (HBoxContainer)  # 6 个武器图标槽
│       ├── WeaponSlot_1..6 (TextureRect)
```

---

## 6. 组件化架构

> **核心原则**：Composition over Inheritance。使用独立 Node 组件拼装实体，而非深层继承链。

### 6.1 组件清单

| 组件 | 脚本 | 挂载到 | 职责 |
|------|------|--------|------|
| StatsComponent | `player_stats.gd` / `enemy_stats.gd` | Player / Enemy | 属性存储、修改器堆叠、查询 |
| HealthComponent | `health_component.gd` | Player / Enemy | HP 管理、受伤、死亡判定 |
| WeaponComponent | `weapon_base.gd` | Player.WeaponContainer/子节点 | 武器冷却、攻击逻辑 |
| AIComponent | `enemy_ai.gd` | Enemy | 行为状态机 |
| MovementComponent | `movement_component.gd` | Player / Enemy | 移动逻辑（可选，简单移动可直接在实体脚本中处理） |
| PickupComponent | `pickup_component.gd` | Pickup 节点 | 拾取交互 |

### 6.2 StatsComponent 设计（核心！）

这是整个游戏的数据核心。所有实体的属性都由 StatsComponent 管理。

```gdscript
# player_stats.gd (挂载在 Player 上)
extends Node
class_name StatsComponent

# 基准属性（从 CharacterData 初始化）
var base_stats: Dictionary = {}

# 当前属性（含所有修改器）= 基准 + 道具加成 + 武器加成 + 临时 Buff
var current_stats: Dictionary = {}

# 属性修改器来源追踪
var stat_modifiers: Dictionary = {}  # stat_name -> [{source, value}]

func init_from_character(character_data: CharacterData):
    base_stats = character_data.base_stats.duplicate(true)
    current_stats = base_stats.duplicate(true)
    stat_modifiers.clear()

func add_modifier(stat_name: String, source: String, value: float):
    if stat_name not in stat_modifiers:
        stat_modifiers[stat_name] = []
    stat_modifiers[stat_name].append({"source": source, "value": value})
    _recalculate_all()

func remove_modifiers_from_source(source: String):
    for stat_name in stat_modifiers:
        stat_modifiers[stat_name] = stat_modifiers[stat_name].filter(
            func(m): return m["source"] != source
        )
    _recalculate_all()

func _recalculate_all():
    current_stats = base_stats.duplicate(true)
    for stat_name in stat_modifiers:
        var total_mod = 0.0
        for m in stat_modifiers[stat_name]:
            total_mod += m["value"]
        # 对各属性应用不同的叠加方式
        match stat_name:
            # 百分比属性：加算叠加
            "attack_speed", "crit_chance", "damage_pct", "dodge", "speed", "life_steal":
                current_stats[stat_name] = base_stats[stat_name] + total_mod
            # 固定值属性：加算叠加
            _:
                current_stats[stat_name] = base_stats[stat_name] + total_mod

    # 应用上下限
    current_stats["dodge"] = clamp(current_stats["dodge"], 0, 60)
    current_stats["attack_speed"] = max(current_stats["attack_speed"], -80)

func get_stat(stat_name: String) -> float:
    return current_stats.get(stat_name, 0.0)
```

---

## 7. 数据系统

### 7.1 Resource 类型定义

所有静态数据使用 Godot `Resource` 子类（.tres 文件）。

```gdscript
# resources/character_data.gd
class_name CharacterData
extends Resource

@export var id: String
@export var display_name: String
@export var description: String
@export var unlock_condition: String
@export var base_stats: Dictionary
@export var starting_weapon: String
@export var max_hp_modifier: float = 1.0
@export var special_rule: String = ""
```

```gdscript
# resources/weapon_data.gd
class_name WeaponData
extends Resource

@export var id: String
@export var display_name: String
@export var weapon_class: String   # melee, ranged, elemental, engineering, primitive
@export var tier: int = 1
@export var base_damage: float
@export var cooldown: float
@export var range: float
@export var crit_multiplier: float = 2.0
@export var pierce: int = 1
@export var bounce: int = 0
@export var projectiles: int = 1
@export var knockback: float = 50.0
@export var lifesteal_multiplier: float = 1.0
@export var tags: Array[String] = []
```

```gdscript
# resources/item_data.gd
class_name ItemData
extends Resource

@export var id: String
@export var display_name: String
@export var rarity: String  # common, uncommon, rare, legendary
@export var base_price: int
@export var max_stack: int = 0  # 0 = 无限
@export var stat_modifiers: Dictionary
@export var tags: Array[String] = []
@export var description: String
@export var special_effect: String = ""  # 特殊效果脚本路径
```

```gdscript
# resources/enemy_data.gd
class_name EnemyData
extends Resource

@export var id: String
@export var enemy_type: String  # chaser, charger, shooter, summoner, tank, elite, boss
@export var base_hp: float
@export var base_damage: float
@export var base_speed: float
@export var material_drop: int = 1
@export var sprite_path: String
```

```gdscript
# resources/wave_config.gd
class_name WaveConfig
extends Resource

@export var wave_number: int
@export var duration: float
@export var total_enemies: int
@export var enemy_types: Array[Dictionary]  # [{type_id, weight, min_wave}]
@export var spawn_interval: float
@export var elite_chance: float = 0.0
@export var material_multiplier: float = 1.0
@export var is_boss_wave: bool = false
```

### 7.2 数据流

```
┌──────────────┐     加载      ┌──────────────┐
│  .tres 文件   │ ──────────→  │  DataManager  │
│  (静态数据)   │              │  (缓存字典)    │
└──────────────┘              └──────┬───────┘
                                     │ 提供数据
                                     ▼
┌──────────────┐    初始化     ┌──────────────┐
│  实体节点     │ ←─────────── │  GameManager  │
│  (运行时)     │              │  (协调器)     │
└──────────────┘              └──────────────┘
       │
       │ 运行时修改
       ▼
┌──────────────┐
│ StatsComponent│  (属性修改器堆叠)
│ current_stats │
└──────────────┘
       │
       │ 属性变化
       ▼
┌──────────────┐
│   EventBus    │  (stat_changed 信号)
└──────┬───────┘
       │
       ▼
┌──────────────┐    存档     ┌──────────────┐
│  SaveManager  │ ←───────── │  元进度数据   │
└──────────────┘             └──────────────┘
```

---

## 8. 事件系统（EventBus）

### 8.1 使用规范

```gdscript
# ✅ 正确：通过 EventBus 通信
EventBus.enemy_killed.connect(_on_enemy_killed)

# ❌ 错误：直接引用其他场景节点
$"../../HUD".update_score()

# ❌ 错误：直接访问其他 Autoload 的私有数据
GameManager.some_internal_var
```

### 8.2 信号流转示例

**场景：敌人被击杀**

```
1. Enemy.take_damage() → hp <= 0 → die()
2. Enemy.die() → EventBus.enemy_killed.emit(enemy_id, position, is_elite)
3. HUD 监听到 enemy_killed → 更新击杀计数（如有）
4. WaveManager 监听到 enemy_killed → enemies_alive -= 1
5. PickupSystem 监听到 enemy_killed → 生成材料掉落
6. 有特殊效果的道具监听 enemy_killed → 触发击杀效果
```

**场景：购买道具**

```
1. ShopUI → 玩家点击购买按钮
2. ShopUI → EventBus.item_purchased.emit(item_id, price)
3. GameManager 监听 → 扣除材料
4. Player.StatsComponent 监听 → add_modifier(...)
5. HUD 监听 → 更新属性显示、材料数
6. EventBus.stat_changed.emit(...)
7. 各武器节点监听 stat_changed → 重新计算冷却/伤害
```

---

## 9. 关键算法实现

### 9.1 伤害计算

```gdscript
# damage_system.gd
class_name DamageSystem
extends RefCounted

static func calculate_damage(weapon: WeaponData, attacker_stats: StatsComponent, target_stats: StatsComponent) -> Dictionary:
    var damage = weapon.base_damage

    # 步骤 1-3：伤害加成
    damage *= (1.0 + attacker_stats.get_stat("damage_pct") / 100.0)
    match weapon.weapon_class:
        "melee":
            damage += attacker_stats.get_stat("melee_damage")
        "ranged":
            damage += attacker_stats.get_stat("ranged_damage")
        "elemental":
            damage += attacker_stats.get_stat("elemental_damage")
        "engineering":
            damage *= (1.0 + attacker_stats.get_stat("engineering") / 100.0)

    # 步骤 4：暴击判定
    var is_crit = false
    var crit_roll = randf() * 100.0
    var total_crit_chance = attacker_stats.get_stat("crit_chance")
    # 幸运对暴击的加成：每 10 点幸运 +1% 暴击率（二次判定）
    var luck = attacker_stats.get_stat("luck")
    if crit_roll < total_crit_chance or (luck > 0 and randf() * 100.0 < luck / 10.0):
        is_crit = true
        damage *= weapon.crit_multiplier

    # 步骤 5：目标减免 — 闪避
    var dodge_roll = randf() * 100.0
    if dodge_roll < target_stats.get_stat("dodge"):
        return {"damage": 0, "is_crit": false, "dodged": true}

    # 步骤 5：目标减免 — 护甲
    var armor = target_stats.get_stat("armor")
    var armor_reduction = armor / (armor + 100.0)
    armor_reduction = min(armor_reduction, 0.9)  # 上限 90%

    # 步骤 6：最终伤害
    var final_damage = damage * (1.0 - armor_reduction)
    final_damage = max(1, roundi(final_damage))  # 至少 1 点伤害

    return {"damage": final_damage, "is_crit": is_crit, "dodged": false}
```

### 9.2 武器冷却计算

```gdscript
# weapon_base.gd
func get_effective_cooldown() -> float:
    var attack_speed = player_stats.get_stat("attack_speed")
    # 攻速 +% 减少冷却，公式：冷却 / (1 + 攻速%)
    var effective_cd = weapon_data.cooldown / (1.0 + attack_speed / 100.0)
    return max(effective_cd, 0.1)  # 冷却不低于 0.1 秒
```

### 9.3 敌人生成算法

```gdscript
# wave_manager.gd
func _spawn_enemy():
    var config = DataManager.wave_configs[GameManager.current_wave]

    # 1. 加权随机选择敌人类型
    var enemy_type = _weighted_random(config.enemy_types)

    # 2. 判断是否为精英（按概率）
    var is_elite = randf() < config.elite_chance

    # 3. 生成位置：地图边缘外，随机角度
    var angle = randf() * TAU
    var spawn_distance = 800.0  # 地图半径 + 边距
    var spawn_pos = GameWorld.player.global_position + Vector2(
        cos(angle) * spawn_distance,
        sin(angle) * spawn_distance
    )

    # 4. 生成敌人（使用对象池）
    var enemy: EnemyBase
    if is_elite:
        enemy = ObjectPool.get_enemy(enemy_type + "_elite")
    else:
        enemy = ObjectPool.get_enemy(enemy_type)

    enemy.init(DataManager.enemies[enemy_type], GameManager.current_wave, is_elite)
    enemy.global_position = spawn_pos
    GameWorld.enemies_container.add_child(enemy)

    enemies_spawned += 1
    enemies_alive += 1
```

### 9.4 商店随机算法

```gdscript
# shop 物品生成逻辑
func generate_shop_items(wave_number: int, luck: float) -> Array:
    var items = []
    var available_items = DataManager.items.values()

    # 根据幸运调整稀有度权重
    var rarity_weights = {
        "common": 60.0 - luck * 0.3,    # 幸运越高，普通越少
        "uncommon": 25.0 + luck * 0.1,
        "rare": 12.0 + luck * 0.15,
        "legendary": 3.0 + luck * 0.05
    }
    # 确保所有权重为正
    for key in rarity_weights:
        rarity_weights[key] = max(rarity_weights[key], 5.0)

    # 生成 4 个不重复道具
    var used_ids = []
    for i in range(4):
        var rarity = _weighted_random_from_dict(rarity_weights)
        var pool = available_items.filter(
            func(item): return item.rarity == rarity and item.id not in used_ids
        )
        if pool.is_empty():
            pool = available_items.filter(func(item): return item.id not in used_ids)

        var chosen = pool[randi() % pool.size()]
        used_ids.append(chosen.id)
        items.append({
            "item": chosen,
            "price": _calculate_price(chosen.base_price, wave_number)
        })

    return items
```

---

## 10. 对象池系统

### 10.1 设计

```gdscript
# object_pool.gd
extends Node

# 每种类型维护一个可用对象队列
var enemy_pool: Dictionary = {}       # enemy_type -> Array[Enemy]
var projectile_pool: Dictionary = {}  # projectile_type -> Array[Projectile]
var pickup_pool: Dictionary = {}      # pickup_type -> Array[Pickup]
var effect_pool: Dictionary = {}      # effect_type -> Array[Node2D]

func get_enemy(enemy_type: String) -> EnemyBase:
    if enemy_pool.has(enemy_type) and not enemy_pool[enemy_type].is_empty():
        var enemy = enemy_pool[enemy_type].pop_back()
        enemy.visible = true
        enemy.process_mode = Node.PROCESS_MODE_INHERIT
        return enemy
    else:
        # 池空，创建新实例
        return _create_enemy(enemy_type)

func return_enemy(enemy: EnemyBase, enemy_type: String):
    enemy.visible = false
    enemy.process_mode = Node.PROCESS_MODE_DISABLED
    if not enemy_pool.has(enemy_type):
        enemy_pool[enemy_type] = []
    enemy_pool[enemy_type].append(enemy)

# get_projectile(), return_projectile(), get_pickup(), return_pickup() 同理
```

### 10.2 使用时机

| 对象类型 | 使用对象池 | 原因 |
|----------|-----------|------|
| 子弹/弹丸 | ✅ 必须 | 极高频率创建/销毁 |
| 敌人 | ✅ 必须 | 高频率创建/销毁 |
| 材料掉落物 | ✅ 必须 | 高频率创建/销毁 |
| 视觉特效 | ✅ 建议 | 中等频率 |
| UI 元素 | ❌ 不需要 | 创建/销毁频率低 |

---

## 11. UI 架构

### 11.1 UI 更新模式

UI 不主动查询数据，而是**监听 EventBus 信号**被动更新：

```gdscript
# hud_ui.gd
func _ready():
    EventBus.stat_changed.connect(_on_stat_changed)
    EventBus.material_collected.connect(_on_material_collected)
    EventBus.wave_timer_updated.connect(_on_timer_updated)
    EventBus.player_damaged.connect(_on_player_damaged)

func _on_stat_changed(stat_name: String, new_value: float):
    # 仅更新受影响的 UI 元素
    match stat_name:
        "max_hp", "hp":
            _update_hp_bar()
        "attack_speed":
            # 武器图标可能需要更新冷却显示
            pass

func _on_material_collected(amount: int, total: int):
    material_label.text = str(total)
    # 播放一个小动画
```

### 11.2 商店 UI 流程

```
1. GameManager.change_state(SHOP)
2. EventBus.shop_opened.emit(wave)
3. ShopUI._on_shop_opened():
   a. 生成 4 个道具 + 0~2 个武器
   b. 计算价格
   c. 显示面板
   d. 启用操作按钮（购买/刷新/锁定/继续）
4. 玩家交互：
   - 购买 → EventBus.item_purchased / weapon_purchased
   - 刷新 → 重新生成道具，扣除材料
   - 锁定 → 标记槽位
   - 继续 → EventBus.shop_closed → GameManager.next_wave()
```

---


> **本文档为 AI Agent 实现规范。所有代码结构、命名、通信方式必须与本文档一致。**
> 如有架构调整，必须同步更新本文档。
