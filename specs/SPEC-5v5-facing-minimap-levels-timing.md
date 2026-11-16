# SPEC — 角色朝向、小地图比例、5v5 五级成长与 8 分钟对局

- 版本目标：`4.11.0-dev.1`（新功能，次版本号 +1；versionCode 49）
- 基线：commit `c980494`（4.10.0-dev.1），2026-11-17
- 范围：仅 Godot 主线 `godot/`；**3v3 玩法、节奏、数值、外观冻结不变**；Web 1.3 / Unity 存档不碰
- 需求来源（用户原话）：
  1. 人物当前不能斜着移动，感觉很奇怪 —— **已澄清：是角色朝向问题**，不是移动被锁轴
  2. 小地图显示的也不对；**追加：英雄和 BOSS 标识要明显，模仿王者荣耀式小地图**
     （借鉴品类通用标识语言：圆形英雄点、队伍色描边、史诗野怪大标记，不抄其具体图标美术）
  3. 5v5 等级可以到 5 级，升级会增加人物属性和技能强度
  4. 5v5 时长增加到 8 分钟，BOSS 5 分钟时才出来

---

## 0. 现状证据（代码走查，全部可在基线 commit 复核）

| # | 证据 | 结论 |
|---|------|------|
| E1 | 移动链路连续：`input_hub.gd:78/94` 摇杆 `move = d / joy_radius`（任意角度）→ `battle_sim.gd:1431-1438` `dir.normalized()` → `move_to` 只做边界钳位。**没有任何轴量化** | 斜向移动本身是通的 |
| E2 | 朝向只有左右两档：`battle_sim.gd:1436` `h.facing = 1.0 if dir.x >= 0 else -1.0`；视图 `battle_view.gd:704-705` `yaw = PI*0.5 - 0.34`，`root.rotation.y = ±yaw` | 模型永远面朝左/右。向上/向下/斜向走时身体横着滑行——用户看到的「不能斜着走」 |
| E3 | 小兵同样两档朝向（`battle_view.gd:804-805`）；巨兽同样（481-482）；野怪根节点**完全不转向**（443 只有身体摇摆） | 5v5  diagonal/L 形兵线上小兵全程横着走；野怪追击/回营也横着走 |
| E4 | 小地图把世界坐标直接线性映射进固定宽面板：`hud.gd:835-836` 面板 `w = safe.w*0.205, h = h*0.175`（2400×1080 横屏下约 492×189，≈2.6:1），而 5v5 地图是 2400×2400 正方形（`hud.gd:853-854/860-861`） | 正方形地图被横向拉伸 2.6 倍：45° 中路压成约 21° 浅斜线，距离/方位全部失真。单位点尺寸还是固定像素（4/5/7/9px），不随面板缩放 |
| E5 | 等级上限 2：`battle_sim.gd:2397` `if h.level >= 2: return`；升级只解锁大招（`unlock_at_2`），**没有任何属性成长**；HUD 经验条 `hud.gd:740` 在 ≥2 级后恒满 | 5v5 八分钟局里 2 级之后成长完全停滞 |
| E6 | 5v5 节奏：`rules.json` `mode_5v5.match_cap = 300`、`sudden_death_time = 180`；`battle_sim.gd:1261-1268` 终极对决与巨兽出场共用 `sudden_death_time` | 现在 3:00 出巨兽、5:00 结束；需求是 5:00 出巨兽、8:00 结束 |
| E7 | 技能伤害全部走 `cast()` 的 `var dmg := float(s.get("dmg", 0.0))`（`battle_sim.gd:2702`），但位移落地伤害另读 `s.get("dmg")`：dash `1512`、backstep `1531`、leap_land `3066+`；spin 的伤害在施法时存进 `h.spin_dmg` | 技能强度成长必须覆盖 cast 主变量 + 三处位移落地点；spin 随 cast 变量自动覆盖 |
| E8 | 难度加成 `enemy_dmg_mul` 在 `deal_damage` 层乘（`battle_sim.gd:2271-2272`），**不是**烘焙进 `u.dmg`；英雄基础值存在 `u.def`（`make_hero:1223`） | 升级时从 `def` 重算 hp/dmg 不会丢失难度加成，方案安全 |

---

## 1. R1 — 角色朝向跟随移动方向（含小兵/野怪/巨兽）

### 1.1 修改方法

**sim 层：新增表现用朝向向量 `face_dir`（不参与任何战斗逻辑）**

- `Unit` 增加字段 `var face_dir := Vector2.ZERO`。
- 规则：**现有每一处写 `facing` / `move_dir` 的地方同步写 `face_dir`**，`facing` 的 ±1 语义保留不动
  （boss 冲锋、backstep 等逻辑继续用 `facing`，零行为变化）。落点清单（实现时以 `grep "facing ="` 复核）：
  - 玩家移动 `battle_sim.gd:1435-1436` → `h.face_dir = dir`
  - 玩家/AI 普攻转向 `1461` → `h.face_dir = (target.pos - h.pos).normalized()`
  - 恐惧逃跑 `1584` → `h.face_dir = away_f.normalized()`
  - AI 移动 `move_ai:1706-1708` → `h.face_dir = dir`
  - 小兵移动 `2087-2088` → `m.face_dir = to`（小兵普攻转向处同理）
  - 施法 `cast:2697` → `h.face_dir = aim_dir`
  - 巨兽冲锋 `1180` → `u.face_dir = u.boss_charge_dir`；巨兽沿路移动（`_move_along_lane` 调用处）→ 路径切向
  - 野怪 `step_jungle` 追击/回营移动处 → 移动方向
- `respawn` / `respawn_jungle` 重置 `face_dir = Vector2.ZERO`（与 `move_dir` 同处）。

**view 层：连续偏航 + 指数平滑转身**

- `hero_nodes` / `minion_nodes` / `boss_nodes` / `jungle_nodes` 的 item 字典增加 `"yaw"`，
  初始值 = 旧公式 `±(PI*0.5 - 0.34)`（按初始 facing），保证开局外观与旧版一致。
- 每帧目标偏航（dir 取 `u.face_dir`，归一化；`face_dir` 为零时保持上一帧目标）：

  ```gdscript
  var yaw_target := atan2(dir.x, dir.y) - 0.34 * signf(dir.x) * (1.0 - absf(dir.y))
  item["yaw"] = lerp_angle(item["yaw"], yaw_target, 1.0 - exp(-12.0 * delta))
  root.rotation.y = item["yaw"]
  ```

  - `atan2(dir.x, dir.y)`：模型本地 +Z 为正面（与现有弹体朝向公式 `battle_view.gd:849` 一致）。
  - 第二项是**露脸偏置**：纯水平移动（dir.y=0）时偏置 = ∓0.34，与旧版 ±(90°−19.5°) **逐位相等**；
    纯竖直移动偏置 = 0（正对/背对镜头）；斜向按水平分量线性过渡。
    这样 3v3 横路外观完全不变，5v5 斜向/竖直移动时脸自然转向镜头侧。
  - 转身速率 12/s：95% 完成约 0.25s，无瞬移跳变；待机保持最后朝向。
- 替换四处硬编码两档 yaw：`battle_view.gd:704-705`（英雄）、`804-805`（小兵）、
  `481-482`（巨兽）、`443`（野怪：root 加 yaw，身体摇摆保留）。
- 攻击/施法期间（`atk_anim > 0` / `cast_anim > 0`）sim 已把 `face_dir` 指向目标，视图无需特判。

### 1.2 验收

| ID | 项目 | 标准 |
|----|------|------|
| A1 | 斜向移动+朝向（无头） | `player_move=(0.7,-0.7)` 走 60 步：Δx>0、Δy<0 且 \|Δx\|≈\|Δy\|（±5%）；`face_dir≈(0.707,-0.707)`（±0.01） |
| A2 | 四向偏航（视图探针/录屏） | 5v5 直线向上走 → \|yaw\|→PI（±0.1）；向下 → yaw→0（±0.1）；向右 → PI/2−0.34（±0.02）；向左 → −(PI/2−0.34)（±0.02）；右上 → 3PI/4 附近（±0.15） |
| A3 | 转身平滑 | 方向反转后 0.3s 内完成 95% 转身；逐帧 \|Δyaw\| 无 >0.7rad 的跳变 |
| A4 | 小兵/野怪 | 5v5 上路竖直段小兵 yaw≈0 或 PI（±0.15），不再恒为 ±PI/2；野怪移动时 root 有朝向 |
| A5 | 3v3 外观冻结 | 3v3 水平移动 yaw 与旧版 ±(PI/2−0.34) 差 ≤0.02；录屏对比无可见差异 |
| A6 | 真机/模拟器截图 | 斜向走位截图：身体长轴与移动方向一致（允许露脸偏置），交付四向对比图给用户确认 |

---

## 2. R2 — 小地图：真实比例 + 王者荣耀式醒目标识

### 2.1 比例修正（`hud.gd:_draw_minimap`，834-881）

- 可用外框不变（右上角，`w = safe.w*0.205`、`h = h*0.175`）。
- inner 按**地图宽高比适配**进外框并居中：

  ```gdscript
  var k := minf(box.size.x / sim.map_w, box.size.y / sim.map_h)
  var inner_size := Vector2(sim.map_w * k, sim.map_h * k)
  # inner 在 box 内居中；_panel(mini) 的面板尺寸改为 inner_size + 8
  ```

  - 5v5（2400×2400）→ 正方形内区（1080p 下约 181×181），面板随之变方。
  - 3v3（3000×1600）→ 1.875:1 内区（约 340×181），比旧版略窄但**比例首次正确**。
- 坐标映射公式不变（`p.x / map_w * inner.size.x`），只是 inner 不再被拉伸。
- 全局尺寸基准：`var u := inner.size.y / 180.0`，下述所有标记尺寸均乘 u，随面板缩放。

### 2.2 标识分级（模仿王者荣耀式小地图的通用语言，全部用现有 draw_*  helper 自绘）

现状问题：所有单位都是 4–9px 固定像素小方块，英雄/BOSS/塔/野怪混在一起无法一眼区分。
改为**形状 + 尺寸 + 描边**三级区分，绘制顺序即层级（后画的在上层）：

| 层 | 对象 | 形状与尺寸（×u） | 颜色/描边 |
|----|------|------------------|-----------|
| 1 | 兵线/河道 | 折线，宽度按 inner 比例（现状保留） | 棕 / 浅蓝 |
| 2 | 野怪营地 | 圆点 ⌀4 | 黄 `e2c46a`，弱存在感（现状保留） |
| 2 | 药剂 | 十字 8（现状保留，随 u 缩放） | 绿 |
| 3 | 防御塔 | **菱形** 对角 7 | 队伍色填充 + 深色描边 1.5（与英雄圆形区分） |
| 3 | 水晶 | 方块 10 + 外圈描边 | 队伍色（比塔更大更亮） |
| 4 | **英雄** | **圆点 ⌀11**（旧 5px 方块的 ~2.2 倍） | 队伍色填充 + 深色描边 1.5；敌红我蓝 |
| 5 | **BOSS** | **最大标记：圆点 ⌀20 + 金色双环**（外环 ⌀24，环宽 2） | 队伍色填充 + 金 `ffd76a` 双环；尺寸呼吸 1±0.08·sin(t·3) 吸引注意；≥1.7× 英雄点 |
| 6 | **玩家** | 英雄圆点之上叠**白/金双环**（外环 ⌀16，环宽 2）+ 朝向小三角（边长 6，指向 `face_dir`，复用 R1 字段；face_dir 为零不画） | 金 `ffd76a` 环 + 奶白三角，永远最上层 |

- 小兵仍不画（避免杂点，与现状一致；王者荣耀小地图兵线也是弱标识）。
- 死亡单位不画（现状 `is_alive()` 过滤保留）；BOSS 未出场时第 5 层自然缺席。
- 3v3 与 5v5 共用同一套标识（3v3 只有一条兵线、无野怪层，其余一致）——
  标识升级是纯视觉增强，不改 3v3 玩法；B3 回归只验比例与兵线。

### 2.3 验收

| ID | 项目 | 标准 |
|----|------|------|
| B1 | 5v5 内区比例 | 截图像素测量 inner 宽/高 = 1.00 ± 0.02 |
| B2 | 5v5 方位正确 | 中路折线与水平夹角 45° ± 3°；蓝基地点位于左下象限、红基地右上象限；河道为对角浅蓝带 |
| B3 | 3v3 回归 | inner 宽/高 = 1.875 ± 0.05；单条水平兵线；标识分级同样生效 |
| B4 | 无 HUD 重叠 | 面板变方后与暂停键/技能键/比分栏无重叠（2400×1080 与 1920×1080 两档截图） |
| B5 | 模拟器实拍 | Android 模拟器 5v5 开局截图：小地图正方形、三路折线清晰可辨 |
| B6 | 标识尺寸分级 | 像素测量：英雄圆点 ⌀≈11u（±15%）、BOSS ⌀≈20u（±15%）且 ≥1.7× 英雄点、带金色双环；塔为菱形而非圆点 |
| B7 | 一眼可辨（用户验收） | 模拟器/真机截图交用户 3 秒快视：能立即指出①自己（金环+朝向三角）②敌方英雄（红圆点）③BOSS（金环大点）；像素分析队伍色圆形 blob 数 = 存活英雄数 |

---

## 3. R3 — 5v5 五级成长（属性 + 技能强度）

### 3.1 数据（`rules.json`，全部新增进 `mode_5v5`，3v3 不读这些键）

```json
"level_cap": 5,
"xp_levels": [110, 380, 900, 1500],
"hp_per_level": 0.09,
"dmg_per_level": 0.08,
"skill_per_level": 0.10
```

- `xp_levels` 为**累计**阈值：L2=110（与现 `xp_to_level2` 一致）、L3=380、L4=900、L5=1500。
  初版 280/520/840 实测满级过早（10 局 5v5 平均 106s 到 5 级），按实测经验速率约 8xp/s
  校准到 1500，目标满级时刻 180–240s。
- 成长幅度（相对 1 级基础值，加法叠加）：
  - L5 时 max_hp ×1.36、普攻 dmg ×1.32、技能伤害 ×1.40。
- 节奏估算（被动 1.8xp/s + 击杀/补刀/野怪）：
  - 纯挂机：L2≈61s、L3≈156s、L4≈289s、L5≈467s（8 分钟局兜底也能满级）。
  - 正常分路（小兵 14/助攻 7、18s 一波）：L5≈180–260s。
  - 打野（营地 70–110xp、45s 刷新 + gank 助攻）：L5≈150–220s。
  - 阈值是**可调参数**：若平衡探针显示成长过快/过慢，只改 `xp_levels`，不动代码。

### 3.2 sim 修改（`battle_sim.gd`）

- 新字段：`var level_cap := 2`、`var xp_levels: Array = [110.0]`；
  `setup` 的 5v5 分支读 `mode_cfg`（3v3 保持默认 → 行为逐位不变）。
- `add_xp`（2396-2407）重写：

  ```gdscript
  if h == null or add <= 0.0 or h.level >= level_cap: return
  h.xp += add
  while h.level < level_cap and h.xp >= float(xp_levels[h.level - 1]):
      h.level += 1
      _apply_level_growth(h)   # 仅 five_v_five 时生效
      ...（L2 保留原「二级解锁大招！」浮字/玩家 banner/ult 音效；
           L3+ 浮字 "Lv%d 属性提升！"，不再刷 banner）
      level_up.emit(h)
  ```

- `_apply_level_growth(h)`（新函数，`if not five_v_five: return`）：
  - 基础值取自 `h.def`（E8 已证安全）：
    `var base_hp := float(h.def.get("hp", 900))`、`var base_dmg := float(h.def.get("dmg", 45))`
  - `var old_max := h.max_hp`
    `h.max_hp = base_hp * (1.0 + hp_per_level * (h.level - 1))`
    `h.hp += h.max_hp - old_max`（升级补回新增血量，不重置当前血量比例）
    `h.dmg = base_dmg * (1.0 + dmg_per_level * (h.level - 1))`
  - 移速/攻速/射程**不成长**（避免风筝与追击手感漂移）。
- 技能强度：新函数 `func skill_power(h) -> float`：
  `return 1.0 + skill_per_level * (h.level - 1) if five_v_five else 1.0`
  应用点（E7 清单，缺一不可）：
  1. `cast:2702` → `var dmg := float(s.get("dmg", 0.0)) * skill_power(h)`
     （覆盖 projectile/radial/splash/beam/chain/multi/boomerang/trap pending/spin 存值等全部用此变量的分支）
  2. `_finish_move_skill` dash `1512`、backstep `1531` → 读 `s.get("dmg")` 处乘 `skill_power(h)`
  3. `leap_land:3066+` → 同上
  - 百分比治疗/护盾（`heal_pct`/`shield_pct` 按 max_hp 计算）**不另乘**——随 max_hp 成长自然放大，
    在 SPEC 与代码注释中写明，避免后人重复加成。
- 不受影响项（复核清单）：`unlock_at_2` 门槛不变（L2 解锁大招）；打野 gank 条件 `level>=2` 不变；
  AI 目标偏好 `o.level < t.level`（2563）天然兼容 5 级；复活 `hp = max_hp` 自动用成长后血量；
  翻盘复活时间按**比分差**算（2319-2323），与等级无关。

### 3.3 HUD 修改（`hud.gd`）

- sim 新增 helper `func xp_next(h) -> float`：返回下一级累计阈值；已满级返回当前阈值（条恒满）。
  3v3 时等价于 `xp_to_level2`。
- `hud.gd:740` 经验条、`767` 大招环进度：`p.xp / sim.xp_to_level2` → 改为
  「当前级内进度」：`(p.xp - prev_threshold) / (xp_next(p) - prev_threshold)`，满级恒 1。
- `764` 等级数字直接显示 `p.level`（1–5，现有绘制已支持任意数字）。
- `439-440` plate 副文案、`937/953/970` 技能锁判定：保持 `level < 2` 语义不变。

### 3.4 验收

| ID | 项目 | 标准 |
|----|------|------|
| C1 | 5v5 成长数值 | 无头：`add_xp` 累计 840 → level=5、max_hp=基础×1.36（±0.5）、dmg=基础×1.32（±0.01）；继续 add_xp 不再升级、数值不再涨 |
| C2 | 3v3 冻结 | 3v3 `add_xp(9999)` → level=2，hp/dmg 与 make_hero 初始值**完全相等**；skill_power=1.0 |
| C3 | 技能强度 | 同一英雄 L1 vs L5：projectile.dmg 比值 1.40±0.01；dash 落地、leap 落地、backstep 弹体、spin 每 tick 比值同 1.40±0.01 |
| C4 | 大招门槛 | L1 按不出大招（unlock_at_2）；L2 解锁播报与旧版一致 |
| C5 | 成长节奏 | 10 种子挑战难度探针：平均满级时刻 150–300s；每局 ≥9/10 英雄到达 L5；打野满级时刻 ≤ 分路平均 +30s |
| C6 | HUD | 截图：L3 时等级徽章=3、经验条为级内进度（非恒满）；L5 恒满；大招环进度正确 |
| C7 | 升级浮字 | L2 播「二级解锁大招！」+ 玩家 banner；L3–L5 只播浮字不刷 banner（不遮挡战斗） |

---

## 4. R4 — 5v5 八分钟对局 / 五分钟巨兽

### 4.1 数据（`rules.json` `mode_5v5`）

```json
"match_cap": 480.0,
"sudden_death_time": 300.0
```

- **设计决策（默认耦合）**：「终极对决」继续与巨兽出场同一时刻（300s = 5:00）。
  理由：现有设计语言是「巨兽加入 = 决战开始」，建筑易伤 ×2.4 与巨兽推进同步开启，
  最后 3 分钟是决胜期；若拆成 3:00 易伤 / 5:00 出兽，中间 2 分钟节奏语义断裂。
  3v3 的 180/285 **一个字不改**。
- 自动跟随项（代码无需改，逐项验证）：
  - 兵线加速 `clock >= match_cap - 45` → 435s（7:15）起波间隔 18→9s；
  - 「最后 45 秒！防御塔停火，兵线加速」播报 435s、「最后 15 秒！」465s；
  - `final_push` 塔停火 435s 起；时间到判定 480s（水晶血量/积分）；
  - 巨兽复活 25s、二形态（翅膀/陨石/旋风）触发逻辑不变。

### 4.2 代码修改

- `main.gd:227/233` `--boss` / `--boss-fly` 调试：`sim.clock = 179.9` →
  `sim.clock = sim.sudden_death_time - 0.1`（3v3 仍 179.9，5v5 自动 299.9）。
- `tests/sim_headless.gd`：
  - 5v5 段 `simf.clock = 179.9`（440 行附近，终极对决保护测试）→ `299.9`；
  - 兵线加速断言 `s3.clock = 250/256`（899-908）→ `430/440`（435 阈值两侧）；
  - 3v3 段 179.9 / 285 相关断言**不动**；
  - 注释「5 分钟上限」→「8 分钟上限」。
- 文案同步：`README.md`、`AGENTS.md §6`、`CHANGELOG.md`、`home.gd` 提示行
  （5v5 描述加「8 分钟对局 · 5 分钟峡谷巨兽」；3v3 描述不动）。

### 4.3 验收

| ID | 项目 | 标准 |
|----|------|------|
| D1 | 5v5 巨兽时机 | 无头：clock=299 无巨兽；step 到 300 → boss_spawned=true、sudden_death=true、播报一条 |
| D2 | 3v3 冻结 | 3v3 巨兽仍 180s、上限 285s，旧断言全绿 |
| D3 | 兵线加速 | 5v5：430s 波间隔 18（±0.5）、440s 波间隔 9（±0.5）；播报时刻 435/465 |
| D4 | 对局节奏 | 10 种子挑战难度探针：0 局在 120s 前结束；平均结束时刻 240–420s；超时 ≤2/10；≥6/10 局双方合计拆塔 ≥4 |
| D5 | 模拟器 E2E | Android 模拟器完整 5v5 一局：计时到 8:00 判定或提前拆 crystal；无 SCRIPT ERROR / shader uniform 报错；fps ≥24 |
| D6 | 调试旗标 | `--boss --mode=5v5` 直接进 5v5 巨兽战；`--boss`（3v3）行为与旧版一致 |

---

## 5. 实施顺序与验证链

1. **R4 数据 + 测试基线**：改 rules/测试/调试旗标 → 无头全绿（SIM_OK 10 局 3v3 + RULE_OK + SIG_OK + MAP_OK + JGL_OK + FIX_OK + FLOW_OK）。
2. **R3 等级系统**：sim 成长 + skill_power + HUD → C1–C4、C7 无头/截图验收。
3. **R1 朝向**：sim face_dir + view yaw → A1–A5 探针 + 录屏。
4. **R2 小地图**：hud 比例适配 + 标识分级 → B1–B6 像素测量，B7 截图交用户快视。
5. **平衡探针**：临时脚本 10 局 5v5 挑战（固定种子）+ 5 局 3v3 回归，验 C5/D4；
   3v3 平均时长应仍落在 210–270s 旧区间（冻结证据）。探针用完即删。
6. **视觉验收**：桌面 `--skip-home --mode=5v5 --top` 与跟拍录屏 → PIL 像素分析
   （小地图比例/中路 45°/朝向四向）；交付截图给用户过目。
7. **Android E2E**：test-android-36 AVD（`-no-window -gpu host`，带窗口会崩）覆盖安装，
   5v5 完整一局 + 3v3 冒烟；logcat 无脚本错误、fps 达标。
8. **发布**：`tools/godot-build.ps1` 本地构建 4.11.0-dev.1（versionCode 49）→
   aapt2 核包名/版本/arm64-v8a + apksigner 核 CN=TapArena + certutil SHA-256 →
   `git -c user.name=sctale -c user.email=18475722+sctale@users.noreply.github.com` 提交（只列本任务文件）→
   push + GitHub Release（notes 用 --notes-file）→ 资产回读 + 下载哈希比对。
   APK 落项目根目录 `TapArena-v4.11.0-dev.1.apk`。

---

## 6. 风险与回滚

| 风险 | 缓解 |
|------|------|
| 英雄血量 +36% 而塔伤不变 → 推进变慢、超时增多 | 探针 D4 把关；超时 >2/10 时先调 `xp_levels`（推迟 L5）或 `hp_per_level` 0.09→0.07，**不动塔/水晶数值**（3v3 共用） |
| 背对镜头时看不到脸（儿童向美术顾虑） | 露脸偏置在水平/斜向移动时保留脸部朝向镜头侧；纯向上走短暂露背是 MOBA 正常视角；A6 截图交用户确认，不接受再调偏置系数 |
| 小地图面板变方后右上留白 | 纯视觉，无功能重叠（B4 把关）；如用户觉得空，可后续加比分/时间进面板，本次不做 |
| 技能强度 ×1.40 叠加野区 buff ×1.10 秒人 | buff 只有 20s 且 L5 普遍在 3 分钟后；探针观察击杀时长，必要时 `skill_per_level` 0.10→0.08 |
| 多会话并发改同一仓库 | 动手前 `git log --oneline -5` 锚定 HEAD；提交只列本任务文件 |

- 回滚：全部改动落单个 feat 提交，`git revert` 即恢复 4.10.0-dev.1 行为；
  rules.json 新键均为 5v5 专属，3v3 读取路径零改动。