# SPEC — 体素视觉对齐宣传片风格（英雄/小兵/野怪/巨兽/建筑/物件/环境）

状态：已实施（4.14.0，待发布验收）
日期：2026-11-18
版本目标：4.14.0 / versionCode 53
参考源：`D:\V-Coding\taparena_video\TapArena-promo-v2.0.mp4`（自有资产）。
色板/造型/光照参数取自该工程 `blender/build_assets.py` 与 `godot/scripts/Main.gd`，不抄外部素材。

## 0. 现状诊断（为什么游戏比视频"暗、脏、平"）

| 维度 | 视频 | 游戏现状 | 结论 |
| --- | --- | --- | --- |
| 光照 | 太阳 DirectionalLight 2.6 + 阴影 + 天空环境光 0.34 + FILMIC 0.80 + 饱和 1.12 | `voxel.gdshader` unshaded，面明暗烘焙进调色板；**无太阳、无阴影、无 tonemap** | 最大差距，先改 |
| 贴图 | 每像素 ±8 微噪 + 少量草叶/白花点缀，干净 | 噪点密度 0.42–0.55、多档强对比，显脏 | 换配方 |
| 英雄 | 眼睛高光+腮红；navy 裤子+深色鞋；五套服饰（虎盾/狐帽杖/兔花环裙/熊巾盾/螈鳃鳍） | 无高光腮红；裤子=毛色加深显脏；只有围巾无服饰 | 补细节 |
| 建筑 | 蘑菇塔奶油柄+亮队色盖+**顶旗**；水晶底座两队同奶油石 | 红方柄/底座偏棕黑；无旗；红水晶暗 | 对齐 |
| 环境 | 云、花、草丛、苔藓巨兽、亮树 | 无云/花/草丛；树偏暗；巨兽纯灰 | 补点缀 |

## 1. 目标与范围

把战斗世界的视觉语言整体对齐宣传片：明亮、通透、有太阳阴影、细节更萌。
**只改表现层与配色数据**：

- 改：`scripts/art/pixel_atlas.gd`、`scripts/art/block_models.gd`、`scripts/art/voxel_model.gd`（面明暗常数）、
  `shaders/voxel.gdshader`、`shaders/voxel_fade.gdshader`、`scripts/view/battle_view.gd`（光照/环境/散布/物件）、
  `data/heroes.json` **仅颜色字段**。
- 不动：`battle_sim.gd`、`rules.json`、HUD/首页/详情页布局、`www/`、`android/`、`build.ps1`、`开始游戏.cmd`；
  不引入 GLB/Blender 管线（现有 GDScript 体素管线保留，动画 pivots 保留）。

## 2. 逐条改动

### T1 光照与影调（先做，收益最大）
- [x] `battle_view._build_world` 加太阳：`light_color #FFE6BC`、`energy 2.6`、方向同视频比例
      `(66,34,26)→原点`；`shadow_enabled`、`SHADOW_PARALLEL_2_SPLITS`、`max_distance 900`、
      `bias 0.6 / normal_bias 2.0`（初值，按截图痤疮/悬浮调）。
- [x] 补光 `#D6ECFF 0.14` 无阴影，方向 `(-30,22,40)`。
- [x] Environment：`ambient SOURCE_SKY 0.34`；`TONEMAP_FILMIC exposure 0.80`；
      `adjustment_saturation 1.12 / contrast 1.06`；`glow intensity 0.22 / bloom 0.02 / hdr_threshold 1.25`；
      薄雾 `fog_density 0.00002`（视频 0.0016 ÷ 尺度≈80）、`fog_light_color #CCE7F6 energy 0.38`、`sky_affect 0.35`。
      **不开 SSAO**（Android 性能，视频有但游戏取舍掉）。
- [x] `voxel.gdshader` / `voxel_fade.gdshader` 去掉 `unshaded`（保留 palette/UV2 方案，**不用顶点色**，
      不写 ALPHA 的纪律不变）；`voxel_model._shade_for` 放宽为 top 1.0 / 前后 0.97 / 左右 0.93 / 底 0.80，
      避免与真光照双重压暗。
- [x] 地面/兵线路/河道/路缘/山丘材质改 shaded（能接阴影）；技能圈/药瓶光晕等 alpha 特效保持 unshaded。
- [x] `cast_shadow` 开启：英雄/小兵/野怪/巨兽/塔/水晶/树/石头/蘑菇/路牌/山丘；
      关闭：路缘、云、alpha 特效、HUD 无关。
- [x] 性能兜底单一开关 `shadow_quality`（high/low）：low = 1 split + max_distance 600 + 树/石 MultiMesh 关阴影 + glow 关。
      模拟器实测 fps 不达标即切 low 复测（见 §4）。

### T2 贴图集换视频配方（`pixel_atlas.gd`，16px 适配）
- [x] `grass_top`：base `#6fb84f` 每像素 ±8 微噪 + 3 条深色草叶(`base-26/-22/-18`) + 2 粒奶油花点 `#f6ecb2`。
- [x] `path`：base `#dcc9a4` ±7 + 5 粒 `#c4b08c`（去掉现在 4 档强噪点）。
- [x] `leaves`：base `#5ca84a` ±9 + 3 块 2×2 亮斑(+20/+18/+14)。
- [x] `log_side`：base `#96704c` ±8 + 每 3px 竖条纹 `#7e5c3c` + 3 块亮斑 `#a88058`。
- [x] `stone`：base `#d8d2c2` ±8 + 4 粒 `#c0baaa`；`fur` 噪点降为 ±5。
- [x] 新增瓦片：`water #7ec6e2`、`moss #6c9852`、`blush #f49ea6`、`navy #485474`、`wood #b28c5c`、
      `purple #8060b8`、`purple_light #a486d6`、`pink #f6aebc`、`cream #f0e8d2`。
- [x] 队色对齐：`mushroom_blue` base `#4fc3e8`、`mushroom`(红) base `#f0845c`（白斑保留）；
      河道改用 `water` 瓦片、alpha 0.9。

### T3 英雄脸与基础骨架（`block_models._humanoid_base` + `heroes.json` 颜色）
- [x] 每只眼加 1px 白色高光；两颊加 3×1 腮红（`blush`）。
- [x] 裤子默认 `navy`、鞋 `dark #3a3432`（替换"毛色加深"）；`heroes.json` 增可选 `pants` 字段：
      rabbit `pink`、bear `wood`，其余 navy。
- [x] 五主角毛色对齐视频：tiger `#f29842`/fox `#ee9648`/rabbit `#f6f0e8`/bear `#b07e54`/axolotl `#92c2e8`，
      cream 统一暖白 `#faeeda` 系；其余 10 只暗毛色提亮 10–15%、物种识别色保留（熊猫黑白等）。
      **只改颜色字段，数值字段一律不动。**

### T4 英雄服饰（15 只，视频 5 套照搬、其余同语言设计；单位换算≈视频×80）
- [x] tiger：绿围巾环+前垂巾；左臂圆盾（wood 22×22×4 + 绿盾心 8×8×2）。
- [x] fox：紫巫师帽（檐 37×4×35 / 身 24×18 / 斜顶 16×13 + 金星）；紫袍摆+浅紫边；右臂星杖（金杆+十字星）。
- [x] rabbit：头顶 8 朵小花环（pink/white/gold 循环）；粉裙+白裙摆；胸前蝴蝶结 3 盒。
- [x] bear：绿领巾+垂尖；左臂小圆盾（wood + 金盾心）。
- [x] axolotl：外鳃改 pink + 鳃尖 blush；背部小鳍。
- [x] 其余 10 只各 2–4 盒同语言配件：cat 青围巾+金铃；panda 右臂竹竿；owl 深蓝学者巾+金星徽；
      frog 荷叶帽+粉花；deer 左胯奶油挎包；turtle 红侦察巾；hedgehog 红围巾+浆果背袋；
      redpanda 金围巾+奶油尾尖；wolf 深蓝巾+白牙项链；crane 金腿环。
- [x] 配件盒必须落入正确 `_part_of` 部件（帽/冠→head，盾/杖/竹→arm，裙/巾→body），走路摆臂不穿帮。

### T5 小兵与野怪
- [x] 蓝果冻体色提亮到 `#4fc3e8` 系、脸加眼高光；红尖刺怪 `#f0845c`、刺/爪改暖深棕 `#6a4a3a`，熔岩核心保留。
- [x] 野怪提亮+奶油吻部+眼高光：boar `#b08050`、wolf `#a8b2be`、crab `#e07850`。

### T6 巨兽
- [x] 石甲改暖灰 `#8a867e` / 深 `#5f5b54`；肩/头顶/背加 `moss` 苔藓块；金角与队色核心保留；
      飞行石翼提亮 `#cfc8d8` + 苔藓翼缘。

### T7 建筑与废墟
- [x] 蘑菇塔：两队菌柄都改奶油 `cream`；菌盖用 T2 新队色；**顶部加旗杆+队色旗**（替换现有顶部发光块，
      旗下保留小发光核心）。
- [x] 水晶底座：红方改与蓝方同奶油石台；红角柱改 `crystal_red` 晶柱（替换暗砖+熔岩）；能量环改队色晶体。
- [x] 水晶：蓝 `#92e4f8` 系、红 `#faa06e` 系（替换暗红）。
- [x] 塔废墟/基地废墟/装饰蘑菇/路牌：用新瓦片与奶油石色统一提亮（装饰蘑菇盖 `#e27860`）。

### T8 环境点缀
- [x] 树冠三档 `#5ca84a / #4a923e / #74be5a`；树干用新 bark 配方。
- [x] 新增散布：草丛 ~40 处（2–3 盒亮绿）、小花 ~24 处（茎+pink/gold/white 头）、
      体素云 6–8 朵悬于 y 320–460（`cloud` 瓦片，不投影，可缓慢漂移）。
- [x] 路缘石提亮奶油色；山丘草侧提亮；天空顶改 `#4aa8dc`、地平线 `#b9e4f5`（截图核对）。

### T9 药瓶
- [x] 改不透明体素小瓶（绿玻璃 `#58c878` + 浅绿颈 + 木塞 + 白十字），进 `BlockModels.potion()`；
      脚下 alpha 光晕环保留。

## 3. 验收

- [x] 门禁：`sim_headless`（`SIM_OK` 10 局 + 全部子项）/ `flow_headless`（`FLOW_OK`，含新增调色板断言）全绿，逻辑零改动。
- [x] 桌面截图逐类核对：3v3 兵线、5v5 俯瞰、塔、蓝/红基地、巨兽、飞兽、废墟、15 英雄走路特写；与 `taparena_video` 抽帧并排目视：明亮通透、阴影干净无痤疮、服饰/队旗/花可见、帽子/盾牌/法杖/裙摆随对应关节不穿帮。
- [x] PIL 审计：同机位兵线帧平均亮度 157.0（4.13 worktree 基线 152.4），`max(RGB)<20` 像素 0.00%；虎/兔特写检出白色高光与腮红像素。
- [x] 调色板不超 64：`flow_headless` 对 3v3/5v5 两次战斗的全部模型断言 `palette ≤ 64` 且 `palette_overflow == 0`。
- [x] 性能：Android 16 模拟器（2400×1080，`-gpu host`）5v5 稳定段 11 个采样平均 25.2fps（22.1–30.1 波动，结果页 38fps），达到 ≥24 且与 4.13 基线 25–28 持平；high 档即达标，未切 low。
- [x] 模拟器 E2E：首页→选角详情→5v5 开局→整局（4:20 水晶被摧毁）→双队结算→回首页，`SCRIPT ERROR`/`Parse Error` 计数 0；结算/详情 UI 正常。
- [x] 发布：4.14.0 / code 53，本地 `tools/godot-build.ps1`；aapt2 包名 `com.sctale.taparena`/53/4.14.0/arm64、apksigner `CN=TapArena`；APK 落根目录 `TapArena-v4.14.0.apk`（27,397,520 字节，SHA-256 `32BA7292…A45DA682`）；push + Release（--notes-file）+ 资产回读下载哈希一致。
- [x] 构建前删 `godot/shots`；SPEC 勾选随代码同提交。

## 4. 验证方法

```bash
# 门禁
godot --headless --path godot --script tests/sim_headless.gd
godot --headless --path godot --script tests/flow_headless.gd
# 截图（目录须工程内已存在；用完构建前删 godot/shots）
godot --path godot --skip-home --no-hud --look-lane --fixed-fps 30 --write-movie shots/style/lane3.png
godot --path godot --mode=5v5 --skip-home --top --no-hud ... --write-movie shots/style/top5.png
# 塔/基地/巨兽/废墟：--look-tower / --look-base / --boss / --boss-fly / --ruins
# 英雄特写：--hero=<id> --walk=1 --no-hud（15 只逐只）
# 性能与 E2E：模拟器 test-android-36 -gpu host，adb 路径见项目记忆
```

## 4.1 实施偏差（4.14.0 实测记录）

GL Compatibility 的 3D 光照是「sRGB 直出叠加」的近似，不是 Forward+ 的线性光照 + FILMIC 曲线；
照抄宣传片的 2.6 / 0.34 / 0.80 会把奶油路与草地直接打爆，且 `AMBIENT_SOURCE_SKY` 会让
ProceduralSky 的地面绿色成为环境色（全场景发绿）。因此最终落地值按截图实测标定：

- 太阳：`#FFE6BC`、能量 `0.55`、方向 `(60,58,74)`（比宣传片的 `(66,34,26)` 更偏高，俯视镜头下角色正脸才受光）；
  阴影参数保持 `2 splits / max 900 / bias 0.6 / normal_bias 2.0`（low 档改单级 / 600）。
- 环境：`AMBIENT_SOURCE_COLOR` `#cfe4f5` × `0.28`；`FILMIC exposure 0.85`；调整 1.12/1.06；雾密度 `0.00002`。
  glow 参数保留但 Compatibility 不支持，实际无泛光；SSAO 依旧不开。
- 图集纹理由运行时 `ImageTexture` 生成，不加 `albedo_texture_force_srgb`（该开关在 Compatibility 下会二次解码，
  绿色/黄色单独压暗）；体素调色板同样按原始 sRGB 数值采样，与地面管线一致。
- `path` 瓦片基色由 `#dcc9a4` 微调到 `#cfbd99`，在 0.55 阳光 + 0.28 冷环境光下落在宣传片的米色区间。
- 云在 `--top` 俯瞰调试模式下不生成（否则悬在镜头前挡满屏）；正常镜头不显示云，仅留作高视角装饰。
- 装饰花草避开建筑半径（`_near_structure`），不再长到祭坛上。

## 5. 风险与兜底

- Android ANGLE 驱动：palette/UV2 方案不变、不引顶点色；若 shaded 出现通道异常，回退 unshaded+烘焙常数（保留旧值分支）。
- fps 下降：T1 的 `shadow_quality` 单开关降级。
- 部件误分类（帽子随臂摆）：T4 截图走路逐只核对，必要时调 `_part_of` 阈值。
- 同一问题两轮修不好：停止猜测，回看视频工程对应实现照做。