# -*- coding: utf-8 -*-
"""生成六位英雄的脸/身体贴图（球面 UV）。
输出：unity/Assets/Resources/HeroFaces/<id>_face.png / <id>_blink.png / <id>_body.png
脸的 UV：u=0.5 在 +X（正面），v=0.5 在赤道；贴图 y=(1-v)*H。
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "unity", "Assets", "Resources", "HeroFaces")
os.makedirs(OUT, exist_ok=True)

W, H = 1024, 512
BS = 512
S = 2  # supersample

HEROES = {
    "tiger": dict(fur="#F2A94F", dark="#C9752F", cream="#FFF3E2", accent="#2E8B6F",
                  iris="#C97B18", eye_dark="#3A2010", pattern="tiger", muzzle="cream"),
    "fox": dict(fur="#E9A24C", dark="#B5713A", cream="#FFF6EC", accent="#7B54C7",
                iris="#8A5A1E", eye_dark="#2E1A0A", pattern="fox", muzzle="cream"),
    "rabbit": dict(fur="#FFF7F3", dark="#E9B9CB", cream="#FFFFFF", accent="#EE8FB8",
                   iris="#C46A86", eye_dark="#4A2530", pattern="rabbit", muzzle="white"),
    "bear": dict(fur="#B98155", dark="#8A5A36", cream="#FBE9D2", accent="#4E9A63",
                 iris="#7A4A22", eye_dark="#2E1A0A", pattern="bear", muzzle="cream"),
    "otter": dict(fur="#7F9FC4", dark="#5A7290", cream="#F3F7FF", accent="#4FA88F",
                  iris="#2F5F8A", eye_dark="#182636", pattern="otter", muzzle="cream"),
    "hedgehog": dict(fur="#D9B98F", dark="#9C7B55", cream="#FFF1DC", accent="#E0604F",
                     iris="#6A4A2A", eye_dark="#2A1A0C", pattern="hedgehog", muzzle="cream"),
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def soft_ellipse(layer, box, color, blur=6, alpha=255):
    """在独立层画椭圆并高斯模糊，再合成回 layer。"""
    x0, y0, x1, y1 = box
    pad = int(blur * 3 + 4)
    w, h = int(x1 - x0 + pad * 2), int(y1 - y0 + pad * 2)
    tmp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    d.ellipse((pad, pad, pad + (x1 - x0), pad + (y1 - y0)), fill=color + (alpha,))
    tmp = tmp.filter(ImageFilter.GaussianBlur(blur))
    layer.alpha_composite(tmp, (int(x0 - pad), int(y0 - pad)))


def noise_layer(size, strength=10):
    n = Image.effect_noise(size, 18).convert("L")
    n = n.filter(ImageFilter.GaussianBlur(3))
    return n


def gradient_bg(base, top_light=0.10, bottom_dark=0.10):
    img = Image.new("RGBA", (W * S, H * S), base + (255,))
    px = img.load()
    for y in range(H * S):
        t = y / (H * S - 1)
        k = top_light * (1 - t) - bottom_dark * t
        col = tuple(max(0, min(255, int(base[i] * (1 + k)))) for i in range(3))
        for x in range(W * S):
            px[x, y] = col + (255,)
    # 细噪点：低频噪声放大，避免塑料感
    n = noise_layer((W * S // 8, H * S // 8), 20).resize((W * S, H * S), Image.BILINEAR)
    npx = n.load()
    for y in range(H * S):
        for x in range(W * S):
            v = (npx[x, y] - 128) / 128.0
            r, g, b, a = px[x, y]
            d = int(v * 7)
            px[x, y] = (max(0, min(255, r + d)), max(0, min(255, g + d)), max(0, min(255, b + d)), 255)
    return img


def draw_eye(img, cx, cy, ew, eh, pal, closed=False):
    """一只大眼：奶油眼白 + 彩色虹膜 + 深瞳 + 两枚高光。坐标是 1x 设计坐标。"""
    iris = rgb(pal["iris"])
    ed = rgb(pal["eye_dark"])
    cx, cy, ew, eh = cx * S, cy * S, ew * S, eh * S
    d = ImageDraw.Draw(img)
    # 眼眶阴影
    soft_ellipse(img, (cx - ew * 0.56, cy - eh * 0.56, cx + ew * 0.56, cy + eh * 0.56),
                 ed, blur=5, alpha=120)
    if closed:
        # 闭眼：一条上弯的弧 + 外眼角短睫
        d.line([(cx - ew * 0.42, cy + eh * 0.04), (cx, cy - eh * 0.16), (cx + ew * 0.42, cy + eh * 0.04)],
               fill=ed, width=int(7 * S), joint="curve")
        d.line([(cx + ew * 0.40, cy + eh * 0.02), (cx + ew * 0.62, cy - eh * 0.14)],
               fill=ed, width=int(4 * S))
        return
    # 眼白
    soft_ellipse(img, (cx - ew * 0.5, cy - eh * 0.5, cx + ew * 0.5, cy + eh * 0.5),
                 (255, 250, 244), blur=1.2, alpha=255)
    # 虹膜
    soft_ellipse(img, (cx - ew * 0.46, cy - eh * 0.43, cx + ew * 0.46, cy + eh * 0.47),
                 iris, blur=0.8, alpha=255)
    # 虹膜下半反光
    soft_ellipse(img, (cx - ew * 0.30, cy + eh * 0.10, cx + ew * 0.30, cy + eh * 0.44),
                 lerp(iris, (255, 245, 220), 0.45), blur=3, alpha=110)
    # 瞳孔
    soft_ellipse(img, (cx - ew * 0.25, cy - eh * 0.25, cx + ew * 0.25, cy + eh * 0.33),
                 ed, blur=0.7, alpha=255)
    # 高光
    soft_ellipse(img, (cx - ew * 0.26, cy - eh * 0.34, cx - ew * 0.02, cy - eh * 0.06),
                 (255, 255, 255), blur=0.6, alpha=245)
    soft_ellipse(img, (cx + ew * 0.12, cy + eh * 0.12, cx + ew * 0.24, cy + eh * 0.26),
                 (255, 255, 255), blur=0.5, alpha=220)
    soft_ellipse(img, (cx + ew * 0.20, cy - eh * 0.18, cx + ew * 0.27, cy - eh * 0.10),
                 (255, 255, 255), blur=0.3, alpha=180)
    # 上眼线
    d.arc((cx - ew * 0.52, cy - eh * 0.55, cx + ew * 0.52, cy + eh * 0.45), 195, 345,
          fill=ed, width=int(5 * S))
    # 外眼角睫毛
    for i in range(2):
        ax = cx + ew * (0.40 + i * 0.10)
        ay = cy - eh * (0.20 - i * 0.04)
        d.line([(ax, ay), (ax + ew * 0.16, ay - eh * 0.10)], fill=ed, width=int(3.5 * S))


def draw_brow(img, cx, cy, w, pal, tilt=0.0):
    cx, cy, w = cx * S, cy * S, w * S
    d = ImageDraw.Draw(img)
    dk = rgb(pal["dark"])
    pts = []
    n = 12
    for i in range(n + 1):
        t = i / n
        x = cx - w / 2 + w * t
        y = cy - math.sin(t * math.pi) * 7 * S + (t - 0.5) * tilt * S
        pts.append((x, y))
    d.line(pts, fill=lerp(dk, (80, 50, 40), 0.35) + (235,), width=int(6 * S), joint="curve")


def face_texture(hero_id, pal, closed=False, hurt=False):
    base = rgb(pal["fur"])
    cream = rgb(pal["cream"])
    dark = rgb(pal["dark"])
    img = gradient_bg(base, 0.12, 0.10)
    d = ImageDraw.Draw(img)


    # 花纹
    if pal["pattern"] == "tiger":
        for i in range(3):
            x = (440 + i * 55) * S
            y0 = (110 + (i % 2) * 18) * S
            d.line([(x, y0), (x - 10 * S, y0 + 70 * S), (x + 4 * S, y0 + 120 * S)],
                   fill=dark + (230,), width=int(10 * S), joint="curve")
        for side in (-1, 1):
            for j in range(2):
                x0 = (512 + side * (190 + j * 46)) * S
                y0 = (250 + j * 38) * S
                d.line([(x0, y0), (x0 + side * 70 * S, y0 + 10 * S)],
                       fill=dark + (220,), width=int(9 * S))
    elif pal["pattern"] == "fox":
        soft_ellipse(img, (512 * S - 190 * S, 270 * S, 512 * S + 190 * S, 470 * S),
                     cream, blur=18, alpha=240)
        for side in (-1, 1):
            soft_ellipse(img, (512 * S + side * 150 * S - 55 * S, 300 * S,
                               512 * S + side * 150 * S + 55 * S, 420 * S), (255, 255, 255), blur=12, alpha=150)
    elif pal["pattern"] == "otter":
        # 只留一小块浅色下巴，别把下半张脸整个刷白
        soft_ellipse(img, (512 * S - 150 * S, 360 * S, 512 * S + 150 * S, 485 * S),
                     cream, blur=20, alpha=135)
    elif pal["pattern"] == "hedgehog":
        soft_ellipse(img, (512 * S - 180 * S, 260 * S, 512 * S + 180 * S, 470 * S),
                     cream, blur=18, alpha=230)
        for side in (-1, 1):
            soft_ellipse(img, (512 * S + side * 120 * S - 90 * S, 215 * S,
                               512 * S + side * 120 * S + 90 * S, 330 * S), lerp(dark, (0, 0, 0), 0.05),
                         blur=20, alpha=70)

    # 口鼻区（奶油色，柔和边）
    muzzle_col = (255, 250, 240) if pal["muzzle"] == "white" else cream
    soft_ellipse(img, (512 * S - 84 * S, 300 * S - 54 * S, 512 * S + 84 * S, 300 * S + 54 * S),
                 muzzle_col, blur=14, alpha=215)

    # 腮红
    for side in (-1, 1):
        soft_ellipse(img, (512 * S + side * 150 * S - 55 * S, 310 * S - 34 * S,
                           512 * S + side * 150 * S + 55 * S, 310 * S + 34 * S),
                     (255, 120, 140), blur=26, alpha=90)

    # 眼窝阴影（3D 珠眼会装在这里，贴图只压一点暗）
    for side in (-1, 1):
        soft_ellipse(img, (512 * S + side * 53 * S - 42 * S, 250 * S - 50 * S,
                           512 * S + side * 53 * S + 42 * S, 250 * S + 50 * S),
                     lerp(base, (0, 0, 0), 0.35), blur=14, alpha=55)

    # 眉毛（3D 眼睛上方）
    for side in (-1, 1):
        draw_brow(img, 512 + side * 56, 212 if not hurt else 218, 42, pal, tilt=side * (3 if not hurt else -12))

    # 嘴：小 w 笑；受伤时张嘴
    if hurt:
        d = ImageDraw.Draw(img)
        soft_ellipse(img, (512 * S - 26 * S, 334 * S, 512 * S + 26 * S, 372 * S),
                     rgb(pal["eye_dark"]), blur=1.2, alpha=245)
        soft_ellipse(img, (512 * S - 16 * S, 356 * S, 512 * S + 16 * S, 370 * S),
                     (230, 120, 130), blur=2, alpha=200)
    elif not closed:
        my = 352
        d.arc((512 * S - 34 * S, my * S - 20 * S, 512 * S - 2 * S, my * S + 12 * S),
              20, 160, fill=rgb(pal["eye_dark"]) + (235,), width=int(4 * S))
        d.arc((512 * S + 2 * S, my * S - 20 * S, 512 * S + 34 * S, my * S + 12 * S),
              20, 160, fill=rgb(pal["eye_dark"]) + (235,), width=int(4 * S))
        # 人中
        d.line([(512 * S, 330 * S), (512 * S, 350 * S)], fill=rgb(pal["eye_dark"]) + (150,), width=int(2.5 * S))

    # 胡须点（獭/狐/熊）
    if pal["pattern"] in ("otter", "fox", "bear"):
        for side in (-1, 1):
            for k in range(3):
                x = (512 + side * (100 + k * 16)) * S
                y = (340 + k * 8) * S
                d.ellipse((x - 2.2 * S, y - 2.2 * S, x + 2.2 * S, y + 2.2 * S),
                          fill=rgb(pal["eye_dark"]) + (180,))

    # 鼻梁高光
    soft_ellipse(img, (512 * S - 46 * S, 200 * S, 512 * S + 46 * S, 250 * S),
                 (255, 255, 255), blur=20, alpha=28)

    img = img.resize((W, H), Image.LANCZOS)
    return img.convert("RGB")


def body_texture(hero_id, pal):
    base = rgb(pal["fur"])
    cream = rgb(pal["cream"])
    dark = rgb(pal["dark"])
    img = gradient_bg(base, 0.06, 0.12).resize((BS, BS), Image.LANCZOS).convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    # 肚皮
    soft_ellipse(img, (BS * 0.5 - BS * 0.075, BS * 0.29, BS * 0.5 + BS * 0.075, BS * 0.73),
                 cream, blur=12, alpha=215)
    if pal["pattern"] == "tiger":
        for side in (-1, 1):
            for i in range(3):
                x = (BS * 0.5 + side * BS * (0.30 + i * 0.055)) % BS
                y0 = BS * (0.20 + i * 0.10)
                d.line([(x, y0), (x + side * BS * 0.06, y0 + BS * 0.16)],
                       fill=dark + (220,), width=int(BS * 0.014))
    elif pal["pattern"] == "otter":
        soft_ellipse(img, (BS * 0.5 - BS * 0.22, BS * 0.18, BS * 0.5 + BS * 0.22, BS * 0.80),
                     cream, blur=14, alpha=180)
    elif pal["pattern"] == "hedgehog":
        soft_ellipse(img, (BS * 0.5 - BS * 0.13, BS * 0.26, BS * 0.5 + BS * 0.13, BS * 0.76),
                     cream, blur=10, alpha=230)
    elif pal["pattern"] == "rabbit":
        soft_ellipse(img, (BS * 0.5 - BS * 0.12, BS * 0.26, BS * 0.5 + BS * 0.12, BS * 0.74),
                     (255, 235, 240), blur=10, alpha=160)
    return img.convert("RGB")


def main():
    for hid, pal in HEROES.items():
        face_texture(hid, pal, False).save(os.path.join(OUT, f"{hid}_face.png"))
        face_texture(hid, pal, True).save(os.path.join(OUT, f"{hid}_blink.png"))
        face_texture(hid, pal, False, True).save(os.path.join(OUT, f"{hid}_hurt.png"))
        body_texture(hid, pal).save(os.path.join(OUT, f"{hid}_body.png"))
        print("wrote", hid)

    # 六张脸拼一张检查图
    sheet = Image.new("RGB", (W * 2, H * 3), (40, 40, 40))
    for i, hid in enumerate(HEROES):
        im = Image.open(os.path.join(OUT, f"{hid}_face.png"))
        sheet.paste(im, ((i % 2) * W, (i // 2) * H))
    sheet.save(os.path.join(ROOT, "unity", "face_sheet.png"))


if __name__ == "__main__":
    main()
