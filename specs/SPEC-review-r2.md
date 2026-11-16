# SPEC — 4.11.0 自查整改（第二轮 review）

- 基线：第一轮整改后的工作树；APK 4.11.0-dev.1（versionCode 49）已装进 2400×1080 模拟器
- 方法：Android 实机截图像素分析 + 桌面性能采样 + 验收缺口复核
- 范围：只做验证驱动的修正与可测性补强；3v3 冻结约束不变

## 1. 发现

| ID | 现象 | 证据 | 位置 |
|----|------|------|------|
| R2-01 | **世界血条画在小地图之上**：小地图内出现 53×8 / 43×9 的队伍色条带，看上去像额外的英雄标记 | Android 截图 `shots/android-4.11-5v5.png`：小地图内 (2131..2183, 71..78)、(2154..2196, 101..109) 出现纯蓝横条 | `hud.gd` `_draw_battle_bg`：先画小地图、后画 `_draw_world_bars` |
| R2-02 | 等级 HUD（C6）没有可复现的截图证据：无法直接进入 3/4 级看经验条中段 | 现有调试旗标只有 `--ult`（2 级） | `main.gd` 调试参数 |
| R2-03 | 桌面性能没有本轮实测数字（小地图新增 33 个圆盘与 20+ 线段） | 只有 Android 25–31fps | `battle_view.gd` / `hud.gd` |
| R2-04 | 临时探针与录屏缓存散落：`tests/dev_smoke.gd`、`dev_facing.gd`、`dev_balance.gd`、`dev_leap.gd`、`dev_respawn.gd`、`shots/analyze_minimap.py`、`godot/shots/*` | 工作树 | — |
| R2-05 | CHANGELOG 的验证段缺少本轮实测数字（平衡、设备帧率、小地图像素判据） | `CHANGELOG.md` | — |

## 2. 修改方法

- **R2-01**：把 `_draw_world_bars(safe, h)` 移到 `_draw_battle_bg` 的最前面（面板/小地图/技能钮之后都被覆盖），
  保证所有 HUD 面板压在世界血条之上；3v3 同样生效（纯层级修正，不改数值）。
- **R2-02**：`main.gd` 增加 `--lv=N` 调试参数（N=2..5）：按 `xp_levels` 计算「该等级中段进度」的经验值
  （满级则取最后阈值），调用 `sim.add_xp` 一次性升到目标级；用于截图核对等级徽章与经验条。
  - 公式：L2/L3/L4 取 `(xp_levels[L-2] + xp_levels[L-1]) / 2`；L5 取 `xp_levels[3]`（条满）。
  - AGENTS §7 补一行说明。
- **R2-03**：桌面 `--skip-home --mode=5v5 --auto-run` 运行 15 秒，采集 `[FPS]` 与 `[VIEW] sync_ms`；
  判据 FPS ≥58、sync_ms ≤2.0（4.10 基线 1.4–2.3ms，允许持平）。
- **R2-04**：删除全部临时脚本与 `godot/shots` 录屏缓存；`shots/` 只保留本版交付截图
  （四向走位、Android 首页/5v5、桌面小地图三帧）。
- **R2-05**：CHANGELOG 验证段写入：
  - 平衡探针 10 局 5v5：平均 311s、0 超时、0 局 <120s、拆塔≥4 共 10/10、L5 平均 176s；
  - 3v3 五局 253–272s（冻结）；
  - 桌面/模拟器小地图：比例 1.000（5v5）/1.873（3v3）、中路 44.9–45.0°、英雄点 ⌀11px（1080p）；
  - Android 2400×1080：25–31fps（预热后）、无 SCRIPT ERROR。

## 3. 验收

| ID | 项目 | 标准 |
|----|------|------|
| V2-1 | 血条层级 | Android/桌面截图：小地图内不再出现任何 30px 以上的队伍色横条；世界血条在面板下沿被完全遮挡 |
| V2-2 | 等级 HUD | `--lv=3` 截图经验条金条宽度约为轨道的 50%±6%；`--lv=5` 恒满；等级徽章数字与等级一致 |
| V2-3 | 桌面性能 | 5v5 自动推进 15s：稳态 FPS ≥58、`[VIEW] sync_ms` ≤2.0 |
| V2-4 | 清理 | `git status` 无临时探针；`godot/shots` 不存在；未跟踪文件只剩交付截图与规格文档 |
| V2-5 | 回归 | 构建脚本内置 `SIM_OK`/`RULE_OK`/`FLOW_OK` 全绿；最终 APK 重新核验 code/证书/SHA |

## 4. 用户实机反馈追加（4.11.0-dev.2）

- **现象**：人物整体有点半透明，斜着走时感觉正脸透到了后脑勺。
- **根因**：`shaders/voxel.gdshader` 在 fragment 里写 `ALPHA = 1.0`。Godot 只要写 ALPHA 就把材质归入透明队列：
  不写深度、双面渲染（`cull_disabled`）、按物体排序。于是从背面能透看到正面的眼睛/嘴，身体/头部/四肢
  多个 MeshInstance 之间也会互相透叠，整只看起来发虚。
- **修改**：移除 `ALPHA` 写入与 `depth_draw_opaque`，改为纯不透明着色器。需要半透明的地方各自保留：
  建筑遮挡 `voxel_fade.gdshader`、药瓶/技能圈/水面 `_alpha_material`、弹体与特效材质。
- **验收**：桌面实拍向正上（背视）头部深色像素占比 1.3%，向正下（正视）12.3%——背后不再看到脸；
  截图 `shots/opaque-up.png` / `shots/opaque-down.png`。构建门禁全绿 + Android 覆盖安装复测。