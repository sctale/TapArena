# -*- coding: utf-8 -*-
"""TapArena 大招台词合成 —— 15 位英雄各一句，mmx (MiniMax speech-2.8-hd)。

产出：ult/ult_<hero_id>.wav，48kHz / 单声道 / 16-bit，响度统一到 -16 LUFS。
台词与音色写在 LINES 表里，改稿只动这张表。
"""
import array
import json
import math
import os
import pathlib
import shutil
import subprocess
import sys
import wave

MMX = shutil.which("mmx") or "/opt/data/local/bin/mmx"
SR = 48000
OUT = pathlib.Path(__file__).resolve().parent / "ult"
ASSETS = pathlib.Path(__file__).resolve().parents[2] / "godot" / "assets" / "audio" / "ult"

# hero_id, 角色, 性别, 大招, 音色, 语速, 音调, 台词
# 选角纪律：男孩音色 F0 ≤ 223Hz、女孩 ≥ 235Hz（同句实测），15 个音色互不重复。
LINES = [
    ("tiger",    "阿狮", "boy",  "旋风爪",   "Chinese (Mandarin)_Straightforward_Boy", 1.04, -1, "旋风爪！都让开！"),
    ("fox",      "灵灵", "girl", "星河坠落", "Chinese (Mandarin)_Cute_Spirit",          1.02,  0, "星河，落下来吧！"),
    ("rabbit",   "朵朵", "girl", "满月祝福", "lovely_girl",                             1.05,  0, "满月，照亮大家！"),
    ("bear",     "阿岳", "boy",  "山崩地裂", "badao_shaoye",                            0.96, -2, "山崩地裂！"),
    ("frog",     "泡泡", "girl", "瀑布冲击", "qiaopi_mengmei",                          1.06,  1, "瀑布，冲垮他们！"),
    ("cat",      "尖尖", "girl", "万爪齐发", "female-shaonv",                           1.08,  0, "万爪齐发，看招！"),
    ("panda",    "团团", "boy",  "竹林震地", "male-qn-qingse",                          1.02,  0, "竹林震地！"),
    ("owl",      "咕咕", "girl", "夜枭俯冲", "Chinese (Mandarin)_Warm_Girl",            1.00,  0, "夜枭，俯冲！"),
    ("axolotl",  "绒绒", "girl", "再生水域", "Chinese (Mandarin)_Soft_Girl",            1.00,  0, "再生水域，别怕！"),
    ("deer",     "角角", "boy",  "林间箭雨", "chunzhen_xuedi",                          1.04, -2, "林间箭雨，落！"),
    ("turtle",   "甲甲", "boy",  "龟甲震地", "Chinese (Mandarin)_Gentle_Youth",         0.96, -1, "龟甲震地，站稳！"),
    ("hedgehog", "刺刺", "boy",  "滚动刺球", "Chinese (Mandarin)_Pure-hearted_Boy",     1.12,  0, "滚动刺球，滚起来！"),
    ("redpanda", "火火", "boy",  "烈焰冲锋", "male-qn-daxuesheng",                      1.08,  0, "烈焰冲锋，烧起来！"),
    ("wolf",     "灰灰", "boy",  "猎影突袭", "male-qn-jingying",                        0.96, -1, "猎影突袭！"),
    ("crane",    "小白", "girl", "风之领域", "female-tianmei",                          1.00,  0, "风之领域，起风了。"),
    ("monkey",   "阿跳", "boy",  "定海神针", "junlang_nanyou",                          1.06, -1, "长棍一扫，让开！"),
    ("elephant", "阿吨", "boy",  "大地践踏", "male-qn-badao",                           0.94, -1, "大地，听我脚步！"),
    ("penguin",  "冰冰", "girl", "暴风雪",   "Chinese (Mandarin)_Crisp_Girl",           1.04,  1, "冰雪，听我号令！"),
    ("sheep",    "云朵", "girl", "暖云牧场", "Sweet_Girl",                              1.02,  0, "云朵，护住大家！"),
    ("bat",      "夜羽", "girl", "音波风暴", "female-yujie",                            1.04,  0, "黑夜，为我让路！"),
]


def mmx_synth(text, voice, speed, pitch, out_mp3):
    cmd = [MMX, "speech", "synthesize", "--text", text, "--voice", voice,
           "--speed", f"{speed:.2f}", "--pitch", str(pitch), "--format", "mp3",
           "--out", str(out_mp3)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if r.returncode != 0 or not out_mp3.exists() or out_mp3.stat().st_size < 2000:
        raise RuntimeError(f"mmx 失败: {(r.stderr or r.stdout)[:300]}")


def to_wav(src, dst):
    # 台词必须贴帧起声：去掉 TTS 自带的 0.1–0.24s 首静音，尾音也只留 0.12s。
    af = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,"
          "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,"
          "areverse,loudnorm=I=-16:TP=-1.5:LRA=11")
    cmd = ["ffmpeg", "-y", "-v", "error", "-i", str(src), "-ac", "1", "-ar", str(SR),
           "-af", af, "-c:a", "pcm_s16le", str(dst)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg 失败: {r.stderr[:300]}")


def lead_silence(p, th_db=-45.0) -> float:
    with wave.open(str(p), "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        vals = array.array("h")
        vals.frombytes(w.readframes(w.getnframes()))
    if ch > 1:
        vals = vals[::ch]
    win = max(1, int(sr * 0.01))
    th = 32768.0 * (10.0 ** (th_db / 20.0))
    for i in range(0, max(0, len(vals) - win), win):
        rms = math.sqrt(sum(v * v for v in vals[i:i + win]) / float(win))
        if rms > th:
            return round(i / float(sr), 3)
    return round(len(vals) / float(sr), 3)


def probe(p):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "default=nw=1:nk=1", str(p)],
                         capture_output=True, text=True).stdout.strip()
    return float(out or 0)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = OUT / "_src"
    tmp.mkdir(exist_ok=True)
    rows, fails = [], []
    for hid, name, gender, ult, voice, speed, pitch, line in LINES:
        mp3 = tmp / f"{hid}.mp3"
        wav = OUT / f"ult_{hid}.wav"
        try:
            mmx_synth(line, voice, speed, pitch, mp3)
            to_wav(mp3, wav)
            rows.append({"hero": hid, "name": name, "gender": gender, "ult": ult,
                         "voice": voice, "line": line,
                         "dur": round(probe(wav), 2), "lead": lead_silence(wav)})
            print(f"  [OK]   {hid:9s} {gender:4s} {ult:5s} {rows[-1]['dur']:.2f}s "
                  f"lead={rows[-1]['lead']:.2f}s  {line}")
        except Exception as e:
            fails.append((hid, str(e)[:160]))
            print(f"  [FAIL] {hid}: {e}")
    (OUT / "manifest.json").write_text(
        json.dumps({"sample_rate": SR, "lines": rows, "failed": fails},
                   ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n成功 {len(rows)} / {len(LINES)}")
    # 直接覆盖游戏资产，避免生成在 tools/audio/ult 却忘记拷贝。
    ASSETS.mkdir(parents=True, exist_ok=True)
    for wav in OUT.glob("ult_*.wav"):
        shutil.copy2(wav, ASSETS / wav.name)
    (ASSETS / "manifest.json").write_text(
        (OUT / "manifest.json").read_text(encoding="utf-8"), encoding="utf-8")
    print(f"已同步游戏资产 {ASSETS}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
