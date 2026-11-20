# -*- coding: utf-8 -*-
"""TapArena 大招台词合成 —— 15 位英雄各一句，mmx (MiniMax speech-2.8-hd)。

产出：ult/ult_<hero_id>.wav，48kHz / 单声道 / 16-bit，响度统一到 -16 LUFS。
台词与音色写在 LINES 表里，改稿只动这张表。
"""
import json
import os
import pathlib
import subprocess
import sys

MMX = "/opt/data/local/bin/mmx"
SR = 48000
OUT = pathlib.Path(__file__).resolve().parent / "ult"

# hero_id, 角色, 大招, 音色, 语速, 音调, 台词
LINES = [
    ("tiger",    "阿狮", "旋风爪",   "male-qn-jingying",                        1.06,  0,  "旋风爪！都让开！"),
    ("fox",      "灵灵", "星河坠落", "Chinese (Mandarin)_Crisp_Girl",            1.02,  2,  "星河，落下来吧！"),
    ("rabbit",   "朵朵", "满月祝福", "Chinese (Mandarin)_Cute_Spirit",           1.06,  4,  "满月，照亮大家！"),
    ("bear",     "阿岳", "山崩地裂", "male-qn-badao",                            0.96, -4,  "山崩地裂！"),
    ("frog",     "泡泡", "瀑布冲击", "male-qn-qingse",                           1.06,  0,  "瀑布，冲垮他们！"),
    ("cat",      "尖尖", "万爪齐发", "Chinese (Mandarin)_Warm_Girl",             1.08,  2,  "万爪齐发，看招！"),
    ("panda",    "团团", "竹林震地", "Chinese (Mandarin)_Straightforward_Boy",   1.04,  0,  "竹林震地！"),
    ("owl",      "咕咕", "夜枭俯冲", "Chinese (Mandarin)_Wise_Women",            1.00, -1,  "夜枭，俯冲！"),
    ("axolotl",  "绒绒", "再生水域", "Chinese (Mandarin)_Soft_Girl",             1.00,  3,  "再生水域，别怕！"),
    ("deer",     "角角", "林间箭雨", "Chinese (Mandarin)_Sweet_Lady",            1.05,  2,  "林间箭雨，落！"),
    ("turtle",   "甲甲", "龟甲震地", "Chinese (Mandarin)_Gentleman",             0.96, -3,  "龟甲震地，站稳！"),
    ("hedgehog", "刺刺", "滚动刺球", "Chinese (Mandarin)_Pure-hearted_Boy",      1.12,  1,  "滚动刺球，滚起来！"),
    ("redpanda", "火火", "烈焰冲锋", "Chinese (Mandarin)_Unrestrained_Young_Man",  1.08,  0,  "烈焰冲锋，烧起来！"),
    ("wolf",     "灰灰", "猎影突袭", "male-qn-badao",                            1.04, -2,  "猎影突袭！"),
    ("crane",    "小白", "风之领域", "Chinese (Mandarin)_Lyrical_Voice",         0.98, -1,  "风之领域，起风了。"),
]


def mmx_synth(text, voice, speed, pitch, out_mp3):
    cmd = [MMX, "speech", "synthesize", "--text", text, "--voice", voice,
           "--speed", f"{speed:.2f}", "--pitch", str(pitch), "--format", "mp3",
           "--out", str(out_mp3)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if r.returncode != 0 or not out_mp3.exists() or out_mp3.stat().st_size < 2000:
        raise RuntimeError(f"mmx 失败: {(r.stderr or r.stdout)[:300]}")


def to_wav(src, dst):
    cmd = ["ffmpeg", "-y", "-v", "error", "-i", str(src), "-ac", "1", "-ar", str(SR),
           "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-c:a", "pcm_s16le", str(dst)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg 失败: {r.stderr[:300]}")


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
    for hid, name, ult, voice, speed, pitch, line in LINES:
        mp3 = tmp / f"{hid}.mp3"
        wav = OUT / f"ult_{hid}.wav"
        try:
            mmx_synth(line, voice, speed, pitch, mp3)
            to_wav(mp3, wav)
            rows.append({"hero": hid, "name": name, "ult": ult, "voice": voice,
                         "line": line, "dur": round(probe(wav), 2)})
            print(f"  ✅ {hid:9s} {ult:5s} {rows[-1]['dur']:.2f}s  {line}")
        except Exception as e:
            fails.append((hid, str(e)[:160]))
            print(f"  ❌ {hid}: {e}")
    (OUT / "manifest.json").write_text(
        json.dumps({"sample_rate": SR, "lines": rows, "failed": fails},
                   ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n成功 {len(rows)} / {len(LINES)}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
