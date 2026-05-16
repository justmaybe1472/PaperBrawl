# Task Phase — Potato Survivor (Godot 4.x 2D)

> **版本**: 1.2 | **最后更新**: 2026-05-16 | **引擎**: Godot 4.x
> 当前阶段 Phase 5
> 本文档是 AI Agent 实现游戏的开发顺序。

## 1. AI Agent 开发路线图

### 1.1 开发阶段（MVP 优先）

#### Phase 1：最小可玩原型（约 3-5 天）

目标：一个角色、一把武器、一种敌人、3 波、能移动和自动攻击。

**步骤：**
- [√] 1. 创建 Godot 项目，完成 `project.godot` 配置
- [√] 2. 实现 `EventBus`、`DataManager` Autoload
- [√] 3. 创建 `CharacterData`、`WeaponData`、`EnemyData` Resource 类
- [√] 4. 创建 1 个角色、1 个武器、1 个敌人的 `.tres` 文件
- [√] 5. 实现 `Player` 场景（移动 + StatsComponent + 武器挂载）
- [√] 6. 实现 `Enemy` 场景（追踪 AI + 受击 + 死亡）
- [√] 7. 实现 `Weapon` + `Projectile`（远程武器自动攻击）
- [√] 8. 实现 `GameWorld` 场景（摄像机 + 敌人生成 + 碰撞）
- [√] 9. 实现 `HUD`（HP 条 + 波次显示）
- [√] 10. 实现 `WaveManager`（3 波简单配置）

**验证标准**：WASD 移动、自动射击、敌人追踪受击死亡、波次推进、HP 归零游戏结束。

#### Phase 2：完整核心循环（约 4-6 天）

目标：完整波次、商店、道具、掉落、多种敌人。

**步骤：**
- [√] 1. 补全 20 波配置
- [√] 2. 实现全部敌人类型（冲刺、远程、召唤、坦克、精英）
- [√] 3. 实现 ShopUI + 商店逻辑
- [√] 4. 实现 DropSystem（材料掉落 + 自动拾取）
- [√] 5. 扩充道具库（至少 20 个道具 + 属性修改器系统）
- [√] 6. 武器合成逻辑
- [√] 7. 玩家 HP 再生 + 生命偷取
- [√] 8. 暂停菜单
- [√] 9. 结算界面

#### Phase 3：内容填充（约 3-5 天）

目标：多个角色、多种武器、元进度、完整 UI。

**步骤：**
- [√] 1. 所有角色（8 个）+ 解锁条件
- [√] 2. 所有武器类型 + 每种 3-4 个武器
- [√] 3. 道具补全至 30+ 个
- [√] 4. SaveManager + 元进度
- [√] 5. 主菜单 + 角色选择 UI
- [√] 6. 难度等级
- [√] 7. 波次提示动画
- [√] 8. Boss 战（第 20 波）

#### Phase 4：打磨（约 3-5 天）

目标：视觉特效、音效、平衡性、对象池、性能优化。

**步骤：**
- [√] 1. 对象池（子弹、敌人）
- [√] 2. 伤害数字弹出
- [√] 3. 屏幕震动
- [√] 4. 武器/道具图标
- [√] 5. 音效 + 音乐
- [√] 6. 数值平衡调整
- [√] 7. Bug 修复


### 1.2 给每个系统的独立 Prompt 建议

| 系统 | 建议 Prompt 侧重点 |
|------|-------------------|
| Player | "实现 player.gd，只需移动、StatsComponent 初始化、无敌帧" |
| Weapon | "实现 weapon_base.gd 和 weapon_ranged.gd，冷却 + 自动瞄准 + 子弹生成" |
| Enemy | "实现 enemy_base.gd 死亡流程 + enemy_chaser.gd 追踪 AI" |
| Shop | "实现 shop_ui.gd，4 个道具槽 + 购买/刷新/锁定" |
| 每个道具 | "创建 medkit.tres，属性修改器 {'max_hp': 3, 'hp_regen': 1}" |

**关键原则**：每次喂给 AI Agent 的任务越小越具体，成功率越高。

---

#### Phase 5：核心 Bug 修复（P0/P1）

目标：修复崩溃级 Bug 和核心战斗逻辑缺失，确保所有武器类型正常工作。

**步骤：**
- [ ] 1. 修复远程/元素武器崩溃 — `DamageSystem.calculate_damage()` 在 `target_stats` 为 null 时访问 `target_stats.get_stat("dodge")` 直接崩溃。`weapon_ranged.gd` 和 `weapon_elemental.gd` 的 `_spawn_projectile()` 传入 `null` 作为 target_stats。修改 `DamageSystem` 对 null target_stats 做防御处理（跳过闪避和护甲计算），或改为投射物命中时再计算伤害。
- [ ] 2. 修复投射物无视闪避/护甲 — `projectile_base.gd:_on_body_entered()` 使用预计算的 `damage` 值直接调用 `enemy.take_damage()`，完全跳过 `DamageSystem` 中的目标闪避和护甲减免。应将伤害计算移至命中时，在 `_on_body_entered` 中传入实际敌人的 stats 重新调用 `DamageSystem.calculate_damage()`。
- [ ] 3. 修复工程武器绕过伤害系统 — `weapon_engineering.gd` 中炮塔和地雷的伤害手动计算（`base_damage * engineering_mult`），未经过 `DamageSystem`，导致无暴击、无全局 `damage_pct` 加成、无目标闪避/护甲。改为在 `turret_deploy.gd` 和 `mine_deploy.gd` 命中时调用 `DamageSystem.calculate_damage()`。
- [ ] 4. 实现道具堆叠上限（max_stack）— `ItemData` 有 `max_stack` 字段，多数道具限制 1-5 个，但 `StatsComponent.add_modifier()` 无堆叠数量检查。在 `Player` 或 `StatsComponent` 中增加 `_item_stack_counts: Dictionary` 记录每个道具的购买次数，购买前检查是否已达 `max_stack`（0 表示无限制），已达上限时阻止购买并提示。

**验证标准**：购买并使用远程/元素/工程武器不报错；投射物伤害正确计算闪避和护甲；同一道具购买次数不超过 max_stack。

---

#### Phase 6：功能补全（P2）

目标：补齐已设计但未实现的核心功能。

**步骤：**
- [ ] 1. 商店解锁筛选 — `SaveManager` 已有 `is_weapon_unlocked()` / `is_item_unlocked()` 和初始化解锁列表（`unlocked_weapons: ["stick"]`, `unlocked_items: []`），但 `shop_ui.gd:_generate_shop()` 未过滤。在生成商店物品和武器时，调用 `SaveManager.is_item_unlocked()` / `SaveManager.is_weapon_unlocked()` 过滤未解锁项。同时添加武器/道具解锁逻辑：首次通关/达到特定波次时解锁新武器，购买特定道具后解锁关联道具。
- [ ] 2. 精英敌人属性增益 — `enemy_base.gd:set_elite()` 仅改变颜色和尺寸，无属性加成。精英敌人应获得：HP ×2、伤害 ×1.5、移动速度 ×1.2、体型 +20%。在 `set_elite()` 中直接修改 `stats` 的属性值，或在 `EnemyStats.init_from_data()` 中接收 `is_elite` 参数。精英掉落材料已有 3 倍加成，保留。
- [ ] 3. 更换美术资源 - 临时资源路径 res://assets/TestTexture/ 尺寸大小需要重新调整，直接调整缩放即可
- [ ] 4. 给每一行代码增加中文注释

**验证标准**：商店只显示已解锁的物品和武器；精英敌人明显比普通敌人更强。


#### Phase 7：打磨完善（P3）

目标：完善体验细节，补充交互反馈和 UI 信息展示。

**步骤：**
- [ ] 1. 道具特殊效果系统 — `ItemData.special_effect` 字段已定义但无代码读取。设计并实现特殊效果接口：
  - 在 `ItemData` 中定义效果类型枚举：`on_kill`（击杀触发）、`on_hit`（命中触发）、`on_wave_start`（波次开始触发）、`conditional`（条件被动）、`consumable`（一次性使用）
  - 创建 `SpecialEffect` 基类 Resource，子类实现具体逻辑
  - 在 `Player` 中监听对应事件，遍历已持有道具执行特殊效果
  - 至少实现 2 个示例效果（如：医疗包 — 波次结束时恢复 20% HP；狂战士戒指 — 击杀时 +3% 伤害持续 10 秒）
- [ ] 2. 武器替换确认对话框 — `player_weapon_slot.gd:add_weapon()` 在槽满时自动替换最低等级武器。改为发射 `weapon_replace_prompt` 信号，由 UI 层弹出确认对话框，展示新旧武器对比，玩家确认后再执行替换。或简化为：仅在购买更高等级的同类型武器时才自动替换，不同类型武器槽满时拒绝购买并提示。
- [ ] 3. 未使用信号处理 — `EventBus.all_enemies_cleared` 和 `EventBus.pickup_collected` 已声明但从未 emit。评估是否需要：
  - `all_enemies_cleared`：当 `WaveManager` 检测到所有敌人已消灭时 emit，可用于触发特殊效果或 UI 提示
  - `pickup_collected`：当 `PickupSystem._collect()` 时 emit（携带拾取类型和数值），可用于音效和统计
  - 如确定不需要则从 `event_bus.gd` 中移除声明
- [ ] 4. 武器合成视觉反馈 — `weapon_synthesized` 信号已 emit，HUD 刷新图标但无提示。在合成时弹出短暂文字（"合成成功！等级 +1"）或播放粒子特效，持续 1.5 秒后消失。
- [ ] 5. HUD 武器冷却指示器 — `hud_ui.gd` 显示武器图标并在攻击时闪烁，但无冷却进度。为每个武器槽添加冷却转圈遮罩（从满到空的 radial fill），通过监听 `weapon_fired` 信号读取武器节点的 `cooldown_timer` 计算剩余冷却比例。
- [ ] 6. 暂停菜单道具列表 — 暂停时展示当前持有的所有道具及其效果描述、堆叠数量。在 `pause_menu_ui.gd` 中遍历 `Player` 的 `stats_component.stat_modifiers` 和 `_item_stack_counts`，动态生成道具列表。

**验证标准**：特殊效果道具正常工作；替换武器有确认流程；合成有视觉反馈；HUD 能看到冷却进度；暂停可查看道具列表。
