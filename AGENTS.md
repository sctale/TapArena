# AGENTS.md — TapArena（萌兽峡谷）

本文件是 TapArena 子项目的权威协作规则，优先于工作区根目录 `d:\V-Coding\AGENTS.md` 的通用摘要。
所有改动先读本文件，再动手。

## 1. 项目定位

- **唯一主线：Godot 4.7.2 版**，工程在 `godot/`，出 Android APK。
- **Web 版 1.3 已冻结**：`www/`、`android/`、`build.ps1`、`开始游戏.cmd` 属于历史存档，不接收功能更新。
- **Unity 3.2.0 存档已移除**（2026-11-15），不要再引入 Unity 相关文件、脚本或文档。
- 玩法：3v3 单路 / 5v5 三路森林推塔，25 位自制像素动物英雄（3v3/5v5 都可选），6 个野区营地；无联网、无内购、无广告。

## 2. 目录与职责

```
godot/                        唯一主线工程
  project.godot               版本号单一数据源（application/config/version）
  scripts/core/battle_sim.gd  纯逻辑战斗：不引用节点/相机/UI/音频，可无头跑
  scripts/view/battle_view.gd 3D 表现：体素模型、动画、特效、废墟、遮挡挖空
  scripts/view/camera_rig.gd  跟随相机：固定俯角/高度，推镜仅改 FOV
  scripts/ui/hud.gd           战斗 HUD、播报、暂停、结算
  scripts/ui/home.gd          首页选人（版本号从 project.godot 读取）
  scripts/ui/input_hub.gd     触屏摇杆 + 技能 + 键盘
  scripts/art/                像素图集、图标、体素模型
  data/heroes.json            25 位英雄与 75 个技能
  data/rules.json             数值、节奏、巨兽与结算规则
  tests/sim_headless.gd       10 局回归 + 规则单测（SIM_OK / RULE_OK）
  tests/flow_headless.gd      首页→战斗→首页状态机（FLOW_OK）
tools/godot-build.ps1         唯一本地构建发布脚本
tools/*.js                    仅 Web 存档自检脚本，勿用于 Godot 版
previews/                     README 用正式截图
reference/                    美术参考图，未跟踪、不要提交
keystore/ + keystore.properties  签名素材，已 gitignore，禁止删除或提交
```

## 3. 构建与发布（唯一流程）

```powershell
# 1) 先在 CHANGELOG.md 写目标版本条目
# 2) 本地构建 + 全量回归 + 校验 + 复制 APK 到项目根目录
powershell -ExecutionPolicy Bypass -File .\tools\godot-build.ps1 -VersionCode <新 versionCode>
```

脚本依次完成：读 `project.godot` 版本 → 生成 `export_presets.cfg` → 导入资产 → 10 局无头回归（`SIM_OK`/`RULE_OK`）→ 流程回归（`FLOW_OK`）→ 导出 release APK → `aapt2`/`apksigner` 校验 → 复制根目录 `TapArena-v<版本>.apk`。

发布要求：

- **只用本地脚本，不加 GitHub Actions。**
- APK 命名固定 `TapArena-v<版本>.apk`，放在项目根目录。
- `versionCode` 单调递增（当前 79），版本名与 `project.godot` 完全一致。
- 必须实际核验：包名 `com.sctale.taparena`、versionCode、versionName、`arm64-v8a`、签名证书 `CN=TapArena`；不能只看脚本退出码。
- 发布后必须 `git push` 并创建 GitHub Release，APK 作为资产上传：
  ```powershell
  gh release create v<版本> "TapArena-v<版本>.apk" --title "..." --notes-file <临时 md 文件>
  ```
  Release 说明从 CHANGELOG 最新条目同步；含 `[x]` 等字符时**必须**用 `--notes-file`，不要用 `--notes`。
- 发布后**同步更新 SCTale 工坊站点**（技能 `sctale-workshop-publish`）：改 `D:\V-Coding\sctale-workshop\site-data.js` 的 TapArena `release` 段 → `sync-dist.sh` → `verify-site.mjs` → Qoder Sites 发布并核验线上版本。

## 4. 版本与文档规则

- 版本号只改 `godot/project.godot` 的 `config/version`；`versionCode` 只在构建命令里传。
- 版本号必须是纯 `X.Y.Z`，不带 `-dev`、`-beta`、`-rc` 等后缀；历史 CHANGELOG 条目不改写。
- 语义化版本：新功能 + 次版本号，Bug 修复 + 修订号，破坏性更新 + 主版本号。
- 每次改动必须同步：
  - `CHANGELOG.md`：版本号 + 日期 + 分类（新增/修复/优化/验证），写清"为什么"。
  - `README.md`：功能、操作、构建命令、APK 大小/versionCode/SHA-256 有变化时同步。
  - 首页版本号自动读取 `project.godot`，不要再硬编码。
- `README.md` 中的 APK 信息以根目录实际产物为准，构建后用 `Get-FileHash` 回填。

## 5. 测试与验收

```powershell
# 规则 + 10 局无头对局
godot --headless --path godot --script res://tests/sim_headless.gd

# 首页/选人/战斗/暂停/回首页
godot --headless --path godot --script res://tests/flow_headless.gd

# 桌面快速冒烟（不弹首页）
godot --path godot -- --skip-home --auto-run
```

验收判据：

- 无头输出必须包含 `SIM_OK`、`RULE_OK`、`FLOW_OK`，且无 `SCRIPT ERROR` / `Parse Error`。
- 涉及 UI/相机/播报的改动，要用 `--write-movie` 逐帧录屏核对，不能只凭代码判断。
- 英雄身高守卫：`flow_headless.gd` 会计算「装配后包围盒高度 × heroes.json height ÷ HERO_DESIGN_H」，并按定位卡范围（法师 55–90、辅助 55–108、坦克 72–110、战士 65–96、刺客/射手 50–82 等）；超出即 `FLOW_FAIL`，新模型必须过这一关。
- 相机相关改动的判据：机位高度、俯角、朝向恒定；行走录像背景位移稳定，无停顿/回跳帧。
- 播报相关改动的判据：顶部玩家面板、小地图、比分、状态标签、播报条互不叠字。

## 6. 代码与设计约束（必须遵守）

- `battle_sim.gd` 保持纯逻辑：不引用 `Node`、`Camera3D`、UI、音频；表现层只通过信号订阅。
- 攻击选取（4.13 起）：普攻/技能统一走 `pick_attack_target` / `pick_skill_target`——敌方英雄优先、残血单位优先、建筑最后，`atk_target` 带粘性；远程普攻是 homing 弹道，技能对移动目标做提前量。不要再退回 `nearest_enemy` 一把抓。
- 启动图标：自适应前景有效像素必须落在 432 画布中央 264 安全区内并居中；`launcher_icons/adaptive_monochrome_432x432` 必须指向 `app_icon_monochrome.png`，否则 Android 13 主题图标缺 monochrome 节点。
- 建筑保护层级严格为 **外塔 → 内塔 → 水晶**：前序建筑未毁时后续建筑完全免疫伤害，AI 不得绕过前塔。
- 节奏固定：3v3 为 3:00 终极对决 + 峡谷巨兽，4:00 起 45 秒结算倒计时，4:45 兜底结算；5v5 为 4:00 峡谷巨兽、5:00 终极对决，8:00 上限，最后 45 秒防御塔停火。巨兽与终极对决由 `boss_time` / `sudden_death_time` 两个字段控制，3v3 默认同帧。
- 3v3 为 3600×1600 单路（4.31 起由 3000 加宽）：双方外塔相距 1100（蓝 1250 / 红 2350），塔与药剂坐标在 `rules.json`；3v3 树缩放 0.50–0.72，5v5 保持 0.85–1.35。
- 5v5 为 3600×3600 对角三路（4.20 起由 2400 放大 1.5 倍）：上路沿左/上边、中路对角、下路沿下/右边，河道斜穿野区；每方 3 座路塔，拆掉 2 座后水晶失去保护；野区 6 个营地（野猪/灰狼/河蟹，狼营给增伤、蟹营给加速），双方各一名打野只刷本方野区；终极对决只放大建筑伤害，塔/水晶保护层级全程有效。
- 结算页必须展示双方全部玩家的完整战绩（3v3 六人 / 5v5 十人：头像/姓名/等级/击杀·死亡/输出），不能只显示玩家本人，也不能出现只有底色的空行。
- 相机：机位高度、俯角、朝向为常量；推镜/打击感只改 `fov`，震屏只平移机位、不重新对准。
- 播报条固定位于 `h*0.245`，宽度 0.52w；3v3 巨兽与终极对决同帧，合并为一条播报；5v5 巨兽 4:00 单独播报，5:00 终极对决不再叠一条横幅。
- HUD 以 1920×1080 为基准，必须适配 Android 安全区；触摸热区不小于 44vp。
- 像素美术、音效均为项目自制或运行时合成；不引入任何第三方游戏素材。
- 新英雄建模以 88 单位人形模板为基准：长脖子、高冠、尾屏等超出模板的结构，必须在 `HERO_DESIGN_H` 登记**模型实测自然高度**（例：长长 118），`heroes.json.height` 填期望的进游戏身高；两者任一填错都会被 `height/设计身高` 二次放大。登记条目本身不代表尺寸正确，必须用模拟器同屏对比同定位老英雄。
- 体素模型的「视觉身高」以装配后 AABB 为准（body 的世界高度 + head/tail 等枢轴抬升），不是单个 mesh 的局部包围盒；调尺寸时用 `flow_headless` 的守卫输出核对。
- GDScript 用 Tab 缩进，注释用中文；数值改 `data/*.json`，不要散落在脚本里。
- PowerShell 脚本必须保存为 **UTF-8 with BOM**（Windows PowerShell 5.x 否则解析中文报错）。

## 7. 调试参数（写在 `--` 之后）

- `--skip-home` 跳过首页；`--hero=frog` 指定英雄；`--mode=5v5` 进入三路 5v5；`--auto-run` 自动向右推进
- `--dash` 移动中反复放 1 技能；`--boss` 直接触发峡谷巨兽（3v3 3:00 / 5v5 4:00，含播报/震屏）；`--boss-fly` 直接看飞行第二形态
- `--walk=up|down|left|right|up-right|down-left…` 按固定方向走，用于核对角色朝向
- `--ult` 检查大招冷却；`--dead` 直接击杀玩家并拉到 9 秒复活，用于核对复活倒计时面板；`--lv=3` 直接把玩家升到指定等级（2–5，经验条停在该级中段）；`--fx=waterfall_ult` 居中播放指定大招；`--no-hud` 隐藏 HUD
- `--top` 全图俯瞰；`--look-base` / `--look-red` / `--look-lane` / `--look-tower` 定点镜头
- `--behind` 检查建筑遮挡挖空；`--ruins` 检查废墟；`--pause` / `--result` / `--victory` 检查界面；`--result-demo` 配合 `--result` 填入 4–5 位输出，压测十行结算数字不被批上限截断
- 录制画面：`godot --path godot --write-movie <目录>/shot.png --fixed-fps 30 --quit-after <帧数> -- <参数>`

## 8. 禁止事项

- 不修改或删除 `www/`、`android/`、`build.ps1`、`开始游戏.cmd`（Web 冻结存档），除非用户明确要求。
- 不提交 `keystore/`、`keystore.properties`、`godot/keystore/`、`godot/export_presets.cfg`、`godot/build/`、`.adbtmp/`、`godot/.godot/`、`reference/`、根目录 APK。
- 不在项目重新引入 Unity 工程或 Polyfork/Blender 美术管线。
- 不绕过本地构建脚本直接手工拼 APK；不使用 debug 签名。
- 不在没有跑完无头回归与 APK 校验的情况下宣布"已完成"。
- 不推送未经核验的 Release；Release 资产名必须与根目录 APK 一致。

## 9. Git 约定

- 提交身份：`git -c user.name=sctale -c user.email=18475722+sctale@users.noreply.github.com`，不改全局配置。
- 提交前查 `git log --oneline -5` 确认版本归属；`git add` 只列本任务文件。
- 提交信息格式：`feat/fix/docs/chore: 中文描述（版本号）`。
- 多智能体并发时，若发现工作区出现非本任务改动，先停下核对，不要覆盖。
