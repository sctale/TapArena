using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    /// <summary>程序合成音效：不依赖任何音频资源，包里省体积。</summary>
    public static class Sfx
    {
        static AudioSource _src;
        static Dictionary<string, AudioClip> _clips = new Dictionary<string, AudioClip>();
        public static float Volume = 0.55f;

        public static void Init(AudioSource src)
        {
            _src = src;
            if (_clips.Count > 0) return;
            _clips["hit"] = Make("hit", 0.09f, t => Noise(t) * Mathf.Exp(-t * 40f) * 0.5f);
            _clips["cast"] = Make("cast", 0.18f, t => Mathf.Sin(T(t) * Mathf.Lerp(520f, 980f, t / 0.18f) * 6.2831f) * Mathf.Exp(-t * 9f) * 0.35f);
            _clips["boom"] = Make("boom", 0.36f, t => (Mathf.Sin(T(t) * Mathf.Lerp(150f, 60f, t / 0.36f) * 6.2831f) * 0.6f + Noise(t) * 0.4f) * Mathf.Exp(-t * 7f));
            _clips["ult"] = Make("ult", 0.5f, t => (Mathf.Sin(T(t) * 320f * 6.2831f) + 0.6f * Mathf.Sin(T(t) * 480f * 6.2831f)) * Mathf.Exp(-t * 4.5f) * 0.3f);
            _clips["win"] = Make("win", 0.8f, t => Arp(t, new[] { 523f, 659f, 784f, 1046f }) * Mathf.Exp(-t * 2.4f) * 0.3f);
            _clips["lose"] = Make("lose", 0.8f, t => Arp(t, new[] { 392f, 330f, 262f }) * Mathf.Exp(-t * 2.4f) * 0.3f);
        }

        static float T(float t) => t;
        static float Noise(float t) => Mathf.PerlinNoise(t * 900f, 0.37f) * 2f - 1f;
        static float Arp(float t, float[] notes)
        {
            int idx = Mathf.Clamp((int)(t / 0.12f), 0, notes.Length - 1);
            return Mathf.Sin(t * notes[idx] * 6.2831f);
        }

        static AudioClip Make(string name, float dur, System.Func<float, float> fn)
        {
            const int rate = 44100;
            int n = Mathf.CeilToInt(dur * rate);
            var data = new float[n];
            for (int i = 0; i < n; i++)
            {
                float t = i / (float)rate;
                data[i] = Mathf.Clamp(fn(t), -1f, 1f);
            }
            var clip = AudioClip.Create(name, n, 1, rate, false);
            clip.SetData(data, 0);
            return clip;
        }

        public static void Play(string key, float vol = 1f)
        {
            if (_src == null || !_clips.TryGetValue(key, out var c)) return;
            _src.PlayOneShot(c, Volume * vol);
        }
    }

    /// <summary>战斗特效：火花、地面法阵、拖影、飘字、播报。飘字/播报由 Hud 投影绘制。</summary>
    public static class Fx
    {
        public class TextItem { public Vector3 pos; public string s; public Color c; public float life, t; public float size = 1f; }
        public class BannerItem { public string s; public float life, t; }

        public static readonly List<TextItem> Texts = new List<TextItem>(64);
        public static readonly List<BannerItem> Banners = new List<BannerItem>(4);

        static Transform _root;
        static Material _mat;
        static Mesh _quad;
        static Texture2D _glow, _ringTex, _slashTex;
        static readonly List<GameObject> _pool = new List<GameObject>(128);
        static readonly List<FxSpark> _live = new List<FxSpark>(128);

        public static void Init(Transform root)
        {
            _root = root;
            var sh = Shader.Find("Sprites/Default") ?? Shader.Find("Unlit/Transparent");
            if (sh == null) { var m = Resources.Load<Material>("TapArenaFx"); if (m != null) sh = m.shader; }
            if (sh == null) sh = Art.StdShader();
            _mat = new Material(sh) { hideFlags = HideFlags.DontSave };
            _quad = BuildQuad();
            _glow = Build(e => Mathf.Clamp01(1f - e * e) * (1f - e * 0.25f));
            _ringTex = BuildRing();
            _slashTex = BuildSlash();
        }

        static Mesh BuildQuad()
        {
            var m = new Mesh();
            m.vertices = new[] { new Vector3(-0.5f, -0.5f, 0), new Vector3(0.5f, -0.5f, 0), new Vector3(0.5f, 0.5f, 0), new Vector3(-0.5f, 0.5f, 0) };
            m.uv = new[] { new Vector2(0, 0), new Vector2(1, 0), new Vector2(1, 1), new Vector2(0, 1) };
            m.triangles = new[] { 0, 1, 2, 0, 2, 3 };
            m.RecalculateNormals();
            return m;
        }

        static Texture2D Build(System.Func<float, float> f)
        {
            const int s = 64;
            var t = new Texture2D(s, s, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[s * s];
            for (int y = 0; y < s; y++)
                for (int x = 0; x < s; x++)
                {
                    float dx = (x + 0.5f) / s * 2f - 1f, dy = (y + 0.5f) / s * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    px[y * s + x] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(f(Mathf.Clamp01(d))) * 255f));
                }
            t.SetPixels32(px); t.Apply();
            return t;
        }

        /* 月牙形挥砍弧：中间亮、两头收尖 */
        static Texture2D BuildSlash()
        {
            const int s = 128;
            var t = new Texture2D(s, s, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[s * s];
            for (int y = 0; y < s; y++)
                for (int x = 0; x < s; x++)
                {
                    float dx = (x + 0.5f) / s * 2f - 1f, dy = (y + 0.5f) / s * 2f - 1f;
                    float r = Mathf.Sqrt(dx * dx + (dy - 0.1f) * (dy - 0.1f));
                    float band = Mathf.Clamp01(1f - Mathf.Abs(r - 0.72f) * 11f);
                    float span = Mathf.Clamp01(1f - Mathf.Abs(dx) * 1.35f);
                    float below = Mathf.Clamp01((0.55f - dy) * 3.5f);
                    float a = band * span * below;
                    px[y * s + x] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(a) * 255f));
                }
            t.SetPixels32(px); t.Apply();
            return t;
        }

        static Texture2D BuildRing()
        {
            const int s = 128;
            var t = new Texture2D(s, s, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[s * s];
            for (int y = 0; y < s; y++)
                for (int x = 0; x < s; x++)
                {
                    float dx = (x + 0.5f) / s * 2f - 1f, dy = (y + 0.5f) / s * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float ring = Mathf.Clamp01(1f - Mathf.Abs(d - 0.82f) * 9f);
                    float inner = Mathf.Clamp01(1f - d * 2.2f) * 0.28f;
                    px[y * s + x] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(Mathf.Max(ring, inner)) * 255f));
                }
            t.SetPixels32(px); t.Apply();
            return t;
        }

        static FxSpark Spawn(Vector3 pos, Color c, float size, float life, Vector3 vel, float gravity, Texture2D tex, bool billboard)
        {
            GameObject go = null;
            for (int i = 0; i < _pool.Count; i++)
                if (!_pool[i].activeSelf) { go = _pool[i]; break; }
            if (go == null)
            {
                go = new GameObject("fx");
                go.transform.SetParent(_root, false);
                go.AddComponent<MeshFilter>().sharedMesh = _quad;
                var mr = go.AddComponent<MeshRenderer>();
                mr.material = new Material(_mat) { mainTexture = tex };
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                mr.receiveShadows = false;
                var sp = go.AddComponent<FxSpark>();
                _pool.Add(go);
            }
            go.SetActive(true);
            var s = go.GetComponent<FxSpark>();
            s.Setup(pos, c, size, life, vel, gravity, billboard, tex);
            if (!_live.Contains(s)) _live.Add(s);
            return s;
        }

        public static void Hit(Vector3 pos, Color c, bool big)
        {
            int n = big ? 12 : 7;
            for (int i = 0; i < n; i++)
            {
                Vector3 v = new Vector3(Random.Range(-1f, 1f), Random.Range(0.35f, 1.3f), Random.Range(-1f, 1f)) * Random.Range(90f, 240f);
                Spawn(pos, c, Random.Range(10f, big ? 26f : 18f), Random.Range(0.16f, 0.34f), v, -420f, _glow, true);
            }
            Spawn(pos, Color.white, big ? 74f : 46f, 0.16f, Vector3.zero, 0f, _glow, true);
            CameraRig.Shake(big ? 5f : 2.4f);
            CameraRig.Punch(big ? 0.8f : 0.35f);
        }

        public static void Burst(Vector3 pos, Color c, int n)
        {
            for (int i = 0; i < n; i++)
            {
                Vector3 v = new Vector3(Random.Range(-1f, 1f), Random.Range(0.2f, 1f), Random.Range(-1f, 1f)) * Random.Range(70f, 210f);
                Spawn(pos, c, Random.Range(12f, 30f), Random.Range(0.25f, 0.55f), v, -260f, _glow, true);
            }
        }

        public static void Muzzle(Vector3 pos, Color c)
        {
            Spawn(pos, c, 34f, 0.12f, Vector3.zero, 0f, _glow, true);
        }

        /* 脚步扬尘：贴地的小片，给走路一点重量 */
        public static void Dust(Vector3 pos, Color c)
        {
            for (int i = 0; i < 3; i++)
            {
                Vector3 v = new Vector3(Random.Range(-32f, 32f), Random.Range(10f, 46f), Random.Range(-32f, 32f));
                var s = Spawn(pos + Vector3.up * 3f, c, Random.Range(13f, 22f),
                    Random.Range(0.32f, 0.5f), v, -55f, _glow, true);
                s.Flat();
                s.Grow(1.7f);
            }
        }

        public static void Ring(Vector3 pos, float radius, Color c, float life)
        {
            var s = Spawn(pos + Vector3.up * 3f, c, radius * 2f, life, Vector3.zero, 0f, _ringTex, false);
            s.Flat();
            s.Grow(1.15f);
        }

        /* 近战挥砍：一张朝向镜头的月牙，快速放大淡出 */
        public static void Slash(Vector3 pos, float yaw, Color c, float size = 120f)
        {
            var s = Spawn(pos + Vector3.up * 34f, c, size, 0.17f, Vector3.zero, 0f, _slashTex, true);
            s.Grow(1.35f);
            s.Roll(yaw >= 0f ? 18f : -198f);
        }

        public static void Trail(Vector3 a, Vector3 b, Color c)
        {
            int n = 8;
            for (int i = 0; i <= n; i++)
            {
                Vector3 p = Vector3.Lerp(a, b, i / (float)n);
                Spawn(p, c, 26f, 0.28f + i * 0.012f, Vector3.zero, 0f, _glow, true);
            }
        }

        public static void Text(Vector3 pos, string s, Color c, float size = 1f)
        {
            /* 同时命中时错开一点，避免数字叠成一根柱子 */
            var jitter = new Vector3(Random.Range(-26f, 26f), Random.Range(0f, 26f), Random.Range(-18f, 18f));
            var it = new TextItem { pos = pos + Vector3.up * 20f + jitter, s = s, c = c, life = 1.0f, size = size };
            Texts.Add(it);
            if (Texts.Count > 26) Texts.RemoveAt(0);
        }

        public static void Banner(string s, float life)
        {
            Banners.Clear();
            Banners.Add(new BannerItem { s = s, life = life });
        }

        public static void Step(float dt)
        {
            for (int i = Texts.Count - 1; i >= 0; i--)
            {
                var t = Texts[i];
                t.t += dt;
                t.pos.y += 46f * dt;
                if (t.t >= t.life) Texts.RemoveAt(i);
            }
            for (int i = Banners.Count - 1; i >= 0; i--)
            {
                var b = Banners[i];
                b.t += dt;
                if (b.t >= b.life) Banners.RemoveAt(i);
            }
        }
    }

    /// <summary>单个特效粒子：位置/缩放/透明度插值。</summary>
    public class FxSpark : MonoBehaviour
    {
        Vector3 _vel; float _life, _t, _size; Color _c; float _gravity; bool _billboard = true; bool _flat; float _grow = 1f;
        float _roll;
        Renderer _r;

        public void Setup(Vector3 pos, Color c, float size, float life, Vector3 vel, float gravity,
            bool billboard, Texture2D tex)
        {
            transform.position = pos;
            _vel = vel; _life = Mathf.Max(0.02f, life); _t = 0f; _size = size; _c = c; _gravity = gravity;
            _billboard = billboard; _flat = false; _grow = 1f; _roll = 0f;
            transform.rotation = Quaternion.identity;
            if (_r == null) _r = GetComponent<Renderer>();
            var mat = _r.material;
            if (tex != null) mat.mainTexture = tex;
            mat.color = c;
            Apply();
        }

        public void Flat() { _flat = true; }
        public void Grow(float g) { _grow = g; }
        public void Roll(float deg) { _roll = deg; }

        void Apply()
        {
            if (_r == null) return;
            float k = _t / _life;
            float scale = _size * (1f + (_grow - 1f) * k) * (1f - k * 0.35f);
            transform.localScale = new Vector3(scale, scale, scale);
            if (_flat) transform.rotation = Quaternion.Euler(90f, 0f, 0f);
            else if (_billboard && CameraRig.I != null)
            {
                transform.rotation = Quaternion.LookRotation(transform.position - CameraRig.I.transform.position, Vector3.up);
                if (Mathf.Abs(_roll) > 0.01f) transform.rotation *= Quaternion.Euler(0f, 0f, _roll);
            }
            var m = _r.material;
            float a = 1f - k;
            m.color = new Color(_c.r, _c.g, _c.b, _c.a * a * a);
        }

        void Update()
        {
            float dt = Time.deltaTime;
            _t += dt;
            if (_t >= _life) { gameObject.SetActive(false); return; }
            _vel.y += _gravity * dt;
            transform.position += _vel * dt;
            _vel *= (1f - dt * 1.6f);
            Apply();
        }
    }
}
