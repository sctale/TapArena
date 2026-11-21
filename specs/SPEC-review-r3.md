# SPEC — 4.35.0 第三轮全面 review（UI / 武器 / 攻击效果 / 技能效果）

状态：已实现（4.35.0 / code 84）

- 基线：4.34.1（versionCode 83）工作树；25 英雄 / 75 技能 / 25+25 条音频资产已全覆盖
- 方法：静态走读 `hud.gd` / `home.gd` / `input_hub.gd` / `battle_view.gd` / `block_models.gd` /
  `battle_sim.gd` / `heroes.json` + `shots/` 真机与审计截图比对（4.11、4.33.1、4.34.0、4.34.1、weapon_audit）
- 范围：只修本 SPEC 列出的表现层与体验问题；**不改战斗数值/平衡、不增删英雄技能、不换美术风格、不碰 3v3 冻结项**
- 建议版本：4.35.0 / versionCode 84（体验增强 + 缺陷修复，次版本 +1，最终 Sid 拍板）
- 纪律：完成一条勾一条；中断后从本文件未勾项继续；SPEC 与代码一起提交

## 0. 正面结论（不再重复造轮子）

| 域 | 现状证据 |
|----|----------|
| 武器覆盖 | `block_models.gd:531-871` `_gear_boxes` 25 个 match 分支全有专属武器/盾/法器，握把遮挡、刃口高光、发光尖齐全；武器盒挂 arm 枢轴随动作摆动 |
| 攻击表现 | `battle_view.gd:1735-1818` `_weapon_strike` 25 英雄全覆盖：近战弧光+尖端火花、重武器地环+碎块、弓手箭线、法杖杖端爆点；25 条 atk wav + 3D 声源池 + 台词独立池 + BGM ducking |
| 技能覆盖 | `heroes.json` 75 个 fx 名称在 `battle_view.gd:2227-2305` `_spawn_style` 全有分支且带默认兜底；15+ 大招有专属 spawner；25 个大招 cast_action 全显式映射（556-606），小技能按 kind 回退 13 种全身动作 |
| 大招反馈 | 玩家本人放大招必有整屏轻闪：`battle_sim.gd:3106-3108` 仅 `is_player and index==2` 发 `punch`，链路正确，无需改 |
| 音频覆盖 | `assets/audio/atk`、`ult` 各 25 条 wav；`sfx.gd` HERO_AUDIO 25 英雄音色参数齐全 |

## 1. 发现清单

| ID | 级 | 现象 | 证据 / 位置 |
|----|----|------|-------------|
| R3-01 | P0 | **FX 共享材质透明度串扰（确定性 bug）**：`_fx_mat/_fx_glow/_alpha_material` 按 key 缓存并跨 FX 共享同一材质；`_step_fx` 每帧直接覆写 `m.albedo_color.a = 1.0-k`。同色同 alpha 的并存特效互相覆盖透明度（后写者赢），团战中表现为闪烁/淡出错乱；且无视材质原始 alpha（0.22 的残影也从 1.0 起步） | `battle_view.gd:1418-1428`、`1543-1553`、`2149-2161` 缓存；`1564-1578` 挂载；`2867-2869` 覆写 |
| R3-02 | P0 | **FX 节点无上限、无池化**：`fx_items` 无容量控制，一次施法 = 起手光 9~21 节点 + 风格 FX 3~25 节点；5v5 十英雄自动施法估算常驻 150~400 个独立 MeshInstance3D，全部现场 new / queue_free（弹道 shot 已有池，FX 没有）；`_spawn_slashes` 还每次 `BoxMesh.new()` 绕过 `_fx_mesh` 缓存 | `battle_view.gd:34`、`1564-1578`、`2350-2356` |
| R3-03 | P0 | **技能按钮无按压/拒绝反馈**：触点命中直接 `sim.set_skill(i)`，HUD 无 pressed 态；冷却中/锁定时点按被静默吞掉（`set_skill` 只置标志位，无返回值）；全工程 0 处 `vibrate_handheld` | `input_hub.gd:64-67`；`battle_sim.gd:1328-1331`；`hud.gd:1153-1215` |
| R3-04 | P1 | **飘字无上限且不夹取屏幕边缘**：`floats` 数组无 cap，AoE 团战峰值会挤占 8192 矩形批次；顶部飘字直接钻到计分板下方（实测 `shots/android-4.11-5v5.png` 的 -46 贴顶部面板） | `hud.gd:511-513`、`1250-1264` |
| R3-05 | P1 | **MultiMesh 批次溢出静默丢元素**：`_add_rect/_add_rot_rect/_add_disc` 超 8192/192 容量直接 return，无任何日志（仅小地图 disc_ui 有一次性警告），出问题无法定位 | `hud.gd:320-328`、`338-346`、`360-366`（对比 `369-378`） |
| R3-06 | P1 | **调试 print 残留**：首页每次触摸都打印一行；对局与周期性能日志无 debug 开关 | `home.gd:1016`；`main.gd:331,342`；`battle_view.gd:830` |
| R3-07 | P1 | **`previews/` 五张截图严重过期**：内容为 v1.2 时代 2D 插画风（首页标 v1.2、选角仅 6 人、战斗为光滑 chibi），与当前 4.34.1 的 25 英雄体素 3D 完全不符，违反"截图与当前 UI 一致"纪律 | `previews/home.jpg`、`select.jpg`、`battle.jpg`、`pause.jpg`、`result.jpg` |
| R3-08 | P1 | **待机武器微光只覆盖 13/25 英雄**：其余 12 位落到默认白色，与武器主题色不匹配 | `battle_view.gd:1869-1883`（缺 monkey/elephant/penguin/sheep/bat/croc/giraffe/raccoon/koala/peacock 等） |
| R3-09 | P1 | **小型武器实战辨识度弱**：weapon_audit 全景图中刺猬双匕、蝙蝠双刃、浣熊短匕、猫/鹿短弓在战斗相机距离下只剩几个像素；9 把法杖同为"木杆+小杖头"轮廓，杖头装饰实战不可读 | `shots/weapon_audit/_front.png`；`block_models.gd:611-628`、`704-718`、`791-802`、`825-835` |
| R3-10 | P2 | **英雄名牌无重叠消解**：固定宽度居中挂头顶，5v5 抱团时名字互相叠压（实测 battle.jpg 朵朵/阿虎重叠） | `hud.gd:568-590` |
| R3-11 | P2 | **远程攻击动作不区分武器**：远程统一"双手前推"，弓手无拉弓姿态、杖系无举杖姿态，弓上搭箭为静态模型 | `battle_view.gd:1053-1056` |
| R3-12 | P2 | **过时注释 4 处**：音频"15 条"实际 25 条、音色"8 位英雄"实际 25 位、英雄数"当前 20 位"实际 25 位 | `battle_view.gd:50`；`sfx.gd:9`；`battle_sim.gd:412`；`home.gd:174` |
| R3-13 | P2 | **同模板英雄技能观感同质**：虎/狼同为 claw+roar+claw_ult、quake 系 4 英雄、leafheal 系 4 英雄，仅颜色不同。列为后续可选打磨，不阻塞本轮 | `heroes.json` fx 字段；`battle_view.gd:2227-2305` |

## 2. 逐条改动方案

### P0 — 缺陷与性能

- [x] **R3-01 FX 材质实例化**（`battle_view.gd`，单点修复覆盖全部 FX）
  1. `_add_fx_mesh` 内对传入 `mat` 执行 `mat.duplicate()` 后再赋给 `node.material_override`，缓存材质只作模板；zone 圆盘（`_sync_zones`，恒定 alpha 不参与淡出）保持共享不动。
  2. `_step_fx` 淡出改为基于实例材质：记录材质初始 alpha 到 `item["base_a"]`，每帧写 `m.albedo_color.a = base_a * (1.0 - k)`，保留作者意图的原始透明度。
  3. 验收用例：同帧连放两个同色 `cast_` 技能，两个光效各自独立淡出、互不闪烁。
- [x] **R3-02 FX 池化 + 软上限 + 网格缓存补齐**（`battle_view.gd`）
  1. 新增 `fx_free: Array` 节点池：`_add_fx_mesh` 优先取池中 MeshInstance3D 复用，死亡节点入池而非 `queue_free`（视图销毁时统一释放）。
  2. `fx_items.size()` 超 360 时，淘汰最旧且非大招（life ≤ 0.5s 的粒子项）；无法淘汰时跳过本次生成并打一次性 warning，严禁无界增长。
  3. `_spawn_slashes` 的 `BoxMesh.new()` 改走 `_fx_mesh("fx_slashes_...", factory)`；全文件搜 `Mesh.new()` 确认 FX 路径无遗漏（建筑/角色静态建模不受影响）。
  4. 桌面 5v5 自动推进 60s，打印 `fx_items` 峰值与池命中率，峰值 ≤360、无 queue_free 风暴。
- [x] **R3-03 技能钮按压与拒绝反馈**（`input_hub.gd` + `hud.gd` + `battle_sim.gd`）
  1. `set_skill(i)` 增加可用性判断并返回 `bool`：锁定（`unlock_at_2` 且等级<2）或 `cds[i] > 0` 时返回 false，标志位不变。
  2. input_hub 记录 `press_i` 与按下时间戳；HUD 在 0.12s 内给该钮画一圈亮色描边（pressed 态）。
  3. 返回 false 时：HUD 对该钮播放 0.18s 横向抖动（相位衰减），Android 调 `Input.vibrate_handheld(15)`；桌面无震动则只抖动。震动跟随音效开关（声音关则不震）。
  4. 键盘 Q/E/R 走同一返回值路径，表现一致。

### P1 — 体验与一致性

- [x] **R3-04 飘字限流与边缘夹取**（`hud.gd`）：`_on_float_text` 超 40 条时移除最旧；`_draw_floats` 的屏幕 y 夹取到计分板下沿 + 8px、x 夹取到安全区内，超出时贴边显示而非被面板盖住。
- [x] **R3-05 批次溢出一次性警告**（`hud.gd`）：rect/disc 超容时参照 `disc_ui_warned` 模式各打一条一次性 warning（含当前实例计数），不再静默丢元素。
- [x] **R3-06 调试日志收口**：删 `home.gd:1016` 的 tap print；`main.gd` 两条与 `battle_view.gd` 的 sync_ms 日志包 `if OS.is_debug_build()`；发布包 logcat 无周期性输出。
- [x] **R3-07 重生成 previews 五图**：沿用现有截图工作流出 2400×1080 横屏五张（home 首页 / select 选角详情 / battle 实战含技能 FX / pause 暂停 / result 结算），文件名与路径不变；画面必须是当前体素 3D 风格与 25 英雄版本，旧 v1.2 图删除替换。
- [x] **R3-08 补全 `_glint_color`**：为 monkey(金)、elephant(钢蓝灰)、penguin(冰蓝)、sheep(粉)、bat(紫)、croc(青)、giraffe(叶绿)、raccoon(金)、koala(叶绿)、peacock(紫+金) 等补齐主题色，25 英雄无默认白色落网。
- [x] **R3-09 小武器可读性增强**（仅 `block_models.gd` 视觉盒，不改碰撞/数值）
  1. 刺猬双匕、蝙蝠双刃、浣熊短匕：刃部尺寸放大约 12%，刃尖补 1 格 `glow` 块。
  2. 猫/鹿短弓：弓臂加粗 1 格或弦侧补亮色细边，保证战斗距离能读出"弓"轮廓。
  3. 法杖盘点补 glow 核心：sheep（粉心）、giraffe（黄果）、koala（叶团）杖头各补 1 格 glow；已有 glow 的 fox/rabbit/owl/frog/penguin/crane 不动；panda 竹杖保持质朴设定。
  4. weapon_audit 重新出全景图 + 对应英雄 zoom 图，战斗视距截图中武器轮廓可辨。

### P2 — 打磨（本轮时间盒内做完，做不完移 r4，不偷偷扩范围）

- [x] **R3-10 名牌重叠消解**（`hud.gd`）：屏幕空间同名牌矩形水平相交时，按 uid 奇偶左右各偏 0.6 个牌宽；玩家自己名牌永不偏移。
- [x] **R3-11 远程攻击姿态分化**（`battle_view.gd:1053-1056`）：cat/deer 攻击帧左臂后拉做拉弦感；杖系（fox/owl/rabbit/frog/penguin/sheep/giraffe/koala/crane）右手抬杖约 0.3rad；幅度小、时长复用 0.34s 攻击窗。
- [x] **R3-12 修正 4 处过时注释**，数字与 25 英雄 / 25+25 音频现状一致。
- [x] **R3-13 签名差异化预研（只出结论不改代码）**：给出虎/狼、quake 系、leafheal 系各 1 个低成本签名元素方案（1~2 个盒/1 个粒子形状），写回本 SPEC 附录供 r4 决策。

## 3. 验收

| ID | 项目 | 量化标准 |
|----|------|----------|
| V3-1 | 材质串扰 | 同帧双同色技能：逐帧截图/肉眼无闪烁；两个 FX 节点 material_override 为不同资源实例 |
| V3-2 | FX 容量 | 5v5 自动 60s：`fx_items` 峰值 ≤360，超容 warning ≤1 次；池命中率日志 ≥70% |
| V3-3 | 按钮反馈 | 冷却中点技能钮：必出抖动 +（Android）震动；可用时点按：0.12s 高亮描边；`set_skill` 返回值与可用性一致 |
| V3-4 | 飘字 | 团战造 40+ 飘字：条数封顶 40、无消失；顶部飘字全部位于计分板下沿以下 |
| V3-5 | 日志 | 发布构建 logcat 无 `[HOME]`/`[FPS]`/`[VIEW]` 周期输出；debug 构建保留 |
| V3-6 | 截图 | previews 五张全部重生成，画面为 25 英雄体素版本，无 v1.2 残留 |
| V3-7 | 武器 | 25 英雄 glint 全主题色；zoom 图中刺猬/蝙蝠/浣熊刃部与猫/鹿弓轮廓可辨；3 把法杖 glow 补齐 |
| V3-8 | 回归 | 构建门禁 SIM_OK / RULE_OK / FLOW_OK 全绿；桌面无 SCRIPT ERROR；Android 覆盖安装 2400×1080 一局 5v5 完成 |
| V3-9 | 文档 | CHANGELOG 记录本轮条目；版本号 4.35.0/code 84 全工程单一数据源一致；README 若引用版本号同步 |

## 4. 验证流程

1. 桌面无头：`--skip-home --mode=5v5 --auto-run` 跑 60s，采集 `[VIEW] sync_ms`、fx 峰值/池命中、SCRIPT ERROR 计数（基线：FPS ≥58、sync_ms ≤2.0，允许持平不得劣化 >15%）。
2. Android 2400×1080 模拟器/真机：技能钮冷却点按、可用点按、团战飘字、5v5 整局各录一帧证据图入 `shots/`。
3. weapon_audit 截图工作流重跑：`_front.png` + 改动英雄 zoom 前后对比。
4. previews 五图重生成后逐张人工核对与当前 UI 一致。
5. 构建走本地 `tools/godot-build.ps1`（不加 GitHub Actions），验 APK 命名 `TapArena-v4.35.0.apk`、签名、versionCode、Release 资产名与正文。
6. 全部勾选完成后本 SPEC 随代码提交；未完成项保留未勾并注明移至 r4。

## 5. 非目标（明确不做）

- 不改英雄数值、技能 cd/dmg/radius、经济与经验曲线、AI 决策
- 不新增/删除英雄或技能，不改 `heroes.json` 的玩法字段
- 不重做体素美术风格、不替换音频资产
- 不动 3v3 冻结规则与地图结构
- R3-13 本轮只预研不落代码

## 附录：R3-13 签名差异化预研（本轮只出结论，r4 决策）

成本口径：每个签名元素只用 1–2 个盒子/粒子形状，复用 `_add_fx_mesh` / `_fx_mat`，不新增贴图与音频。

### A. 虎 / 狼（claw + roar + claw_ult）

- **虎**：三道*橙黑相间*斜爪光（现有 `_spawn_slashes` 每个条带交替 `ff9a4a` / `2a2420`，中间留 1 格断层），
  咆哮改成「虎啸」——以嘴为原点向前铺 3 条横向声波条（每 0.06s 一条，长度递减）。
- **狼**：半月形灰蓝爪光（`8fa0b8`，较窄较长），嚎叫时地面浮出 4 个 1×1 格冷色狼爪印（2 前 2 后，
  0.4s 淡出）。虎是「横向声波」，狼是「地面脚印」，同屏可一眼区分。

### B. quake 系（熊 / 猴 / 象 / 鳄）

统一用「一次地面印」取代同款尘环：

- 熊：3 个棕色圆块组成熊掌印（前掌 2 大 + 后掌 1 小）；
- 猴：一条 1 格宽金色直线裂纹 + 两端金环（对应金箍棒）；
- 象：2 个灰色大圆脚印（左右各一）；
- 鳄：3 个白色三角牙印沿弧线排开。

### C. leafheal 系（兔 / 羊 / 考拉 / 长颈鹿）

治疗区域中心改为各自主题的「一片叶子」浮起 0.6s：

- 兔：橙色胡萝卜 + 2 片绿叶；
- 羊：白色云朵泡（2 圆块叠放）；
- 考拉：3 片深绿桉叶扇形；
- 长颈鹿：1 片黄绿长叶（高度是宽度的 3 倍）。

建议 r4 先做 A（虎/狼辨识度最高、只改 2 个 FX 分支），观察一局再决定 B/C。
