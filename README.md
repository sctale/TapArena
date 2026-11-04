# 萌兽峡谷 TapArena

一个给 6–12 岁孩子玩的 **3v3 森林推塔小游戏**：清兵线、拆塔、推水晶。英雄使用 [Polyfork](https://polyfork.dev) 的免费低多边形动物（可商用、无需署名），没有抽卡、内购、广告，也不联网。

## 两个版本

| 版本 | 位置 | 说明 |
| --- | --- | --- |
| **Unity 版（3.2.0，主线）** | `unity/` | Unity 6000.3 工程：Polyfork 四足动物英雄 + Blender 服装配件 + Polyfork 森林场景道具 + 自制地形/塔/水晶/小兵 + 2D 选人立绘 + 应用图标，出 Android APK |
| Web 版（1.3，存档） | 仓库根目录 `www/`、`android/` | Three.js 3D 战场 + Android WebView 壳，已封存在 git 标签 `web-v1.3.0` |

备份：`D:/V-Coding/TapArena-web-v1.3.0-backup.zip`（含全部源码与素材，2.6MB）。

## Unity 版怎么跑

1. 双击 `打开Unity工程.cmd`（或 Unity Hub 打开 `unity/` 目录），Unity 6000.3.10f1。
2. 直接点 Play：场景是空的，`Boot.cs` 会在运行时把相机、灯光、地形、英雄全部建起来（工程里没有美术资源依赖）。
3. 出包：`bash tools/unity-build.sh`（先导出 Gradle 工程，再用外部 gradlew 构建；headless 下 Unity 会把 Gradle 堆算成 `-Xmx0m`，必须绕开），产物自动拷到根目录 `TapArena-v3.2.0.apk`。

操作：左下拖动摇杆移动（桌面 WASD/方向键），右下三个圆形按钮放技能（桌面 Q / E / R），Esc 或安卓返回键暂停。

美术资产重建（Blender 4.5 LTS，headless）：

```powershell
blender -b -P tools/polyfork_props.py       # 森林 kit 道具 -> Resources/PolyforkProps
blender -b -P tools/polyfork_to_fbx.py      # 六只动物 + Blender 服装 -> Resources/Heroes
blender -b -P tools/blender_game_art.py     # 地形/塔/水晶/小兵/首页地台 -> Resources/GameArt
Unity.exe -batchmode -quit -projectPath unity -executeMethod TapArena.EditorTools.ArtImport.Run
```

`ArtImport.Run` 会统一 FBX 导入设置、导出 `.anim`、重渲染 2D 立绘与图标，并打印 `[ART] RESULT=PASS`。**原始 GLB/FBX 不提交仓库**（Polyfork 授权只允许随游戏发布，不允许再分发文件本体）；`ArtSource/`、`Resources/Polyfork/`、`Resources/PolyforkProps/`、`Resources/Heroes/` 均在 `.gitignore` 中。

旧的 Blender 程序化英雄管线仍保留：`blender -b -P tools/blender_lowpoly.py` 会重写 `Resources/LowPoly/*.json`；当新英雄 FBX 缺失时 `PolyforkHero` 会依次回退到旧 Polyfork FBX、LowPoly JSON，保证工程仍能启动。

## Unity 版的结构

```
unity/Assets/Scripts/
  Core/Boot.cs        启动器：运行时建相机、灯光、氛围、UI、世界
  Core/Arena.cs       战斗规则：3v3、兵线、塔与水晶保护、18 个技能、AI、4:00 终极对决
  Core/HeroDefs.cs    六位英雄的属性与技能表（按 10–15 秒 TTK 重排，见 CHANGELOG 2.2.0）
  Visuals/PolyforkHero.cs  新英雄 FBX（含服装）→ 材质/骨骼/缩放/施法点，保留作者动画
  Visuals/PolyHeroView.cs  四足英雄视图：Idle/Walk 采样 + 咬击/施法/受击/阵亡叠加
  Visuals/ArtPropLibrary.cs 运行时加载 GameArt / PolyforkProps，缺失时回退程序化道具
  Visuals/Art.cs      程序化场景与回退：树/灌木/蘑菇、塔/水晶、小兵、地图贴图
  Visuals/Views.cs    表现层：地图/道具/结构/弹道/减速区/英雄视图
  Visuals/Fx.cs       火花、法阵、拖影、飘字、播报 + 3 个动态网格粒子批次 + 程序合成音效
  Systems/            InputHub（摇杆/键盘）、CameraRig（跟随/震屏/推镜）
  UI/Hud.cs           IMGUI：首页（含难度）、2D 选人、战斗 HUD、暂停、结算
tools/polyfork_props.py    Polyfork 森林 kit 道具下载 + 顶点色/接触阴影 + FBX
tools/polyfork_to_fbx.py   六只动物 + Blender 服装 + Idle/Walk/Run + hero_meta.json
tools/polyfork_costumes.py 六套低模服装/配件的生成器
tools/blender_game_art.py  自制地形/蘑菇塔/水晶/小兵/首页地台
tools/polyfork_manifest.json 批准使用的 Polyfork 资产清单
unity/Assets/Resources/GameArt/*      原创资产（入库）
unity/Assets/Resources/PolyforkProps/* Polyfork 派生道具（gitignore）
unity/Assets/Resources/Heroes/*        Polyfork 派生英雄 + 服装（gitignore）
unity/Assets/Resources/Splash/*.png   2D 选人卡与详情立绘
```

```
unity/Assets/Shaders/
  LowPoly.shader      Low Poly：顶点色 / 顶点 AO / 三段明暗 / 边缘光 / 描边 / 受击闪白 / GPU instancing
  LowPolyFlat.shader  场景无描边版：地形与植被，省掉描边 pass
  Toon.shader         旧场景卡通渲染（程序化回退用）
  Sky.shader          天空穹顶（512×128 运行时渐变全景）
  Glow.shader         廉价泛光 + 暗角 + 调色（掉帧自动关）
```

**画面**：英雄是 Polyfork 的平直着色 Low Poly 四足动物 + Blender 服装配件（帽子/披风/盾/背甲/箭袋/浮空物），自带 Idle/Walk/Run，战斗中的咬击、施法抬身、受击挤压和阵亡侧倒由 `PolyHeroView` 叠加；场景由 Polyfork Nature & Forest kit 的树/灌木/蘑菇/石头/木桥/灯笼，加上自制地形、蘑菇塔、水晶祭坛和小兵组成；2D 选人页用游戏内模型离屏渲染的 splash/bust，游戏内仍是 3D 模型。首页改成林间空地的苔藓土丘陈列，战场有兵线、河桥、树线、木屋/瞭望塔/石井地标。

设计约束：卡片、血条、名字都用 IMGUI 画（uGUI 在 shader 剥离后会变品红）；中文字体随包带 Noto Sans CJK SC 子集；`PlayerSettings.stripEngineCode = false`（否则原生 MonoBehaviour 被裁，IMGUI 每帧抛异常）；Toon/Sky/LowPoly 通过 `Resources/TapArenaToon.mat` / `TapArenaSky.mat` / `TapArenaLowPoly.mat` 带进包，避免被 shader 剥离；Android 图标由 `PlayerSettings.SetIconsForTargetGroup` 写入 6 个槽。

## Unity 版已验证（3.2.0）

- **阵容与服装**：阿狮（狮，战士，木盾/苔藓披肩）、灵灵（赤狐，法师，尖帽/浮空星）、朵朵（林兔，辅助，花环/挎包）、阿岳（黑熊，坦克，苔藓背甲/木肩片）、泡泡（青蛙，控制，水泡/芦苇披风）、尖尖（猫，射手，箭袋/护腕）。服装按骨骼权重 1 合并进同一张 SkinnedMesh，仍是一次绘制。
- **模型**：6 个 FBX 各带 22–26 根骨骼、Idle/Walk/Run 动画，合计约 2.0–4.1k 三角面/人；`hero_meta.json` 记录不含服装的 `bodyHeight`，缩放不再被帽子影响；`PolyHeroView` 按步态采样再叠加咬击/施法/受击/阵亡。
- **场景**：27 个 Polyfork 森林 kit 道具（树/灌木/蘑菇/石头/木桥/栅栏/灯笼/木屋/瞭望塔/石井）+ 自制 3000×1600 顶点色地形/河道、蘑菇塔、水晶祭坛、果冻小兵；植被按象限静态合批，植被不投射实时阴影。
- **2D 选人**：卡片 512×512 bust、详情 768×1152 splash、HUD/结算 256×256 透明头像，全部用新服装模型重渲染；首页/战斗都从同一套 3D 资产出发。
- **实机**：Android 16 模拟器（1080×1920 转横屏），v3.1.0/versionCode 25 → v3.2.0/versionCode 26 覆盖安装成功；首页、选人、战斗、移动、技能冷却、暂停、切后台自动暂停、结算“差一点点/再来一局”逐项检查；默认轻松 + 挑战各完整跑完一局（挑战 5:00 结算 17:20），logcat 无 Unity 异常。
- **帧率**：同一台软件渲染模拟器上 v3.2.0 约 35–38fps（v3.1.0 同机约 20–29fps）；场景 Renderer 从 294 降到 49（按材质合并静态批次）。冷启动到首页 `am start -W` TotalTime 2.03s。真实设备帧率待补测，模拟器数值只用于同机对比。
- **包体**：`TapArena-v3.2.0.apk` 30,409,196 字节（29.0MiB），versionCode 26，minSdk 25/targetSdk 37；签名 `CN=TapArena, OU=Games, O=sctale, C=CN`；SHA-256 `DE656CF14DA794FC061C3F58A5552E0B1A297866E9EC4C3B222226316238711A`（最终构建后如有变动以根目录 APK 为准）。
- **动画/内存**：18 个 `.anim` 源文件从 39.6MB 降到约 3.1MB（Idle 保留完整循环，导入 `Optimal` 压缩）；主路径不再生成 1280×683 地面贴图。
- **素材授权**：Polyfork 免费资产允许商用、无需署名，允许随游戏分发，但不允许把 GLB/FBX 文件本体再次分发；`unity/ArtSource/`、`Resources/Polyfork/`、`Resources/PolyforkProps/`、`Resources/Heroes/` 在 `.gitignore` 中，构建前用 Blender 脚本拉取。

## 素材授权

英雄模型来自 [Polyfork](https://polyfork.dev)，按其 [Licensing](https://polyfork.dev/licensing) 条款使用：可商用、可修改、无需署名；模型可以随游戏 APK 一起发布，但不能把 GLB/FBX 文件本体重新上传到仓库、素材站或文件分享服务。仓库因此只保留下载/转换脚本与游戏内渲染产物，原始 3D 文件不入库。

---

## Web 版存档：1.3.0 战场改成真 3D

- **俯视 2D 换成 Three.js 立体战场**：透视相机、平行光 + 半球光、实时软阴影、雾与纵深，峡谷变成一座可以俯视的沙盘；62 棵树与灌木从「画在地面上」改成了真立体道具。
- **六位英雄重新做成骨架模型**（每人 11–13 个部件），关节枢轴放在肩/髋/颈/尾根，动作由 `anim.js` 的关键帧通道驱动。
- **动作补了「发力链」**：出招先反拧腰再甩出去、身体前冲、受击沿来击方向后撤、走路对侧摆臂、头部滞后跟随转体——这些是「看着顺不顺手」的关键。
- **遮挡淡出**：比主角更靠近镜头的树和塔会自动变半透明，解决 3D 特有的「前景挡住战场」。
- 名字、血条、伤害数字仍走 2D 投影叠加，任何 DPI 下都清晰；`?render=2d` 可强制回退到原 2D 画面，探测不到 WebGL 时也会自动回退。

已知不足：角色建模是首轮产物（尾巴偏粗、条纹是贴附外壳片），命中火花还没换成 3D 粒子，低端机帧率略低于 2D 版。详见 [CHANGELOG.md](CHANGELOG.md)。

## 怎么玩

1. 选一位小英雄：阿狮（狮，战士）、灵灵（赤狐，法师）、朵朵（林兔，辅助）、阿岳（黑熊，坦克）、泡泡（青蛙，控制）、尖尖（猫，射手）；双方各 3 位、互不重复。
2. 跟随小果冻兵线往右走，先拆掉敌方两座蘑菇塔。
3. 两座塔都拆掉后，敌方水晶护盾消失，攻击水晶就能获胜。
4. 4 分钟进入“终极对决”：双方水晶护盾全部消失，水晶可以直接攻击；5 分钟按水晶剩余血量判定，保证一局能结束。

目标是让第一次玩的小朋友也能看懂：**往右走 → 打塔 → 打水晶**。角色会自动攻击附近敌人，技能会自动瞄准。

### 操作

| 平台 | 移动 | 技能 |
| --- | --- | --- |
| 手机 / 平板 | 左下角拖动摇杆 | 右下角三个圆形技能键（大招 2 级解锁） |
| 电脑 | WASD / 方向键 | Q / E / R 技能 |
| 难度 | 首页“轻松/挑战” | 默认轻松；挑战提高 AI 主动性与敌方伤害 |
| 暂停 | 右上角暂停键或 P / Esc | 暂停面板里可开关音效、重开、回首页 |

## 安卓版

安装 `TapArena-v3.2.0.apk` 即可，首次启动不需要任何权限。应用包名 `com.sctale.taparena`，版本 3.2.0（versionCode 26），最低 Android 7.1（API 25），targetSdk 37。

- 签名：`CN=TapArena, OU=Games, O=sctale, C=CN`（与 1.3.0 同一把 release keystore，可直接覆盖安装）
- SHA-256：`DE656CF14DA794FC061C3F58A5552E0B1A297866E9EC4C3B222226316238711A`
- 体积：30,409,196 字节（29.0MiB）

- 横屏锁定；支持刘海屏；全屏沉浸式。
- 返回键：在战斗中按下会打开暂停面板，不会直接退出；切后台/失去焦点自动暂停。
- 数据只保存在本机（音效偏好），不联网、不上传。

## Web 存档：开发 / 构建

HTML 版是纯原生 Canvas + JavaScript，无构建步骤、无外部 CDN：

```text
www/
  index.html
  css/style.css
  js/data.js     英雄/技能/数值
  js/render.js   程序化地图与角色绘制
  js/anim.js     关键帧动画 clip 数据与采样（动作时长/缓动都在这儿）
  js/stage.js    Phaser 3 特效层（WebGL 粒子，失败自动回退）
  js/game.js     战斗逻辑、AI、UI、音效
  js/vendor/phaser.min.js  Phaser 3.90（离线打包，无 CDN 依赖）
  assets/        AI 生成的英雄立绘与首页背景
```

安卓壳是一个原生 WebView 工程，离线加载 `android/app/src/main/assets/www`。构建发布包（会同步最新 HTML、签名、验签、检查清单）：

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

产物：项目根目录 `TapArena-v1.3.0.apk`。

### 视觉 / 性能自检脚本

```powershell
node tools/visual.js    # 三位英雄 待机·攻击·施法·受击·大招·阵亡 定格截图 + 混战帧率
node tools/closeup.js   # 只截玩家周围的特写，检查肢体与弧光
node tools/perf.js      # CDP 把 CPU 降频 4× / 6×，量手机端帧率余量
node tools/sim3.js      # 纯逻辑 AI 对局模拟
```

这些脚本依赖 `window.__TA` 上的调试入口（`stage` 摆位、`still` 定格、`pose` 指定动作进度）。它们只服务于自动化检查，不是给玩家玩的功能，改动战斗表现时不要删。

> 签名文件：`keystore/taparena-release.keystore` + `keystore.properties`（均被 gitignore）。**务必自行备份**，丢失后无法覆盖升级。

## Web 存档：已验证

- **数值**：12 局 AI 模拟（六位英雄轮流当玩家，轻松/挑战混合）全部正常结束，最快 123.7s；每一局胜方都是先拆 2 座塔才破水晶，新技能没有绕过保护规则。
- **全流程**：Playwright 桌面 1440×900、手机横屏 900×430、竖屏 390×844；选人页 6 张卡无溢出、"出发"始终可见；首页→选人→战斗→暂停→结算无页面错误。
- **动作**：六位英雄 × 待机/攻击/施法/受击 定格截图逐张目视检查（`node tools/newheroes.js`）。
- **帧率**：`node tools/perf.js`（CDP CPU 降频）3D 模式桌面 4× 53.8fps、手机 4× 58.6fps、6× 40.6fps；同机 2D 回退模式 6× 约 44fps。
- **模拟器实机**（Android 16，1080×1920 转横屏）：v1.2.0 → v1.3.0 覆盖安装成功，首页角标 v1.3；3D 战场正常渲染（树影、遮挡淡出、技能环、击杀播报、摇杆、小地图都在），阿岳骨架站姿与血条投影位置正确。
- **WebGL 可行性探针**（`www/spike3d.html`）：同一台模拟器的 WebView 里 90 个 7 部件角色 + PCFSoft 阴影跑到 57fps（DPR 2），证明 3D 选型可用；Phaser 那条 WebGL 路径的失败是它自己的渲染目标配置问题。
- **APK 签名**：`CN=TapArena, OU=Games, O=sctale, C=CN`；清单 `versionCode=4 versionName=1.3.0`；`TapArena-v1.3.0.apk` SHA-256：`AC9C0C59D2E929FC1E9A1FCD51B70A1C5C34716DCB23F3F989036E6E0AD978BA`。

### 自检脚本

```powershell
node tools/sim3.js        # AI 对局模拟（数值与结束条件）
node tools/mobile.js      # 手机横竖屏全流程
node tools/visual.js      # 三位老英雄动作定格 + 混战帧率
node tools/newheroes.js   # 六位英雄动作定格 + 选人页布局
node tools/closeup.js     # 玩家周围特写，检查肢体与弧光
node tools/perf.js        # CPU 降频后的帧率余量
node tools/fxtest.js      # Phaser 特效层启动状态
```

这些脚本依赖 `window.__TA` 上的调试入口（`stage` 摆位、`still` 定格、`pose` 指定动作进度）和 `window.__FX_DISABLE` / `window.__FX_FORCE_CANVAS` 两个特效层开关。它们只服务于自动化检查，不是给玩家玩的功能，改战斗表现时不要删。

## 素材说明

首页背景、三位英雄立绘和应用图标均由 AI 生成，专为本项目制作；没有使用《王者荣耀》或其他商业游戏的图片、音频、UI 素材。玩法机制属于通用 MOBA 规则，未复制任何具体角色、外观或文案。
