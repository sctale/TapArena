# 萌兽峡谷 TapArena

一个给 6–12 岁孩子玩的 **3v3 森林推塔小游戏**：清兵线、拆塔、推水晶，所有角色都是原创萌兽，没有抽卡、内购、广告，也不联网。

## 两个版本

| 版本 | 位置 | 说明 |
| --- | --- | --- |
| **Unity 版（2.0.1，主线）** | `unity/` | Unity 6000.3 工程，卡通渲染（描边/三段明暗/边缘光）+ 天空穹顶 + 真 3D 战场 + 骨架动画 + 实时阴影 + IMGUI HUD，出 Android APK |
| Web 版（1.3，存档） | 仓库根目录 `www/`、`android/` | Three.js 3D 战场 + Android WebView 壳，已封存在 git 标签 `web-v1.3.0` |

备份：`D:/V-Coding/TapArena-web-v1.3.0-backup.zip`（含全部源码与素材，2.6MB）。

## Unity 版怎么跑

1. 双击 `打开Unity工程.cmd`（或 Unity Hub 打开 `unity/` 目录），Unity 6000.3.10f1。
2. 直接点 Play：场景是空的，`Boot.cs` 会在运行时把相机、灯光、地形、英雄全部建起来（工程里没有美术资源依赖）。
3. 出包：`bash tools/unity-build.sh`（先导出 Gradle 工程，再用外部 gradlew 构建；headless 下 Unity 会把 Gradle 堆算成 `-Xmx0m`，必须绕开），产物自动拷到根目录 `TapArena-v2.0.1.apk`。

操作：左下拖动摇杆移动（桌面 WASD/方向键），右下三个圆形按钮放技能（桌面 Q / E / R），Esc 或安卓返回键暂停。

## Unity 版的结构

```
unity/Assets/Scripts/
  Core/Boot.cs        启动器：运行时建相机、灯光、氛围、UI、世界
  Core/Arena.cs       战斗规则：3v3、兵线、塔与水晶保护、18 个技能、AI、8 分钟终极对决
  Core/HeroDefs.cs    六位英雄的属性与技能表（数值与 Web 版一致）
  Visuals/Art.cs      程序化美术：英雄骨架、树/灌木/蘑菇、塔/水晶、小兵、地图贴图
  Visuals/Views.cs    表现层：HeroView 动画驱动、WorldView 同步单位与弹道/减速区
  Visuals/Fx.cs       火花、法阵、拖影、飘字、播报 + 程序合成音效
  Systems/            InputHub（摇杆/键盘）、CameraRig（跟随/震屏/推镜）
  UI/Hud.cs           IMGUI：首页、选人、战斗 HUD、暂停、结算
```

```
unity/Assets/Shaders/
  Toon.shader         卡通渲染：三段明暗 / 边缘光 / 外扩描边 / 接收阴影
  Sky.shader          天空穹顶（等距柱状全景，运行时生成）
  Glow.shader         廉价泛光 + 暗角 + 调色（掉帧自动关）
```

**画面**：天空是运行时生成的渐变全景（太阳光晕 + 云带），远景一圈低多边形山丘与松树线，地图外还有一层大地，边缘藏进雾里；兵线跨河的地方有木桥和灯笼；蘑菇塔有伞盖斑点、金环、发光窗和旗帜；水晶祭坛有三层石台、四柱灯、八面体水晶和环绕碎片。角色有眼白/瞳孔/高光/眉毛/腮红，描边把轮廓从背景里挑出来。

设计约束：卡片、血条、名字都用 IMGUI 画（uGUI 在 shader 剥离后会变品红）；中文字体随包带 Noto Sans CJK SC 子集；`PlayerSettings.stripEngineCode = false`（否则原生 MonoBehaviour 被裁，IMGUI 每帧抛异常）；Toon/Sky 通过 `Resources/TapArenaToon.mat` / `TapArenaSky.mat` 带进包，避免被 shader 剥离。

## Unity 版已验证

- **模型重做**：六位英雄换成大头短肢的玩偶比例；大眼白/瞳孔/双高光/睫毛/细眉/小口鼻/腮红；两段手臂（肩/上臂/前臂/手掌/拇指）和两段腿（大腿/膝/小腿/脚）；布料噪点材质；虎纹与围巾、狐狸尖吻与巫师帽、兔子花环与双层裙、熊叶盾与叶披风、水獭贝壳与水泡、刺猬侧刺与背带。展示台六人完整入镜。
- **动作修正**：四肢原来绕 X 轴在身体两侧横摆，已改为绕 Z 轴前后摆；走路有膝弯、攻击有蓄力-甩出-收势、施法抬臂；头会朝镜头偏转最多 30°，战斗中能看到脸。
- **模拟器实机**（Android 16，1920×1080 横屏）：首页、选人、出生、水平兵线、木桥、混战、升级大招、冷却、塔/水晶血条、死亡倒计时、复活、暂停（继续/重开/回首页/音效）、返回键逐项检查；战斗内计时、AI、兵线、技能、伤害飘字全部推进；结算面板（胜利/失败 → 再来一局/回首页）用临时短局验证；无异常日志。
- **帧率**：战斗内每 5 秒采样，40–59fps（模拟器负载波动时最低 33fps）；重开世界重建时有一次 27fps 的瞬时毛刺。
- **已修的关键 bug**：塔/基地/小兵没初始化 `cds` 导致战斗每帧空引用；相机不跟随；锥体/八面体绕序反了显示成黑块；阵亡小兵尸体不回收；小兵每帧跳兵线路点（直线冲家）；大招只能靠击杀升级；返回键暂停两次；暂停菜单下半部分按钮被透明层吃掉点击；返回首页/重开时旧战场没销毁（会叠图）；终极对决 AI 不拆家导致对局无限拖。

---

## Web 版存档：1.3.0 战场改成真 3D

- **俯视 2D 换成 Three.js 立体战场**：透视相机、平行光 + 半球光、实时软阴影、雾与纵深，峡谷变成一座可以俯视的沙盘；62 棵树与灌木从「画在地面上」改成了真立体道具。
- **六位英雄重新做成骨架模型**（每人 11–13 个部件），关节枢轴放在肩/髋/颈/尾根，动作由 `anim.js` 的关键帧通道驱动。
- **动作补了「发力链」**：出招先反拧腰再甩出去、身体前冲、受击沿来击方向后撤、走路对侧摆臂、头部滞后跟随转体——这些是「看着顺不顺手」的关键。
- **遮挡淡出**：比主角更靠近镜头的树和塔会自动变半透明，解决 3D 特有的「前景挡住战场」。
- 名字、血条、伤害数字仍走 2D 投影叠加，任何 DPI 下都清晰；`?render=2d` 可强制回退到原 2D 画面，探测不到 WebGL 时也会自动回退。

已知不足：角色建模是首轮产物（尾巴偏粗、条纹是贴附外壳片），命中火花还没换成 3D 粒子，低端机帧率略低于 2D 版。详见 [CHANGELOG.md](CHANGELOG.md)。

## 怎么玩

1. 选一位小英雄：阿虎（战士）、灵灵（法师）、朵朵（辅助）、阿岳（坦克）、泡泡（控制）、尖尖（射手）；双方各 3 位、互不重复。
2. 跟随小果冻兵线往右走，先拆掉敌方两座蘑菇塔。
3. 两座塔都拆掉后，敌方水晶护盾消失，攻击水晶就能获胜。
4. 6 分钟进入“终极对决”：双方水晶护盾全部消失，水晶可以直接攻击；8 分钟按水晶剩余血量判定，保证一局能结束。

目标是让第一次玩的小朋友也能看懂：**往右走 → 打塔 → 打水晶**。角色会自动攻击附近敌人，技能会自动瞄准。

### 操作

| 平台 | 移动 | 技能 |
| --- | --- | --- |
| 手机 / 平板 | 左下角拖动摇杆 | 右下角三个圆形技能键（大招 2 级解锁） |
| 电脑 | WASD / 方向键 | Q / E / R 技能 |
| 暂停 | 右上角暂停键或 P / Esc | 暂停面板里可开关音效、重开、回首页 |

## 安卓版

安装 `TapArena-v2.0.1.apk` 即可，首次启动不需要任何权限。应用包名 `com.sctale.taparena`，版本 2.0.1（versionCode 21），最低 Android 7.1（API 25），targetSdk 37。

- 签名：`CN=TapArena, OU=Games, O=sctale, C=CN`（与 1.3.0 同一把 release keystore，可直接覆盖安装）
- SHA-256：`8ce76d86231a2b94bf8368e3945e6c1c17012dc34f2ecdc292ab929f10abfa25`

- 横屏锁定；支持刘海屏；全屏沉浸式。
- 返回键：在战斗中按下会打开暂停面板，不会直接退出。
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
