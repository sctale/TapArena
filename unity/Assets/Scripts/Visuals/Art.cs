using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// 程序化美术：所有模型与贴图都在运行时生成，工程里没有美术资源依赖。
    /// 统一使用 TapArena/Toon 卡通 shader（三段明暗 + 描边 + 边缘光），
    /// 引擎里没编进这支 shader 时自动退回 Standard，不会出洋红。
    /// </summary>
    public static class Art
    {
        static Shader _std, _toon;
        public static Vector3 SunDir = new Vector3(0.34f, 0.66f, -0.67f).normalized;

        public static Shader StdShader()
        {
            if (_std != null) return _std;
            _std = Shader.Find("Standard");
            if (_std == null)
            {
                var m = Resources.Load<Material>("TapArenaBase");
                if (m != null) _std = m.shader;
            }
            if (_std == null) _std = Shader.Find("Sprites/Default");
            return _std;
        }

        public static Shader ToonShader()
        {
            if (_toon != null) return _toon;
            _toon = Shader.Find("TapArena/Toon");
            if (_toon == null)
            {
                var m = Resources.Load<Material>("TapArenaToon");
                if (m != null) _toon = m.shader;
            }
            if (_toon == null) _toon = StdShader();
            return _toon;
        }

        /// <summary>独立材质（英雄受击要单独变色，不能共享）。</summary>
        public static Material Mat(Color c, float smooth = 0.18f, float metal = 0f, float outline = 0f)
        {
            var sh = ToonShader();
            var m = new Material(sh) { hideFlags = HideFlags.DontSave };
            m.color = c;
            if (m.HasProperty("_Glossiness")) m.SetFloat("_Glossiness", smooth);
            if (m.HasProperty("_Metallic")) m.SetFloat("_Metallic", metal);
            if (m.HasProperty("_Outline")) m.SetFloat("_Outline", outline);
            if (m.HasProperty("_OutlineColor")) m.SetColor("_OutlineColor", new Color(0.17f, 0.12f, 0.13f));
            if (m.HasProperty("_RimStrength")) m.SetFloat("_RimStrength", 0.3f);
            return m;
        }

        /* 场景道具共享材质：颜色相同的合并成一批，减少 draw call */
        static readonly Dictionary<int, Material> _shared = new Dictionary<int, Material>();
        public static Material MatShared(Color c, float outline = 0f, float smooth = 0.1f)
        {
            int key = ColorKey(c) * 131 + (int)(outline * 10f) * 7 + (int)(smooth * 100f);
            if (_shared.TryGetValue(key, out var m) && m != null) return m;
            m = Mat(c, smooth, 0f, outline);
            _shared[key] = m;
            return m;
        }

        static int ColorKey(Color c) =>
            ((int)(Mathf.Clamp01(c.r) * 255f) << 24) | ((int)(Mathf.Clamp01(c.g) * 255f) << 16) |
            ((int)(Mathf.Clamp01(c.b) * 255f) << 8) | (int)(Mathf.Clamp01(c.a) * 255f);

        public static Material Emissive(Color c, float intensity = 1.6f)
        {
            var m = Mat(Color.Lerp(c, Color.white, 0.2f), 0.5f, 0f, 0f);
            m.EnableKeyword("_EMISSION");
            m.SetColor("_EmissionColor", c * intensity);
            return m;
        }

        public static GameObject Prim(PrimitiveType type, Transform parent, Vector3 localPos,
            Vector3 scale, Material m, Quaternion? rot = null)
        {
            var go = GameObject.CreatePrimitive(type);
            var col = go.GetComponent<Collider>();
            if (col != null) Object.Destroy(col);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = rot ?? Quaternion.identity;
            go.transform.localScale = scale;
            var mr = go.GetComponent<MeshRenderer>();
            mr.sharedMaterial = m;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            mr.receiveShadows = true;
            return go;
        }

        /* Unity 没有 Cone 图元，这里自己生成一个单位圆锥（高 1、底半径 0.5，轴向 +Y） */
        static Mesh _cone;
        public static Mesh ConeMesh()
        {
            if (_cone != null) return _cone;
            const int seg = 16;
            var verts = new Vector3[seg + 2];
            var tris = new int[seg * 6];
            verts[0] = Vector3.up;
            verts[1] = Vector3.down;
            for (int i = 0; i < seg; i++)
            {
                float a = i / (float)seg * Mathf.PI * 2f;
                verts[i + 2] = new Vector3(Mathf.Cos(a) * 0.5f, -0.5f, Mathf.Sin(a) * 0.5f);
            }
            for (int i = 0; i < seg; i++)
            {
                int cur = i + 2, nxt = (i + 1) % seg + 2;
                /* 侧面朝外：顶点 → 下一个 → 当前（顺时针从外面看） */
                tris[i * 3] = 0; tris[i * 3 + 1] = nxt; tris[i * 3 + 2] = cur;
                /* 底面朝下 */
                tris[seg * 3 + i * 3] = 1; tris[seg * 3 + i * 3 + 1] = cur; tris[seg * 3 + i * 3 + 2] = nxt;
            }
            var uvs = new Vector2[verts.Length];
            for (int i = 0; i < verts.Length; i++) uvs[i] = new Vector2(0.5f, 0.5f);
            _cone = new Mesh { name = "cone", vertices = verts, triangles = tris, uv = uvs };
            _cone.RecalculateNormals();
            _cone.tangents = MakeTangents(verts.Length);
            return _cone;
        }

        public static GameObject Cone(Transform parent, Vector3 localPos, Vector3 scale, Material m, Quaternion? rot = null)
        {
            var go = new GameObject("cone");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = rot ?? Quaternion.identity;
            go.transform.localScale = scale;
            go.AddComponent<MeshFilter>().sharedMesh = ConeMesh();
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = m;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            mr.receiveShadows = true;
            return go;
        }

        /* 八面体：水晶的核心形状（高 1、半径 0.5，轴向 +Y） */
        static Mesh _octa;
        public static Mesh OctaMesh()
        {
            if (_octa != null) return _octa;
            var verts = new List<Vector3>();
            var tris = new List<int>();
            Vector3 top = new Vector3(0f, 0.5f, 0f), bottom = new Vector3(0f, -0.5f, 0f);
            Vector3[] ring =
            {
                new Vector3(0.5f, 0f, 0f), new Vector3(0f, 0f, 0.5f),
                new Vector3(-0.5f, 0f, 0f), new Vector3(0f, 0f, -0.5f)
            };
            for (int i = 0; i < 4; i++)
            {
                Vector3 a = ring[i], b = ring[(i + 1) % 4];
                verts.Add(top); verts.Add(b); verts.Add(a);
                tris.Add(verts.Count - 3); tris.Add(verts.Count - 2); tris.Add(verts.Count - 1);
                verts.Add(bottom); verts.Add(a); verts.Add(b);
                tris.Add(verts.Count - 3); tris.Add(verts.Count - 2); tris.Add(verts.Count - 1);
            }
            var uvs = new Vector2[verts.Count];
            for (int i = 0; i < uvs.Length; i++) uvs[i] = new Vector2(0.5f, 0.5f);
            _octa = new Mesh { name = "octa", vertices = verts.ToArray(), triangles = tris.ToArray(), uv = uvs };
            _octa.RecalculateNormals();
            _octa.tangents = MakeTangents(verts.Count);
            return _octa;
        }

        public static GameObject Octa(Transform parent, Vector3 localPos, Vector3 scale, Material m, Quaternion? rot = null)
        {
            var go = new GameObject("octa");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = rot ?? Quaternion.identity;
            go.transform.localScale = scale;
            go.AddComponent<MeshFilter>().sharedMesh = OctaMesh();
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = m;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            mr.receiveShadows = true;
            return go;
        }

        static Vector4[] MakeTangents(int n)
        {
            var t = new Vector4[n];
            for (int i = 0; i < n; i++) t[i] = new Vector4(1f, 0f, 0f, -1f);
            return t;
        }

        static Texture2D _fabric;
        /// <summary>细密的布料/绒毛噪点，给纯色材质一点手感。</summary>
        public static Texture2D FabricTex()
        {
            if (_fabric != null) return _fabric;
            const int s = 64;
            var tex = new Texture2D(s, s, TextureFormat.RGB24, true)
            { wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Bilinear };
            var px = new Color32[s * s];
            for (int y = 0; y < s; y++)
                for (int x = 0; x < s; x++)
                {
                    float n = Mathf.PerlinNoise(x * 0.42f + 3.1f, y * 0.42f + 7.7f) * 0.55f
                              + Mathf.PerlinNoise(x * 1.7f + 11f, y * 1.7f + 5f) * 0.45f;
                    float weave = (Mathf.Sin(x * 1.9f) + Mathf.Sin(y * 1.9f)) * 0.012f;
                    float v = Mathf.Clamp01(0.9f + n * 0.12f + weave);
                    byte b = (byte)(v * 255f);
                    px[y * s + x] = new Color32(b, b, b, 255);
                }
            tex.SetPixels32(px); tex.Apply();
            _fabric = tex;
            return tex;
        }

        public static Material MatFur(Color c, float outline)
        {
            var m = Mat(c, 0.22f, 0f, outline);
            if (m.HasProperty("_MainTex"))
            {
                m.mainTexture = FabricTex();
                m.mainTextureScale = new Vector2(2.2f, 2.2f);
            }
            return m;
        }

        static GameObject Ball(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Prim(PrimitiveType.Sphere, p, pos, scale, m, q);
        static GameObject Box(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Prim(PrimitiveType.Cube, p, pos, scale, m, q);
        static GameObject Tube(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Prim(PrimitiveType.Capsule, p, pos, scale, m, q);
        static GameObject Cyl(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Prim(PrimitiveType.Cylinder, p, pos, scale, m, q);

        /// <summary>把一个骨骼节点下的直系零件按材质合成一个网格，减少 draw call；子骨骼组不受影响。</summary>
        public static void Batch(Transform g)
        {
            if (g == null || g.childCount == 0) return;
            var byMat = new Dictionary<Material, List<MeshFilter>>();
            for (int i = 0; i < g.childCount; i++)
            {
                var child = g.GetChild(i);
                var mf = child.GetComponent<MeshFilter>();
                if (mf == null || mf.sharedMesh == null) continue;
                var mr = child.GetComponent<MeshRenderer>();
                if (mr == null || mr.sharedMaterial == null) continue;
                if (!byMat.TryGetValue(mr.sharedMaterial, out var list))
                {
                    list = new List<MeshFilter>();
                    byMat[mr.sharedMaterial] = list;
                }
                list.Add(mf);
            }
            foreach (var kv in byMat)
            {
                var list = kv.Value;
                if (list.Count < 2) continue;
                var combines = new CombineInstance[list.Count];
                for (int i = 0; i < list.Count; i++)
                {
                    combines[i].mesh = list[i].sharedMesh;
                    combines[i].transform = g.worldToLocalMatrix * list[i].transform.localToWorldMatrix;
                    combines[i].subMeshIndex = 0;
                }
                var mesh = new Mesh { name = "batch_" + kv.Key.name, hideFlags = HideFlags.DontSave };
                mesh.CombineMeshes(combines, true, true);
                mesh.RecalculateBounds();
                var go = new GameObject("b");
                go.transform.SetParent(g, false);
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                var mr2 = go.AddComponent<MeshRenderer>();
                mr2.sharedMaterial = kv.Key;
                mr2.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
                mr2.receiveShadows = true;
                for (int i = 0; i < list.Count; i++) Object.Destroy(list[i].gameObject);
            }
        }

        public static GameObject Group(Transform parent, Vector3 localPos, string name = "part")
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            return go;
        }

        /* ---------------- 天空 ---------------- */

        /* 运行时生成的等距柱状天空图：渐变 + 太阳光晕 + 云带 */
        public static Texture2D SkyTexture(int w, int h)
        {
            var tex = new Texture2D(w, h, TextureFormat.RGB24, false)
            { wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Bilinear };
            var px = new Color32[w * h];
            Color zenith = new Color(0.26f, 0.50f, 0.78f);
            Color mid = new Color(0.52f, 0.73f, 0.88f);
            Color horizon = new Color(0.96f, 0.91f, 0.78f);
            Color sunCol = new Color(1f, 0.92f, 0.72f);
            var sd = SunDir.normalized;

            for (int y = 0; y < h; y++)
            {
                float elev = (y + 0.5f) / h;
                float ang = elev * Mathf.PI * 0.5f;
                float cy = Mathf.Sin(ang), cr = Mathf.Cos(ang);
                float t = Mathf.Pow(elev, 0.75f);
                Color baseC = Color.Lerp(horizon, mid, Mathf.SmoothStep(0f, 1f, Mathf.Min(1f, t * 2.1f)));
                baseC = Color.Lerp(baseC, zenith, Mathf.SmoothStep(0f, 1f, Mathf.Max(0f, (t - 0.42f) / 0.58f)));

                for (int x = 0; x < w; x++)
                {
                    float az = (x + 0.5f) / w * Mathf.PI * 2f - Mathf.PI;
                    float ca = Mathf.Cos(az), sa = Mathf.Sin(az);
                    var dir = new Vector3(ca * cr, cy, sa * cr);

                    float d = Mathf.Max(0f, Vector3.Dot(dir, sd));
                    Color c = baseC;
                    c += sunCol * (Mathf.Pow(d, 320f) * 1.5f + Mathf.Pow(d, 24f) * 0.16f + Mathf.Pow(d, 4f) * 0.05f);

                    /* 云带：用方向投影采样 Perlin，接缝天然连续 */
                    if (elev > 0.02f && elev < 0.62f)
                    {
                        float n1 = Mathf.PerlinNoise(ca * 2.6f + 4.3f, sa * 2.6f + elev * 6.5f + 1.7f);
                        float n2 = Mathf.PerlinNoise(ca * 6.1f + 12.7f, sa * 6.1f + elev * 11f + 8.2f);
                        float n = n1 * 0.68f + n2 * 0.32f;
                        float mask = Mathf.SmoothStep(0.56f, 0.78f, n)
                                     * Mathf.SmoothStep(0.02f, 0.14f, elev)
                                     * (1f - Mathf.SmoothStep(0.42f, 0.62f, elev));
                        c = Color.Lerp(c, new Color(1f, 0.99f, 0.95f), mask * 0.55f);
                    }

                    /* 地平线附近压一点灰紫，远山才不飘 */
                    float low = 1f - Mathf.SmoothStep(0f, 0.16f, elev);
                    c = Color.Lerp(c, new Color(0.80f, 0.83f, 0.76f), low * 0.35f);

                    px[y * w + x] = c;
                }
            }
            tex.SetPixels32(px);
            tex.Apply();
            return tex;
        }

        public static GameObject SkyDome(Transform parent, Vector3 center, float radius)
        {
            var go = new GameObject("SkyDome");
            go.transform.SetParent(parent, false);
            go.transform.position = center;

            const int seg = 64, rings = 14;
            float start = -0.05f;
            var verts = new Vector3[(seg + 1) * (rings + 1)];
            var uvs = new Vector2[verts.Length];
            var tris = new int[seg * rings * 6];
            for (int r = 0; r <= rings; r++)
            {
                float f = r / (float)rings;
                float e = Mathf.Lerp(start, Mathf.PI * 0.5f, f);
                float y = Mathf.Sin(e) * radius;
                float rr = Mathf.Cos(e) * radius;
                for (int s = 0; s <= seg; s++)
                {
                    float a = s / (float)seg * Mathf.PI * 2f;
                    int idx = r * (seg + 1) + s;
                    verts[idx] = new Vector3(Mathf.Cos(a) * rr, y, Mathf.Sin(a) * rr);
                    uvs[idx] = new Vector2(s / (float)seg, f);
                }
            }
            int ti = 0;
            for (int r = 0; r < rings; r++)
                for (int s = 0; s < seg; s++)
                {
                    int i0 = r * (seg + 1) + s, i1 = i0 + 1, i2 = i0 + seg + 1, i3 = i2 + 1;
                    tris[ti++] = i0; tris[ti++] = i2; tris[ti++] = i1;
                    tris[ti++] = i1; tris[ti++] = i2; tris[ti++] = i3;
                }

            var mesh = new Mesh { name = "sky", vertices = verts, uv = uvs, triangles = tris };
            mesh.RecalculateNormals();
            go.AddComponent<MeshFilter>().sharedMesh = mesh;

            Shader sh = Shader.Find("TapArena/Sky");
            var res = Resources.Load<Material>("TapArenaSky");
            if (res != null && res.shader != null) sh = res.shader;
            var mat = sh != null ? new Material(sh) : Mat(new Color(0.55f, 0.72f, 0.82f));
            if (mat.HasProperty("_MainTex")) mat.mainTexture = SkyTexture(1024, 256);
            if (mat.HasProperty("_Tint")) mat.SetColor("_Tint", Color.white);
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = mat;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            mr.receiveShadows = false;
            return go;
        }

        /* ---------------- 英雄骨架 ---------------- */
        public class Rig
        {
            public Transform root, hips, chest, neck, head, eyes;
            public Transform shL, elL, wrL, shR, elR, wrR;
            public Transform thL, knL, anL, thR, knR, anR;
            public Transform earL, earR, tail1, tail2, weapon;
            public float height, headR, headCenterY;
            public Material[] mats;
            public Color[] baseCols;
            public Material faceMat;
            public Texture2D faceOpen, faceBlink, faceHurt;
        }

        public static Rig BuildHero(HeroDef d, Transform parent)
        {
            return HeroBuilder.Build(d, parent);
        }

        static void EarRound(Transform ear, float r, Material fur, Material inner)
        {
            Ball(ear, new Vector3(0f, r * 0.12f, 0f), new Vector3(r * 0.60f, r * 0.80f, r * 0.45f), fur);
            Ball(ear, new Vector3(r * 0.12f, r * 0.12f, 0f), new Vector3(r * 0.34f, r * 0.50f, r * 0.20f), inner);
        }

        static void TailDefault(Transform tail, float torsoR, float h, Material fur)
        {
            Tube(tail, new Vector3(-torsoR * 0.30f, -h * 0.02f, 0f),
                new Vector3(h * 0.09f, h * 0.12f, h * 0.09f), fur, Quaternion.Euler(0f, 0f, 138f));
            Ball(tail, new Vector3(-torsoR * 0.55f, -h * 0.12f, 0f), Vector3.one * h * 0.09f, fur);
        }

        /* ---------------- 场景道具 ---------------- */
        public static GameObject Tree(Transform parent, Vector3 pos, float s, int variant)
        {
            var g = new GameObject("tree");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            g.transform.localScale = Vector3.one * s;

            var trunk = MatShared(new Color(0.42f, 0.30f, 0.22f), 0.4f);
            var leafA = MatShared(variant % 3 == 0 ? new Color(0.30f, 0.52f, 0.30f)
                : variant % 3 == 1 ? new Color(0.24f, 0.47f, 0.31f) : new Color(0.34f, 0.56f, 0.30f), 0.7f);
            var leafB = MatShared(variant % 2 == 0 ? new Color(0.40f, 0.64f, 0.36f) : new Color(0.33f, 0.58f, 0.35f), 0.7f);

            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 30f, 0f), new Vector3(9f, 30f, 9f), trunk);
            /* 树根 */
            for (int i = 0; i < 3; i++)
            {
                float a = i * Mathf.PI * 2f / 3f + 0.4f;
                Cone(g.transform, new Vector3(Mathf.Cos(a) * 7f, 4f, Mathf.Sin(a) * 7f),
                    new Vector3(11f, 16f, 11f), trunk, Quaternion.Euler(0f, 0f, 0f) * Quaternion.Euler(90f, a * Mathf.Rad2Deg, 0f));
            }
            /* 分层树冠：下层深、上层亮 */
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(0f, 78f, 0f), new Vector3(90f, 66f, 90f), leafA);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(20f, 58f, -12f), new Vector3(54f, 42f, 52f), leafA);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(-22f, 62f, 14f), new Vector3(48f, 38f, 46f), leafA);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(8f, 98f, 4f), new Vector3(58f, 44f, 56f), leafB);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(-16f, 104f, -10f), new Vector3(38f, 30f, 36f), leafB);
            return g;
        }

        public static GameObject Bush(Transform parent, Vector3 pos, float s, int variant = 0)
        {
            var g = new GameObject("bush");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            g.transform.localScale = Vector3.one * s;
            var m = MatShared(variant % 2 == 0 ? new Color(0.29f, 0.54f, 0.35f) : new Color(0.35f, 0.60f, 0.36f), 0.6f);
            Prim(PrimitiveType.Sphere, g.transform, Vector3.zero, new Vector3(52f, 30f, 46f), m);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(22f, -2f, 10f), new Vector3(34f, 24f, 30f), m);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(-16f, -4f, -8f), new Vector3(28f, 20f, 26f), m);
            for (int i = 0; i < 3; i++)
                Prim(PrimitiveType.Sphere, g.transform,
                    new Vector3(-12f + i * 14f, 16f + (i % 2) * 5f, 12f - i * 9f),
                    Vector3.one * 4.2f, MatShared(i == 1 ? new Color(1f, 0.82f, 0.4f) : new Color(1f, 0.72f, 0.82f)));
            return g;
        }

        public static GameObject Mushroom(Transform parent, Vector3 pos, float s, Color cap)
        {
            var g = new GameObject("shroom");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            g.transform.localScale = Vector3.one * s;
            var stem = MatShared(new Color(0.96f, 0.92f, 0.84f), 0.4f);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 14f, 0f), new Vector3(9f, 14f, 9f), stem);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(0f, 30f, 0f), new Vector3(32f, 19f, 32f),
                MatShared(cap, 0.5f));
            for (int i = 0; i < 4; i++)
            {
                float a = i * Mathf.PI * 0.5f + 0.3f;
                Prim(PrimitiveType.Sphere, g.transform,
                    new Vector3(Mathf.Cos(a) * 8f, 36f, Mathf.Sin(a) * 8f),
                    new Vector3(5f, 3f, 5f), MatShared(new Color(1f, 0.98f, 0.9f)));
            }
            return g;
        }

        public static GameObject Rock(Transform parent, Vector3 pos, float s, int variant)
        {
            var g = new GameObject("rock");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            g.transform.localScale = Vector3.one * s;
            var stone = MatShared(variant % 2 == 0 ? new Color(0.53f, 0.55f, 0.53f) : new Color(0.45f, 0.49f, 0.48f), 0.5f);
            Prim(PrimitiveType.Sphere, g.transform, Vector3.zero, new Vector3(26f, 16f, 22f), stone,
                Quaternion.Euler(0f, variant * 37f, 0f));
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(10f, -3f, 8f), new Vector3(14f, 9f, 13f), stone,
                Quaternion.Euler(0f, variant * 71f, 0f));
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(-4f, 4f, -2f), new Vector3(12f, 6f, 10f),
                MatShared(new Color(0.35f, 0.55f, 0.34f)), Quaternion.Euler(0f, 24f, 0f));
            return g;
        }

        public static GameObject GrassTuft(Transform parent, Vector3 pos, float s, int variant)
        {
            var g = new GameObject("tuft");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            g.transform.localScale = Vector3.one * s;
            var m = MatShared(variant % 3 == 0 ? new Color(0.42f, 0.66f, 0.38f)
                : variant % 3 == 1 ? new Color(0.36f, 0.60f, 0.35f) : new Color(0.48f, 0.70f, 0.40f), 0f);
            for (int i = 0; i < 3; i++)
            {
                float a = i * 2.1f + variant;
                Cone(g.transform, new Vector3(Mathf.Cos(a) * 4f, 8f, Mathf.Sin(a) * 4f),
                    new Vector3(7f, 18f, 7f), m, Quaternion.Euler(Mathf.Sin(a) * 12f, 0f, Mathf.Cos(a) * 12f));
            }
            return g;
        }

        /* 远景山：一圈压扁的低多边形山包，把地图边缘藏进雾里 */
        public static void Hills(Transform parent, Vector3 center, float radiusMin, float radiusMax, int count, int seed, float scale = 1f)
        {
            var rnd = new System.Random(seed);
            var far = MatShared(new Color(0.36f, 0.50f, 0.42f), 0f);
            var far2 = MatShared(new Color(0.42f, 0.56f, 0.44f), 0f);
            for (int i = 0; i < count; i++)
            {
                float a = (i / (float)count) * Mathf.PI * 2f + (float)rnd.NextDouble() * 0.08f;
                float r = Mathf.Lerp(radiusMin, radiusMax, (float)rnd.NextDouble());
                float w = Mathf.Lerp(420f, 780f, (float)rnd.NextDouble()) * scale;
                float hgt = Mathf.Lerp(160f, 340f, (float)rnd.NextDouble()) * scale;
                var p = center + new Vector3(Mathf.Cos(a) * r, -10f, Mathf.Sin(a) * r);
                Prim(PrimitiveType.Sphere, parent, p, new Vector3(w, hgt, w * 0.9f),
                    (i & 1) == 0 ? far : far2, Quaternion.Euler(0f, a * Mathf.Rad2Deg, 0f))
                    .GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            }
            /* 第二层更近的树线 */
            var pine = MatShared(new Color(0.30f, 0.46f, 0.34f), 0f);
            var trunk = MatShared(new Color(0.40f, 0.31f, 0.24f), 0f);
            for (int i = 0; i < count * 2; i++)
            {
                float a = (i / (float)(count * 2)) * Mathf.PI * 2f + 0.05f;
                float r = radiusMin * 0.94f + (float)rnd.NextDouble() * 70f;
                var p = center + new Vector3(Mathf.Cos(a) * r, 0f, Mathf.Sin(a) * r);
                float hgt = Mathf.Lerp(120f, 220f, (float)rnd.NextDouble()) * scale;
                Prim(PrimitiveType.Cylinder, parent, p + Vector3.up * (hgt * 0.22f),
                    new Vector3(7f, hgt * 0.22f, 7f), trunk)
                    .GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                Cone(parent, p + Vector3.up * (hgt * 0.55f), new Vector3(hgt * 0.5f, hgt * 0.85f, hgt * 0.5f), pine)
                    .GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            }
        }


        /* 木桥：兵线跨河的地方，桥面横着铺板，两侧有栏杆和小灯 */
        public static GameObject Bridge(Transform parent, Vector3 pos, float yaw)
        {
            var g = new GameObject("bridge");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            g.transform.localRotation = Quaternion.Euler(0f, yaw, 0f);
            var woodA = MatShared(new Color(0.56f, 0.40f, 0.26f), 0.4f);
            var woodB = MatShared(new Color(0.47f, 0.33f, 0.21f), 0.4f);
            var woodC = MatShared(new Color(0.38f, 0.26f, 0.17f), 0.4f);
            var glow = MatShared(new Color(1f, 0.86f, 0.5f), 0f);

            /* 桥面：一排木板，长度方向 X、宽度方向 Z */
            for (int i = 0; i < 9; i++)
            {
                float x = Mathf.Lerp(-200f, 200f, i / 8f);
                Prim(PrimitiveType.Cube, g.transform, new Vector3(x, 0f, 0f),
                    new Vector3(42f, 2.2f, 250f), (i & 1) == 0 ? woodA : woodB);
            }
            /* 两根纵梁 */
            Prim(PrimitiveType.Cube, g.transform, new Vector3(0f, -3f, -118f), new Vector3(460f, 6f, 10f), woodC);
            Prim(PrimitiveType.Cube, g.transform, new Vector3(0f, -3f, 118f), new Vector3(460f, 6f, 10f), woodC);

            /* 栏杆：立柱 + 扶手 */
            for (int side = -1; side <= 1; side += 2)
            {
                for (int i = 0; i < 5; i++)
                {
                    float x = Mathf.Lerp(-200f, 200f, i / 4f);
                    Prim(PrimitiveType.Cylinder, g.transform, new Vector3(x, 20f, side * 118f),
                        new Vector3(7f, 20f, 7f), woodC);
                    Prim(PrimitiveType.Sphere, g.transform, new Vector3(x, 44f, side * 118f),
                        Vector3.one * 9f, glow);
                }
                Prim(PrimitiveType.Cube, g.transform, new Vector3(0f, 38f, side * 118f),
                    new Vector3(440f, 6f, 6f), woodA);
            }
            return g;
        }

        public static GameObject Tower(Transform parent, Vector3 pos, bool blue, int tier)
        {
            var g = new GameObject("tower");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            if (tier == 1) g.transform.localScale = Vector3.one * 1.06f;

            var stone = MatShared(new Color(0.93f, 0.87f, 0.76f), 0.6f);
            var stoneDark = MatShared(new Color(0.78f, 0.70f, 0.58f), 0.4f);
            var wood = MatShared(new Color(0.48f, 0.33f, 0.22f), 0.3f);
            Color capC = blue ? new Color(0.36f, 0.68f, 0.82f) : new Color(0.88f, 0.46f, 0.42f);
            var cap = MatShared(capC, 0.8f);
            var capDark = MatShared(Color.Lerp(capC, Color.black, 0.25f), 0.6f);
            var spot = MatShared(new Color(0.99f, 0.96f, 0.88f), 0.5f);
            var glow = MatShared(blue ? new Color(0.65f, 0.95f, 1f) : new Color(1f, 0.82f, 0.6f), 0.0f);

            /* 台阶底座 */
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 6f, 0f), new Vector3(118f, 6f, 118f), stoneDark);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 16f, 0f), new Vector3(96f, 8f, 96f), stone);
            /* 蘑菇塔身 */
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 50f, 0f), new Vector3(60f, 32f, 60f), stone);
            /* 木箍 */
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 34f, 0f), new Vector3(66f, 3f, 66f), wood);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 66f, 0f), new Vector3(64f, 3f, 64f), wood);
            /* 门 */
            Prim(PrimitiveType.Cube, g.transform, new Vector3(0f, 28f, -30.5f), new Vector3(18f, 26f, 3f), wood);
            /* 窗：暖色发光 */
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(-13f, 52f, -30f), new Vector3(9f, 11f, 4f),
                Emissive(blue ? new Color(0.6f, 0.95f, 1f) : new Color(1f, 0.8f, 0.5f), 1.2f));
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(13f, 52f, -30f), new Vector3(9f, 11f, 4f),
                Emissive(blue ? new Color(0.6f, 0.95f, 1f) : new Color(1f, 0.8f, 0.5f), 1.2f));

            /* 蘑菇伞盖 */
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(0f, 100f, 0f), new Vector3(160f, 92f, 160f), cap);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 82f, 0f), new Vector3(132f, 5f, 132f), capDark);
            for (int i = 0; i < 7; i++)
            {
                float a = i / 7f * Mathf.PI * 2f + 0.3f;
                float rr = 34f + (i % 3) * 13f;
                float sy = 100f + 92f * Mathf.Sqrt(Mathf.Max(0.06f, 1f - (rr / 80f) * (rr / 80f))) - 5f;
                Prim(PrimitiveType.Sphere, g.transform,
                    new Vector3(Mathf.Cos(a) * rr, sy, Mathf.Sin(a) * rr),
                    new Vector3(16f, 7f, 16f), spot, Quaternion.Euler(0f, -a * Mathf.Rad2Deg, 0f));
            }
            if (tier == 1)
            {
                /* 内塔：伞盖一圈金边 */
                Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 99f, 0f), new Vector3(166f, 4f, 166f),
                    MatShared(new Color(0.95f, 0.80f, 0.42f), 0.5f));
            }
            /* 塔顶小旗 */
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 200f, 0f), new Vector3(3f, 16f, 3f), wood);
            Prim(PrimitiveType.Cube, g.transform, new Vector3(10f, 208f, 0f), new Vector3(22f, 13f, 2f), cap,
                Quaternion.Euler(0f, 0f, -8f)).AddComponent<Waver>();
            return g;
        }

        public static GameObject Crystal(Transform parent, Vector3 pos, bool blue)
        {
            var g = new GameObject("base");
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;

            var stone = MatShared(new Color(0.88f, 0.83f, 0.73f), 0.6f);
            var stoneDark = MatShared(new Color(0.72f, 0.66f, 0.56f), 0.4f);
            var wood = MatShared(new Color(0.46f, 0.31f, 0.21f), 0.3f);
            var glowC = blue ? new Color(0.4f, 0.86f, 1f) : new Color(1f, 0.54f, 0.46f);
            var crystalMat = Emissive(glowC, 1.15f);
            var flagMat = MatShared(blue ? new Color(0.36f, 0.68f, 0.86f) : new Color(0.88f, 0.44f, 0.42f), 0.6f);

            /* 三层石台 */
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 6f, 0f), new Vector3(320f, 12f, 320f), stoneDark);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 14f, 0f), new Vector3(272f, 8f, 272f), stone);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 23f, 0f), new Vector3(216f, 10f, 216f), stone);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 31f, 0f), new Vector3(180f, 4f, 180f), stoneDark);

            /* 四根石柱 + 灯 */
            for (int i = 0; i < 4; i++)
            {
                float a = i * Mathf.PI * 0.5f + Mathf.PI * 0.25f;
                var p = new Vector3(Mathf.Cos(a) * 128f, 0f, Mathf.Sin(a) * 128f);
                Prim(PrimitiveType.Cylinder, g.transform, p + Vector3.up * 52f, new Vector3(20f, 34f, 20f), stoneDark);
                Prim(PrimitiveType.Sphere, g.transform, p + Vector3.up * 90f, Vector3.one * 18f,
                    Emissive(glowC, 1.6f));
            }
            /* 旗帜 */
            for (int i = 0; i < 2; i++)
            {
                float a = i * Mathf.PI + Mathf.PI * 0.5f;
                var p = new Vector3(Mathf.Cos(a) * 186f, 0f, Mathf.Sin(a) * 186f);
                Prim(PrimitiveType.Cylinder, g.transform, p + Vector3.up * 70f, new Vector3(4f, 70f, 4f), wood);
                var flag = Prim(PrimitiveType.Cube, g.transform, p + Vector3.up * 124f + new Vector3(14f, 0f, 0f),
                    new Vector3(30f, 22f, 2f), flagMat);
                flag.AddComponent<Waver>();
            }

            /* 悬浮水晶：本体 + 环绕碎片，整体旋转 */
            var cry = new GameObject("crystal");
            cry.transform.SetParent(g.transform, false);
            cry.transform.localPosition = new Vector3(0f, 112f, 0f);
            Octa(cry.transform, Vector3.zero, new Vector3(78f, 170f, 78f), crystalMat);
            Octa(cry.transform, Vector3.zero, new Vector3(44f, 96f, 44f), Emissive(Color.Lerp(glowC, Color.white, 0.22f), 1.8f));
            for (int i = 0; i < 4; i++)
            {
                float a = i * Mathf.PI * 0.5f;
                Octa(cry.transform, new Vector3(Mathf.Cos(a) * 120f, Mathf.Sin(a * 2f) * 22f, Mathf.Sin(a) * 120f),
                    new Vector3(18f, 34f, 18f), crystalMat, Quaternion.Euler(20f, 0f, 15f));
            }
            cry.AddComponent<Spinner>();

            return g;
        }

        public static GameObject Minion(Transform parent, bool blue)
        {
            var g = new GameObject("minion");
            g.transform.SetParent(parent, false);
            var body = MatShared(blue ? new Color(0.46f, 0.78f, 0.92f) : new Color(0.94f, 0.56f, 0.50f), 0.8f);
            var belly = MatShared(blue ? new Color(0.80f, 0.94f, 1f) : new Color(1f, 0.84f, 0.78f), 0.5f);
            var leaf = MatShared(new Color(0.38f, 0.68f, 0.40f), 0.5f);
            var eye = MatShared(new Color(0.15f, 0.1f, 0.1f));

            Prim(PrimitiveType.Sphere, g.transform, new Vector3(0f, 26f, 0f), new Vector3(38f, 40f, 34f), body);
            Prim(PrimitiveType.Sphere, g.transform, new Vector3(6f, 22f, 0f), new Vector3(24f, 26f, 24f), belly);
            Prim(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 50f, 0f), new Vector3(3f, 8f, 3f), leaf);
            Cone(g.transform, new Vector3(0f, 60f, 0f), new Vector3(16f, 18f, 6f), leaf);
            for (int s = -1; s <= 1; s += 2)
            {
                Prim(PrimitiveType.Sphere, g.transform, new Vector3(12f, 30f, s * 10f), new Vector3(6f, 9f, 8f),
                    MatShared(Color.white));
                Prim(PrimitiveType.Sphere, g.transform, new Vector3(15f, 30f, s * 10f), new Vector3(4f, 6f, 5f), eye);
            }
            for (int s = -1; s <= 1; s += 2)
                Prim(PrimitiveType.Sphere, g.transform, new Vector3(6f, 8f, s * 12f), new Vector3(12f, 7f, 9f), body);
            return g;
        }

        /* 地图贴图：草地 + 兵线 + 河流 + 花点 */
        public static Texture2D GroundTexture(int w, int h)
        {
            var tex = new Texture2D(w, h, TextureFormat.RGB24, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[w * h];
            var lane = Arena.Lane;
            var cGrassA = new Color(0.42f, 0.62f, 0.40f);
            var cGrassB = new Color(0.32f, 0.52f, 0.34f);
            var cGrassC = new Color(0.38f, 0.57f, 0.36f);
            var cLane = new Color(0.80f, 0.70f, 0.50f);
            var cLaneEdge = new Color(0.62f, 0.53f, 0.37f);
            var cRiver = new Color(0.32f, 0.56f, 0.64f);
            var cRiverEdge = new Color(0.48f, 0.66f, 0.60f);
            var rnd = new System.Random(20261101);

            for (int y = 0; y < h; y++)
            {
                float wz = (y + 0.5f) / h * Arena.MapH;
                for (int x = 0; x < w; x++)
                {
                    float wx = (x + 0.5f) / w * Arena.MapW;

                    /* 河流：中间一条斜带，岸边带一点噪声，不是一条直线 */
                    float bend = Mathf.Sin(wz * 0.012f) * 34f + (Mathf.PerlinNoise(wz * 0.01f, 3.7f) - 0.5f) * 46f;
                    float riverD = Mathf.Abs(wx - (1500f + (wz - 800f) * 0.16f + bend));
                    float riverW = 150f;
                    bool river = riverD < riverW;
                    bool riverEdge = riverD < riverW + 30f;

                    /* 到兵线的距离 */
                    float d = float.MaxValue;
                    for (int i = 0; i < lane.Length - 1; i++)
                    {
                        Vector3 a = lane[i], b = lane[i + 1];
                        Vector2 ap = new Vector2(a.x, a.z), bp = new Vector2(b.x, b.z), pp = new Vector2(wx, wz);
                        float t = Mathf.Clamp01(Vector2.Dot(pp - ap, bp - ap) / Vector2.Dot(bp - ap, bp - ap));
                        float dd = Vector2.Distance(pp, ap + (bp - ap) * t);
                        if (dd < d) d = dd;
                    }

                    Color c;
                    if (river)
                    {
                        /* 中心深、岸边浅，再叠一层缓慢的水纹 */
                        float sh = Mathf.Clamp01(riverD / riverW);
                        c = Color.Lerp(cRiver * 0.82f, cRiver, sh);
                        float ripple = Mathf.PerlinNoise(wx * 0.012f + 5f, wz * 0.03f);
                        c = Color.Lerp(c, cRiverEdge, ripple * 0.22f);
                        int hr = (x * 92837111 ^ y * 689287499) & 2047;
                        if (hr < 2) c = Color.Lerp(c, Color.white, 0.35f);
                    }
                    else if (riverEdge)
                    {
                        float tEdge = Mathf.Clamp01((riverD - riverW) / 30f);
                        c = Color.Lerp(cRiver, new Color(0.55f, 0.68f, 0.47f), tEdge);
                    }
                    else if (d < 118f)
                    {
                        float n = Mathf.PerlinNoise(wx * 0.05f, wz * 0.05f);
                        c = Color.Lerp(cLane, cLane * 0.94f, n);
                    }
                    else if (d < 150f) c = cLaneEdge;
                    else
                    {
                        float n = Mathf.PerlinNoise(wx * 0.004f, wz * 0.004f);
                        float n2 = Mathf.PerlinNoise(wx * 0.02f + 11f, wz * 0.02f + 7f);
                        c = Color.Lerp(cGrassB, cGrassA, n * 0.75f + n2 * 0.25f);
                        /* 割草条纹 */
                        float stripe = Mathf.Sin((wx * 0.6f + wz * 0.35f) * 0.05f);
                        c *= 1f + stripe * 0.028f;
                        c = Color.Lerp(c, cGrassC, 0.12f);
                    }

                    /* 花与草点 */
                    if (!river && d > 170f)
                    {
                        int r = (x * 73856093 ^ y * 19349663) & 1023;
                        if (r < 3)
                            c = rnd.NextDouble() < 0.5 ? new Color(1f, 0.93f, 0.62f) : new Color(1f, 0.76f, 0.85f);
                        else if (r < 6) c *= 0.92f;
                    }
                    px[y * w + x] = c;
                }
            }
            tex.SetPixels32(px);
            tex.Apply();
            return tex;
        }
    }

    /// <summary>头顶水泡：轻微上下浮动。</summary>
    public class Bobber : MonoBehaviour
    {
        float _t;
        Vector3 _base, _scale;
        void Start() { _base = transform.localPosition; _scale = transform.localScale; _t = Random.value * 6f; }
        void Update()
        {
            _t += Time.deltaTime;
            transform.localPosition = _base + Vector3.up * Mathf.Sin(_t * 2.2f) * 3f;
            transform.localScale = _scale * (1f + Mathf.Sin(_t * 1.7f) * 0.05f);
        }
    }

    /// <summary>旗帜：绕 Y 轴轻轻摆动。</summary>
    public class Waver : MonoBehaviour
    {
        float _t;
        Quaternion _base;
        void Start() { _base = transform.localRotation; _t = Random.value * 6f; }
        void Update()
        {
            _t += Time.deltaTime;
            transform.localRotation = _base * Quaternion.Euler(Mathf.Sin(_t * 4.1f) * 4f, 0f, Mathf.Sin(_t * 3.3f) * 9f);
        }
    }

    /// <summary>水晶缓慢旋转，带一点点上下浮动。</summary>
    public class Spinner : MonoBehaviour
    {
        float _t;
        Vector3 _base;
        void Start() { _base = transform.localPosition; _t = Random.value * 6f; }
        void Update()
        {
            _t += Time.deltaTime;
            transform.localRotation = Quaternion.Euler(0f, _t * 32f, 0f);
            transform.localPosition = _base + Vector3.up * (Mathf.Sin(_t * 1.5f) * 6f);
        }
    }
}
