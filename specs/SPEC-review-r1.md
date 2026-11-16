# SPEC — 4.11.0 自查整改（第一轮 review）

- 基线：本轮 4.11.0-dev.1 实施后的工作树（面向用户 SPEC 见 `SPEC-5v5-facing-minimap-levels-timing.md`）
- 方法：逐文件走查 + 无头探针 + 录屏像素分析 + 模拟器
- 范围：只修本轮实现引入或暴露的问题；3v3 冻结约束不变

## 1. 发现

| ID | 现象 | 根因 | 位置 |
|----|------|------|------|
| R1-01 | 边走边普攻时角色朝向抖动：挥砍帧朝目标，下一帧又被移动方向拉回 | `face_dir` 每帧先被移动覆盖、攻击帧再指向目标，平滑插值来回摆 | `battle_sim.gd` step_hero 移动块 / move_ai / step_minion |
| R1-02 | 巨兽普攻与技能起手不转身，只有冲锋和走路会转向 | `step_boss` 普攻只写 `facing`；`_begin_boss_cast` 完全不写朝向 | `battle_sim.gd:1004`、`1082` |
| R1-03 | 英雄/巨兽复活后保持死亡瞬间的朝向（可能背对兵线） | `respawn`/`respawn_boss` 未设置 `face_dir` | `battle_sim.gd` respawn / respawn_boss |
| R1-04 | SPEC C3 只实测了投射类技能 ×1.4，dash/leap/spin 未覆盖 | 测试缺口 | `tests/sim_headless.gd` `_level_checks` |
| R1-05 | `--walk` 与 `--auto-run` 同时传入时 walk 方向被 auto_run 覆盖 | `_process` 先写 walk 后写 auto | `main.gd` |
| R1-06 | 小地图上层圆盘批次（128）如果超限会静默丢标记 | `_add_ui_disc` 无提示 | `hud.gd` |

## 2. 修改方法

- **R1-01**：移动只在 `atk_anim <= 0.0 and cast_anim <= 0.0` 时写 `face_dir`（`move_dir`/`facing` 照旧每帧更新）：
  - 玩家移动块、`move_ai`、`step_minion` 三处。
  - 意义：挥砍/施法期间保持面向目标或施法方向，动作结束再回到移动方向。
- **R1-02**：`step_boss` 普攻分支补 `u.face_dir = (target.pos - u.pos).normalized()`；
  `_begin_boss_cast` 在 `target != null` 时补同样一行。
- **R1-03**：`respawn(h)` 补 `h.face_dir = (base_pos(1 - h.team) - h.pos).normalized()`；
  `respawn_boss(u)` 补 `u.face_dir = (base_pos(1 - u.team) - u.pos).normalized()`。
- **R1-04**：`_level_checks` 增加三类实测：
  1. dash：找 `kind == "dash"` 技能，L1 vs L5 释放后比较落地 `area_damage` 伤害（用一个站桩敌人记录 hp 差）；
  2. leap：同上（`kind == "leap"`）；
  3. spin：`kind == "spin"`，比较 `h.spin_dmg` 在 L1 vs L5 的比值（施法时已按 `skill_power` 写入）。
  断言比值 1.40 ±0.01。
- **R1-05**：`auto_run` 仅在 `walk_debug.length_squared() < 0.01` 时生效（walk 优先）。
- **R1-06**：`_add_ui_disc` 超限时 `print` 一次警告并继续。

## 3. 验收

| ID | 项目 | 标准 |
|----|------|------|
| V1-1 | 挥砍朝向稳定 | 无头：玩家向右移动并持续普攻，统计 120 帧 yaw 峰峰值 ≤0.35rad（修复前 >0.8）；`atk_anim>0` 期间 `face_dir` 恒指向目标 |
| V1-2 | 巨兽朝向 | 无头：巨兽普攻/起手技能后 `face_dir` 与目标方向夹角 ≤0.05rad |
| V1-3 | 复活朝向 | 无头：英雄复活后 `face_dir` 指向敌方基地（夹角 ≤0.05） |
| V1-4 | 技能成长覆盖 | `LEVEL_OK` 输出包含 projectile/dash/leap/spin 四项 ×1.4 断言 |
| V1-5 | walk 优先 | 同传 `--walk=up --auto-run` 时玩家 `move_dir.y < 0` |
| V1-6 | 回归 | `SIM_OK`/`RULE_OK`/`SIG_OK`/`MAP_OK`/`JGL_OK`/`FIX_OK`/`LEVEL_OK`/`FLOW_OK` 全绿；3v3 数值断言不变 |
| V1-7 | 录屏 | 5v5 跟拍 6 秒：挥砍期间身体不再左右摆动；小地图标记与上一轮像素验收一致 |