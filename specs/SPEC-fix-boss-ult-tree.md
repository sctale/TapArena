# SPEC — 修三个 Bug：飞行 BOSS 可攻击 / 大招语音 / 水晶后大树

状态：已修复（4.22.0 / code 64）
日期：2026-11-20
版本目标：4.22.0 / versionCode 64

用户报障原文：

1. 英雄没办法攻击飞行形态的 BOSS；
2. 大招语音好像有点问题，需要再检查下；
3. 水晶后面的大树挡住水晶了，去掉或者挪一下位置。

只动这三处表现/选敌逻辑，不改英雄数值、不改地图尺寸、不改已有音效资产。

## 1. BOSS 不可攻击

### 根因

`battle_sim.gd` 的 `pick_attack_target()` 用 `match u.kind` 给候选打分，只覆盖
HERO / MINION,JUNGLE / TOWER / BASE；`BOSS` 没有分支，得分停在 `-1e20`，
所以普攻永远选不中巨兽。飞行形态（`boss_flying`）只是状态不是新单位，
问题与飞行无关，是**地面/飞行都打不了**，玩家在飞行阶段最容易被注意到。

`ai_target()` 同样没有 BOSS 分支（默认 0 分），AI 英雄也不会主动打巨兽。
`nearest_enemy()` 包含 BOSS，所以小兵/防御塔本来就会打，只有英雄普攻漏了。

### 改动

- `data/rules.json → targeting` 新增：`boss_weight 2600`、`boss_dist 0.35`、`boss_focus_hp 300`。
  分值介于英雄（3000）与小兵（1200）之间：附近有敌方英雄先打英雄，否则打巨兽。
- `data/rules.json → ai` 新增：`boss_weight 300`、`boss_dist 0.3`，让 AI 英雄也会集火巨兽。
- `pick_attack_target()` 增加 `BOSS` 分支：`boss_weight - d * boss_dist + 残血加成`。
- `ai_target()` 增加 `BOSS` 分支：`boss_weight - d * boss_dist`。
- 技能选敌已包含 BOSS（`pick_skill_target` 只排除塔/水晶），不改。

## 2. 大招语音

### 复查结论（四个叠加问题，都要修）

1. **语音被普攻音效抢占播放器**：语音与音效共用一个 10 个 `AudioStreamPlayer3D` 的轮转池，
   每秒约 9 次普攻会复用同一播放器，1.1–2.9 秒的台词会被从中间掐断。
2. **语音被 BGM 盖住**：台词资产本身是 −16 LUFS、峰值 −1.5 dBFS（已复测），
   但 BGM 床 RMS 比台词高约 10 dB，语音在混音里几乎听不出。
3. **3D 低通滤波**：`AudioStreamPlayer3D.attenuation_filter_db` 默认 −24 dB @ 5 kHz，
   台词的高频辅音被削掉，听起来发闷。
4. **同帧 6 源上限按距离丢最远**：远处队友/敌人的台词会输给脚边的普攻，直接被丢掉。

### 改动

- 新增独立 `voice_pool`（4 个 `AudioStreamPlayer3D`），语音与普攻音效彻底分池；
  优先取空闲播放器，不再被普攻抢占。
- 语音播放器 `attenuation_filter_db = 0.0`（关闭低通），普攻池保持原样。
- 每帧 6 源上限：**先保语音**（最多 2 条），剩余槽位再给普攻音效。
- 语音音量 −5 → −1 dB；播放距离 ≤700 的台词时自动压低 BGM 总线 9 dB
  （0.12 秒压下、台词结束后 0.35 秒恢复），远处台词不压 BGM。
- 8 秒同英雄去重、3D 距离衰减、max_distance 1500 保持不变。
- 顺带补上 4.21 接入遗漏：声音开关（HUD 小喇叭）现在会静音 `SFX` 总线，
  3D 语音/普攻不会再「关了声音还在响」。

## 3. 水晶后大树

### 根因

`battle_view._build_scatter()` 的树/石头只避让兵线与河道，
没有调用 `_near_structure()`（草丛/小花早已调用），所以能刷在基地水晶正后方。

### 改动

- `_near_structure()` 支持基地单独边距：`_near_structure(x, z, tower_margin, base_margin)`。
- 树：塔 300 / 基地 600（再叠加建筑半径，实测最近树离水晶中心 700 以上）。
- 石头：塔 260 / 基地 400。
- 3v3（基地 230,800 / 2770,800）与 5v5（540,3060 / 3060,540）同时生效。

## 验收

- [x] `sim_headless`：新增 `BOSS_OK` 断言——飞行/地面巨兽在 60 px 内
      玩家 `pick_attack_target()==boss`、AI `ai_target()==boss`，且一步后巨兽掉血
- [x] `flow_headless`：语音池 4 个、低通 0、语音请求在 6 条普攻请求之前仍被播放、
      近距台词触发 BGM 压低；新增 `_check_base_clear`（树 600+半径、石头 400+半径）；
      声音开关静音/恢复 `SFX` 总线
- [x] 混音实测：`--write-movie --ult` 录 4 秒（32-bit PCM，按 int32 读），
      台词段 0.3–1.5 s 的 300–3000 Hz 能量 8.3 dB vs BGM 段 2.4–3.9 s 的 3.9 dB（+4.4 dB）；
      BGM 总线在台词段实测 −9.0 dB；台词 1.683 s 完整播完（0.7–1.0 s 的停顿是原句换气）
- [x] 截图：3v3/5v5 双方基地水晶四周无树冠遮挡（`--look-base` / `--look-red` / `--look-at`）
- [x] `SIM_OK` / `FLOW_OK`；未改动英雄数值、地图尺寸、音频资产
- [x] 模拟器：4.22.0 覆盖安装并跑通 5v5，0 条脚本/音频错误
- [x] 巨兽：`BOSS_OK` 覆盖地面/飞行、玩家/AI、一步掉血
- [x] 台词：混音实测 1.683 s 完整播放，近距自动压低 BGM
