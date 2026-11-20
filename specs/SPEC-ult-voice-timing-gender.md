# SPEC — 大招台词重配：贴帧起声 + 男女声明确

状态：已修复（4.23.0 / code 65）
日期：2026-11-20
版本目标：4.23.0 / versionCode 65

用户反馈：

1. 大招释放时的语音时机不对，应该在大招释放瞬间就说出那句话；
2. 男孩女孩的声音分得不清，有些动物应该是男孩、有些应该是女孩。

只改台词资产与音色表，不改台词文字、不改技能数值、不改播放架构。

## 1. 复查结论

### 1.1 时机：台词文件开头有 0.11–0.24 秒静音

`try_cast()` 与 `cast()` 在同一帧执行，`battle_view` 在施法第一帧就排入台词，
代码侧没有延迟；实测 15 条 WAV 的首段静音：

| 最长 | 最短 | 典型 |
|---|---|---|
| crane 0.240s | turtle 0.040s | 0.11–0.17s |

人耳感知为「先放特效、话晚半拍」。修法是**在资产里去掉首段静音**（保留 20ms），
尾段也收到 120ms，台词总时长会缩短 0.1–0.3 秒。

### 1.2 男女声：候选音色的基频有重叠

用同一句「旋风爪，都让开！」测各候选音色的中位基频（F0）：

| 音色 | F0 | 音色 | F0 |
|---|---|---|---|
| badao_shaoye | 113 Hz | Crisp_Girl | 235 Hz |
| male-qn-jingying | 175 Hz | lovely_girl | 253 Hz |
| male-qn-qingse | 186 Hz | qiaopi_mengmei | 277 Hz |
| Gentle_Youth | 189 Hz | female-shaonv | 293 Hz |
| Pure-hearted_Boy | 192 Hz | Warm_Girl | 296 Hz |
| male-qn-daxuesheng | 195 Hz | Cute_Spirit | 301 Hz |
| chunzhen_xuedi | 200 Hz | Soft_Girl | 316 Hz |
| Straightforward_Boy | 223 Hz | **clever_boy** | **296 Hz** |
|  |  | **cute_boy** | **333 Hz** |

原来的 `cute_boy`（333 Hz）与 `clever_boy`（296 Hz）比 `lovely_girl`（254 Hz）、
`qiaopi_mengmei`（277 Hz）还高，男孩反而更像女孩——这就是「分不清」的根因。
新表只选 **男孩 F0 ≤ 223 Hz、女孩 F0 ≥ 235 Hz** 的音色，且 15 位各不相同。

## 2. 新音色表（15 位，8 男 7 女）

性别依据头像配件与角色设定：花环/粉围巾/项链为女孩，鹿角/竹棍/牙饰为男孩。

| hero_id | 角色 | 性别 | 大招 | 音色 | 语速 | 音调 |
|---|---|---|---|---|---|---|
| tiger | 阿狮 | 男 | 旋风爪 | Chinese (Mandarin)_Straightforward_Boy | 1.04 | -1 |
| fox | 灵灵 | 女 | 星河坠落 | Chinese (Mandarin)_Crisp_Girl | 1.02 | 0 |
| rabbit | 朵朵 | 女 | 满月祝福 | lovely_girl | 1.05 | 0 |
| bear | 阿岳 | 男 | 山崩地裂 | badao_shaoye | 0.96 | -2 |
| frog | 泡泡 | 女 | 瀑布冲击 | qiaopi_mengmei | 1.06 | 0 |
| cat | 尖尖 | 女 | 万爪齐发 | female-shaonv | 1.08 | 0 |
| panda | 团团 | 男 | 竹林震地 | male-qn-qingse | 1.02 | 0 |
| owl | 咕咕 | 女 | 夜枭俯冲 | Chinese (Mandarin)_Warm_Girl | 1.00 | 0 |
| axolotl | 绒绒 | 女 | 再生水域 | Chinese (Mandarin)_Soft_Girl | 1.00 | 0 |
| deer | 角角 | 男 | 林间箭雨 | chunzhen_xuedi | 1.04 | 0 |
| turtle | 甲甲 | 男 | 龟甲震地 | Chinese (Mandarin)_Gentle_Youth | 0.96 | -1 |
| hedgehog | 刺刺 | 男 | 滚动刺球 | Chinese (Mandarin)_Pure-hearted_Boy | 1.12 | 0 |
| redpanda | 火火 | 男 | 烈焰冲锋 | male-qn-daxuesheng | 1.08 | 0 |
| wolf | 灰灰 | 男 | 猎影突袭 | male-qn-jingying | 1.04 | -1 |
| crane | 小白 | 女 | 风之领域 | Chinese (Mandarin)_Cute_Spirit | 0.98 | 0 |

台词文字不变。调整的是：泡泡、角角从原异性音色改为符合头像设定的性别；
所有成年男女声换成少年/少女声，保证「小动物」的年龄感。

## 3. 生成脚本

- `tools/audio/gen_ult_voice.py`
  - `LINES` 增加 `gender` 列；`MMX` 用 `shutil.which("mmx")`，找不到再回落旧路径。
  - `to_wav()` 先做 `silenceremove`：首段保留 20ms、尾段保留 120ms，再 `loudnorm −16 LUFS`。
  - manifest 增加 `gender`、`lead`（首段静音）、`dur`；生成后自动复制到
    `godot/assets/audio/ult/`（中间产物 `tools/audio/ult/` 已 gitignore）。
- 重新生成 15 条 48kHz 单声道 PCM WAV，覆盖 `godot/assets/audio/ult/`。

## 验收

- [x] 15 条台词 `ffprobe`：48kHz / 单声道 / pcm_s16le，时长 0.84–2.27s
- [x] 首段静音 0.00–0.01s（目标 ≤50ms）；尾段统一保留 0.12s
- [x] F0：男孩 128–228Hz，女孩 251–354Hz（最小间隔 23Hz），15 个音色名不重复
- [x] manifest 15 条、`gender` 齐全；`flow_headless` 新增 8 男/7 女、首静音 ≤50ms、音色不重复断言
- [x] 混音实测：`--ult` 录像与原始台词包络互相关，最佳延迟 **0.00s**（台词与施法同帧起声）
- [x] 模拟器 5v5 跑通，0 条脚本/音频错误
- [x] `SIM_OK` / `FLOW_OK`；不改技能数值、地图、台词文字
