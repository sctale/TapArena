using System.Collections.Generic;
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
        GUIStyle _title, _sub, _btn, _btnSmall, _card, _cardName, _hud, _hudSmall,
            _center, _section, _big, _num, _chip, _hint, _name, _time, _stat, _skillName, _micro;
        Texture2D _pad, _ring, _clear, _white, _round, _disc;
        Texture2D _gradH, _gradHRev, _gradV, _gradVDown;
        Texture2D[] _cdPie = new Texture2D[3];
        float[] _cdRatio = { -1f, -1f, -1f };
        readonly Dictionary<HeroId, Texture2D> _portraits = new Dictionary<HeroId, Texture2D>();
        readonly Dictionary<HeroId, Texture2D> _headPortraits = new Dictionary<HeroId, Texture2D>();
        readonly Dictionary<SkillKind, Texture2D> _icons = new Dictionary<SkillKind, Texture2D>();
        float _scale = 1f;
        Rect[] _skillRects = new Rect[3];

        static readonly Color CGold = new Color(1f, 0.78f, 0.34f);
        static readonly Color CGoldSoft = new Color(1f, 0.88f, 0.58f);
        static readonly Color CInk = new Color(0.14f, 0.10f, 0.06f);
        static readonly Color CPanel = new Color(0.07f, 0.17f, 0.15f, 0.9f);
        static readonly Color CPanelDeep = new Color(0.05f, 0.13f, 0.11f, 0.95f);
        static readonly Color CCream = new Color(1f, 0.96f, 0.87f);
        static readonly Color CBlue = new Color(0.55f, 0.90f, 1f);
        static readonly Color CRed = new Color(1f, 0.62f, 0.55f);
        static readonly Color CGreen = new Color(0.52f, 0.92f, 0.58f);

        Texture2D Portrait(HeroId id)
        {
            if (_portraits.TryGetValue(id, out var t) && t != null) return t;
            t = Resources.Load<Texture2D>("Portraits/" + id.ToString().ToLowerInvariant());
            _portraits[id] = t;
            return t;
        }

        Texture2D PortraitHead(HeroId id)
        {
            if (_headPortraits.TryGetValue(id, out var t) && t != null) return t;
            t = Resources.Load<Texture2D>("Portraits/" + id.ToString().ToLowerInvariant() + "_head");
            if (t == null) t = Portrait(id);
            _headPortraits[id] = t;
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
                    b[y * px + x] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(1f - Mathf.Abs(d - 0.88f) * 18f) * 255f));
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
            _gradHRev = MakeGrad(true, 256, t => Mathf.Pow(t, 1.55f));
            _gradV = MakeGrad(false, 256, t => Mathf.Pow(t, 2.2f));
            _gradVDown = MakeGrad(false, 256, t => Mathf.Pow(1f - t, 2.2f));

            for (int i = 0; i < 3; i++)
                _cdPie[i] = MakePie(Color.clear);

            foreach (SkillKind k in System.Enum.GetValues(typeof(SkillKind)))
                _icons[k] = BuildIcon(k);
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
            _title = Style(120, TextAnchor.MiddleLeft, true);
            _sub = Style(38, TextAnchor.MiddleLeft);
            _btn = Style(46, TextAnchor.MiddleCenter, true);
            _btnSmall = Style(28, TextAnchor.MiddleCenter, true);
            _card = Style(24, TextAnchor.MiddleCenter);
            _cardName = Style(38, TextAnchor.MiddleCenter, true);
            _hud = Style(30, TextAnchor.MiddleLeft, true);
            _hudSmall = Style(21, TextAnchor.MiddleLeft);
            _center = Style(42, TextAnchor.MiddleCenter, true);
            _section = Style(54, TextAnchor.MiddleCenter, true);
            _big = Style(100, TextAnchor.MiddleCenter, true);
            _num = Style(38, TextAnchor.MiddleCenter, true);
            _chip = Style(22, TextAnchor.MiddleCenter, true);
            _hint = Style(26, TextAnchor.MiddleCenter);
            _name = Style(28, TextAnchor.MiddleLeft, true);
            _time = Style(42, TextAnchor.MiddleCenter, true);
            _stat = Style(28, TextAnchor.MiddleLeft);
            _skillName = Style(21, TextAnchor.MiddleCenter, true);
            _micro = Style(19, TextAnchor.MiddleCenter);
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
            st.normal.textColor = new Color(0.04f, 0.07f, 0.06f, 0.55f * c.a);
            GUI.Label(new Rect(r.x + off, r.y + off, r.width, r.height), s, st);
            st.normal.textColor = c;
            GUI.Label(r, s, st);
            st.normal.textColor = old;
        }

        static void Panel(Rect r, Color c)
        {
            Rounded(new Rect(r.x + 3f, r.y + 6f, r.width, r.height), new Color(0.02f, 0.05f, 0.04f, 0.32f));
            Rounded(r, c);
            Fill(new Rect(r.x + r.width * 0.04f, r.y + 1f, r.width * 0.92f, 2f),
                new Color(1f, 0.84f, 0.44f, 0.5f), I != null ? I._white : Texture2D.whiteTexture);
        }

        static void Chip(Rect r, string s, Color bg, Color fg, GUIStyle st)
        {
            Rounded(r, bg);
            Label(r, s, st, fg);
        }

        static void HLine(Rect r, Color c)
        {
            Fill(new Rect(r.x, r.y, r.width, Mathf.Max(1f, r.height)), c, I != null ? I._white : Texture2D.whiteTexture);
        }

        /* 金色大按钮：底影 + 深色边 + 主体 + 顶部高光 + 文字 */
        bool GoldButton(Rect r, string label, GUIStyle style)
        {
            Rounded(new Rect(r.x + 4f, r.y + 8f, r.width, r.height), new Color(0.16f, 0.10f, 0.05f, 0.38f));
            Rounded(new Rect(r.x - 2f, r.y - 2f, r.width + 4f, r.height + 4f), new Color(0.62f, 0.40f, 0.13f, 0.98f));
            Rounded(r, CGold);
            Fill(new Rect(r.x + r.width * 0.07f, r.y + r.height * 0.09f, r.width * 0.86f, r.height * 0.13f),
                new Color(1f, 0.95f, 0.72f, 0.6f), _round);
            bool hit = GUI.Button(r, GUIContent.none, _btnSmall);
            LabelShadow(new Rect(r.x, r.y + 1f, r.width, r.height), label, style, CInk, 2f);
            return hit;
        }

        bool DarkButton(Rect r, string label, GUIStyle style)
        {
            Rounded(new Rect(r.x + 3f, r.y + 4f, r.width, r.height), new Color(0.02f, 0.05f, 0.04f, 0.3f));
            Rounded(r, new Color(0.10f, 0.24f, 0.20f, 0.96f));
            Fill(new Rect(r.x + r.width * 0.08f, r.y + 1f, r.width * 0.84f, 2f),
                new Color(1f, 0.88f, 0.5f, 0.28f), _white);
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
            Fill(new Rect(0, 0, w * 0.72f, h), new Color(0.03f, 0.11f, 0.10f, 0.94f), _gradH);
            Fill(new Rect(0, h * 0.78f, w, h * 0.22f), new Color(0.02f, 0.08f, 0.07f, 0.92f), _gradVDown);

            float x = w * 0.075f;
            var badge = new Rect(x, h * 0.105f, w * 0.22f, h * 0.046f);
            Chip(badge, "3v3 · 森林推塔", new Color(0.10f, 0.26f, 0.21f, 0.9f),
                new Color(1f, 0.90f, 0.66f), _chip);
            Circle(new Rect(badge.x + 12f, badge.y + badge.height * 0.35f, badge.height * 0.30f, badge.height * 0.30f),
                CGold);

            LabelShadow(new Rect(x, h * 0.155f, w * 0.66f, h * 0.20f), "萌兽峡谷", _title, CCream, 5f);
            Label(new Rect(x + h * 0.012f, h * 0.395f, w * 0.62f, h * 0.06f),
                "六位小英雄，一起去点亮水晶", _sub, new Color(1f, 0.95f, 0.84f, 0.92f));
            HLine(new Rect(x + h * 0.014f, h * 0.482f, w * 0.10f, h * 0.005f), CGold);

            var btn = new Rect(x, h * 0.555f, w * 0.30f, h * 0.115f);
            if (GoldButton(btn, "开始冒险", _btn)) GameFlow.screen = UiScreen.Select;

            float cy = h * 0.715f;
            string[] chips = { "一局约 4 分钟", "适合 6–12 岁", "单手也能玩" };
            float cxp = x + h * 0.012f;
            for (int i = 0; i < chips.Length; i++)
            {
                float cw = h * 0.205f;
                var cr = new Rect(cxp, cy, cw, h * 0.052f);
                Rounded(cr, new Color(0.08f, 0.21f, 0.18f, 0.82f));
                Label(cr, chips[i], _chip, new Color(0.93f, 0.97f, 0.90f, 0.94f));
                cxp += cw + h * 0.012f;
            }

            Label(new Rect(w * 0.77f, h * 0.91f, w * 0.21f, h * 0.045f),
                "Unity 版 v" + Application.version, _hudSmall, new Color(1f, 1f, 1f, 0.55f));
        }

        /* ---------------- 选人 ---------------- */
        void DrawSelect()
        {
            float w = Screen.width, h = Screen.height;
            Fill(new Rect(0, 0, w, h), new Color(0.03f, 0.11f, 0.10f, 0.88f), _white);
            Fill(new Rect(0, 0, w, h * 0.30f), new Color(0.02f, 0.09f, 0.08f, 0.88f), _gradV);
            Fill(new Rect(0, h * 0.70f, w, h * 0.30f), new Color(0.02f, 0.07f, 0.06f, 0.6f), _gradVDown);

            LabelShadow(new Rect(0, h * 0.022f, w, h * 0.08f), "选一位小英雄", _section, CCream, 3f);
            Label(new Rect(0, h * 0.108f, w, h * 0.038f), "点一下卡片，看技能，再出发", _hint,
                new Color(1f, 0.96f, 0.86f, 0.72f));

            if (DarkButton(new Rect(w * 0.025f, h * 0.035f, w * 0.10f, h * 0.065f), "← 返回", _btnSmall))
                GameFlow.screen = UiScreen.Home;
            Chip(new Rect(w * 0.755f, h * 0.045f, w * 0.22f, h * 0.048f), "6 位英雄 · 每局 3v3",
                new Color(0.08f, 0.20f, 0.17f, 0.85f), new Color(1f, 0.93f, 0.78f, 0.9f), _chip);

            var all = HeroDef.All;
            float margin = w * 0.032f, gap = w * 0.012f;
            float cw = (w - margin * 2f - gap * (all.Length - 1)) / all.Length;
            float ch = h * 0.425f;
            float y0 = h * 0.158f;
            for (int i = 0; i < all.Length; i++)
            {
                var d = all[i];
                var r = new Rect(margin + i * (cw + gap), y0, cw, ch);
                bool on = GameFlow.picked == d.id;
                var accent = d.accent;

                if (on)
                {
                    Rounded(new Rect(r.x - 7f, r.y - 7f, r.width + 14f, r.height + 14f),
                        new Color(1f, 0.86f, 0.46f, 0.42f));
                    Rounded(new Rect(r.x - 3f, r.y - 3f, r.width + 6f, r.height + 6f),
                        new Color(1f, 0.93f, 0.68f, 0.95f));
                }
                else
                    Rounded(new Rect(r.x + 3f, r.y + 5f, r.width, r.height), new Color(0.02f, 0.05f, 0.04f, 0.32f));

                Rounded(r, on ? new Color(1f, 0.94f, 0.78f, 0.98f) : new Color(0.10f, 0.24f, 0.20f, 0.96f));
                Fill(new Rect(r.x + r.width * 0.06f, r.y + 1f, r.width * 0.88f, 4f),
                    on ? new Color(0.55f, 0.33f, 0.06f, 0.55f) : new Color(accent.r, accent.g, accent.b, 0.8f), _white);

                var art = new Rect(r.x + cw * 0.055f, r.y + ch * 0.035f, cw * 0.89f, ch * 0.585f);
                Rounded(art, on ? new Color(1f, 0.91f, 0.68f, 0.55f) : new Color(0.05f, 0.15f, 0.12f, 0.75f));
                Circle(new Rect(art.x + art.width * 0.16f, art.y + art.height * 0.10f,
                    art.width * 0.68f, art.width * 0.68f), new Color(accent.r, accent.g, accent.b, 0.13f));

                var tex = Portrait(d.id);
                if (tex != null)
                    GUI.DrawTexture(art, tex, ScaleMode.ScaleToFit, true);
                else
                {
                    Circle(new Rect(art.x + art.width * 0.22f, art.y + art.height * 0.05f,
                        art.width * 0.56f, art.width * 0.56f), d.fur);
                    Label(art, d.name.Substring(0, 1), _big, CInk);
                }

                Color nameC = on ? CInk : CCream;
                Color roleC = on ? new Color(0.44f, 0.28f, 0.08f) : new Color(1f, 0.93f, 0.78f, 0.9f);
                Label(new Rect(r.x, r.y + ch * 0.625f, r.width, ch * 0.105f), d.name, _cardName, nameC);

                var roleBar = new Rect(r.x + r.width * 0.16f, r.y + ch * 0.735f, r.width * 0.68f, ch * 0.075f);
                Rounded(roleBar, on ? new Color(0.55f, 0.36f, 0.07f, 0.24f) : new Color(0.04f, 0.12f, 0.10f, 0.55f));
                Label(roleBar, d.role, _chip, roleC);

                string stars = new string('●', d.difficulty) + new string('○', 3 - d.difficulty);
                Label(new Rect(r.x, r.y + ch * 0.815f, r.width, ch * 0.075f), "难度 " + stars, _chip,
                    on ? new Color(0.55f, 0.34f, 0.08f) : new Color(1f, 0.88f, 0.6f, 0.9f));
                Label(new Rect(r.x, r.y + ch * 0.905f, r.width, ch * 0.065f), on ? "已选择" : "点击选择", _micro,
                    on ? new Color(0.45f, 0.29f, 0.06f, 0.85f) : new Color(1f, 1f, 1f, 0.38f));

                if (GUI.Button(r, GUIContent.none, _btnSmall)) GameFlow.picked = d.id;
            }

            DrawPickDetail(new Rect(w * 0.035f, h * 0.655f, w * 0.93f, h * 0.30f));
        }

        void DrawPickDetail(Rect dp)
        {
            Panel(dp, CPanelDeep);
            var d = HeroDef.Get(GameFlow.picked);
            float h = Screen.height, w = Screen.width;
            Label(new Rect(dp.x + w * 0.018f, dp.y + h * 0.010f, w * 0.52f, h * 0.040f),
                d.name + "  ·  " + d.title, _cardName, CCream);
            Label(new Rect(dp.x + w * 0.018f, dp.y + h * 0.050f, w * 0.62f, h * 0.028f),
                d.role + " · " + d.blurb, _hint, new Color(1f, 0.95f, 0.84f, 0.82f));

            float rowH = h * 0.060f, rowGap = h * 0.004f;
            float sy = dp.y + h * 0.080f;
            float skillW = w * 0.66f;
            for (int i = 0; i < d.skills.Length; i++)
            {
                var s = d.skills[i];
                var sr = new Rect(dp.x + w * 0.018f, sy + i * (rowH + rowGap), skillW, rowH);
                Rounded(sr, new Color(0.08f, 0.20f, 0.17f, i % 2 == 0 ? 0.55f : 0.32f));
                var ir = new Rect(sr.x + h * 0.010f, sr.y + (rowH - h * 0.043f) * 0.5f, h * 0.043f, h * 0.043f);
                Circle(new Rect(ir.x - 3f, ir.y - 3f, ir.width + 6f, ir.height + 6f),
                    new Color(s.color.r, s.color.g, s.color.b, 0.22f));
                DrawIcon(ir, s.kind, s.color);
                Label(new Rect(sr.x + h * 0.068f, sr.y + h * 0.003f, w * 0.18f, rowH * 0.46f),
                    s.name, _name, CCream);
                Label(new Rect(sr.x + h * 0.068f, sr.y + rowH * 0.48f, w * 0.41f, rowH * 0.46f),
                    s.hint, _hudSmall, new Color(1f, 0.95f, 0.85f, 0.8f));
                string tail = s.unlockAt2 ? "2 级解锁" : "冷却 " + s.cd.ToString("0.#") + " 秒";
                Label(new Rect(sr.xMax - w * 0.115f, sr.y, w * 0.10f, rowH), tail, _micro,
                    s.unlockAt2 ? CGold : new Color(0.82f, 0.96f, 0.88f, 0.66f));
            }

            var go = new Rect(dp.xMax - w * 0.137f, dp.y + h * 0.065f, w * 0.115f, h * 0.115f);
            if (GoldButton(go, "出发！", _btn)) Boot.StartBattle(GameFlow.picked);
            Label(new Rect(go.x - w * 0.01f, go.yMax + h * 0.012f, go.width + w * 0.02f, h * 0.03f),
                "自动攻击 · 专心跳位", _micro, new Color(1f, 0.96f, 0.86f, 0.5f));
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
                    _num.normal.textColor = new Color(0.04f, 0.07f, 0.06f, Mathf.Clamp01(k * 1.2f) * 0.65f);
                    var tr = new Rect(sp.x - 100f, Screen.height - sp.y - 20f, 200f, 46f);
                    GUI.Label(new Rect(tr.x + 2f, tr.y + 3f, tr.width, tr.height), t.s, _num);
                    _num.normal.textColor = new Color(t.c.r, t.c.g, t.c.b, Mathf.Clamp01(k * 1.6f));
                    GUI.Label(tr, t.s, _num);
                }
                _num.normal.textColor = Color.white;
            }

            /* 塔 / 水晶血条：投影到模型头顶 */
            if (cam != null) DrawStructureBars(a, cam, w, h);
            if (cam != null) DrawHeroBars(a, cam, w, h);

            if (a.player != null) DrawPlayerPlate(a.player, w, h);
            DrawScore(a, w, h);

            var mini = new Rect(w - w * 0.205f - w * 0.012f, h * 0.022f, w * 0.205f, h * 0.165f);
            Panel(mini, CPanel);
            DrawMinimap(mini, a);

            _pauseRect = new Rect(mini.xMax - h * 0.072f, mini.yMax + h * 0.010f, h * 0.062f, h * 0.062f);
            var pauseHit = new Rect(_pauseRect.x - 6f, _pauseRect.y - 6f, _pauseRect.width + 12f, _pauseRect.height + 12f);
            if (GUI.Button(pauseHit, GUIContent.none, _btnSmall)) Boot.Pause(!Boot.Paused);
            Rounded(_pauseRect, CPanelDeep);
            Fill(new Rect(_pauseRect.x + _pauseRect.width * 0.34f, _pauseRect.y + _pauseRect.height * 0.30f,
                _pauseRect.width * 0.10f, _pauseRect.height * 0.40f), CCream, _white);
            Fill(new Rect(_pauseRect.x + _pauseRect.width * 0.56f, _pauseRect.y + _pauseRect.height * 0.30f,
                _pauseRect.width * 0.10f, _pauseRect.height * 0.40f), CCream, _white);

            DrawSkillBar(a, w, h);
            DrawJoystick(h);
            DrawLowHp(a, w, h);
            DrawDead(a, w, h);

            /* 开局小提示 */
            if (a.clock < 9f && !Boot.Paused)
            {
                float k = a.clock < 7f ? 1f : (9f - a.clock) * 0.5f;
                var hint = new Rect(w * 0.5f - w * 0.19f, h * 0.865f, w * 0.38f, h * 0.052f);
                Rounded(hint, new Color(0.05f, 0.14f, 0.12f, 0.58f * k));
                Label(hint, "拖左下摇杆走路 · 点右边技能出招 · 普攻自动", _hint,
                    new Color(1f, 0.97f, 0.88f, 0.92f * k));
            }

            /* 播报 */
            foreach (var b in Fx.Banners)
            {
                float k = 1f - b.t / b.life;
                float aa = Mathf.Clamp01(k * 2f);
                var r = new Rect(w * 0.22f, h * 0.142f, w * 0.56f, h * 0.068f);
                Rounded(new Rect(r.x, r.y + 3f, r.width, r.height), new Color(0.04f, 0.10f, 0.09f, 0.4f * aa));
                Rounded(r, new Color(0.05f, 0.15f, 0.12f, 0.78f * aa));
                HLine(new Rect(r.x + r.width * 0.30f, r.yMax - 4f, r.width * 0.40f, 2f),
                    new Color(1f, 0.84f, 0.44f, 0.72f * aa));
                LabelShadow(r, b.s, _center, new Color(1f, 0.97f, 0.88f, aa), 2f);
            }

            if (Boot.Paused) DrawPause();
        }

        void DrawStructureBars(Arena a, Camera c0, float w, float h)
        {
            foreach (var u in a.units)
            {
                if (!u.alive || (u.kind != UnitKind.Tower && u.kind != UnitKind.Base)) continue;
                Vector3 wp = u.pos + Vector3.up * (u.height * 0.55f + 20f);
                Vector3 sp = c0.WorldToScreenPoint(wp);
                if (sp.z <= 0f || sp.x < -80f || sp.x > w + 80f) continue;
                float bw = u.kind == UnitKind.Base ? w * 0.095f : w * 0.07f;
                float by = Mathf.Clamp(Screen.height - sp.y - 10f, h * 0.03f, h * 0.9f);
                var br = new Rect(sp.x - bw * 0.5f, by, bw, h * 0.012f);
                Rounded(new Rect(br.x - 2f, br.y - 2f, br.width + 4f, br.height + 4f), new Color(0.02f, 0.06f, 0.05f, 0.85f));
                Rounded(br, new Color(0.03f, 0.08f, 0.07f, 0.9f));
                float hpK = Mathf.Clamp01(u.hp / u.maxHp);
                if (hpK > 0.005f)
                    Rounded(new Rect(br.x, br.y, br.width * hpK, br.height),
                        u.team == Team.Blue ? new Color(0.5f, 0.9f, 1f, 0.95f) : new Color(1f, 0.62f, 0.55f, 0.95f));
                if (u.kind == UnitKind.Base)
                    Label(new Rect(br.x - 20f, br.y - h * 0.026f, br.width + 40f, h * 0.024f),
                        u.team == Team.Blue ? "我方水晶" : "敌方水晶", _micro,
                        u.team == Team.Blue ? CBlue : CRed);
            }
        }

        void DrawHeroBars(Arena a, Camera c0, float w, float h)
        {
            foreach (var u in a.heroes)
            {
                if (!u.alive || u == a.player) continue;
                Vector3 sp = c0.WorldToScreenPoint(u.pos + Vector3.up * (u.height * 1.16f + 16f));
                if (sp.z <= 0f || sp.x < -60f || sp.x > w + 60f) continue;
                float bw = w * 0.050f, bh = h * 0.008f;
                float x = sp.x - bw * 0.5f, y = Screen.height - sp.y;
                if (y < h * 0.20f || y > h * 0.88f) continue;
                Color teamC = u.team == Team.Blue ? CBlue : CRed;
                Rounded(new Rect(x - 2f, y - 2f, bw + 4f, bh + 4f), new Color(0.02f, 0.06f, 0.05f, 0.88f));
                Rounded(new Rect(x, y, bw, bh), new Color(0.04f, 0.10f, 0.09f, 0.9f));
                float hpK = Mathf.Clamp01(u.hp / u.maxHp);
                if (hpK > 0.005f) Rounded(new Rect(x, y, bw * hpK, bh), teamC);
                if (u.shield > 1f)
                {
                    float shK = Mathf.Min(Mathf.Clamp01(u.shield / u.maxHp), 1f - hpK);
                    if (shK > 0.005f)
                        Rounded(new Rect(x + bw * hpK, y, bw * shK, bh), new Color(0.62f, 0.92f, 1f, 0.55f));
                }
                Label(new Rect(x - w * 0.02f, y - h * 0.024f, bw + w * 0.04f, h * 0.022f),
                    u.name + "  Lv." + u.level, _micro, new Color(1f, 0.96f, 0.86f, 0.72f));
            }
        }

        void DrawPlayerPlate(Unit p, float w, float h)
        {
            var plate = new Rect(w * 0.012f, h * 0.022f, w * 0.315f, h * 0.126f);
            Panel(plate, CPanel);

            var av = new Rect(plate.x + h * 0.012f, plate.y + h * 0.013f, h * 0.090f, h * 0.090f);
            Circle(new Rect(av.x - 3f, av.y - 3f, av.width + 6f, av.height + 6f), new Color(1f, 0.82f, 0.42f, 0.9f));
            Circle(av, new Color(0.04f, 0.10f, 0.09f, 0.96f));
            var avTex = PortraitHead(p.def.id);
            if (avTex != null) GUI.DrawTexture(new Rect(av.x + 3f, av.y + 3f, av.width - 6f, av.height - 6f), avTex, ScaleMode.ScaleAndCrop, true);
            else Circle(new Rect(av.x + av.width * 0.2f, av.y + av.height * 0.2f, av.width * 0.6f, av.height * 0.6f), p.def.fur);
            var lv = new Rect(av.xMax - h * 0.034f, av.yMax - h * 0.028f, h * 0.048f, h * 0.048f);
            Circle(lv, new Color(1f, 0.83f, 0.42f, 1f));
            Label(lv, p.level.ToString(), _chip, CInk);

            Label(new Rect(av.xMax + h * 0.016f, plate.y + h * 0.010f, plate.width * 0.52f, h * 0.032f),
                p.def.name + " · " + p.def.role, _name, CCream);

            float barX = av.xMax + h * 0.016f;
            var bar = new Rect(barX, plate.y + h * 0.047f, plate.width - h * 0.118f, h * 0.030f);
            Rounded(new Rect(bar.x - 2f, bar.y - 2f, bar.width + 4f, bar.height + 4f), new Color(0.02f, 0.06f, 0.05f, 0.9f));
            Rounded(bar, new Color(0.02f, 0.08f, 0.07f, 0.9f));
            float hpK = Mathf.Clamp01(p.hp / p.maxHp);
            Color hpC = hpK > 0.55f ? new Color(0.44f, 0.87f, 0.50f, 0.96f)
                : hpK > 0.28f ? new Color(1f, 0.80f, 0.36f, 0.96f) : new Color(1f, 0.48f, 0.40f, 0.98f);
            var fillRect = new Rect(bar.x + 2f, bar.y + 2f, (bar.width - 4f) * hpK, bar.height - 4f);
            if (fillRect.width > 2f) Rounded(fillRect, hpC);
            if (p.shield > 1f)
            {
                float shK = Mathf.Clamp01(p.shield / p.maxHp);
                float shW = Mathf.Min(shK, Mathf.Max(0f, 1f - hpK));
                if (shW > 0.005f)
                    Rounded(new Rect(bar.x + 2f + (bar.width - 4f) * hpK, bar.y + 2f,
                        (bar.width - 4f) * shW, bar.height - 4f), new Color(0.62f, 0.92f, 1f, 0.45f));
            }
            LabelShadow(new Rect(bar.x + h * 0.008f, bar.y - 1f, bar.width - h * 0.008f, bar.height),
                Mathf.CeilToInt(p.hp) + " / " + Mathf.RoundToInt(p.maxHp), _hudSmall,
                new Color(0.98f, 1f, 0.96f, 0.98f), 2.2f);

            var xb = new Rect(bar.x, bar.yMax + h * 0.012f, bar.width, h * 0.010f);
            Rounded(xb, new Color(0.03f, 0.08f, 0.07f, 0.8f));
            float xpK = Mathf.Clamp01(p.xp / Arena.XpToLevel2);
            if (p.level < 2 && xpK > 0.01f)
                Rounded(new Rect(xb.x, xb.y, xb.width * xpK, xb.height), new Color(1f, 0.80f, 0.35f, 0.95f));
            else if (p.level >= 2)
                Rounded(xb, new Color(1f, 0.80f, 0.35f, 0.92f));

            float chipW = w * 0.115f;
            var uchip = new Rect(plate.xMax - chipW - h * 0.012f, plate.y + h * 0.012f, chipW, h * 0.033f);
            if (p.level >= 2 && p.cds[2] > 0f)
                Chip(uchip, "大招冷却 " + Mathf.CeilToInt(p.cds[2]) + "s", new Color(0.04f, 0.11f, 0.09f, 0.72f),
                    new Color(0.95f, 0.92f, 0.8f, 0.7f), _micro);
            else if (p.level >= 2)
                Chip(uchip, "大招就绪", CGoldSoft, CInk, _micro);
            else
                Chip(uchip, "大招 " + Mathf.RoundToInt(xpK * 100f) + "%", new Color(0.04f, 0.11f, 0.09f, 0.7f),
                    new Color(0.95f, 0.92f, 0.8f, 0.66f), _micro);
        }

        void DrawScore(Arena a, float w, float h)
        {
            var top = new Rect(w * 0.34f, h * 0.020f, w * 0.32f, h * 0.078f);
            Panel(top, new Color(0.07f, 0.17f, 0.15f, 0.9f));

            Circle(new Rect(top.x + top.width * 0.055f, top.y + top.height * 0.30f, h * 0.014f, h * 0.014f), CBlue);
            Label(new Rect(top.x + w * 0.012f, top.y, top.width * 0.20f, top.height * 0.72f), a.scoreBlue.ToString(), _center, CBlue);
            Circle(new Rect(top.xMax - w * 0.018f, top.y + top.height * 0.30f, h * 0.014f, h * 0.014f), CRed);
            Label(new Rect(top.x + top.width * 0.68f, top.y, top.width * 0.20f, top.height * 0.72f), a.scoreRed.ToString(), _center, CRed);

            int mm = Mathf.FloorToInt(a.clock / 60f), ss = Mathf.FloorToInt(a.clock % 60f);
            string ts = (a.suddenDeath ? "终局 " : "") + $"{mm:00}:{ss:00}";
            Label(new Rect(top.x + top.width * 0.25f, top.y, top.width * 0.5f, top.height * 0.72f), ts, _time,
                a.suddenDeath ? new Color(1f, 0.72f, 0.48f) : CCream);

            /* 双方塔数：两颗小塔，灰了就是被拆了 */
            DrawTowerPips(new Rect(top.x + top.width * 0.055f, top.yMax - h * 0.019f, top.width * 0.22f, h * 0.014f),
                a.towersBlue, Team.Blue);
            DrawTowerPips(new Rect(top.xMax - top.width * 0.275f, top.yMax - h * 0.019f, top.width * 0.22f, h * 0.014f),
                a.towersRed, Team.Red);
        }

        void DrawTowerPips(Rect r, List<Unit> list, Team team)
        {
            for (int i = 0; i < 2; i++)
            {
                bool alive = i < list.Count && list[i].alive;
                Color c = team == Team.Blue ? CBlue : CRed;
                var pr = new Rect(r.x + i * r.width * 0.34f, r.y, r.width * 0.26f, r.height);
                Rounded(pr, alive ? c : new Color(0.16f, 0.22f, 0.20f, 0.7f));
                if (alive)
                    Fill(new Rect(pr.x + pr.width * 0.42f, pr.y - r.height * 0.45f, pr.width * 0.16f, r.height * 0.45f),
                        new Color(1f, 0.95f, 0.8f, 0.85f), _white);
            }
        }

        void DrawMinimap(Rect r, Arena a)
        {
            var inner = new Rect(r.x + r.width * 0.06f, r.y + r.height * 0.10f, r.width * 0.88f, r.height * 0.78f);
            Rounded(inner, new Color(0.10f, 0.25f, 0.19f, 0.92f));
            System.Func<Vector3, Vector2> map = p => new Vector2(
                inner.x + p.x / Arena.MapW * inner.width,
                inner.y + (1f - p.z / Arena.MapH) * inner.height);

            var lane = Arena.Lane;
            for (int i = 0; i < lane.Length - 1; i++)
            {
                for (int k = 0; k < 9; k++)
                {
                    Vector3 p = Vector3.Lerp(lane[i], lane[i + 1], k / 9f);
                    Vector2 m = map(p);
                    Fill(new Rect(m.x - 2f, m.y - 2f, 4f, 4f), new Color(0.95f, 0.82f, 0.55f, 0.26f), _white);
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
                    Ring(new Rect(m.x - 9f, m.y - 9f, 18f, 18f), new Color(1f, 0.96f, 0.85f, 0.7f));
                    continue;
                }
                float s = u.kind == UnitKind.Hero ? 8f : (u.kind == UnitKind.Minion ? 4f : 6f);
                if (u.kind == UnitKind.Tower)
                {
                    Fill(new Rect(m.x - s * 0.55f, m.y - s * 0.55f, s * 1.1f, s * 1.1f), c, _white);
                    Fill(new Rect(m.x - s * 0.75f, m.y - s * 0.9f, s * 1.5f, s * 0.35f),
                        new Color(1f, 0.95f, 0.82f, 0.65f), _white);
                    continue;
                }
                Fill(new Rect(m.x - s * 0.5f, m.y - s * 0.5f, s, s), c, _white);
                if (u == a.player)
                    Ring(new Rect(m.x - 9f, m.y - 9f, 18f, 18f), new Color(1f, 0.85f, 0.45f, 0.95f));
            }
        }

        void DrawSkillBar(Arena a, float w, float h)
        {
            float bs0 = h * 0.150f, bs1 = h * 0.140f, bs2 = h * 0.160f;
            _skillRects[0] = new Rect(w - h * 0.270f - bs0 * 0.5f, h - h * 0.215f - bs0 * 0.5f, bs0, bs0);
            _skillRects[1] = new Rect(w - h * 0.160f - bs1 * 0.5f, h - h * 0.395f - bs1 * 0.5f, bs1, bs1);
            _skillRects[2] = new Rect(w - h * 0.180f - bs2 * 0.5f, h - h * 0.580f - bs2 * 0.5f, bs2, bs2);

            for (int i = 0; i < 3; i++)
                DrawSkillButton(i, _skillRects[i], a, h);
        }

        void DrawSkillButton(int i, Rect r, Arena a, float h)
        {
            var p = a.player;
            var s = p != null ? p.skills[i] : null;
            bool locked = s != null && s.unlockAt2 && (p == null || p.level < 2);
            bool cooling = p != null && p.cds[i] > 0f;
            bool ready = p != null && !locked && !cooling;
            bool ult = i == 2;

            Circle(new Rect(r.x - 7f, r.y - 7f, r.width + 14f, r.height + 14f),
                locked ? new Color(0.05f, 0.09f, 0.08f, 0.72f) : new Color(0.38f, 0.25f, 0.08f, 0.88f));
            Circle(r, locked ? new Color(0.25f, 0.30f, 0.28f, 0.94f)
                : ult ? new Color(1f, 0.84f, 0.45f, 0.98f) : new Color(0.98f, 0.74f, 0.40f, 0.98f));

            if (ready)
            {
                float pulse = 0.45f + Mathf.Sin(Time.unscaledTime * 3.2f + i) * 0.12f;
                Ring(new Rect(r.x + 4f, r.y + 4f, r.width - 8f, r.height - 8f),
                    new Color(1f, 0.97f, 0.8f, ult ? pulse : 0.45f));
                if (ult)
                    Ring(new Rect(r.x - 11f, r.y - 11f, r.width + 22f, r.height + 22f),
                        new Color(1f, 0.92f, 0.6f, 0.35f));
            }

            if (locked)
            {
                DrawLockIcon(new Rect(r.center.x - h * 0.016f, r.center.y - h * 0.032f, h * 0.032f, h * 0.036f));
                Label(new Rect(r.x, r.y + r.height * 0.61f, r.width, r.height * 0.22f), "2 级解锁", _micro,
                    new Color(1f, 1f, 1f, 0.78f));
                return;
            }

            var iconR = new Rect(r.center.x - r.width * 0.19f, r.y + r.height * 0.20f, r.width * 0.38f, r.width * 0.38f);
            Color iconC = cooling ? new Color(1f, 1f, 1f, 0.82f) : new Color(0.16f, 0.12f, 0.07f, 0.95f);
            DrawIcon(iconR, s != null ? s.kind : SkillKind.Projectile, iconC);

            if (cooling && s != null)
            {
                float ratio = Mathf.Clamp01(p.cds[i] / Mathf.Max(0.01f, s.cd));
                /* 96×96 扇形每次 Apply 都是一次纹理上传，按 4% 步进更新就够了 */
                if (Mathf.Abs(ratio - _cdRatio[i]) > 0.04f || _cdRatio[i] < 0f)
                {
                    _cdRatio[i] = ratio;
                    PaintPie(_cdPie[i], ratio);
                }
                /* 先整体压暗，再用暖色扇形表示“还剩多久”，白字才看得清 */
                Circle(r, new Color(0.02f, 0.05f, 0.04f, 0.62f));
                var old = GUI.color;
                GUI.color = new Color(0.78f, 0.54f, 0.22f, 0.42f);
                GUI.DrawTexture(r, _cdPie[i], ScaleMode.StretchToFill);
                GUI.color = old;
                LabelShadow(new Rect(r.x, r.y + r.height * 0.24f, r.width, r.height * 0.38f),
                    Mathf.CeilToInt(p.cds[i]).ToString(), _center, Color.white, 2f);
            }

            var nameR = new Rect(r.x + r.width * 0.06f, r.y + r.height * 0.70f, r.width * 0.88f, r.height * 0.17f);
            Rounded(nameR, new Color(0.04f, 0.10f, 0.09f, 0.62f));
            Label(nameR, s != null ? s.name : "技能", _skillName, new Color(1f, 0.97f, 0.88f, 0.94f));

            if (ult && ready)
                Label(new Rect(r.x, r.y - h * 0.030f, r.width, h * 0.028f), "大招", _micro, CGoldSoft);
        }

        void DrawIcon(Rect r, SkillKind kind, Color c)
        {
            if (!_icons.TryGetValue(kind, out var tex) || tex == null) return;
            var old = GUI.color;
            GUI.color = new Color(c.r, c.g, c.b, 0.96f);
            GUI.DrawTexture(r, tex, ScaleMode.ScaleToFit);
            GUI.color = old;
        }

        void DrawLockIcon(Rect r)
        {
            Rounded(new Rect(r.x, r.y + r.height * 0.35f, r.width, r.height * 0.65f), new Color(1f, 0.95f, 0.82f, 0.85f));
            Ring(new Rect(r.x + r.width * 0.15f, r.y - r.height * 0.05f, r.width * 0.70f, r.height * 0.62f),
                new Color(1f, 0.95f, 0.82f, 0.85f));
        }

        void DrawJoystick(float h)
        {
            if (!InputHub.JoyVisible) return;
            float jr = h * 0.12f;
            var c = new Vector2(InputHub.JoyCenter.x, Screen.height - InputHub.JoyCenter.y);
            var knob = new Vector2(InputHub.JoyKnob.x, Screen.height - InputHub.JoyKnob.y);
            Circle(new Rect(c.x - jr, c.y - jr, jr * 2f, jr * 2f), new Color(0.05f, 0.12f, 0.10f, 0.28f));
            Ring(new Rect(c.x - jr, c.y - jr, jr * 2f, jr * 2f), new Color(1f, 0.95f, 0.8f, 0.38f));
            Fill(new Rect(c.x - 1f, c.y - jr * 0.86f, 3f, jr * 0.13f), new Color(1f, 0.95f, 0.8f, 0.4f), _white);
            Fill(new Rect(c.x - 1f, c.y + jr * 0.73f, 3f, jr * 0.13f), new Color(1f, 0.95f, 0.8f, 0.4f), _white);
            Fill(new Rect(c.x - jr * 0.86f, c.y - 1f, jr * 0.13f, 3f), new Color(1f, 0.95f, 0.8f, 0.4f), _white);
            Fill(new Rect(c.x + jr * 0.73f, c.y - 1f, jr * 0.13f, 3f), new Color(1f, 0.95f, 0.8f, 0.4f), _white);
            Circle(new Rect(knob.x - jr * 0.44f, knob.y - jr * 0.44f, jr * 0.88f, jr * 0.88f),
                new Color(1f, 0.96f, 0.85f, 0.72f));
            Circle(new Rect(knob.x - jr * 0.24f, knob.y - jr * 0.24f, jr * 0.48f, jr * 0.48f),
                new Color(1f, 0.99f, 0.92f, 0.75f));
        }

        void DrawLowHp(Arena a, float w, float h)
        {
            var pp = a.player;
            if (pp == null || !pp.alive) return;
            float hpP = pp.hp / Mathf.Max(1f, pp.maxHp);
            if (hpP >= 0.28f) return;
            float pulse = 0.11f + Mathf.Sin(Time.unscaledTime * 6f) * 0.04f + (0.28f - hpP) * 0.5f;
            var red = new Color(0.55f, 0.03f, 0.03f, Mathf.Clamp01(pulse));
            Fill(new Rect(0, 0, w * 0.10f, h), red, _gradH);
            Fill(new Rect(w * 0.90f, 0, w * 0.10f, h), red, _gradHRev);
            Fill(new Rect(0, 0, w, h * 0.10f), red, _gradV);
            Fill(new Rect(0, h * 0.90f, w, h * 0.10f), red, _gradVDown);
        }

        void DrawDead(Arena a, float w, float h)
        {
            var pp = a.player;
            if (pp == null || pp.alive) return;
            var dead = new Rect(w * 0.5f - w * 0.16f, h * 0.38f, w * 0.32f, h * 0.16f);
            Panel(dead, new Color(0.06f, 0.14f, 0.12f, 0.9f));
            LabelShadow(new Rect(dead.x, dead.y + dead.height * 0.10f, dead.width, dead.height * 0.45f),
                "倒下啦…", _center, new Color(1f, 0.86f, 0.78f), 3f);
            Label(new Rect(dead.x, dead.y + dead.height * 0.55f, dead.width, dead.height * 0.35f),
                Mathf.Max(1, Mathf.CeilToInt(pp.respawnT)) + " 秒后复活", _hint,
                new Color(1f, 0.96f, 0.86f, 0.92f));
        }

        void DrawPause()
        {
            float w = Screen.width, h = Screen.height;
            Fill(new Rect(0, 0, w, h), new Color(0.03f, 0.10f, 0.09f, 0.74f), _white);
            var panel = new Rect(w * 0.31f, h * 0.14f, w * 0.38f, h * 0.72f);
            Panel(panel, new Color(0.09f, 0.22f, 0.19f, 0.98f));
            LabelShadow(new Rect(panel.x, panel.y + h * 0.035f, panel.width, h * 0.09f), "暂停一下", _center, CCream, 3f);

            var r1 = new Rect(panel.x + panel.width * 0.20f, panel.y + h * 0.15f, panel.width * 0.60f, h * 0.085f);
            if (GoldButton(r1, "继续", _btn)) Boot.Pause(false);
            var r2 = new Rect(panel.x + panel.width * 0.20f, panel.y + h * 0.26f, panel.width * 0.60f, h * 0.075f);
            if (DarkButton(r2, "重新开始", _btnSmall)) { Boot.Pause(false); Boot.StartBattle(GameFlow.picked); }
            var r3 = new Rect(panel.x + panel.width * 0.20f, panel.y + h * 0.355f, panel.width * 0.60f, h * 0.075f);
            if (DarkButton(r3, "回首页", _btnSmall)) { Boot.Pause(false); Boot.ToHome(); }
            var r4 = new Rect(panel.x + panel.width * 0.20f, panel.y + h * 0.45f, panel.width * 0.60f, h * 0.075f);
            bool sound = AudioListener.volume > 0.01f;
            if (DarkButton(r4, sound ? "音效：开" : "音效：关", _btnSmall))
                AudioListener.volume = sound ? 0f : 1f;

            HLine(new Rect(panel.x + panel.width * 0.12f, panel.y + h * 0.565f, panel.width * 0.76f, 1f),
                new Color(1f, 0.88f, 0.55f, 0.22f));
            Label(new Rect(panel.x, panel.y + h * 0.585f, panel.width, h * 0.035f),
                "目标：拆两座蘑菇塔，再点亮敌方水晶", _micro, new Color(1f, 0.95f, 0.84f, 0.72f));
            Label(new Rect(panel.x, panel.y + h * 0.620f, panel.width, h * 0.035f),
                "操作：左摇杆走路，右边三个技能，普攻自动", _micro, new Color(1f, 0.95f, 0.84f, 0.72f));
            Label(new Rect(panel.x, panel.y + panel.height - h * 0.055f, panel.width, h * 0.04f),
                "按 Esc / 返回键继续 · v" + Application.version, _micro, new Color(1f, 1f, 1f, 0.42f));
        }

        /* ---------------- 结算 ---------------- */
        void DrawResult()
        {
            var a = Arena.I;
            float w = Screen.width, h = Screen.height;
            Fill(new Rect(0, 0, w, h), new Color(0.03f, 0.10f, 0.09f, 0.78f), _white);
            bool win = a != null && a.winner == Team.Blue;

            var panel = new Rect(w * 0.24f, h * 0.11f, w * 0.52f, h * 0.78f);
            Panel(panel, new Color(0.09f, 0.22f, 0.19f, 0.97f));
            LabelShadow(new Rect(panel.x, panel.y + h * 0.045f, panel.width, h * 0.14f),
                win ? "胜利！" : "差一点点！", _big, win ? new Color(1f, 0.91f, 0.6f) : new Color(1f, 0.85f, 0.8f), 4f);

            var av = new Rect(panel.x + panel.width * 0.5f - h * 0.070f, panel.y + h * 0.215f, h * 0.14f, h * 0.14f);
            Circle(new Rect(av.x - 4f, av.y - 4f, av.width + 8f, av.height + 8f), new Color(1f, 0.83f, 0.44f, 0.9f));
            Circle(av, new Color(0.04f, 0.10f, 0.09f, 0.96f));
            var tex = PortraitHead(GameFlow.picked);
            if (tex != null) GUI.DrawTexture(new Rect(av.x + 3f, av.y + 3f, av.width - 6f, av.height - 6f), tex, ScaleMode.ScaleAndCrop, true);
            Label(new Rect(panel.x, panel.y + h * 0.365f, panel.width, h * 0.045f),
                HeroDef.Get(GameFlow.picked).name, _cardName, CCream);

            if (a != null)
            {
                Label(new Rect(panel.x, panel.y + h * 0.420f, panel.width, h * 0.055f),
                    $"击杀 蓝 {a.scoreBlue} : {a.scoreRed} 红   ·   用时 {Mathf.FloorToInt(a.clock / 60f)}:{Mathf.FloorToInt(a.clock % 60f):00}",
                    _center, new Color(1f, 0.95f, 0.84f, 0.9f));
                if (a.player != null)
                    Label(new Rect(panel.x + panel.width * 0.15f, panel.y + h * 0.480f, panel.width * 0.70f, h * 0.045f),
                        $"你击败了 {a.player.kills} 位，倒下 {a.player.deaths} 次", _center,
                        new Color(0.85f, 0.96f, 0.88f, 0.82f));
            }

            var r = new Rect(panel.x + panel.width * 0.20f, panel.y + h * 0.555f, panel.width * 0.60f, h * 0.095f);
            if (GoldButton(r, "再来一局", _btn)) Boot.StartBattle(GameFlow.picked);
            var r2 = new Rect(panel.x + panel.width * 0.20f, panel.y + h * 0.675f, panel.width * 0.29f, h * 0.075f);
            if (DarkButton(r2, "换英雄", _btnSmall)) Boot.ToSelect();
            var r3 = new Rect(panel.x + panel.width * 0.51f, panel.y + h * 0.675f, panel.width * 0.29f, h * 0.075f);
            if (DarkButton(r3, "回首页", _btnSmall)) Boot.ToHome();
        }

        /* ---------------- 程序化技能图标 / 冷却扇形 ---------------- */
        Texture2D BuildIcon(SkillKind kind)
        {
            const int S = 72;
            const int N = S * 2;
            var cov = new bool[N * N];

            void Mark(int ix, int iy)
            {
                if (ix >= 0 && iy >= 0 && ix < N && iy < N) cov[iy * N + ix] = true;
            }
            void Dot(float cx, float cy, float r)
            {
                int x0 = Mathf.Clamp(Mathf.FloorToInt((cx - r + 1f) * 0.5f * N), 0, N - 1);
                int x1 = Mathf.Clamp(Mathf.CeilToInt((cx + r + 1f) * 0.5f * N), 0, N);
                int y0 = Mathf.Clamp(Mathf.FloorToInt((cy - r + 1f) * 0.5f * N), 0, N - 1);
                int y1 = Mathf.Clamp(Mathf.CeilToInt((cy + r + 1f) * 0.5f * N), 0, N);
                for (int y = y0; y < y1; y++)
                    for (int x = x0; x < x1; x++)
                    {
                        float px = (x + 0.5f) / N * 2f - 1f, py = (y + 0.5f) / N * 2f - 1f;
                        if ((px - cx) * (px - cx) + (py - cy) * (py - cy) <= r * r) Mark(x, y);
                    }
            }
            void Seg(float x0, float y0, float x1, float y1, float w)
            {
                float hw = w * 0.5f;
                float vx = x1 - x0, vy = y1 - y0;
                float len2 = Mathf.Max(1e-6f, vx * vx + vy * vy);
                for (int y = 0; y < N; y++)
                    for (int x = 0; x < N; x++)
                    {
                        float px = (x + 0.5f) / N * 2f - 1f, py = (y + 0.5f) / N * 2f - 1f;
                        float t = Mathf.Clamp01(((px - x0) * vx + (py - y0) * vy) / len2);
                        float dx = px - (x0 + vx * t), dy = py - (y0 + vy * t);
                        if (dx * dx + dy * dy <= hw * hw) Mark(x, y);
                    }
            }
            void Ring(float cx, float cy, float r, float w)
            {
                for (int y = 0; y < N; y++)
                    for (int x = 0; x < N; x++)
                    {
                        float px = (x + 0.5f) / N * 2f - 1f, py = (y + 0.5f) / N * 2f - 1f;
                        float d = Mathf.Sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
                        if (Mathf.Abs(d - r) <= w * 0.5f) Mark(x, y);
                    }
            }
            void Arc(float cx, float cy, float r, float w, float a0, float a1)
            {
                for (int y = 0; y < N; y++)
                    for (int x = 0; x < N; x++)
                    {
                        float px = (x + 0.5f) / N * 2f - 1f, py = (y + 0.5f) / N * 2f - 1f;
                        float dx = px - cx, dy = py - cy;
                        float d = Mathf.Sqrt(dx * dx + dy * dy);
                        float ang = Mathf.Atan2(dy, dx) * Mathf.Rad2Deg;
                        if (ang >= a0 && ang <= a1 && Mathf.Abs(d - r) <= w * 0.5f) Mark(x, y);
                    }
            }
            void Star4(float cx, float cy, float s)
            {
                for (int y = 0; y < N; y++)
                    for (int x = 0; x < N; x++)
                    {
                        float px = (x + 0.5f) / N * 2f - 1f, py = (y + 0.5f) / N * 2f - 1f;
                        float dx = px - cx, dy = py - cy;
                        float d = Mathf.Sqrt(dx * dx + dy * dy);
                        float a = Mathf.Atan2(dy, dx);
                        float r = (0.14f + 0.40f * Mathf.Pow(Mathf.Abs(Mathf.Cos(2f * a)), 3f)) * s;
                        if (d <= r) Mark(x, y);
                    }
            }

            switch (kind)
            {
                case SkillKind.Projectile:
                    Star4(0.28f, 0f, 0.68f);
                    Dot(0.02f, 0f, 0.055f); Dot(-0.20f, 0f, 0.045f); Dot(-0.40f, 0f, 0.035f);
                    break;
                case SkillKind.Splash:
                    Ring(0f, 0f, 0.40f, 0.10f);
                    Dot(0f, 0f, 0.14f);
                    for (int k = 0; k < 6; k++)
                    {
                        float a = k * Mathf.PI / 3f;
                        Dot(Mathf.Cos(a) * 0.70f, Mathf.Sin(a) * 0.70f, 0.075f);
                    }
                    break;
                case SkillKind.Dash:
                    Seg(-0.62f, -0.45f, -0.18f, 0f, 0.17f);
                    Seg(-0.18f, 0f, -0.62f, 0.45f, 0.17f);
                    Seg(-0.16f, -0.45f, 0.28f, 0f, 0.17f);
                    Seg(0.28f, 0f, -0.16f, 0.45f, 0.17f);
                    Seg(0.30f, -0.45f, 0.74f, 0f, 0.17f);
                    Seg(0.74f, 0f, 0.30f, 0.45f, 0.17f);
                    break;
                case SkillKind.Aoe:
                    Ring(0f, 0f, 0.22f, 0.07f);
                    Ring(0f, 0f, 0.48f, 0.07f);
                    Ring(0f, 0f, 0.74f, 0.07f);
                    Dot(0f, 0f, 0.09f);
                    break;
                case SkillKind.Cone:
                    Seg(-0.56f, 0f, 0.66f, 0.56f, 0.10f);
                    Seg(-0.56f, 0f, 0.66f, -0.56f, 0.10f);
                    Arc(-0.56f, 0f, 0.66f, 0.09f, -40f, 40f);
                    Arc(-0.56f, 0f, 0.94f, 0.07f, -34f, 34f);
                    break;
                case SkillKind.Heal:
                    Seg(-0.46f, 0f, 0.46f, 0f, 0.24f);
                    Seg(0f, -0.46f, 0f, 0.46f, 0.24f);
                    Ring(0f, 0f, 0.72f, 0.07f);
                    break;
                case SkillKind.Shield:
                    Seg(-0.58f, 0.44f, 0f, 0.78f, 0.11f);
                    Seg(0f, 0.78f, 0.58f, 0.44f, 0.11f);
                    Seg(0.58f, 0.44f, 0.46f, -0.24f, 0.11f);
                    Seg(0.46f, -0.24f, 0f, -0.76f, 0.11f);
                    Seg(0f, -0.76f, -0.46f, -0.24f, 0.11f);
                    Seg(-0.46f, -0.24f, -0.58f, 0.44f, 0.11f);
                    Seg(0f, 0.44f, 0f, -0.34f, 0.10f);
                    break;
                case SkillKind.Pull:
                    Seg(-0.42f, 0.62f, -0.42f, -0.05f, 0.16f);
                    Seg(0.42f, 0.62f, 0.42f, -0.05f, 0.16f);
                    Arc(0f, -0.05f, 0.42f, 0.16f, 180f, 360f);
                    Dot(-0.22f, -0.16f, 0.055f); Dot(0f, -0.20f, 0.055f); Dot(0.22f, -0.16f, 0.055f);
                    break;
                case SkillKind.Leap:
                    for (int k = 0; k <= 9; k++)
                    {
                        float t = k / 9f;
                        float px = Mathf.Lerp(-0.65f, 0.45f, t);
                        float py = Mathf.Lerp(0.10f, -0.38f, t) + Mathf.Sin(t * Mathf.PI) * 0.62f;
                        Dot(px, py, 0.045f);
                    }
                    Seg(0.45f, -0.38f, 0.22f, -0.26f, 0.10f);
                    Seg(0.45f, -0.38f, 0.32f, -0.62f, 0.10f);
                    Seg(-0.72f, -0.62f, 0.10f, -0.62f, 0.07f);
                    break;
                case SkillKind.Multi:
                    Star4(-0.44f, 0.30f, 0.38f);
                    Star4(0.10f, -0.12f, 0.46f);
                    Star4(0.52f, 0.42f, 0.32f);
                    Dot(-0.02f, 0.55f, 0.035f); Dot(0.62f, -0.18f, 0.035f);
                    break;
                case SkillKind.Radial:
                    Dot(0f, 0f, 0.13f);
                    for (int k = 0; k < 8; k++)
                    {
                        float a = k * Mathf.PI * 0.25f;
                        float cx = Mathf.Cos(a), cy = Mathf.Sin(a);
                        Seg(cx * 0.30f, cy * 0.30f, cx * 0.72f, cy * 0.72f, 0.09f);
                        Seg(cx * 0.72f, cy * 0.72f, cx * 0.52f - cy * 0.13f, cy * 0.52f + cx * 0.13f, 0.07f);
                        Seg(cx * 0.72f, cy * 0.72f, cx * 0.52f + cy * 0.13f, cy * 0.52f - cx * 0.13f, 0.07f);
                    }
                    break;
                default:
                    Ring(0f, 0f, 0.50f, 0.10f);
                    Dot(0f, 0f, 0.14f);
                    break;
            }

            var tex = new Texture2D(S, S, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px2 = new Color32[S * S];
            for (int y = 0; y < S; y++)
                for (int x = 0; x < S; x++)
                {
                    int c = 0;
                    for (int dy = 0; dy < 2; dy++)
                        for (int dx = 0; dx < 2; dx++)
                            if (cov[(y * 2 + dy) * N + x * 2 + dx]) c++;
                    px2[y * S + x] = new Color32(255, 255, 255, (byte)(c * 255 / 4));
                }
            tex.SetPixels32(px2); tex.Apply();
            return tex;
        }

        static Texture2D MakePie(Color c)
        {
            const int S = 96;
            var tex = new Texture2D(S, S, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[S * S];
            for (int i = 0; i < px.Length; i++) px[i] = c;
            tex.SetPixels32(px); tex.Apply();
            return tex;
        }

        static void PaintPie(Texture2D tex, float ratio)
        {
            const int S = 96;
            var px = new Color32[S * S];
            float edge = ratio * Mathf.PI * 2f;
            for (int y = 0; y < S; y++)
                for (int x = 0; x < S; x++)
                {
                    float dx = (x + 0.5f) / S * 2f - 1f, dy = (y + 0.5f) / S * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    if (d > 0.49f) { px[y * S + x] = new Color32(255, 255, 255, 0); continue; }
                    float a = Mathf.Atan2(dx, dy);
                    if (a < 0f) a += Mathf.PI * 2f;
                    bool on = a <= edge;
                    float soft = Mathf.Clamp01((0.49f - d) * 40f);
                    px[y * S + x] = new Color32(255, 255, 255, (byte)(on ? soft * 235f : 0f));
                }
            tex.SetPixels32(px); tex.Apply();
        }

        void Update()
        {
            if (GameFlow.screen != UiScreen.Battle) return;
            if (Boot.Paused) return;
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
