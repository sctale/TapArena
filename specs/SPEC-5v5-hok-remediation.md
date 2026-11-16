# SPEC — 5v5 模式与全英雄技能整改（含王者荣耀式地图）

- 版本目标：`4.10.0-dev.1`（新功能，次版本号 +1；versionCode 48）
- 审计基线：commit `157b45b`（4.9.0-dev.1），2026-11-16
- 范围：仅 Godot 主线 `godot/`；3v3 玩法与节奏冻结不变；Web/Unity 存档不碰
- 版权边界：借鉴 MOBA 品类的通用布局（对角三路、河道、野区四象限、打野位），
  **不复制王者荣耀的具体美术、英雄名称、数值与文案**；所有模型/图标/音效继续项目自制。

---

## 0. 审计证据（本 SPEC 的事实基础）

无头探针实测（临时脚本已删除，复现方法见 §5）：

| # | 证据 | 结论 |
|---|------|------|
| E1 | 6 局 5v5（seed 11–66，挑战难度）：野怪击杀 蓝 7–17 / 红 15–23，全部来自路过顺带攻击 | AI 没有打野行为，野区是装饰 |
| E2 | 6 局蓝方阵容全部为 fox+turtle+rabbit+hedgehog+deer | `take_preferred` 确定性优先级 → 队友阵容每局完全一样 |
| E3 | 拆上路蓝塔后，三路蓝药剂全部停刷（活跃数 0，期望 2） | `step_potions` 守卫只查 `towers_blue[0]`（battle_sim.gd:555） |
| E4 | 狼嚎对塔生效：塔 hp 2600→2565，`mark_t=4.5` | `mark` 无单位类型过滤（battle_sim.gd:2420） |
| E5 | 再生水域中心距敌人 0、距自己 300 | 治疗区放在敌人脚下（battle_sim.gd:2497） |
| E6 | 陷阱延时 0.7s，目标以 250/s 移动后掉血 0 | 陷阱对移动目标必空（battle_sim.gd:2476） |
| E7 | 英雄复活后 spin_t=2.0 / mark_t=2.98 / fear_t=0.98 | `respawn` 不清差异化状态（battle_sim.gd:1954） |
| E8 | 简单/挑战各 3 局：2 局拆光双方全部塔后仍拖到 300s 超时 | 水晶攻坚停滞：水晶 120 攻/400 射程压制近战 |
| E9 | 代码走查：地图为三条平行横线（y=320/800/1280），视图按平均 y 画整幅横条（battle_view.gd:146–162），小地图同理（hud.gd:841–850） | 与王者荣耀式对角地图完全不符 |
| E10 | 代码走查：`front_structure`/追击限制/`clamp_to_front`/塔前 standoff 全部用 x 坐标比较（battle_sim.gd:1469、1299、1506、2535、1321） | 换成折线/竖直路后这些逻辑全部失效，必须先重构 |

---

## 1. 问题清单（按优先级）

### P0 — 功能性 bug（必须修）

| ID | 问题 | 位置 |
|----|------|------|
| B1 | 5v5 药剂守卫只查第一座塔：拆任意一路塔导致三路药剂全停；拆中/下路塔反而不影响本路药剂 | battle_sim.gd:554–559 |
| B2 | 复活不清 spin/mark/fear/taunt：复活后继续旋身、带着标记和恐惧 | battle_sim.gd:1954–1965；respawn_jungle:517 同样不清 mark |
| B3 | 兵线加速写死 `clock >= 240`，5v5 的「最后 45 秒」实际是 255s 触发，播报与行为相差 15s | battle_sim.gd:982 |
| B4 | 嘲讽只改 `ai_target`，普攻仍打最近敌人 → 嘲讽目标不是最近时完全失效 | battle_sim.gd:1292–1294 vs 1137–1146 |
| B5 | 狼嚎标记可打在塔/水晶上，塔被标记后承受 ×1.22 伤害（含小兵 2.4 倍结构伤害） | battle_sim.gd:2420–2428 |
| B6 | 刺刺回旋尖刺 `count:3` 未实现，只扔一把；数据与行为不符 | battle_sim.gd:2025–2047，heroes.json:716 |
| B7 | 灰灰「猎影突袭」文案说跳到敌人身后，实际落在目标正身上 | battle_sim.gd:2342–2343，heroes.json:862 |

### P1 — 设计缺口（本次需求核心）

| ID | 问题 |
|----|------|
| D1 | 地图是三条平行横线，没有对角布局、河道、野区象限（用户明确要求模仿王者荣耀式地图） |
| D2 | 没有打野位：`ai_target` 直接跳过 JUNGLE（battle_sim.gd:1493），wolf 的 role=打野 却和所有人一样分路 |
| D3 | 6 个营地数值完全相同，没有 buff 差异（王者荣耀式红蓝 buff/河道蟹收益区分） |
| D4 | 野怪击杀经验只给击杀者，无助攻经验；与英雄/小兵击杀规则不一致（battle_sim.gd:1895–1903） |
| D5 | 蓝方队友阵容每局固定（E2），5v5 重开价值低 |
| D6 | 再生水域落在敌人脚下，队友几乎吃不到治疗（E5） |
| D7 | 陷阱对移动目标必空（E6），火火二技能等于没有 |
| D8 | 恐惧期间仍普攻、且恐惧自带的减速让「吓退」变成慢走（fear 施加 slow 0.8，move_ai 再乘 0.55） |
| D9 | 刺刺基础属性与尖尖完全相同（hp820/dmg46/range540/atk0.62/speed252），二技能同为护盾（0.26/3.5s/cd14）——差异化需求未闭环 |
| D10 | 5v5 终极对决（180s）后 `is_tower_protected/is_base_protected` 直接返回 false，三路塔全活着也能直扑水晶，分路结构在 3 分钟后失效 |
| D11 | 水晶攻坚停滞（E8）：5v5 水晶沿用 3v3 的 120 攻/400 射程，近战拆水晶必死循环 |
| D12 | 5v5 巨兽用 `front_structure(team)`（lane_id=-1）按 x 选塔，会从基地斜穿去别路；新地图下必须锁定中路 |

### P2 — 数据卫生与数值入表

| ID | 问题 |
|----|------|
| H1 | 硬编码数值违反「数值放 data/*.json」：标记增伤 1.22（:1835）、链式衰减 0.82（:2407）、旋身 tick 0.30/knock 14/slow 0.35（:1249–1250）、巨兽击杀经验 90（:1911）、反伤 24+5×level（:1842）、恐惧移速 1.15（:1261） |
| H2 | heroes.json 死字段：刺刺 spin 的 count/speed、火火 trap 的 shield_pct/buff_t、小白 beam 的 count/speed/pierce、绒绒 heal_zone 的 count/delay |
| H3 | AI 新技能全走 `_` 兜底分支（battle_sim.gd:1417），spin/fear/mark 没有 `range` 字段 → 用默认 260 判定，与实际半径 150/210/270 不符，经常空放 |
| H4 | 小白 beam cd 5s：620 射程贯穿+治疗，消耗频率高于所有同类技能 |

---

## 2. 整改设计 A：王者荣耀式地图（D1、E9、E10、D12）

### 2.1 几何定义（全部进 `data/rules.json`，脚本不写死坐标）

5v5 改用 **2400×2400 正方形战场**，蓝方左下、红方右上，180° 旋转对称
（对称映射 `(x,y) → (2400-x, 2400-y)`）。3v3 地图（3000×1600 单横路）完全不动。

`mode_5v5` 增加：

```json
"mode_5v5": {
  "team_size": 5, "match_cap": 300.0, "sudden_death_time": 180.0,
  "base_open_towers": 1,
  "map_w": 2400, "map_h": 2400,
  "keep_protection_in_sudden_death": true
}
```

`lanes_5v5` 替换为三条折线（每路 7 点，保持 `path[2]`=蓝塔、`path[4]`=红塔、
`path[1]`/`path[5]`=药剂的现有约定）：

```json
"lanes_5v5": [
  [[360,2040],[300,1500],[300,900],[300,300],[900,300],[1500,300],[2040,360]],
  [[360,2040],[700,1700],[1000,1400],[1200,1200],[1400,1000],[1700,700],[2040,360]],
  [[360,2040],[900,2100],[1500,2100],[2100,2100],[2100,1500],[2100,900],[2040,360]]
]
```

- 上路：沿左边竖直北上 → 沿顶边水平东进（蓝塔 (300,900)，红塔 (900,300)）。
- 中路：对角直线（蓝塔 (1000,1400)，红塔 (1400,1000)）。
- 下路：沿底边水平东进 → 沿右边竖直北上（蓝塔 (1500,2100)，红塔 (2100,1500)）。
- 上/下路长约 3480，中路约 2400，符合「边路长、中路短」的 MOBA 常识。

基地：`setup` 中 5v5 分支改为 `base_blue=(360,2040)`、`base_red=(2040,360)`
（坐标同样放 `mode_5v5.base_blue/base_red`，不写死在脚本）。

河道（新增 `river_5v5`）：与中路垂直的对角带，中心线 `[[450,450],[1950,1950]]`，
宽 260。中路与河道交点 (1200,1200) 即地图中心。

野区营地（替换 `jungle`，6 个，旋转对称）：

```json
"jungle": [
  {"kind":"boar","pos":[620,1200]},  {"kind":"boar","pos":[1780,1200]},
  {"kind":"wolf","pos":[1200,1750]}, {"kind":"wolf","pos":[1200,650]},
  {"kind":"crab","pos":[950,950]},   {"kind":"crab","pos":[1450,1450]}
]
```

几何约束（写成测试断言，见 §5 A1）：
- 每个营地到任一兵线折线距离 ≥ 220；到河道中心线距离：野猪/灰狼 ≥ 300，河蟹 ≤ 130（河蟹必须在河道里）。
- 营地关于地图中心旋转对称；蓝方半场（x+y<2400 且 y>x 象限等）各 2 个，河道 2 个。

### 2.2 核心重构：x 坐标逻辑 → 兵线进度逻辑（E10，先于一切地图改动）

新增两个纯函数（battle_sim.gd，不引用节点）：

```gdscript
# 点在折线上的累计进度（投影到最近线段，返回从蓝方起点起的弧长）
func lane_progress(lane_id: int, p: Vector2) -> float:
	var path: Array = lane_paths[lane_id] if five_v_five and lane_id < lane_paths.size() else lane
	var acc := 0.0
	var best := 1.0e20
	var best_s := 0.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var ab: Vector2 = b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var proj: Vector2 = a + ab * t
		var d: float = proj.distance_to(p)
		if d < best:
			best = d
			best_s = acc + ab.length() * t
		acc += ab.length()
	return best_s

# 折线上指定进度处的点（供 clamp_to_front / 塔前 standoff 用）
func point_at_progress(lane_id: int, s: float) -> Vector2:
	# 沿 path 累计弧长，落在哪段就线性插值；s 超出两端时钳到端点
```

逐处替换（行号为基线）：

| 位置 | 现状 | 改法 |
|------|------|------|
| `front_structure` :1458 | 按 `pos.x` 最小/最大选塔 | 同队同路存活塔中，BLUE 取 `lane_progress` 最小、RED 取最大；`lane_id=-1` 时遍历全部塔用各自路的进度归一化比较（3v3 横路下与旧行为等价） |
| 追击限制 :1298–1302、:1505–1509 | `o.pos.x > front.pos.x + 20` | `lane_progress(o.lane_id, o.pos) > lane_progress(front.lane_id, front.pos) + 20`（仅同路比较；跨路目标用 320 距离规则，维持现状） |
| `clamp_to_front` :2528 | 钳 dest.x | 若 `lane_progress(h.lane_id, dest) > front_progress - keep`，则 `dest = point_at_progress(h.lane_id, front_progress - keep)` |
| 塔前 standoff :1321、:1335 | `front.pos + Vector2(±1,0)*(range+100)` | `point_at_progress(lane, front_progress - (front.attack_range + tower_standoff))` |
| `step_boss` :689/:703/:709 | `front_structure(u.team)` 全图按 x | 5v5 固定 `front_structure(u.team, 1)`（中路）；移动改为沿中路 waypoints 推进（复用 `lane_index`，逻辑照抄 `step_minion` :1631–1645），不再直线穿野区 |
| `spawn_boss` :606 | 基地旁 ±190 | 5v5 出生点 = 中路河道交点偏向领先方一侧 200（`point_at_progress(1, mid_progress ± 200)`），播报不变 |

`step_minion` 已是折线寻路（:1632–1645），**无需改动**，新几何直接生效。
`move_to`/`separate_units` 用 `map_w/map_h` 钳位，setup 读 `mode_5v5.map_w/h` 后自动生效。

### 2.3 表现层（battle_view.gd / hud.gd）

1. **路面**：删除「平均 y 横条」画法（:146–162）。改为沿每条 path 的每个线段铺
   宽 190 的 PlaneMesh 四边形（位置=线段中点，`rotation.y = -atan2(dy,dx)`，
   长度=线段长+190 以覆盖拐角接缝），材质沿用 `_tiled_material("path", …)`，
   UV 按线段长度平铺。拐角处额外铺一个 190×190 方块补缝。
2. **路缘石**：`_build_lane_curb`（:190–205）改为沿折线两侧 ±118 按 56 间距摆块
   （对每段按方向向量布点，拐角去重：相邻段端点 60 内不重复放）。
3. **装饰排除**：`_near_lane`（:183）改为「点到折线距离 < margin」；
   树木/石头撒点（:248、:273） additionally 排除河道带（点到河道中心线距离 < 200）。
4. **河道**：沿 `river_5v5` 中心线铺宽 260 的浅蓝水面四边形（自制像素水纹材质，
   复用现有 water 系贴图风格），略低于路面 y=0.3；两端各放一组自制芦苇方块。
   河蟹营地视觉上位于水面。
5. **野区**：四象限地面用稍深草色拼块（PlaneMesh 四边形即可，不引入新贴图），
   营地旁放自制灌木/蘑菇方块标识；营地模型沿用 `BlockModels.jungle_monster`。
6. **小地图**（hud.gd:841–850）：横条改为折线（`draw_polyline`，宽 3px），
   河道画一条浅蓝对角线；单位点/塔点/药剂点逻辑不变（已按 map_w/h 归一化，
   正方形地图自动正确）。小地图外框保持正方形比例。
7. **相机**：camera_rig 无机位钳位、只跟随玩家，无需改动；用 `--top` 俯瞰验收全图。

### 2.4 首页与播报

- home.gd 5v5 详情 tip 文案更新为「对角三路 · 河道野区 · 打野游走」。
- 开场播报（battle_sim.gd:416）改为「三路推进 → 拆掉两座塔，就能进攻敌方水晶！」保持不变（规则没变）。
- 分路分配见 §3.1（打野位出现后，开场播报追加一句「灰灰去野区打野了！」仅当队伍有打野）。

---

## 3. 整改设计 B：野区生态（D2–D4）

### 3.1 打野位与分路

`setup` 的分路逻辑（:402–411）改为**按 role 分配**：

- 玩家固定中路（lane_id=1）。
- 队友/对手各按 role 填位：1 个坦克/战士走上路，1 个射手/法师走下路，
  1 个辅助跟随打野（前 60s）或守中，**role=打野 的英雄（wolf）进野区**（`lane_id=-2` 标记为打野位）。
- 队伍里没有打野 role 时，取刺客（hedgehog）顶替；都没有则维持 2-2-1。
- 新增 `Unit.is_jungler: bool`；`make_hero` 按分配结果设置。
- 红方用同一套 role 分配（不再拿蓝方挑剩的前 5 个）。

### 3.2 打野 AI（step_hero_ai 顶部新增分支）

```
if h.is_jungler and not retreat:
    1. .clock < 60 或 level < 2：
       目标 = 己方半场按路线顺序的下一个存活营地（路线：本方野猪→本方灰狼→河道蟹→对方半场蟹）
       没有存活营地时原地等刷新（不越塔、不送线）
       移动到营地并普攻（nearest_enemy 已含 JUNGLE，无需改攻击逻辑）
    2. level >= 2 且 clock >= 60：
       游走 gank —— 选「敌方英雄最多且己方塔还在」的一路，临时 lane_id=该路，
       走正常 ai_target 逻辑 20s，然后回野区
    3. 恐惧/嘲讽/撤退规则照常覆盖打野分支
```

营地路线顺序放 `rules.json` 的 `jungle_route`（按 kind+半场过滤），不写死坐标。

### 3.3 营地差异化 buff（王者荣耀式收益区分）

`jungle_stats` 改为按 kind 覆盖 + buff 字段：

```json
"jungle_stats": {
  "hp": 650, "dmg": 26, "range": 110, "atk_interval": 1.1,
  "respawn": 45, "xp": 90, "heal_pct": 0.12,
  "kinds": {
    "boar": {"xp": 90, "heal_pct": 0.08},
    "wolf": {"xp": 110, "buff": {"dmg_pct": 0.10, "duration": 20, "label": "猎狼增益"}},
    "crab": {"xp": 70, "buff": {"speed_pct": 0.15, "duration": 12, "label": "迅捷蟹增益"}}
  }
}
```

- Unit 新增 `buff_dmg_t/buff_dmg_pct/buff_speed_t/buff_speed_pct`；`step_unit` 每帧递减。
- `deal_damage`：`if src != null and src.buff_dmg_t > 0: amount *= 1.0 + src.buff_dmg_pct`。
- 移动速度：`move_ai`、玩家移动、`_step_move_skill` 统一乘 `1.0 + buff_speed_pct`（抽一个 `speed_of(u)` 辅助函数，三处共用）。
- `kill` JUNGLE 分支：按 kind 读配置发经验/回血/buff，float_text 显示「获得猎狼增益！」；
  **助攻经验**：击杀者 700 范围内同队存活英雄得 `xp × 0.5`（对齐小兵助攻规则）。
- 增益对打野位 AI 的决策加权：有 buff 时 gank 倾向提前（clock ≥ 45 即可游走）。

### 3.4 野怪状态清理

`respawn_jungle`（:517）补清 `mark_t/fear_t/taunt_t/spin_t` 与 buff 字段。

---

## 4. 整改设计 C：技能与通用机制修复

### 4.1 通用机制（按英雄无关）

| ID | 修改方法 |
|----|----------|
| B1 | `Potion` 增加 `guard` 引用字段；`make_potion(team, pos, guard_tower)` 创建时传入本路塔（3v3 传外塔）。`step_potions` 用 `p.guard` 判活，删除 `towers_blue[0]` 硬查 |
| B2 | `respawn`（:1954）补：`spin_t=0, spin_tick=0, mark_t=0, fear_t=0, fear_src=null, taunt_t=0, taunt_src=null, buff_*=0` |
| B3 | :982 改 `if clock >= match_cap - 45.0:`（与 final_push 同条件） |
| B4 | `step_hero` 普攻块（:1137）：`var target = nearest_enemy(...)` 改为——若 `h.taunt_t>0` 且 taunt_src 存活且在攻击距离内 → 打 taunt_src；否则若 `h.ai_target` 存活、非保护建筑、在攻击距离内 → 打 ai_target；否则最近敌人。玩家手动移动时同样生效（普攻是自动的） |
| B5 | `mark` 分支（:2420）加 `if u.kind == TOWER or u.kind == BASE: continue`；`deal_damage` 的 ×1.22 改读 `rules.combat.mark_amp`（默认 1.22） |
| D8 | fear 施加时**不再给被恐惧英雄上 slow**（:2458 对 HERO 跳过 slow）；`move_ai` 恐惧分支速度系数改读 `rules.combat.fear_speed`（1.15），且恐惧期间忽略 `slow_t`（`slow_k = 1.0 if h.fear_t > 0 else …`）。被恐惧英雄不再普攻：`step_hero` 普攻块顶部 `if h.fear_t > 0: return`（仅 AI；玩家被恐惧时同样禁止普攻 1.25s，保持公平） |
| D10 | `is_tower_protected/is_base_protected`（:2079/:2091）：`if sudden_death and not five_v_five: return false`；5v5 终极对决只保留 `sudden_death_structure_mul` 伤害放大，保护层级持续有效（`keep_protection_in_sudden_death` 配置开关，默认 true） |
| D11 | `base` 增加 `dmg_5v5: 90, range_5v5: 360`；`make_base` 按模式读取（与 tower 的 hp_5v5/dmg_5v5 同构） |
| H1 | 新增 `rules.combat`：`mark_amp 1.22 / chain_falloff 0.82 / spin_tick 0.30 / spin_knock 6 / spin_slow 0.35 / fear_speed 1.15 / boss_kill_xp 90 / thorn_base 24 / thorn_per_level 5`；对应脚本位置全部改读配置。旋身 knock 14→6（每 tick 把人推出半径是自我削弱） |
| H3 | `step_hero_skills` 为 spin/fear/mark/taunt/heal_zone/trap/boomerang/beam/chain/blink 增加显式分支：判定半径用 `s.get("radius", s.get("range", 260))`；heal_zone 条件 = 自身或 380 内队友 hp<0.7；taunt 条件 = 230 内 ≥1 敌方英雄；spin 条件 = 半径内 ≥2 敌人或 hp<0.5 且 ≥1 |

### 4.2 逐英雄修改表

| 英雄 | 技能 | 问题 | 具体修改 |
|------|------|------|----------|
| 刺刺 hedgehog | 基础属性 | 与尖尖完全相同（D9） | heroes.json：hp 820→900、dmg 46→62、range 540→170（近战刺客）、atk_interval 0.62→0.58、move_speed 252→285；普攻弹道风格改近战（`hero_shot_style` 不受影响，range≤250 自动走近战 hit_with_fx） |
| 刺刺 | 二技能 缩成刺球 | 与尖尖炸毛护盾 identical（D9） | 换成新机制 `vanish`（尖刺伏击）：0.8s 无敌 + 移速 +30%，结束后 2s 内下一次普攻伤害 ×1.8。实现：Unit 加 `vanish_t/ambush_t`；cast 分支设 `invuln_t=0.8, vanish_t=0.8, buff_speed_pct=0.3, buff_speed_t=0.8`；`step_unit` 递减 vanish_t，结束时 `ambush_t=2.0`；`hit_with_fx` 中 src.ambush_t>0 时 amount×1.8 并清 ambush_t；fx 用现有 `burst`+半透明提示 float_text「伏击！」；AI 分支：enemy_hero_near(300) 且 hp<0.65 时使用。cd 14、数值进 heroes.json |
| 刺刺 | 一技能 回旋尖刺 | count:3 未实现（B6） | `_throw_boomerang` 外层按 `s.get("count",1)` 循环，方向 ±0.14rad 扇形展开；三把回旋镖各自独立 hit 表 |
| 刺刺 | 大招 滚动刺球 | 死字段 count/speed（H2） | 删除；knock 改读 rules.combat.spin_knock=6 |
| 灰灰 wolf | 大招 猎影突袭 | 落点与文案不符（B7） | leap 分支：wolf 的 dest = `target.pos + (target.pos - h.pos).normalized() * 90`（穿过目标落到身后）；用技能字段 `"behind": 90` 驱动，不写死英雄 id；AI clamp_to_front 照常 |
| 灰灰 | 二技能 猎杀标记 | 打塔（B5）+ 增伤硬编码 | 见 B5/H1；半径 270 补 `"range": 270` 供 AI 判定 |
| 火火 redpanda | 二技能 竹叶陷阱 | 移动目标必空（D7）+ 死字段 | 落点预判：`trap_pos = target.pos + target.move_dir * target.move_speed * delay * 0.8`（目标静止则原地）；delay 0.7→0.55、radius 130→150；删 shield_pct/buff_t；预判系数进 `rules.combat.trap_lead: 0.8` |
| 绒绒 axolotl | 大招 再生水域 | 落在敌人脚下（D6）+ 死字段 | 目标改为「380 内血量比例最低的存活队友（含自己）」，没有则放自己脚下；删 count/delay；heal_pct 0.045 保持 |
| 小白 crane | 二技能 鹤羽贯日 | cd 过短（H4）+ 死字段 | cd 5→6.5；删 count/speed/pierce；width 42 保持 |
| 甲甲 turtle | 二技能 潮汐嘲讽 | 嘲讽不强制普攻（B4） | 见 B4；taunt_time 1.8 保持 |
| 阿狮 tiger | 二技能 震慑咆哮 | 恐惧机制矛盾（D8） | 见 D8；fear_time 1.25 保持 |
| 其余 7 英雄 | — | 审计未发现机制 bug | 不动机制；仅随 H1 把共用常量改读配置 |

### 4.3 阵容多样性（D5）

`take_preferred`（:446）改为**角色约束下的随机**：
- 蓝方 4 队友按槽位角色需求（前排×1、治疗/辅助×1、输出×2）从池中随机抽取；
  池先按 role 分桶，桶内 `rng.shuffle` 后取第一个。
- 红方同规则独立抽取（先抽红方再抽蓝方，避免蓝方挑剩）。
- 验收：10 个 seed 产生 ≥5 种不同蓝方阵容（§5 C1）。

---

## 5. 验收项目与验收标准

所有自动化断言写进 `godot/tests/sim_headless.gd`（新增 MAP_OK / JGL_OK / FIX_OK 三类输出），
命令统一：

```powershell
godot --headless --path godot --script res://tests/sim_headless.gd   # SIM_OK + RULE_OK + SIG_OK + MAP_OK + JGL_OK + FIX_OK
godot --headless --path godot --script res://tests/flow_headless.gd   # FLOW_OK（含 5v5 分支，维持现状）
```

### A 组：地图（对应 §2）

| 编号 | 验收项 | 验收标准（自动化） |
|------|--------|--------------------|
| A1 | 几何合法性 | MAP_OK：三路各 ≥7 点；每路蓝塔=路径进度 30–45% 处、红塔 55–70% 处；营地到兵线距离 ≥220；河蟹在河道带内（到中心线 ≤130）、野猪/灰狼 ≥300；全部坐标关于 (1200,1200) 旋转对称（容差 1） |
| A2 | 进度函数正确性 | MAP_OK：`lane_progress` 对折线端点返回 0/全长（误差 <1）；`point_at_progress(lane_progress(p)) ≈ p`（对路径上的点，误差 <2）；3v3 横路上 front_structure 结果与旧 x 逻辑逐 seed 一致 |
| A3 | 小兵沿折线推进 | 5v5 无头 30s：三路都有小兵；上路出现 x<430 且 y<1450 的小兵（走了左侧竖直段），下路出现 y>1970 且 x>1500 的小兵（走了下侧水平段） |
| A4 | AI 不越塔 | 5v5 无头 120s：任一英雄对「进度超过敌方前塔 +60」的敌方建筑造成伤害次数 = 0（deal_damage 保护拦截计数） |
| A5 | 位移钳位 | AI 灰灰/灵灵在敌塔存活时释放 leap/blink/dash 后，自身进度 ≤ 前塔进度（抽样 20 次全部成立） |
| A6 | 巨兽走中路 | 5v5 触发巨兽后 30s 内，巨兽到中路折线距离 ≤200；攻击目标塔 lane_id=1 |
| A7 | 视觉（人工+录屏） | `--top --mode=5v5 --write-movie` 俯瞰帧：可见对角三路+河道+四象限野区，路面无横条残留、拐角无缝；小地图折线与主图一致；`--mode=5v5` 正常视角 25s 无 SCRIPT ERROR。录屏存 shots/ 逐帧核对（AGENTS §5 要求） |

### B 组：野区生态（对应 §3）

| 编号 | 验收项 | 验收标准 |
|------|--------|----------|
| B1 | 打野位存在 | JGL_OK：双方各恰 1 名 is_jungler；有 wolf 时必为 wolf |
| B2 | 打野行为 | 5v5 无头 90s：打野英雄击杀营地 ≥3；前 60s 至少 50% 采样离兵线 >200（跨野区转场必然经过兵线），且非恐惧/嘲讽状态下从不进入敌方半场；60s 前到 2 级 |
| B3 | buff 生效 | JGL_OK：杀灰狼营后 killer.buff_dmg_t≈20 且 deal_damage 实测 ×1.10（±1%）；杀河蟹后移速实测 ×1.15（±1%）；buff 到期归零 |
| B4 | 助攻经验 | JGL_OK：击杀者 700 内队友获得 xp×0.5（±1），700 外不得 |
| B5 | 营地刷新 | 击杀后 45s（±0.5）满血复活于原坐标，mark/buff 清零 |
| B6 | 对局节奏 | 10 个固定 seed（11,22,…,110）5v5 挑战难度：平均时长 180–280s；超时局 ≤2；双方合计拆塔 ≥4 的局 ≥7 |

### C 组：技能与机制修复（对应 §4）

| 编号 | 验收项 | 验收标准（FIX_OK 断言） |
|------|--------|------------------------|
| C1 | 阵容多样性 | 10 seed 蓝方阵容去重 ≥5 种；每队 ≥1 前排 + ≥1 治疗/辅助 |
| C2 | 药剂守卫 | 拆上路蓝塔后：上路蓝药剂停刷、中/下路蓝药剂仍活跃（复现 E3，期望活跃数=2）；3v3 行为不变 |
| C3 | 复活清状态 | 复现 E7：复活后 spin/mark/fear/taunt/buff 全 0 |
| C4 | 兵线加速时机 | 5v5 clock=250 时 wave_gap=18；clock=256 时 wave_gap=9（3v3 为 240/241 切换，不变） |
| C5 | 嘲讽强制普攻 | 构造「被嘲讽者身边有更近的小兵」场景：嘲讽期间普攻伤害全部落在甲甲身上（小兵掉血=0） |
| C6 | 标记不打塔 | 复现 E4：狼嚎后塔 hp 不变、mark_t=0；范围内英雄/小兵 mark_t=4.5；被标记英雄实测承伤 ×1.22（±1%） |
| C7 | 陷阱命中 | 复现 E6 场景（目标 250/s 垂直移动）：预判后掉血 >0；10 次随机方向移动命中 ≥6 |
| C8 | 再生水域位置 | 复现 E5：水域中心距「最残血队友或自己」≤60，距任何敌人 >150（除非敌人恰好贴脸队友） |
| C9 | 恐惧行为 | 被恐惧英雄 1.25s 内普攻次数=0、位移方向远离施法者、实测移速 ≥ 基础×1.1（不被减速拖累） |
| C10 | 回旋尖刺 ×3 | 一次施法产生 3 个 boom 弹体；静止目标去程+回程各命中一次（总伤=2×dmg×3 把内实际命中数） |
| C11 | 狼跃身后 | 灰灰大招落点在目标背向灰灰一侧 90（±10） |
| C12 | 刺刺差异化 | heroes.json 断言：hedgehog 与 cat 的 hp/dmg/range/atk_interval/move_speed 至少 4 项不同；hedgehog 二技能 kind=vanish；vanish 期间无敌（invuln 生效）且结束后首击 ×1.8 |
| C13 | 终极对决保护 | 5v5 clock=181 且三塔全活：水晶仍受保护（deal_damage 拦截）；拆到剩 1 塔后水晶可被攻击且承伤 ×2.4 |
| C14 | 水晶攻坚 | 复现 E8 场景（双方塔全拆）：10 seed 中 ≤1 局拖到 300s 超时 |
| C15 | 数值入表 | 断言：`deal_damage` 的标记增伤、`chain` 衰减、`_step_spin` 的 tick/knock/slow、`kill` 的巨兽经验、反伤公式、恐惧移速系数全部来自 `rules.combat`（构造改配置值后行为随之变化的对照测试，各 ±1%）；heroes.json 无 H2 所列死字段 |
| C16 | 既有回归不回退 | SIM_OK（10 局 3v3）、RULE_OK、SIG_OK（十机制）、FLOW_OK 全绿；3v3 十局平均时长与基线差 ≤15% |

### D 组：交付闭环（AGENTS §3/§5）

| 编号 | 验收项 | 验收标准 |
|------|--------|----------|
| D1 | 构建 | `tools/godot-build.ps1 -VersionCode 48` 全绿；根目录 `TapArena-v4.10.0-dev.1.apk` |
| D2 | 包校验 | aapt2：包名 com.sctale.taparena / versionCode 48 / versionName 4.10.0-dev.1 / arm64-v8a；apksigner：CN=TapArena；Get-FileHash 回填 README |
| D3 | 真机/模拟器 | Android 模拟器（-gpu host）覆盖安装：首页→5v5 开局日志 `mode=5v5`；新地图渲染无 shader/SCRIPT ERROR；小地图折线可见；打野英雄可见刷野；5v5 帧率 ≥24fps |
| D4 | 发布 | git push + Release v4.10.0-dev.1，资产名与根目录 APK 一致，下载哈希与本地一致 |
| D5 | 文档 | CHANGELOG 新条目（为什么这么改）；README 更新地图/野区/英雄描述与 APK 信息；AGENTS.md §6 同步「对角三路+河道野区+打野位」表述（塔数规则不变，无需改保护层级条款） |

---

## 6. 实施顺序（依赖关系）

1. **阶段 1｜进度重构**（§2.2）：lane_progress/point_at_progress + 六处替换。
   门槛：A2 + C16（3v3 完全等价）先绿，再动几何。
2. **阶段 2｜新地图数据与表现**（§2.1/2.3/2.4）：rules.json 新几何 + 视图折线路面/河道/小地图。
   门槛：A1、A3–A7。
3. **阶段 3｜野区生态**（§3）：打野位分配 + 打野 AI + buff + 助攻经验。
   门槛：B1–B6。
4. **阶段 4｜技能修复**（§4）：B1–B7、D6–D11、H1–H4、刺刺重做。
   门槛：C1–C15。
5. **阶段 5｜平衡复测与交付**（§5 D 组）：10 seed 复测 → 构建 → 模拟器 → 发布 → 文档。

每阶段结束跑全量无头回归；阶段 2/4 涉及视觉，必须 `--write-movie` 录屏核对。
同一问题修两轮仍失败 → 停止猜测，参照 `step_minion` 的既有折线寻路实现照做（AGENTS 硬规则）。

## 7. 风险与回滚

- **最大风险**：x→进度重构波及 AI 追击/位移钳位/巨兽，3v3 可能被误伤。
  对策：阶段 1 单独提交，C16 的 3v3 等价断言不过不进阶段 2；回滚 = revert 该提交。
- **性能**：lane_progress 每帧对每英雄调用（O(路径段数)=6），10 英雄×60Hz 可忽略；
  视图折线路面为静态网格，一次性构建。若模拟器 5v5 帧率 <24fps，先降路缘石密度（56→84 间距）。
- **平衡**：新地图路长变化（边路 +40%）会拉长游走时间，B6 的 10 seed 门槛兜底；
  不达标时优先调 `wave_interval`（18→16）与打野 gank 时机，不动塔/水晶血量。
- **规则冲突**：本 SPEC 不改「每方 3 塔、拆 2 开水晶」与 3v3 节奏（AGENTS §6 冻结项）；
  D10 的 5v5 保护持续化是新增配置开关，3v3 行为逐位不变。