# 萌兽峡谷 TapArena

一个给 6–12 岁孩子玩的 **3v3 森林推塔小游戏**。玩法借鉴 MOBA 的“清兵线、拆塔、推水晶”，但节奏更短、规则更简单，所有角色都是原创萌兽，没有抽卡、内购、广告，也不联网。

- HTML 试玩版：`www/index.html`（横屏，建议 Chrome / Edge）
- 安卓版：`TapArena-v1.2.0.apk`（Android 7.0+，锁横屏，离线运行，无网络权限）

![首页](previews/home.jpg)
![选英雄](previews/select.jpg)
![战斗](previews/battle.jpg)
![结算](previews/result.jpg)

## 1.2.0 更新：六位英雄与动画系统

- **新增三位可玩英雄**，英雄池 6 位、仍然 3v3：阿岳（棕熊坦克：荷叶拍击 / 熊抱一下 / 山崩地裂）、泡泡（水獭控制：大水泡 / 滑水冲刺 / 瀑布冲击）、尖尖（刺猬射手：三连尖刺 / 缩成刺球 / 万刺齐发）。
- **动作改成关键帧驱动**（`www/js/anim.js`）：每个动作都是「蓄力 → 爆发 → 命中停顿 → 收势」的数据轨道，熊最重、水獭最轻快、刺猬出手先缩再弹；动作时长不再散落在逻辑和渲染两处。
- **有了顿帧**：打中人的瞬间把世界时间压到 18%（45–60 毫秒）并轻微推镜，击杀和拆塔更强——这是手感提升最大的一块。
- 命中火花、脚底尘土、技能星屑改由 **Phaser 3 的粒子池**绘制（`www/js/stage.js`）；WebGL 不可用时自动退回原来的 Canvas 特效，不会黑屏也不会少特效。
- 选人界面改成 2×3 网格，新增「最好上手 / 最抗打 / 要会走位」角标。

完整变更见 [CHANGELOG.md](CHANGELOG.md)。

## 怎么玩

1. 选一位小英雄：阿虎（战士）、灵灵（法师）、朵朵（辅助）、阿岳（坦克）、泡泡（控制）、尖尖（射手）；双方各 3 位、互不重复。
2. 跟随小果冻兵线往右走，先拆掉敌方两座蘑菇塔。
3. 两座塔都拆掉后，敌方水晶护盾消失，攻击水晶就能获胜。
4. 8 分钟进入“终极对决”：双方水晶护盾全部消失，水晶可以直接攻击，保证一局能结束。

目标是让第一次玩的小朋友也能看懂：**往右走 → 打塔 → 打水晶**。角色会自动攻击附近敌人，技能会自动瞄准。

### 操作

| 平台 | 移动 | 技能 |
| --- | --- | --- |
| 手机 / 平板 | 左下角拖动摇杆 | 右下角 Q / W / E 技能（E 大招 2 级解锁） |
| 电脑 | WASD / 方向键 | Q / W / E 技能 |
| 暂停 | 右上角暂停键或 P / Esc | 暂停面板里可开关音效、重开、回首页 |

## 安卓版

安装 `TapArena-v1.2.0.apk` 即可，首次启动不需要任何权限。应用包名 `com.sctale.taparena`，版本 1.2.0，最低 Android 7.0（API 24）。

- 横屏锁定；支持刘海屏；全屏沉浸式。
- 返回键：在战斗中按下会打开暂停面板，不会直接退出。
- 数据只保存在本机（音效偏好），不联网、不上传。

## 开发 / 构建

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

产物：项目根目录 `TapArena-v1.2.0.apk`。

### 视觉 / 性能自检脚本

```powershell
node tools/visual.js    # 三位英雄 待机·攻击·施法·受击·大招·阵亡 定格截图 + 混战帧率
node tools/closeup.js   # 只截玩家周围的特写，检查肢体与弧光
node tools/perf.js      # CDP 把 CPU 降频 4× / 6×，量手机端帧率余量
node tools/sim3.js      # 纯逻辑 AI 对局模拟
```

这些脚本依赖 `window.__TA` 上的调试入口（`stage` 摆位、`still` 定格、`pose` 指定动作进度）。它们只服务于自动化检查，不是给玩家玩的功能，改动战斗表现时不要删。

> 签名文件：`keystore/taparena-release.keystore` + `keystore.properties`（均被 gitignore）。**务必自行备份**，丢失后无法覆盖升级。

## 已验证

- **数值**：12 局 AI 模拟（六位英雄轮流当玩家，轻松/挑战混合）全部正常结束，最快 123.7s；每一局胜方都是先拆 2 座塔才破水晶，新技能没有绕过保护规则。
- **全流程**：Playwright 桌面 1440×900、手机横屏 900×430、竖屏 390×844；选人页 6 张卡无溢出、"出发"始终可见；首页→选人→战斗→暂停→结算无页面错误。
- **动作**：六位英雄 × 待机/攻击/施法/受击 定格截图逐张目视检查（`node tools/newheroes.js`）。
- **帧率**：`node tools/perf.js`（CDP CPU 降频）桌面 4× 55fps、手机尺寸 4× 57fps、6× 44fps；不降频 60fps。
- **模拟器实机**（Android 16，1080×1920 转横屏）：v1.1.0 → v1.2.0 覆盖安装成功，首页角标 v1.2；选中新英雄阿岳后开局，1420 血、三个新技能图标与冷却均正常；`dumpsys gfxinfo` 8 秒 485 帧（≈60fps），Janky 0.82%。
- **特效层回退**：无头浏览器与本机模拟器都拿不到可用 WebGL（`dumpsys meminfo` 的 Graphics 为 0），Phaser 走 Canvas 渲染器或整体回退；两条路径都实测无黑屏、无丢失特效、无残留报错。WebGL 粒子路径**尚未在真机 GPU 上验证**。
- **APK 签名**：`CN=TapArena, OU=Games, O=sctale, C=CN`；清单 `versionCode=3 versionName=1.2.0`；`TapArena-v1.2.0.apk` SHA-256：`6C8C0CC382211FF172C91AE7968BFB75127377CA546D87A9AC8DACF3B7604442`。

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
