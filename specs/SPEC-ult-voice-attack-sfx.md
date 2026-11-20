# SPEC — 大招台词 + 普攻音效（音频资产第一批）

状态：已接入（4.21.0 / code 63）；4.23.0 重配台词（见 `SPEC-ult-voice-timing-gender.md`）
日期：2026-11-20
版本目标：4.21.0 / versionCode 63

## 背景

项目至今**零音频资产**：`godot/assets/` 里只有 fonts 与 icons，`battle_view.gd` 也没有任何
`AudioStreamPlayer`。AGENTS.md §102 定死一条：**音效必须项目自制或运行时合成，不引第三方素材**。

本轮只做两件事，不碰战斗数值、不碰 UI：

1. 十五位英雄各**一句大招台词**（人声，播在大招释放瞬间）
2. 十五位英雄各**一条普攻音效**（合成音，播在攻击起始帧）

4.21.0 已按 §5 接入 `battle_view`：3D 声源、8 秒去重、同帧 6 源、SFX/BGM 总线。

## 1. 资产清单与目录

```
godot/assets/audio/
  ult/ult_<hero_id>.wav      15 条人声台词
  atk/atk_<hero_id>.wav      15 条普攻音效
  ult/manifest.json          台词表（hero/name/ult/voice/line/dur），供接入与复查读取
```

`<hero_id>` 与 `data/heroes.json` 的 `id` 完全一致：tiger / fox / rabbit / bear / frog / cat /
panda / owl / axolotl / deer / turtle / hedgehog / redpanda / wolf / crane。

## 2. 技术规格（30 个文件全部满足）

| 项目 | 台词（ult） | 音效（atk） |
|---|---|---|
| 容器/编码 | WAV / PCM 16-bit | WAV / PCM 16-bit |
| 采样率 | 48000 Hz | 48000 Hz |
| 声道 | 单声道 | 单声道 |
| 响度 | −16 LUFS（±1） | 峰值 −3 dBFS 左右 |
| 峰值 | ≤ −1.5 dBFS | ≤ −3 dBFS |
| 时长 | 1.1–2.9 s | 0.18–0.42 s |
| 首尾 | 自然收尾 | 4 ms 淡入淡出，防爆音 |

选 48 kHz 与 Godot 默认混音率一致，避免运行期重采样；单声道让 3D 声源按位置摆位，
不预置立体声。

## 3. 台词表（15）

| hero_id | 角色 | 大招 | 台词 | 时长 |
|---|---|---|---|---|
| tiger | 阿狮 | 旋风爪 | 旋风爪！都让开！ | 1.68s |
| fox | 灵灵 | 星河坠落 | 星河，落下来吧！ | 2.21s |
| rabbit | 朵朵 | 满月祝福 | 满月，照亮大家！ | 2.37s |
| bear | 阿岳 | 山崩地裂 | 山崩地裂！ | 1.59s |
| frog | 泡泡 | 瀑布冲击 | 瀑布，冲垮他们！ | 1.88s |
| cat | 尖尖 | 万爪齐发 | 万爪齐发，看招！ | 1.78s |
| panda | 团团 | 竹林震地 | 竹林震地！ | 1.10s |
| owl | 咕咕 | 夜枭俯冲 | 夜枭，俯冲！ | 1.79s |
| axolotl | 绒绒 | 再生水域 | 再生水域，别怕！ | 2.25s |
| deer | 角角 | 林间箭雨 | 林间箭雨，落！ | 1.95s |
| turtle | 甲甲 | 龟甲震地 | 龟甲震地，站稳！ | 1.95s |
| hedgehog | 刺刺 | 滚动刺球 | 滚动刺球，滚起来！ | 1.94s |
| redpanda | 火火 | 烈焰冲锋 | 烈焰冲锋，烧起来！ | 2.01s |
| wolf | 灰灰 | 猎影突袭 | 猎影突袭！ | 1.56s |
| crane | 小白 | 风之领域 | 风之领域，起风了。 | 2.87s |

配音规则（4.23.0 起以下表为准，见 `SPEC-ult-voice-timing-gender.md`）：按**性别**分声，
男孩 8 位、女孩 7 位，男孩 F0 ≤ 228Hz、女孩 ≥ 251Hz；不再用成年男/女声，
台词文件去掉首段静音后贴帧起声。本表是 4.21.0 的历史记录，时长与音色以
`ult/manifest.json` 为准。
台词统一「大招名 + 一个短动作或情绪尾句」，控制在 4–10 字，保证团战里两秒内听完。

## 4. 音效设计表（15）

| hero_id | 武器/体型 | 合成配方 | 时长 |
|---|---|---|---|
| tiger | 利爪 | 带通噪声 1.5–6.5k 快速衰减 + 低频扫地 + 起手 click | 0.26s |
| fox | 法杖 | FM 铃声（载波 820Hz，调制比 3.1）+ 高频闪光尾 | 0.34s |
| rabbit | 法杖 | FM 铃声（1040Hz） | 0.34s |
| bear | 重拳 | 62Hz 下滑正弦 + 120–900Hz 砂砾噪声 | 0.42s |
| frog | 水弹 | 300–3000Hz 噪声 + 26Hz 气泡调幅 | 0.30s |
| cat | 爪击 | 带通 2.6–9.5k，起手 click 更亮 | 0.26s |
| panda | 竹棍 | 880/1320/2480Hz 三根衰减正弦 + 木质噪声 | 0.22s |
| owl | 羽刃 | 带通 0.9–3.6k，气声为主 | 0.26s |
| axolotl | 水鞭 | 同水弹，不同随机种子 | 0.30s |
| deer | 弓弦 | Karplus-Strong 拨弦（196Hz）+ 2–9k 空气声 | 0.30s |
| turtle | 撞甲 | 52Hz 重击 + 砂砾 | 0.42s |
| hedgehog | 刺突 | 4–14k 极短嘶声 + 1.9k 尖点 | 0.18s |
| redpanda | 火焰斩 | 200–4200Hz 噪声 + 9 处爆裂颗粒 | 0.34s |
| wolf | 影爪 | 带通 1.2–5.2k，比阿狮更闷 | 0.26s |
| crane | 风刃 | 带通 2–8k，click 最轻 | 0.26s |

同族不重样：虎/狼/刺猬/猫/小白都属挥砍，但频段、起手亮度、时长各不相同，闭眼能分辨。

## 5. 接入约定（本轮不做，接代码时照此执行）

- **只在表现层播**：`scripts/view/battle_view.gd`。`battle_sim.gd` 保持零音频引用（AGENTS.md §92）。
- **大招**：技能第 3 条（`unlock_at_2`）释放瞬间播一次 `ult_<hero_id>.wav`；同一英雄 8 秒内不重播。
- **普攻**：攻击起始帧播 `atk_<hero_id>.wav`，`pitch_scale` 在 0.94–1.06 随机，避免连击像机关枪。
- **距离衰减**：沿用 `specs/SPEC-sfx-distance.md` 的口径，3D 声源 + `max_distance`，不要全局同响。
- **并发上限**：同帧最多 6 个音效源，超出按与相机距离丢弃最远的。
- **总线路由**：SFX 与 BGM 分总线（AudioServer bus），预留 `BGM` 与 `SFX` 两条，方便后续加设置项。

## 6. 可再生性

两个生成脚本随资产一起入库，改台词/改音色只动表不改文件：

```
tools/audio/gen_atk_sfx.py     numpy 合成 15 条普攻音效（无外部依赖，秒级完成）
tools/audio/gen_ult_voice.py   mmx TTS 合成 15 条台词（需 MINIMAX_API_KEY）
```

`gen_ult_voice.py` 顶部 `LINES` 表是台词唯一数据源：hero_id / 角色 / 大招 / 音色 / 语速 / 音调 / 台词。

## 验收

- [x] 30 个文件齐（ult 15 + atk 15），`ffprobe` 抽查：48 kHz / 单声道 / pcm_s16le
- [x] 台词响度抽检：−16.1 ~ −16.7 LUFS，峰值 −1.5 dBFS
- [x] 音效峰值抽检：−3.1 ~ −4.3 dBFS，无静音、无削波
- [x] 台词可懂度抽检 6 条（Whisper 转写）：旋风爪、满月照亮大家、滚动刺球、风之领域、山崩地裂、
      烈焰冲锋，全部可辨
- [x] 未改动 `battle_sim.gd`、`heroes.json`、任何脚本

## 4.21.0 接入验收（本次）

- [x] `battle_view` 加载 15+15 条 WAV，10 个 `AudioStreamPlayer3D`（inverse-square / unit_size 600 / max_distance 1500）；
- [x] 大招：第 3 条技能起始帧播台词，同一英雄 8 秒去重（`--ult` 实拍 `ult_tiger d=0`）；
- [x] 普攻：攻击起始帧播音效，音高 0.94–1.06（`--auto-run` 实拍玩家 d=0、AI 90–565）；
- [x] 同帧最多 6 源、按玩家距离丢最远；新增 `SFX`/`BGM` 总线，旧合成音效走 `SFX`；
- [x] flow 断言：30 个资产、两条总线、视图池 15/15 + 10 播放器；`SIM_OK`/`FLOW_OK`；
- [x] Android 16 模拟器 5v5 平均 27.4fps、0 条脚本/音频错误。
