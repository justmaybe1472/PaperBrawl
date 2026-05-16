# Lessons Learned — Potato Survivor

> **用途**：记录开发过程中犯过的错、踩过的坑、走过的弯路。
> 每次新对话的 AI 必须读取此文件，避免重蹈覆辙。
>
> **维护原则**：每发现一个 Bug 或走了一次弯路，立即追加一条。

---

## 使用规则（给 AI Agent）

1. 开始任何任务前，**先读本文档**，检查要改的区域是否有历史问题
2. 如果开发中犯了错误，**任务完成后立即追加一条记录**
3. 每条记录必须包含「预防规则」，让未来的 AI 知道该怎么做
4. 不要删除旧记录——错误的决策也是知识
5. 每写一行代码，必须写中文注释

---

## 错误记录

> 格式：
> ```
> ### [日期] 简短标题
> - **场景**：当时在做什么
> - **错误**：犯了什么错
> - **根因**：为什么会犯错
> - **修复**：怎么修好的
> - **预防**：下次怎么避免（AI 可执行的检查规则）
> ```

### [2026-05-16] 对象池化后 `await` 导致节点失效
- **场景**：实现对象池后，`enemy_base.take_damage()` 中使用 `await` 做受击闪烁
- **错误**：`await` 期间节点可能已被归还到对象池（从树中移除），之后访问 `sprite` 属性会报错
- **根因**：对象池归还时移除了节点的父子关系，但 `await` 恢复后仍尝试访问子节点
- **修复**：在 `await` 后添加 `is_instance_valid(sprite)` 检查，且在 `await` 前也检查 `is_dead` 状态
- **预防**：任何使用 `await` 的实体方法，恢复后必须先检查 `is_instance_valid` 和 `is_dead`

### [2026-05-16] 私有方法命名约定被外部调用
- **场景**：`player.gd` 中 `_apply_damage()` 以 `_` 开头（GDScript 私有约定），但被 `enemy_projectile.gd` 从外部调用
- **错误**：命名暗示私有但实际需要公开接口
- **根因**：Phase 2-3 开发中命名不规范，未考虑跨文件调用场景
- **修复**：重命名为 `apply_damage()`
- **预防**：任何需要被其他脚本调用的方法不得以 `_` 开头

### [2026-05-16] 对象池归还时在物理回调中禁用碰撞导致报错
- **场景**：`ObjectPool.return_pickup()` 在 `_on_body_entered` 物理回调中被调用
- **错误**：`monitoring = false` 在物理回调中禁用 CollisionObject，Godot 不允许此操作
- **根因**：`_collect()` → `ObjectPool.return_pickup()` 在物理信号链中直接设置 `monitoring = false`
- **修复**：所有 return_* 方法改用 `set_deferred("monitoring", false)` 延迟到空闲帧禁用
- **预防**：对象池归还方法中涉及 CollisionObject 属性变更（monitoring、process_mode）时，始终使用 `set_deferred`

### [2026-05-16] 正弦波生成中使用未定义标识符 `T` 而非时间变量 `t`
- **场景**：`audio_manager.gd` 中程序化生成音效的正弦波公式
- **错误**：`sin(T * TAU * frequency)` 中 `T` 不是 Godot 内置常量（Godot 只有 `TAU`、`PI`），实际应使用局部变量 `t`
- **根因**：手误将小写 `t`（时间变量）写成了大写 `T`，Godot 中 `T` 未定义
- **修复**：全局替换 `T * TAU` → `t * TAU`
- **预防**：任何数学公式中的变量名区分大小写，`t` 是局部变量，`TAU` 是内置常量（= 2π），不要混用

### [2026-05-16] 波次清理时使用 queue_free 绕过对象池
- **场景**：`wave_manager._clear_remaining_enemies()` 在波次结束时清理残余敌人
- **错误**：使用 `queue_free()` 直接销毁节点，绕过对象池，导致下一波需要重新分配
- **根因**：实现对象池后未同步更新所有释放点的代码
- **修复**：改用 `ObjectPool.return_enemy()` 归还到池中
- **预防**：实现对象池后，全局搜索 `queue_free()` 确认所有调用点是否应改为池归还

### [2026-05-16] 投射物预计算伤害导致闪避/护甲被绕过
- **场景**：`weapon_ranged.gd` 和 `weapon_elemental.gd` 在发射投射物时预先调用 `DamageSystem.calculate_damage(weapon_data, player_stats, null)`，`projectile_base.gd` 命中时直接使用预计算值
- **错误**：预计算传入 null 作为 target_stats 导致崩溃；命中时未重新计算，敌方闪避和护甲完全无效
- **根因**：伤害计算应在命中时执行（可获取实际目标 stats），而非发射时预计算
- **修复**：移除发射时的预计算 (`_spawn_projectile`)，改为在 `projectile_base._on_body_entered()` 命中时调用 `DamageSystem.calculate_damage(weapon_data, attacker_stats, enemy.stats)`
- **预防**：任何延迟命中型攻击（投射物、炮塔、地雷），伤害计算必须在命中时执行，传入实际目标的 stats

### [2026-05-16] 工程武器手动计算伤害绕过 DamageSystem
- **场景**：`weapon_engineering.gd` 直接计算 `base_damage * (1 + engineering / 100)`
- **错误**：手动计算跳过全局 `damage_pct` 加成、暴击判定、目标闪避和护甲减免
- **根因**：炮塔/地雷作为独立脚本，未持有 `weapon_data` 和 `attacker_stats` 引用，无法调用 DamageSystem
- **修复**：将 `weapon_data` 和 `attacker_stats` 传入 `turret_deploy.gd` / `mine_deploy.gd`，命中时调用 `DamageSystem.calculate_damage()`
- **预防**：所有伤害计算必须通过 `DamageSystem.calculate_damage()` 统一入口，禁止任何脚本自行计算伤害值

### [2026-05-16] 道具堆叠上限 max_stack 未实现
- **场景**：`ItemData.max_stack` 字段已定义（多数道具限制 1-5 个），但购买时无检查
- **错误**：同一道具可无限购买，属性无上限叠加
- **根因**：Phase 2-3 实现道具系统时遗漏了堆叠上限检查
- **修复**：在 `Player` 中新增 `_item_stack_counts` 字典追踪每道具购买次数，`can_purchase_item()` 方法检查上限，`shop_ui.gd` 购买前调用检查
- **预防**：Resource 类中的约束字段（max_stack、max_hp_modifier 等）必须在购买/装备/初始化逻辑中读取并校验

### [2026-05-16] `load()` 加载 PNG 返回 `CompressedTexture2D` 而非 `ImageTexture`
- **场景**：`placeholder_sprites.gd:load_test_texture()` 声明返回类型为 `ImageTexture`
- **错误**：Godot 导入的 PNG 纹理类型为 `CompressedTexture2D`，运行时 `load()` 返回类型与函数签名不匹配，触发引擎报错并崩溃
- **根因**：`ImageTexture` 仅用于运行时 `Image.create_from_image()` 程序化创建的纹理；从磁盘 `load()` 的资源使用引擎导入管线，返回 `CompressedTexture2D`
- **修复**：返回类型改为基类 `Texture2D`
- **预防**：`load()` 加载外部图片资源时，返回类型应声明为 `Texture2D`；`ImageTexture` 仅适用于代码生成的纹理

## 常见防空指南（给玩家/开发者）

以下是在 Brotato-like 游戏中 AI 容易犯的**系统级错误**，提前列出防患于未然：

### Godot 引擎相关

| # | 易犯错误 | 预防检查 |
|---|---------|---------|
| 1 | `_process` 中写 `get_tree().change_scene_to_file()` 导致 crash | 场景切换只在输入回调或信号回调中执行 |
| 2 | 子节点用 `$` 引用但节点路径已变 | 使用 `@export var` 在编辑器中绑定，或用 `@onready` 延迟引用 |
| 3 | Area2D 的 `collision_layer` 和 `collision_mask` 搞反 | layer=我是什么，mask=我检测什么 |
| 4 | 信号连接后忘记 `disconnect`，节点释放时报错 | 用 `CONNECT_ONE_SHOT` 或检查 `is_inside_tree()` |
| 5 | `.tres` 资源被多个实例共享修改 | 运行时复制：`resource.duplicate(true)` |

### 游戏逻辑相关

| # | 易犯错误 | 预防检查 |
|---|---------|---------|
| 1 | 伤害计算用 int 除法导致结果为 0 | 伤害计算全程用 float，只在最终显示时取整 |
| 2 | 武器冷却用 `delta` 累加但暂停时仍在累加 | 暂停时 `set_process(false)` 或检查 GameManager 状态 |
| 3 | 敌人生成在屏幕外但选择了错误参考系 | 用 `global_position` 而非 `position` 计算生成坐标 |
| 4 | 对象池归还后仍持有引用 | 归还前清空所有外部引用（target、owner 等） |
| 5 | EventBus 信号参数类型不匹配导致静默失败 | 发信号前确认参数类型与 `signal` 声明一致 |
| 6 | 属性修改器未区分百分比和固定值导致数值错误 | StatsComponent 中对不同属性使用不同叠加方式 |
| 7 | 多个武器同时攻击同一敌人时 `enemy_killed` 信号重复触发 | 敌人死亡时检查 `is_alive` 标志，已死亡则忽略后续伤害 |

### 架构相关

| # | 易犯错误 | 预防检查 |
|---|---------|---------|
| 1 | 直接 `get_node("../../HUD")` 跨场景引用 | 必须通过 EventBus 信号通信 |
| 2 | 在 `_ready()` 中依赖其他节点的 `_ready()` 已执行完 | 关键初始化放在 `_enter_tree()` 或用信号延迟 |
| 3 | Autoload 之间循环依赖 | EventBus 不依赖任何 Autoload，DataManager 只做加载 |

---

> **最后提醒**：本文档的价值 = 你维护它的频率。每次踩坑立即记，积少成多。
