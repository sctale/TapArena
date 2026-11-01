using UnityEngine;

namespace TapArena
{
    public enum UiScreen { Home, Select, Battle, Result }

    public static class GameFlow
    {
        public static UiScreen screen = UiScreen.Home;
        public static HeroId picked = HeroId.Tiger;
        public static GameObject rootWorld;
    }

    /// <summary>IMGUI 界面：全部自建样式，字号按屏幕高度等比缩放。</summary>
    public class Hud : MonoBehaviour
    {
        public static Hud I;
        Font _font;
        GUIStyle _title, _sub, _btn, _btnSmall, _card, _cardName, _hud, _hudSmall, _center, _big, _num;
        GUIStyle _chip, _hint, _name, _time;
        Texture2D _pad, _ring, _clear, _white, _round, _disc, _gradH, _gradV, _gradVDown;
        float _scale = 1f;
        Rect[] _skillRects = new Rect[3];
        readonly System.Collections.Generic.Dictionary<HeroId, Texture2D> _portraits =
            new System.Collections.Generic.Dictionary<HeroId, Texture2D>();

        static readonly Color CGold = new Color(1f, 0.78f, 0.34f);
        static readonly Color CGoldDeep = new Color(0.72f, 0.48f, 0.16f);
        static readonly Color CInk = new Color(0.16f, 0.11f, 0.07f);
        static readonly Color CPanel = new Color(0.07f, 0.17f, 0.15f, 0.82f);
        static readonly Color CPanelDeep = new Color(0.05f, 0.12f, 0.11f, 0.9f);
        static readonly Color CCream = new Color(1f, 0.96f, 0.87f);

        Texture2D Portrait(HeroId id)
        {
            if (_portraits.TryGetValue(id, out var t) && t != null) return t;
            t = Resources.Load<Texture2D>("Portraits/" + id.ToString().ToLowerInvariant());
            _portraits[id] = t;
            return t;
        }
        Rect _pauseRect;

        void Awake()
        {
            I = this;
            _font = Resources.Load<Font>("Fonts/TapArenaCJK");
            if (_font == null)
                _font = Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif" }, 30);

            const int px = 96;
            _pad = new Texture2D(px, px, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            _ring = new Texture2D(px, px, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var a = new Color32[px * px];
            var b = new Color32[px * px];
            for (int y = 0; y < px; y++)
                for (int x = 0; x < px; x++)
                {
                    float dx = (x + 0.5f) / px * 2f - 1f, dy = (y + 0.5f) / px * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    a[y * px + x] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(1f - d) * 255f));
                    b[y * px + x] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(1f - Mathf.Abs(d - 0.9f) * 16f) * 255f));
                }
            _pad.SetPixels32(a); _pad.Apply();
            _ring.SetPixels32(b); _ring.Apply();
            _clear = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            _clear.SetPixel(0, 0, new Color(1f, 1f, 1f, 0f));
            _clear.Apply();
            _white = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            _white.SetPixel(0, 0, new Color(1f, 1f, 1f, 1f));
            _white.Apply();

            /* 圆角矩形：22% 圆角，边缘 1.5px 羽化，画卡片/血条底 */
            {
                const int s = 128;
                _round = new Texture2D(s, s, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
                var buf = new Color32[s * s];
                float r = s * 0.22f;
                for (int y = 0; y < s; y++)
                    for (int x = 0; x < s; x++)
                    {
                        float dx = Mathf.Max(0f, Mathf.Abs(x + 0.5f - s * 0.5f) - (s * 0.5f - r));
                        float dy = Mathf.Max(0f, Mathf.Abs(y + 0.5f - s * 0.5f) - (s * 0.5f - r));
                        float d = Mathf.Sqrt(dx * dx + dy * dy) - r;
                        float alpha = Mathf.Clamp01(0.5f - d);
                        buf[y * s + x] = new Color32(255, 255, 255, (byte)(alpha * 255f));
                    }
                _round.SetPixels32(buf); _round.Apply();
            }

            /* 硬边圆形：按钮与头像 */
            {
                const int s = 128;
                _disc = new Texture2D(s, s, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
                var buf = new Color32[s * s];
                for (int y = 0; y < s; y++)
                    for (int x = 0; x < s; x++)
                    {
                        float dx = (x + 0.5f) / s * 2f - 1f, dy = (y + 0.5f) / s * 2f - 1f;
                        float d = Mathf.Sqrt(dx * dx + dy * dy);
                        float alpha = Mathf.Clamp01((0.985f - d) * s * 1.2f);
                        buf[y * s + x] = new Color32(255, 255, 255, (byte)(alpha * 255f));
                    }
                _disc.SetPixels32(buf); _disc.Apply();
            }

            _gradH = MakeGrad(true, 256, t => Mathf.Pow(1f - t, 1.55f));
            _gradV = MakeGrad(false, 256, t => Mathf.Pow(t, 2.2f));
            _gradVDown = MakeGrad(false, 256, t => Mathf.Pow(1f - t, 2.2f));
        }

        static Texture2D MakeGrad(bool horizontal, int n, System.Func<float, float> alpha)
        {
            var t = new Texture2D(horizontal ? n : 1, horizontal ? 1 : n, TextureFormat.RGBA32, false)
            { wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[n];
            for (int i = 0; i < n; i++)
                px[i] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(alpha(i / (float)(n - 1))) * 255f));
            t.SetPixels32(px);
            t.Apply();
            return t;
        }

        GUIStyle Style(int size, TextAnchor anchor = TextAnchor.MiddleLeft, bool bold = false)
        {
            var s = new GUIStyle
            {
                font = _font,
                fontSize = Mathf.Max(9, Mathf.RoundToInt(size * _scale)),
                alignment = anchor,
                richText = false,
                wordWrap = false,
            };
            s.fontStyle = bold ? FontStyle.Bold : FontStyle.Normal;
            s.normal.background = _clear;
            s.normal.textColor = Color.white;
            s.hover.background = _clear; s.hover.textColor = Color.white;
            s.active.background = _clear; s.active.textColor = Color.white;
            s.focused.background = _clear; s.focused.textColor = Color.white;
            return s;
        }

        void EnsureStyles(float h)
        {
            float want = h / 1080f;
            if (_title != null && Mathf.Abs(want - _scale) < 0.02f) return;
            _scale = want;
            _title = Style(124, TextAnchor.MiddleLeft, true);
            _sub = Style(40, TextAnchor.MiddleLeft);
            _btn = Style(46, TextAnchor.MiddleCenter, true);
            _btnSmall = Style(28, TextAnchor.MiddleCenter, true);
            _card = Style(26, TextAnchor.MiddleCenter);
            _cardName = Style(40, TextAnchor.MiddleCenter, true);
            _hud = Style(30, TextAnchor.MiddleLeft, true);
            _hudSmall = Style(22, TextAnchor.MiddleLeft);
            _center = Style(44, TextAnchor.MiddleCenter, true);
            _big = Style(96, TextAnchor.MiddleCenter, true);
            _num = Style(38, TextAnchor.MiddleCenter, true);
            _chip = Style(24, TextAnchor.MiddleCenter, true);
            _hint = Style(26, TextAnchor.MiddleCenter);
            _name = Style(26, TextAnchor.MiddleLeft, true);
            _time = Style(40, TextAnchor.MiddleCenter, true);
        }

        static void Fill(Rect r, Color c, Texture2D tex)
        {
            var old = GUI.color;
            GUI.color = c;
            GUI.DrawTexture(r, tex, ScaleMode.StretchToFill);
            GUI.color = old;
        }

        static void Rounded(Rect r, Color c)
        {
            var old = GUI.color;
            GUI.color = c;
            GUI.DrawTexture(r, I != null ? I._round : Texture2D.whiteTexture, ScaleMode.StretchToFill);
            GUI.color = old;
        }

        static void Circle(Rect r, Color c)
        {
            var old = GUI.color;
            GUI.color = c;
            GUI.DrawTexture(r, I != null ? I._disc : Texture2D.whiteTexture, ScaleMode.StretchToFill);
            GUI.color = old;
        }

        static void Ring(Rect r, Color c)
        {
            var old = GUI.color;
            GUI.color = c;
            GUI.DrawTexture(r, I != null ? I._ring : Texture2D.whiteTexture, ScaleMode.StretchToFill);
            GUI.color = old;
        }

        static void Label(Rect r, string s, GUIStyle st, Color c)
        {
            var old = st.normal.textColor;
            st.normal.textColor = c;
            GUI.Label(r, s, st);
            st.normal.textColor = old;
        }

        static void LabelShadow(Rect r, string s, GUIStyle st, Color c, float off = 3f)
        {
            var old = st.normal.textColor;
            st.normal.textColor = new Color(0.06f, 0.09f, 0.08f, 0.55f * c.a);
            GUI.Label(new Rect(r.x + off, r.y + off, r.width, r.height), s, st);
            st.normal.textColor = c;
            GUI.Label(r, s, st);
            st.normal.textColor = old;
        }

        /* 金色大按钮：底影 + 主体 + 顶部高光 + 文字 */
        bool GoldButton(Rect r, string label, GUIStyle style)
        {
            Rounded(new Rect(r.x + 4f, r.y + 8f, r.width, r.height), new Color(0.18f, 0.12f, 0.06f, 0.35f));
            Rounded(r, new Color(0.62f, 0.40f, 0.13f, 0.98f));
            Rounded(new Rect(r.x, r.y, r.width, r.height * 0.94f), CGold);
            Fill(new Rect(r.x + r.width * 0.08f, r.y + r.height * 0.1f, r.width * 0.84f, r.height * 0.1f),
                new Color(1f, 0.94f, 0.7f, 0.55f), _round);
            bool hit = GUI.Button(r, GUIContent.none, _btnSmall);
            LabelShadow(new Rect(r.x, r.y + 1f, r.width, r.height), label, style, CInk, 2f);
            return hit;
        }

        bool DarkButton(Rect r, string label, GUIStyle style)
        {
            Rounded(r, new Color(0.10f, 0.22f, 0.19f, 0.94f));
            bool hit = GUI.Button(r, GUIContent.none, _btnSmall);
            Label(new Rect(r.x, r.y, r.width, r.height), label, style, CCream);
            return hit;
        }

        void OnGUI()
        {
            if (_font == null) return;
            EnsureStyles(Screen.height);
            GUI.skin.font = _font;
            switch (GameFlow.screen)
            {
                case UiScreen.Home: DrawHome(); break;
                case UiScreen.Select: DrawSelect(); break;
                case UiScreen.Battle: DrawBattle(); break;
                case UiScreen.Result: DrawResult(); break;
            }
        }

        /* ---------------- 首页 ---------------- */
        void DrawHome()
        {
            float w = Screen.width, h = Screen.height;
            /* 左侧柔和的暗角，右侧留出 3D 陈列台 */
            Fill(new Rect(0, 0, w * 0.72f, h), new Color(0.03f, 0.11f, 0.10f, 0.94f), _gradH);
            Fill(new Rect(0, h * 0.80f, w, h * 0.20f), new Color(0.02f, 0.08f, 0.07f, 0.9f), _gradVDown);

            float x = w * 0.075f;
            LabelShadow(new Rect(x, h * 0.15f, w * 0.66f, h * 0.2f), "萌兽峡谷", _title, CCream, 5f);
            Label(new Rect(x + h * 0.012f, h * 0.385f, w * 0.6f, h * 0.06f), "森林里的小英雄对决 · 3v3 推塔", _sub,
                new Color(1f, 0.95f, 0.84f, 0.92f));
            Fill(new Rect(x + h * 0.014f, h * 0.465f, w * 0.10f, h * 0.006f), CGold, _white);

            var btn = new Rect(x, h * 0.54f, w * 0.30f, h * 0.115f);
            if (GoldButton(btn, "开始冒险", _btn)) GameFlow.screen = UiScreen.Select;

            /* 三枚信息胶囊 */
            float cy = h * 0.70f;
            string[] chips = { "3v3 推塔", "一局约 4 分钟", "适合 6–12 岁" };
            float cxp = x + h * 0.012f;
            for (int i = 0; i < chips.Length; i++)
            {
                float cw = h * 0.19f;
                var cr = new Rect(cxp, cy, cw, h * 0.052f);
                Rounded(cr, new Color(0.08f, 0.2f, 0.17f, 0.8f));
                Label(cr, chips[i], _chip, new Color(0.93f, 0.97f, 0.9f, 0.92f));
                cxp += cw + h * 0.012f;
            }

            Label(new Rect(w * 0.78f, h * 0.9f, w * 0.2f, h * 0.05f), "Unity 版 v2.0.1", _hudSmall,
                new Color(1f, 1f, 1f, 0.55f));
        }

        /* ---------------- 选人 ---------------- */
        void DrawSelect()
        {
            float w = Screen.width, h = Screen.height;
            Fill(new Rect(0, 0, w, h), new Color(0.04f, 0.13f, 0.12f, 0.68f), _white);
            Fill(new Rect(0, 0, w, h * 0.28f), new Color(0.02f, 0.09f, 0.08f, 0.8f), _gradV);

            LabelShadow(new Rect(0, h * 0.035f, w, h * 0.09f), "选一位小英雄", _center, CCream, 3f);
            Label(new Rect(0, h * 0.112f, w, h * 0.04f), "点一下卡片，再按出发", _hint,
                new Color(1f, 0.96f, 0.86f, 0.7f));

            if (DarkButton(new Rect(w * 0.025f, h * 0.04f, w * 0.11f, h * 0.068f), "← 返回", _btnSmall))
                GameFlow.screen = UiScreen.Home;

            var all = HeroDef.All;
            float cw = w * 0.17f, ch = h * 0.335f;
            float gapX = w * 0.027f, gapY = h * 0.022f;
            float totalW = cw * 3f + gapX * 2f;
            float x0 = (w - totalW) * 0.5f, y0 = h * 0.155f;
            for (int i = 0; i < all.Length; i++)
            {
                var d = all[i];
                int col = i % 3, row = i / 3;
                var r = new Rect(x0 + col * (cw + gapX), y0 + row * (ch + gapY), cw, ch);
                bool on = GameFlow.picked == d.id;

                if (on) Rounded(new Rect(r.x - 7f, r.y - 7f, r.width + 14f, r.height + 14f),
                    new Color(1f, 0.85f, 0.44f, 0.38f));
                Rounded(r, on ? new Color(1f, 0.90f, 0.66f, 0.98f) : new Color(0.12f, 0.28f, 0.24f, 0.94f));
                if (!on) Rounded(new Rect(r.x, r.y, r.width, r.height * 0.58f), new Color(0.06f, 0.16f, 0.14f, 0.55f));

                var art = new Rect(r.x + r.width * 0.055f, r.y + r.height * 0.035f,
                    r.width * 0.89f, r.height * 0.555f);
                var tex = Portrait(d.id);
                if (tex != null)
                {
                    Fill(new Rect(art.x - 2f, art.y - 2f, art.width + 4f, art.height + 4f),
                        new Color(0.05f, 0.12f, 0.11f, 0.7f), _white);
                    GUI.DrawTexture(art, tex, ScaleMode.ScaleAndCrop, true);
                }
                else
                {
                    Circle(new Rect(art.x + art.width * 0.25f, art.y + art.height * 0.05f,
                        art.width * 0.5f, art.width * 0.5f), d.fur);
                }

                Color nameC = on ? CInk : CCream;
                Color roleC = on ? new Color(0.42f, 0.27f, 0.08f) : new Color(1f, 0.93f, 0.78f, 0.9f);
                Label(new Rect(r.x, r.y + r.height * 0.60f, r.width, r.height * 0.11f), d.name, _cardName, nameC);

                var roleBar = new Rect(r.x + r.width * 0.16f, r.y + r.height * 0.715f, r.width * 0.68f, r.height * 0.085f);
                Rounded(roleBar, on ? new Color(0.55f, 0.36f, 0.07f, 0.3f) : new Color(0.04f, 0.12f, 0.10f, 0.5f));
                Label(roleBar, d.role, _chip, roleC);

                string stars = new string('●', d.difficulty) + new string('○', 3 - d.difficulty);
                Label(new Rect(r.x, r.y + r.height * 0.815f, r.width, r.height * 0.085f), "难度 " + stars, _chip,
                    on ? new Color(0.55f, 0.34f, 0.08f) : new Color(1f, 0.88f, 0.6f, 0.9f));
                var tip = new Rect(r.x, r.y + r.height * 0.90f, r.width, r.height * 0.075f);
                Label(tip, on ? "已选择" : "点击选择", _chip,
                    on ? new Color(0.45f, 0.29f, 0.06f, 0.8f) : new Color(1f, 1f, 1f, 0.4f));

                if (GUI.Button(r, GUIContent.none, _btnSmall)) GameFlow.picked = d.id;
            }

            var go = new Rect(w * 0.355f, h * 0.885f, w * 0.29f, h * 0.088f);
            if (GoldButton(go, "出发！", _btn)) Boot.StartBattle(GameFlow.picked);
        }

        /* ---------------- 战斗 ---------------- */
        void DrawBattle()
        {
            var a = Arena.I;
            if (a == null) return;
            float w = Screen.width, h = Screen.height;

            /* 飘字（伤害数字） */
            var cam = CameraRig.I != null ? CameraRig.I.cam : Camera.main;
            if (cam != null)
            {
                foreach (var t in Fx.Texts)
                {
                    Vector3 sp = cam.WorldToScreenPoint(t.pos);
                    if (sp.z < 0f) continue;
                    float k = 1f - t.t / t.life;
                    _num.normal.textColor = new Color(0.06f, 0.09f, 0.08f, Mathf.Clamp01(k * 1.2f) * 0.6f);
                    var tr = new Rect(sp.x - 100f, Screen.height - sp.y - 20f, 200f, 46f);
                    GUI.Label(new Rect(tr.x + 2f, tr.y + 3f, tr.width, tr.height), t.s, _num);
                    _num.normal.textColor = new Color(t.c.r, t.c.g, t.c.b, Mathf.Clamp01(k * 1.6f));
                    GUI.Label(tr, t.s, _num);
                }
                _num.normal.textColor = Color.white;
            }

            /* 塔 / 水晶血条：投影到模型头顶，推塔时能看到进度 */
            var c0 = CameraRig.I != null ? CameraRig.I.cam : Camera.main;
            if (c0 != null)
            {
                foreach (var u in a.units)
                {
                    if (!u.alive || (u.kind != UnitKind.Tower && u.kind != UnitKind.Base)) continue;
                    Vector3 wp = u.pos + Vector3.up * (u.height * 0.55f + 20f);
                    Vector3 sp = c0.WorldToScreenPoint(wp);
                    if (sp.z <= 0f || sp.x < -80f || sp.x > w + 80f) continue;
                    float bw = u.kind == UnitKind.Base ? w * 0.09f : w * 0.065f;
                    float by = Mathf.Clamp(Screen.height - sp.y - 10f, h * 0.03f, h * 0.9f);
                    var br = new Rect(sp.x - bw * 0.5f, by, bw, h * 0.011f);
                    Rounded(br, new Color(0.03f, 0.08f, 0.07f, 0.8f));
                    float hpK = Mathf.Clamp01(u.hp / u.maxHp);
                    if (hpK > 0.005f)
                        Rounded(new Rect(br.x, br.y, br.width * hpK, br.height),
                            u.team == Team.Blue ? new Color(0.5f, 0.9f, 1f, 0.95f) : new Color(1f, 0.62f, 0.55f, 0.95f));
                }
            }

            /* 左上：英雄状态 */
            if (a.player != null)
            {
                var p = a.player;
                var plate = new Rect(w * 0.012f, h * 0.022f, w * 0.315f, h * 0.116f);
                Rounded(plate, CPanel);
                var av = new Rect(plate.x + h * 0.012f, plate.y + h * 0.012f, h * 0.082f, h * 0.082f);
                Circle(new Rect(av.x - 3f, av.y - 3f, av.width + 6f, av.height + 6f), new Color(1f, 0.82f, 0.42f, 0.9f));
                Circle(av, new Color(0.04f, 0.1f, 0.09f, 0.96f));
                var avTex = Portrait(p.def.id);
                if (avTex != null) GUI.DrawTexture(new Rect(av.x + 3f, av.y + 3f, av.width - 6f, av.height - 6f), avTex, ScaleMode.ScaleAndCrop, true);
                else Circle(new Rect(av.x + av.width * 0.2f, av.y + av.height * 0.2f, av.width * 0.6f, av.height * 0.6f), p.def.fur);
                var lv = new Rect(av.xMax - h * 0.034f, av.yMax - h * 0.028f, h * 0.046f, h * 0.046f);
                Circle(lv, new Color(1f, 0.83f, 0.42f, 1f));
                Label(lv, p.level.ToString(), _chip, CInk);

                Label(new Rect(av.xMax + h * 0.016f, plate.y + h * 0.01f, plate.width * 0.7f, h * 0.03f),
                    p.def.name + " · " + p.def.role, _name, CCream);
                var bar = new Rect(av.xMax + h * 0.016f, plate.y + h * 0.046f, plate.width - h * 0.115f, h * 0.026f);
                Rounded(bar, new Color(0.02f, 0.08f, 0.07f, 0.85f));
                var fillRect = new Rect(bar.x + 2f, bar.y + 2f, (bar.width - 4f) * Mathf.Clamp01(p.hp / p.maxHp), bar.height - 4f);
                if (fillRect.width > 2f) Rounded(fillRect, new Color(0.44f, 0.87f, 0.5f, 0.96f));
                Label(new Rect(bar.x, bar.y - h * 0.002f, bar.width, bar.height),
                    Mathf.CeilToInt(p.hp) + " / " + Mathf.RoundToInt(p.maxHp), _hudSmall, new Color(0.95f, 1f, 0.95f, 0.95f));
                if (p.shield > 1f)
                {
                    var sb = new Rect(bar.x, bar.yMax + h * 0.004f, (bar.width) * Mathf.Clamp01(p.shield / p.maxHp), h * 0.012f);
                    Rounded(sb, new Color(0.6f, 0.9f, 1f, 0.9f));
                }
                /* 大招经验：2 级前是一根细金条，解锁后变成"大招就绪" */
                var xb = new Rect(bar.x, bar.yMax + h * 0.021f, bar.width, h * 0.008f);
                Rounded(xb, new Color(0.03f, 0.08f, 0.07f, 0.72f));
                if (p.level < 2)
                {
                    float k = Mathf.Clamp01(p.xp / 300f);
                    if (k > 0.01f) Rounded(new Rect(xb.x, xb.y, xb.width * k, xb.height),
                        new Color(1f, 0.80f, 0.35f, 0.95f));
                    Circle(new Rect(xb.x - h * 0.006f, xb.y - h * 0.003f, h * 0.014f, h * 0.014f),
                        new Color(1f, 0.86f, 0.45f, 0.9f));
                }
                else
                    Rounded(new Rect(xb.x, xb.y, xb.width, xb.height), new Color(1f, 0.80f, 0.35f, 0.92f));
            }

            /* 中上：比分与时间 */
            var top = new Rect(w * 0.5f - w * 0.155f, h * 0.02f, w * 0.31f, h * 0.072f);
            Rounded(new Rect(top.x, top.y + 4f, top.width, top.height), new Color(0.1f, 0.06f, 0.04f, 0.3f));
            Rounded(top, new Color(0.07f, 0.17f, 0.15f, 0.9f));
            Fill(new Rect(top.x + top.width * 0.03f, top.y, top.width * 0.94f, h * 0.004f), new Color(1f, 0.82f, 0.4f, 0.5f), _white);
            int mm = Mathf.FloorToInt(a.clock / 60f), ss = Mathf.FloorToInt(a.clock % 60f);
            Label(new Rect(top.x + w * 0.02f, top.y, top.width * 0.22f, top.height), a.scoreBlue.ToString(), _center,
                new Color(0.55f, 0.9f, 1f));
            Label(new Rect(top.x + top.width * 0.72f, top.y, top.width * 0.22f, top.height), a.scoreRed.ToString(), _center,
                new Color(1f, 0.65f, 0.58f));
            Label(new Rect(top.x + top.width * 0.25f, top.y, top.width * 0.5f, top.height), $"{mm:00}:{ss:00}", _time, CCream);

            /* 右上：小地图 */
            var mini = new Rect(w - w * 0.228f, h * 0.02f, w * 0.208f, h * 0.16f);
            Rounded(mini, CPanel);
            DrawMinimap(mini, a);
            _pauseRect = new Rect(mini.xMax - h * 0.076f, mini.yMax + h * 0.012f, h * 0.064f, h * 0.064f);
            Rounded(_pauseRect, CPanelDeep);
            Fill(new Rect(_pauseRect.x + _pauseRect.width * 0.34f, _pauseRect.y + _pauseRect.height * 0.3f,
                _pauseRect.width * 0.1f, _pauseRect.height * 0.4f), CCream, _white);
            Fill(new Rect(_pauseRect.x + _pauseRect.width * 0.56f, _pauseRect.y + _pauseRect.height * 0.3f,
                _pauseRect.width * 0.1f, _pauseRect.height * 0.4f), CCream, _white);
            if (GUI.Button(_pauseRect, GUIContent.none, _btnSmall)) Boot.Pause(!Boot.Paused);

            /* 技能按钮：右下扇形排布 */
            float bs = h * 0.15f;
            Rect[] arc = new Rect[3];
            arc[0] = new Rect(w - h * 0.30f - bs * 0.5f, h - h * 0.24f - bs * 0.5f, bs, bs);
            arc[1] = new Rect(w - h * 0.19f - bs * 0.5f, h - h * 0.40f - bs * 0.5f, bs, bs);
            arc[2] = new Rect(w - h * 0.20f - bs * 0.5f, h - h * 0.60f - bs * 0.5f, bs, bs);
            _skillRects = arc;
            var p2 = a.player;
            for (int i = 0; i < 3; i++)
            {
                var r = arc[i];
                var s = p2 != null ? p2.skills[i] : null;
                bool locked = s != null && s.unlockAt2 && (p2 == null || p2.level < 2);
                bool ready = p2 != null && p2.cds[i] <= 0f && !locked;

                Circle(new Rect(r.x - 6f, r.y - 6f, r.width + 12f, r.height + 12f),
                    locked ? new Color(0.06f, 0.09f, 0.08f, 0.7f) : new Color(0.42f, 0.27f, 0.08f, 0.85f));
                Circle(r, locked ? new Color(0.28f, 0.32f, 0.30f, 0.9f)
                    : (i == 2 ? new Color(1f, 0.84f, 0.45f, 0.97f) : new Color(0.98f, 0.72f, 0.36f, 0.97f)));
                if (!locked)
                    Ring(new Rect(r.x + 4f, r.y + 4f, r.width - 8f, r.height - 8f), new Color(1f, 0.97f, 0.8f, 0.5f));

                if (locked)
                {
                    Label(r, "锁", _cardName, new Color(1f, 1f, 1f, 0.7f));
                    Label(new Rect(r.x, r.y + r.height * 0.66f, r.width, r.height * 0.24f), "2 级解锁", _chip,
                        new Color(1f, 1f, 1f, 0.75f));
                }
                else
                {
                    bool cooling = p2 != null && p2.cds[i] > 0f;
                    Label(new Rect(r.x, r.y + r.height * (cooling ? 0.08f : 0.26f), r.width,
                        r.height * (cooling ? 0.30f : 0.42f)),
                        s != null ? s.name : "技能", cooling ? _chip : _cardName,
                        cooling ? new Color(1f, 0.95f, 0.85f, 0.85f) : CInk);
                    if (cooling)
                    {
                        Circle(r, new Color(0.04f, 0.08f, 0.07f, 0.55f));
                        Label(new Rect(r.x, r.y + r.height * 0.06f, r.width, r.height * 0.28f),
                            s != null ? s.name : "技能", _chip, new Color(1f, 0.95f, 0.85f, 0.9f));
                        Label(new Rect(r.x, r.y + r.height * 0.36f, r.width, r.height * 0.5f),
                            Mathf.CeilToInt(p2.cds[i]).ToString(), _center, Color.white);
                    }
                    else if (ready && i == 2)
                    {
                        Ring(new Rect(r.x - 10f, r.y - 10f, r.width + 20f, r.height + 20f),
                            new Color(1f, 0.92f, 0.6f, 0.35f));
                    }
                }
            }

            /* 摇杆 */
            if (InputHub.JoyVisible)
            {
                var c = new Vector2(InputHub.JoyCenter.x, Screen.height - InputHub.JoyCenter.y);
                var knob = new Vector2(InputHub.JoyKnob.x, Screen.height - InputHub.JoyKnob.y);
                Circle(new Rect(c.x - 130f, c.y - 130f, 260f, 260f), new Color(0.05f, 0.12f, 0.10f, 0.3f));
                Ring(new Rect(c.x - 130f, c.y - 130f, 260f, 260f), new Color(1f, 0.95f, 0.8f, 0.35f));
                Circle(new Rect(knob.x - 58f, knob.y - 58f, 116f, 116f), new Color(1f, 0.96f, 0.85f, 0.68f));
            }

            /* 残血警示 + 倒下倒计时 */
            var pp = a.player;
            if (pp != null)
            {
                float hpP = pp.hp / Mathf.Max(1f, pp.maxHp);
                if (hpP < 0.26f && pp.alive)
                {
                    float pulse = 0.06f + Mathf.Sin(Time.unscaledTime * 6f) * 0.025f;
                    Fill(new Rect(0, 0, w, h), new Color(0.55f, 0.04f, 0.04f, Mathf.Max(0.02f, pulse)), _white);
                }
                if (!pp.alive)
                {
                    var dead = new Rect(w * 0.5f - w * 0.16f, h * 0.38f, w * 0.32f, h * 0.16f);
                    Rounded(dead, new Color(0.06f, 0.13f, 0.11f, 0.82f));
                    Fill(new Rect(dead.x + dead.width * 0.25f, dead.y + 2f, dead.width * 0.5f, 4f),
                        new Color(1f, 0.6f, 0.45f, 0.7f), _white);
                    LabelShadow(new Rect(dead.x, dead.y + dead.height * 0.1f, dead.width, dead.height * 0.45f),
                        "倒下啦…", _center, new Color(1f, 0.86f, 0.78f), 3f);
                    Label(new Rect(dead.x, dead.y + dead.height * 0.55f, dead.width, dead.height * 0.35f),
                        Mathf.Max(1, Mathf.CeilToInt(pp.respawnT)) + " 秒后复活", _hint,
                        new Color(1f, 0.96f, 0.86f, 0.9f));
                }
            }

            /* 开局小提示 */
            if (a.clock < 9f && !Boot.Paused)
            {
                float k = a.clock < 7f ? 1f : (9f - a.clock) * 0.5f;
                var hint = new Rect(w * 0.5f - w * 0.2f, h * 0.86f, w * 0.4f, h * 0.055f);
                Rounded(hint, new Color(0.05f, 0.14f, 0.12f, 0.55f * k));
                Label(hint, "拖左下摇杆移动 · 点右边技能出招", _hint, new Color(1f, 0.97f, 0.88f, 0.9f * k));
            }


            /* 播报 */
            foreach (var b in Fx.Banners)
            {
                float k = 1f - b.t / b.life;
                float aa = Mathf.Clamp01(k * 2f);
                var r = new Rect(w * 0.22f, h * 0.13f, w * 0.56f, h * 0.075f);
                Rounded(new Rect(r.x, r.y + 3f, r.width, r.height), new Color(0.05f, 0.12f, 0.10f, 0.35f * aa));
                Rounded(r, new Color(0.06f, 0.16f, 0.13f, 0.72f * aa));
                Fill(new Rect(r.x + r.width * 0.3f, r.yMax - 5f, r.width * 0.4f, 3f), new Color(1f, 0.84f, 0.44f, 0.7f * aa), _white);
                LabelShadow(r, b.s, _center, new Color(1f, 0.97f, 0.88f, aa), 2f);
            }

            if (Boot.Paused) DrawPause();
        }

        void DrawMinimap(Rect r, Arena a)
        {
            var inner = new Rect(r.x + r.width * 0.06f, r.y + r.height * 0.12f, r.width * 0.88f, r.height * 0.76f);
            Fill(inner, new Color(0.12f, 0.26f, 0.2f, 0.9f), _round);
            System.Func<Vector3, Vector2> map = p => new Vector2(
                inner.x + p.x / Arena.MapW * inner.width,
                inner.y + (1f - p.z / Arena.MapH) * inner.height);

            /* 兵线：一串小点 */
            var lane = Arena.Lane;
            for (int i = 0; i < lane.Length - 1; i++)
            {
                for (int k = 0; k < 8; k++)
                {
                    Vector3 p = Vector3.Lerp(lane[i], lane[i + 1], k / 8f);
                    Vector2 m = map(p);
                    Fill(new Rect(m.x - 2f, m.y - 2f, 4f, 4f), new Color(0.95f, 0.82f, 0.55f, 0.22f), _white);
                }
            }

            foreach (var u in a.units)
            {
                if (!u.alive) continue;
                Vector2 m = map(u.pos);
                Color c = u.team == Team.Blue ? new Color(0.55f, 0.9f, 1f) : new Color(1f, 0.62f, 0.55f);
                if (u == a.player) c = Color.white;
                if (u.kind == UnitKind.Base)
                {
                    Circle(new Rect(m.x - 6f, m.y - 6f, 12f, 12f), c);
                    Ring(new Rect(m.x - 8f, m.y - 8f, 16f, 16f), new Color(1f, 0.96f, 0.85f, 0.7f));
                    continue;
                }
                float s = u.kind == UnitKind.Hero ? 8f : (u.kind == UnitKind.Minion ? 4f : 6f);
                Fill(new Rect(m.x - s * 0.5f, m.y - s * 0.5f, s, s), c, _white);
                if (u == a.player) Ring(new Rect(m.x - 9f, m.y - 9f, 18f, 18f), new Color(1f, 0.85f, 0.45f, 0.9f));
            }
        }

        void DrawPause()
        {
            float w = Screen.width, h = Screen.height;
            Fill(new Rect(0, 0, w, h), new Color(0.03f, 0.10f, 0.09f, 0.72f), _white);
            var panel = new Rect(w * 0.32f, h * 0.16f, w * 0.36f, h * 0.68f);
            Rounded(new Rect(panel.x, panel.y + 6f, panel.width, panel.height), new Color(0.02f, 0.06f, 0.05f, 0.35f));
            Rounded(panel, new Color(0.10f, 0.24f, 0.20f, 0.98f));
            Fill(new Rect(panel.x + panel.width * 0.25f, panel.y + 2f, panel.width * 0.5f, 4f),
                new Color(1f, 0.84f, 0.44f, 0.55f), _white);
            LabelShadow(new Rect(panel.x, panel.y + h * 0.035f, panel.width, h * 0.09f), "暂停一下", _center, CCream, 3f);

            var r1 = new Rect(panel.x + panel.width * 0.2f, panel.y + h * 0.15f, panel.width * 0.6f, h * 0.085f);
            if (GoldButton(r1, "继续", _btn)) Boot.Pause(false);
            var r2 = new Rect(panel.x + panel.width * 0.2f, panel.y + h * 0.26f, panel.width * 0.6f, h * 0.085f);
            if (DarkButton(r2, "重新开始", _btnSmall)) { Boot.Pause(false); Boot.StartBattle(GameFlow.picked); }
            var r3 = new Rect(panel.x + panel.width * 0.2f, panel.y + h * 0.37f, panel.width * 0.6f, h * 0.085f);
            if (DarkButton(r3, "回首页", _btnSmall)) { Boot.Pause(false); Boot.ToHome(); }
            var r4 = new Rect(panel.x + panel.width * 0.2f, panel.y + h * 0.48f, panel.width * 0.6f, h * 0.085f);
            bool sound = AudioListener.volume > 0.01f;
            if (DarkButton(r4, sound ? "音效：开" : "音效：关", _btnSmall))
                AudioListener.volume = sound ? 0f : 1f;
            Label(new Rect(panel.x, panel.y + panel.height - h * 0.075f, panel.width, h * 0.05f),
                "按 Esc / 返回键继续", _hint, new Color(1f, 1f, 1f, 0.45f));
        }

        /* ---------------- 结算 ---------------- */
        void DrawResult()
        {
            var a = Arena.I;
            float w = Screen.width, h = Screen.height;
            Fill(new Rect(0, 0, w, h), new Color(0.03f, 0.10f, 0.09f, 0.76f), _white);
            bool win = a != null && a.winner == Team.Blue;

            var panel = new Rect(w * 0.26f, h * 0.14f, w * 0.48f, h * 0.72f);
            Rounded(new Rect(panel.x, panel.y + 8f, panel.width, panel.height), new Color(0.02f, 0.06f, 0.05f, 0.4f));
            Rounded(panel, new Color(0.10f, 0.24f, 0.20f, 0.96f));
            Fill(new Rect(panel.x + panel.width * 0.22f, panel.y + 2f, panel.width * 0.56f, 4f),
                new Color(1f, 0.84f, 0.44f, 0.6f), _white);

            LabelShadow(new Rect(panel.x, panel.y + h * 0.05f, panel.width, h * 0.16f),
                win ? "胜利！" : "水晶被点亮了", _big, win ? new Color(1f, 0.91f, 0.6f) : new Color(1f, 0.85f, 0.8f), 4f);

            var av = new Rect(panel.x + panel.width * 0.5f - h * 0.055f, panel.y + h * 0.25f, h * 0.11f, h * 0.11f);
            Circle(new Rect(av.x - 4f, av.y - 4f, av.width + 8f, av.height + 8f), new Color(1f, 0.83f, 0.44f, 0.9f));
            var tex = Portrait(GameFlow.picked);
            if (tex != null) GUI.DrawTexture(av, tex, ScaleMode.ScaleAndCrop, true);
            Label(new Rect(panel.x, panel.y + h * 0.375f, panel.width, h * 0.045f),
                HeroDef.Get(GameFlow.picked).name, _cardName, CCream);

            if (a != null)
                Label(new Rect(panel.x, panel.y + h * 0.43f, panel.width, h * 0.06f),
                    $"击杀 {a.scoreBlue} : {a.scoreRed}   ·   用时 {Mathf.FloorToInt(a.clock / 60f)}:{Mathf.FloorToInt(a.clock % 60f):00}",
                    _center, new Color(1f, 0.95f, 0.84f, 0.9f));

            var r = new Rect(panel.x + panel.width * 0.2f, panel.y + h * 0.53f, panel.width * 0.6f, h * 0.095f);
            if (GoldButton(r, "再来一局", _btn)) Boot.StartBattle(GameFlow.picked);
            var r2 = new Rect(panel.x + panel.width * 0.2f, panel.y + h * 0.645f, panel.width * 0.6f, h * 0.075f);
            if (DarkButton(r2, "回首页", _btnSmall)) Boot.ToHome();
        }

        void Update()
        {
            if (GameFlow.screen != UiScreen.Battle) return;
            if (Boot.Paused) return;          // 暂停时不吃技能触摸（Esc 由 Boot 统一处理）
            /* 触屏点技能键：OnGUI 里算好的矩形 */
            if (Input.touchCount > 0)
            {
                for (int i = 0; i < Input.touchCount; i++)
                {
                    var t = Input.GetTouch(i);
                    if (t.phase != TouchPhase.Began) continue;
                    var p = new Vector2(t.position.x, Screen.height - t.position.y);
                    for (int k = 0; k < 3; k++)
                        if (_skillRects[k].Contains(p)) InputHub.SetSkill(k);
                }
            }
        }
    }
}
