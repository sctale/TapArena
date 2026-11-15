# SPEC — 参考图驱动的画风升级（TapArena Godot 主线）

> 本文是 `reference/` 概念图 → Godot 版画风升级的实施规格，供其他 Agent 接续执行。
> 协作总规则见 `AGENTS.md`；本文件只描述本轮美术改造的目标、已完成项与剩余项。

## 1. 目标

参考 `reference/` 下 18 张 AI 概念图（6 张场景资产 + 12 张英雄），把当前 Godot 版从「偏暗、原色、灰石」的方块风，升级为：

- **奶油石 + 阵营色**：底座/祭坛/塔基为暖奶油石（#D8D2C2 ~ #E8E1D1），蓝方青蓝（#4FC3E8）、红方珊瑚橙（#F0845C）。
- **明亮粉彩环境**：草地 #6FB84F 系、树冠 #63B44A 系、沙路 #DCC9A4 系；天空为顶部青蓝 → 地平线近白的渐变。
- **发光水晶**：蓝方青白水晶、红方橙金水晶，顶部保留 glow 方块。
- **柔和立体感**：体素面光照提亮（顶 1.0 / 正背 0.94 / 左右 0.86 / 底 0.62），不再有死黑侧面。
- **绿植点缀**：塔基、祭坛周围加亮绿草块，呼应参考图的叶纹与绿植。

**不改**：玩法数值、战斗逻辑、模型拓扑、UI 布局、HUD 可读性、音效。
**不引入**：第三方贴图/模型/字体；所有颜色仍走运行时像素图集与调色板。

## 2. 参考图关键取色

| 用途 | 参考色 |
| --- | --- |
| 奶油石（底座/砖） | `#D8D2C2` `#E4DED0` `#C6C0B0` |
| 蓝方主色 | `#4FC3E8` / 水晶 `#9DEBF7` `#D9FAFF` |
| 红方主色 | `#F0845C` / 水晶 `#F27A32` `#FFC05C` |
| 草绿 | `#6FB84F` `#7CC95A` `#5FA845` |
| 树冠 | `#63B44A` `#559F3E` `#75C75B` |
| 沙路 | `#DCC9A4` `#E8D8B6` |
| 金色点缀 | `#F2C14E` `#FFD970` |
| 天空 | 顶 `#79C8EC` → 地平线 `#E6F7FD` |

## 3. 改动清单与进度

### 3.1 已完成（4.6.2-dev.1 已构建验证）

- [x] `godot/scripts/art/pixel_atlas.gd`：grass/stone/stone_brick/sand/path/log/leaves/planks/crystal/mushroom/mushroom_blue/gold/ice/lava/fur 全部换为粉彩新色。
- [x] `godot/scripts/view/battle_view.gd`：
  - 天空改为 `ProceduralSkyMaterial` 渐变（顶 `#79C8EC`、地平线 `#E6F7FD`）。
  - 阵营色 `C_BLUE = #4FC3E8`、`C_RED = #F0845C`。
  - 树冠三档改为 `#63B44A / #559F3E / #75C75B`。
  - 路缘石 tint 提亮为纯白（配合新奶油石图集）。
- [x] `godot/scripts/art/voxel_model.gd`：面光照柔化（顶 1.0 / 正背 0.94 / 左右 0.86 / 底 0.62）。
- [x] `godot/scripts/art/block_models.gd`：
  - 蘑菇塔：奶油石底座、蓝方奶油菌柄、红方暖木菌柄、塔基加 3 块亮绿草。
  - 祭坛：蓝红双方改为奶油石砖三层台。
  - 水晶：顶部星光改青白；颜色继续由阵营色驱动。
  - 峡谷巨兽：石甲 `#8F8F9C`、暗部 `#5C5C6A`、金角 `#F5CB55`。
  - 红方小兵：暗棕石色整体提亮，避免死黑。
- [x] `godot/data/heroes.json`：8 位英雄 fur/dark 提亮（tiger/fox/rabbit/bear/frog/cat/owl；panda 保持黑白）。

### 3.2 待完成（按顺序执行）

1. [x] `godot/scripts/ui/home.gd` 首页粉彩化：
   - `SKY` → `#9FD9F2`，`GRASS` → `#7FC45C`。
   - `_draw()` 天空改为 6 段渐变（顶部 SKY → 地平线 `#E6F7FD`）。
   - 地平线草边 `#5F9E45`，底部草方块装饰 `#6FB84F`。
   - 暂不改深色卡片面板，保证文字对比度。
2. [x] 运行无头回归：`godot --headless --path godot --script res://tests/sim_headless.gd`（需 `SIM_OK` / `RULE_OK`）。
3. [x] 运行流程回归：`flow_headless.gd`（需 `FLOW_OK`）。
4. [x] 桌面截图验收（`--write-movie` 或直接截图）：
   - 首页、兵线、蓝方基地、红方基地、双方塔、BOSS 出场各 1 张。
   - 对照 `reference/`：奶油石、青/橙阵营色、亮绿植被、渐变天空、发光水晶是否成立。
   - 检查 HUD 文字在更亮场景上的对比度，必要时加深面板或加描边。
5. [x] Android 构建发布（沿用 `AGENTS.md` 流程）：
   - 版本 `4.6.2-dev.1`（画风优化，patch +1），`versionCode 41`。
   - 更新 `CHANGELOG.md` 新条目 + `README.md`（画风描述、APK 大小/SHA-256/versionCode）。
   - `powershell -ExecutionPolicy Bypass -File .\tools\godot-build.ps1 -VersionCode 41`。
   - 校验包名/versionCode/versionName/arm64-v8a/证书后，`git push` + `gh release create`（`--notes-file`）。
   - 结果：`TapArena-v4.6.2-dev.1.apk`，26,954,303 字节，versionCode 41，SHA-256 `B3849EE616F3C5CDB7BD0547F966C1EAB328A01B926BE6F7C544C9B49E3E39DC`；Android 16 模拟器覆盖安装通过。
6. [x] 清理本轮临时录像/截图（`godot/build/` 或 `.adbtmp/`），避免仓库体积回升。

## 4. 验收标准

- 无头：`SIM_OK`、`RULE_OK`、`FLOW_OK` 且无 `SCRIPT ERROR` / `Parse Error`。
- 视觉：
  - 草地/树冠明显比改造前更亮、更粉彩，无大片死黑侧面。
  - 蓝方塔/水晶以青蓝为主，红方以橙红为主，底座均为奶油石而非灰石。
  - 天空在远景可见青→白渐变，不是单色块。
  - 英雄毛色更亮，但 8 位英雄仍可凭颜色区分。
- 性能：GL Compatibility 下桌面稳定 60fps（`[FPS]` 日志），无明显掉帧。
- 包体：APK 通过 aapt2/apksigner 校验，版本与 `project.godot` 一致。

## 5. 调试与验证命令

```powershell
# 桌面看兵线 / 蓝方基地 / 红方基地 / 红方外塔
godot --path godot -- --skip-home --look-lane
godot --path godot -- --skip-home --look-base
godot --path godot -- --skip-home --look-red
godot --path godot -- --skip-home --look-tower

# 首页
godot --path godot

# 逐帧录像（示例）
godot --path godot --write-movie .adbtmp/style.png --fixed-fps 30 --quit-after 60 -- --skip-home --look-lane
```

## 6. 风险与回退

- 天空从 `BG_COLOR` 改为 `BG_SKY`：若 Android GLES/ANGLE 出现天空异常，回退到单色 `#8EC9F0` 并保留其余配色。
- 面光照整体提亮可能让部分深色模型对比不足：优先调整具体模型 tint，不回退全局光照。
- 所有改动集中在 5 个文件（`pixel_atlas.gd`、`battle_view.gd`、`voxel_model.gd`、`block_models.gd`、`heroes.json`）+ 首页 `home.gd`，回退时按文件恢复即可。
