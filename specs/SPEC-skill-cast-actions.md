# SPEC — 技能释放动作全面优化

状态：已实现（4.25.0 / code 68）
日期：2026-11-20
版本目标：4.25.0 / versionCode 68

用户反馈：阿跳的筋斗跃全身动作很好，希望所有人的技能释放都往这个方向改；
例如阿狮的「旋风爪」要真的转起来。

## 1. 现状与问题

- `battle_sim` 只给表现层 `cast_anim / cast_total`，没有技能序号与类型；
- `battle_view._sync_hero` 的施法统一是「双臂上举」，只有 `move_skill_kind == "leap"`
  的位移技能有整段跳跃，所以只有筋斗跃看起来像全身动作；
- 阿狮「旋风爪」的黄色风柱体积太大，即使加了旋身也会把英雄盖住。

## 2. 动作系统

### 数据

- `Unit` 新增 `cast_index`、`cast_kind`；`try_cast()` 写入。
- 表现层 `cast_action_for(hero_id, index, kind)` 返回 12 种动作之一：
  `spin / twirl / slam / stomp / charge / cast / slash / roar / pray / crouch / dive / none`。

### 大招签名动作（index == 2）

| 动作 | 英雄 |
|---|---|
| spin 旋转 | 阿狮（旋风爪）、尖尖（万爪齐发）、冰冰（暴风雪）、夜羽（音波风暴）、刺刺（滚动刺球） |
| twirl 旋舞 | 灵灵、小白 |
| slam 跳砸 | 阿岳、团团、阿跳、阿吨、甲甲 |
| stomp 跺地 | 泡泡 |
| dive 俯冲 | 咕咕、灰灰 |
| cast 施法 | 角角 |
| charge 冲锋 | 火火 |
| pray 祈祷 | 朵朵、绒绒、云朵 |

### 小技能（按 kind）

- `aoe` → spin；`cone` / `boomerang` → slash；
- `dash` / `blink` / `backstep` → charge；`leap` → none（保留原来的整段跳跃）；
- `heal` / `shield` / `heal_zone` → pray；`fear` / `taunt` → roar；
- `spin` → spin；`vanish` → crouch；其余远程 → cast。

### 表现

- 旋转类：根节点按 `TAU × 2.2`（大招）/ `1.2`（小技能）连续旋转，双臂展开，
  结束时刚好回到原朝向；同时轻微离地 + 尾巴甩动。
- 跳砸/跺地：两段式抬身→砸下，落地压扁 `sy`，手臂从高举切到前砸；
  带位移的跳跃大招不重复叠加高度，直接用原有跳跃。
- 前冲：身体前倾 + 手臂后摆；施法：轻微离地 + 双手前推；
  挥砍：躯干扭转 + 右臂横扫；吼叫：后仰 + 张臂；祈祷：离地 + 双手上举；
  蹲伏：压扁 + 收臂；俯冲：前倾 + 展臂。
- 阿狮「旋风爪」去掉三根高大黄色风柱，只留贴地环、旋转爪痕与竖向风条，
  让旋身动作露出来。

## 验收

- [x] `CAST_OK`：20 人 × 3 技能 = 60 条全部映射到合法动作，12 种动作都出现；大招不允许 none
- [x] `HEROES_OK`：每次 `try_cast` 后 `cast_index/cast_kind` 与技能一致
- [x] 桌面逐帧：阿狮 `--ult` 能看到 2.2 圈旋身；阿岳 `--ult` 能看到跳跃砸地
- [x] 模拟器 5v5 跑通，0 条脚本错误
- [x] `SIM_OK` / `FLOW_OK`；不改技能数值、不改 `battle_sim` 的纯逻辑边界（只加表现字段）
