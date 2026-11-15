# AGENTS.md — TapArena（萌兽峡谷）

本文件是 TapArena 子项目的权威协作规则，优先于工作区根目录 `d:\V-Coding\AGENTS.md` 的通用摘要。
所有改动先读本文件，再动手。

## 1. 项目定位

- **唯一主线：Godot 4.7.2 版**，工程在 `godot/`，出 Android APK。
- **Web 版 1.3 已冻结**：`www/`、`android/`、`build.ps1`、`开始游戏.cmd` 属于历史存档，不接收功能更新。
- **Unity 3.2.0 存档已移除**（2026-11-15），不要再引入 Unity 相关文件、脚本或文档。
- 玩法：3v3 森林推塔，8 位自制像素动物英雄，无联网、无内购、无广告。

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
  data/heroes.json            8 位英雄与 18 个技能
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
- `versionCode` 单调递增（当前 40），版本名与 `project.godot` 完全一致。
- 必须实际核验：包名 `com.sctale.taparena`、versionCode、versionName、`arm64-v8a`、签名证书 `CN=TapArena`；不能只看脚本退出码。
- 发布后必须 `git push` 并创建 GitHub Release，APK 作为资产上传：
  ```powershell
  gh release create v<版本> "TapArena-v<版本>.apk" --title "..." --notes-file <临时 md 文件>
  ```
  Release 说明从 CHANGELOG 最新条目同步；含 `[x]` 等字符时**必须**用 `--notes-file`，不要用 `--notes`。

## 4. 版本与文档规则

- 版本号只改 `godot/project.godot` 的 `config/version`；`versionCode` 只在构建命令里传。
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
- 相机相关改动的判据：机位高度、俯角、朝向恒定；行走录像背景位移稳定，无停顿/回跳帧。
- 播报相关改动的判据：顶部玩家面板、小地图、比分、状态标签、播报条互不叠字。

## 6. 代码与设计约束（必须遵守）

- `battle_sim.gd` 保持纯逻辑：不引用 `Node`、`Camera3D`、UI、音频；表现层只通过信号订阅。
- 建筑保护层级严格为 **外塔 → 内塔 → 水晶**：前序建筑未毁时后续建筑完全免疫伤害，AI 不得绕过前塔。
- 节奏固定：3:00 终极对决 + 峡谷巨兽；4:00 起 45 秒结算倒计时（防御塔停火、兵线加速）；4:45 兜底结算。
- 结算页必须展示双方 6 名玩家的完整战绩（击杀/死亡/输出），不能只显示玩家本人。
- 相机：机位高度、俯角、朝向为常量；推镜/打击感只改 `fov`，震屏只平移机位、不重新对准。
- 播报条固定位于 `h*0.245`，宽度 0.52w；3 分钟事件合并为一条播报，避免同帧多条互相覆盖。
- HUD 以 1920×1080 为基准，必须适配 Android 安全区；触摸热区不小于 44vp。
- 像素美术、音效均为项目自制或运行时合成；不引入任何第三方游戏素材。
- GDScript 用 Tab 缩进，注释用中文；数值改 `data/*.json`，不要散落在脚本里。
- PowerShell 脚本必须保存为 **UTF-8 with BOM**（Windows PowerShell 5.x 否则解析中文报错）。

## 7. 调试参数（写在 `--` 之后）

- `--skip-home` 跳过首页；`--hero=frog` 指定英雄；`--auto-run` 自动向右推进
- `--dash` 移动中反复放 1 技能；`--boss` 直接触发 3 分钟巨兽（含播报/震屏）
- `--ult` 检查大招冷却；`--fx=waterfall_ult` 居中播放指定大招；`--no-hud` 隐藏 HUD
- `--top` 全图俯瞰；`--look-base` / `--look-red` / `--look-lane` / `--look-tower` 定点镜头
- `--behind` 检查建筑遮挡挖空；`--ruins` 检查废墟；`--pause` / `--result` / `--victory` 检查界面
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
