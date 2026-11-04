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

    /// <summary>
    /// 战斗特效：火花、地面法阵、拖影、飘字、播报。粒子不再一人一个
    /// GameObject/Material，而是按贴图合并成 3 个动态网格批次。
    /// </summary>
    public static class Fx
    {
        public class TextItem { public Vector3 pos; public string s; public Color c; public float life, t; public float size = 1f; }
        public class BannerItem { public string s; public float life, t; }

        public static readonly List<TextItem> Texts = new List<TextItem>(64);
        public static readonly List<BannerItem> Banners = new List<BannerItem>(4);

        const int MaxSparks = 256;
        const int TexGlow = 0, TexRing = 1, TexSlash = 2;

        class Spark
        {
            public bool active;
            public Vector3 pos, vel;
            public float t, life, size, grow, roll, gravity;
            public Color c;
            public int tex;
            public bool flat, billboard;
        }

        static Transform _root;
        static readonly List<Spark> _sparks = new List<Spark>(MaxSparks);
        static readonly Material[] _mats = new Material[3];
        static readonly Mesh[] _meshes = new Mesh[3];
        static readonly MeshRenderer[] _mrs = new MeshRenderer[3];
        static Texture2D _glow, _ringTex, _slashTex;
        static readonly List<Vector3> _verts = new List<Vector3>(MaxSparks * 4);
        static readonly List<Vector2> _uvs = new List<Vector2>(MaxSparks * 4);
        static readonly List<Color> _cols = new List<Color>(MaxSparks * 4);
        static readonly List<int> _tris = new List<int>(MaxSparks * 6);

        public static void Init(Transform root)
        {
            if (_root != null) return;
            var host = root != null && root.parent != null ? root.parent : root;
            var go = new GameObject("FxRoot");
            go.transform.SetParent(host, false);
            _root = go.transform;

            var sh = Shader.Find("Sprites/Default") ?? Shader.Find("Unlit/Transparent");
            if (sh == null) { var m = Resources.Load<Material>("TapArenaFx"); if (m != null) sh = m.shader; }
            if (sh == null) sh = Art.StdShader();

            _glow = Build(e => Mathf.Clamp01(1f - e * e) * (1f - e * 0.25f));
            _ringTex = BuildRing();
            _slashTex = BuildSlash();
            var texs = new[] { _glow, _ringTex, _slashTex };
            for (int i = 0; i < 3; i++)
            {
                _mats[i] = new Material(sh) { hideFlags = HideFlags.DontSave, mainTexture = texs[i] };
                var b = new GameObject("FxBatch" + i);
                b.transform.SetParent(_root, false);
                b.AddComponent<MeshFilter>().sharedMesh = _meshes[i] = NewMesh();
                var mr = b.AddComponent<MeshRenderer>();
                mr.sharedMaterial = _mats[i];
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                mr.receiveShadows = false;
                _mrs[i] = mr;
            }
        }

        static Mesh NewMesh()
        {
            var m = new Mesh { name = "fx_batch" };
            m.MarkDynamic();
            m.bounds = new Bounds(new Vector3(1500f, 0f, 800f), new Vector3(8000f, 4000f, 8000f));
            return m;
        }

        public static void Clear()
        {
            for (int i = 0; i < _sparks.Count; i++) _sparks[i].active = false;
            for (int i = 0; i < 3; i++)
            {
                if (_meshes[i] == null) continue;
                _meshes[i].Clear();
                if (_mrs[i] != null) _mrs[i].enabled = false;
            }
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

        static Spark Spawn(Vector3 pos, Color c, float size, float life, Vector3 vel,
            float gravity, int tex, bool billboard)
        {
            Spark s = null;
            for (int i = 0; i < _sparks.Count; i++)
                if (!_sparks[i].active) { s = _sparks[i]; break; }
            if (s == null)
            {
                if (_sparks.Count >= MaxSparks) return null;
                s = new Spark();
                _sparks.Add(s);
            }
            s.active = true;
            s.pos = pos; s.vel = vel; s.c = c; s.t = 0f;
            s.life = Mathf.Max(0.02f, life); s.size = size; s.gravity = gravity;
            s.tex = tex; s.billboard = billboard; s.flat = false; s.grow = 1f; s.roll = 0f;
            return s;
        }

        public static void Hit(Vector3 pos, Color c, bool big)
        {
            int n = big ? 12 : 7;
            for (int i = 0; i < n; i++)
            {
                Vector3 v = new Vector3(Random.Range(-1f, 1f), Random.Range(0.35f, 1.3f), Random.Range(-1f, 1f)) * Random.Range(90f, 240f);
                Spawn(pos, c, Random.Range(10f, big ? 26f : 18f), Random.Range(0.16f, 0.34f), v, -420f, TexGlow, true);
            }
            Spawn(pos, Color.white, big ? 74f : 46f, 0.16f, Vector3.zero, 0f, TexGlow, true);
            CameraRig.Shake(big ? 5f : 2.4f);
            CameraRig.Punch(big ? 0.8f : 0.35f);
        }

        public static void Burst(Vector3 pos, Color c, int n)
        {
            for (int i = 0; i < n; i++)
            {
                Vector3 v = new Vector3(Random.Range(-1f, 1f), Random.Range(0.2f, 1f), Random.Range(-1f, 1f)) * Random.Range(70f, 210f);
                Spawn(pos, c, Random.Range(12f, 30f), Random.Range(0.25f, 0.55f), v, -260f, TexGlow, true);
            }
        }

        public static void Muzzle(Vector3 pos, Color c)
        {
            Spawn(pos, c, 34f, 0.12f, Vector3.zero, 0f, TexGlow, true);
        }

        public static void Dust(Vector3 pos, Color c)
        {
            for (int i = 0; i < 3; i++)
            {
                Vector3 v = new Vector3(Random.Range(-32f, 32f), Random.Range(10f, 46f), Random.Range(-32f, 32f));
                var s = Spawn(pos + Vector3.up * 3f, c, Random.Range(13f, 22f), Random.Range(0.32f, 0.5f), v, -55f, TexGlow, true);
                if (s == null) continue;
                s.flat = true;
                s.grow = 1.7f;
            }
        }

        public static void Ring(Vector3 pos, float radius, Color c, float life)
        {
            var s = Spawn(pos + Vector3.up * 3f, c, radius * 2f, life, Vector3.zero, 0f, TexRing, false);
            if (s == null) return;
            s.flat = true;
            s.grow = 1.15f;
        }

        public static void Slash(Vector3 pos, float yaw, Color c, float size = 120f)
        {
            var s = Spawn(pos + Vector3.up * 34f, c, size, 0.17f, Vector3.zero, 0f, TexSlash, true);
            if (s == null) return;
            s.grow = 1.35f;
            s.roll = yaw >= 0f ? 18f : -198f;
        }

        public static void Trail(Vector3 a, Vector3 b, Color c)
        {
            int n = 8;
            for (int i = 0; i <= n; i++)
            {
                Vector3 p = Vector3.Lerp(a, b, i / (float)n);
                Spawn(p, c, 26f, 0.28f + i * 0.012f, Vector3.zero, 0f, TexGlow, true);
            }
        }

        public static void Text(Vector3 pos, string s, Color c, float size = 1f)
        {
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
            if (_root == null) return;
            for (int i = 0; i < _sparks.Count; i++)
            {
                var s = _sparks[i];
                if (!s.active) continue;
                s.t += dt;
                if (s.t >= s.life) { s.active = false; continue; }
                s.vel.y += s.gravity * dt;
                s.pos += s.vel * dt;
                s.vel *= (1f - dt * 1.6f);
            }
            BuildBatch(TexGlow);
            BuildBatch(TexRing);
            BuildBatch(TexSlash);
        }

        static void BuildBatch(int tex)
        {
            var mesh = _meshes[tex];
            var mr = _mrs[tex];
            if (mesh == null || _root == null) return;
            _verts.Clear(); _uvs.Clear(); _cols.Clear(); _tris.Clear();

            Vector3 right = Vector3.right, up = Vector3.up;
            if (CameraRig.I != null)
            {
                var ct = CameraRig.I.transform;
                right = ct.right; up = ct.up;
            }
            for (int i = 0; i < _sparks.Count; i++)
            {
                var s = _sparks[i];
                if (!s.active || s.tex != tex) continue;
                float k = s.t / s.life;
                float sc = s.size * (1f + (s.grow - 1f) * k) * (1f - k * 0.35f) * 0.5f;
                float a = (1f - k) * (1f - k) * s.c.a;
                Vector3 r = right, u = up;
                if (s.flat) { r = Vector3.right; u = Vector3.forward; }
                if (Mathf.Abs(s.roll) > 0.01f)
                {
                    float rad = s.roll * Mathf.Deg2Rad;
                    Vector3 rr = r * Mathf.Cos(rad) + u * Mathf.Sin(rad);
                    u = -r * Mathf.Sin(rad) + u * Mathf.Cos(rad);
                    r = rr;
                }
                int b = _verts.Count;
                _verts.Add(s.pos - r * sc - u * sc);
                _verts.Add(s.pos + r * sc - u * sc);
                _verts.Add(s.pos + r * sc + u * sc);
                _verts.Add(s.pos - r * sc + u * sc);
                _uvs.Add(new Vector2(0f, 0f)); _uvs.Add(new Vector2(1f, 0f));
                _uvs.Add(new Vector2(1f, 1f)); _uvs.Add(new Vector2(0f, 1f));
                Color cc = new Color(s.c.r, s.c.g, s.c.b, a);
                _cols.Add(cc); _cols.Add(cc); _cols.Add(cc); _cols.Add(cc);
                _tris.Add(b); _tris.Add(b + 1); _tris.Add(b + 2);
                _tris.Add(b); _tris.Add(b + 2); _tris.Add(b + 3);
            }
            if (_tris.Count == 0)
            {
                mr.enabled = false;
                return;
            }
            mr.enabled = true;
            mesh.Clear();
            mesh.SetVertices(_verts);
            mesh.SetUVs(0, _uvs);
            mesh.SetColors(_cols);
            mesh.SetTriangles(_tris, 0);
        }
    }
}
