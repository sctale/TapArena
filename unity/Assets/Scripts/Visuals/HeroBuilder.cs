using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// 新的角色构建：连续头/身网格 + 贴图脸 + 两骨 CPU 蒙皮四肢。
    /// 造型原则参考风格化角色设计：先保证剪影（大头、短肢、每只兽一个标志物），
    /// 再靠手绘脸贴图/花纹承载细节；装饰只加在剪影上，不堆碎件。
    /// </summary>
    public static class HeroBuilder
    {
        static readonly List<Material> _all = new List<Material>();

        public static Art.Rig Build(HeroDef d, Transform parent)
        {
            _all.Clear();
            float h = d.height;
            float headR = h * 0.29f;
            var rig = new Art.Rig { height = h, headR = headR, headCenterY = h * 0.93f };
            var root = new GameObject("hero").transform;
            root.SetParent(parent, false);
            rig.root = root;

            // ---------- 骨架 ----------
            var hips = Node(root, "hips", new Vector3(0f, h * 0.40f, 0f));
            var chest = Node(hips, "chest", new Vector3(0f, h * 0.26f, 0f));
            var neck = Node(chest, "neck", new Vector3(0f, h * 0.12f, 0f));
            var head = Node(neck, "head", Vector3.zero);
            rig.hips = hips; rig.chest = chest; rig.neck = neck; rig.head = head;

            var shL = Node(chest, "shL", new Vector3(h * 0.02f, h * 0.005f, -h * 0.245f));
            var elL = Node(shL, "elL", new Vector3(0f, -h * 0.14f, -h * 0.010f));
            var wrL = Node(elL, "wrL", new Vector3(0f, -h * 0.13f, -h * 0.030f));
            var shR = Node(chest, "shR", new Vector3(h * 0.02f, h * 0.005f, h * 0.245f));
            var elR = Node(shR, "elR", new Vector3(0f, -h * 0.14f, h * 0.010f));
            var wrR = Node(elR, "wrR", new Vector3(0f, -h * 0.13f, h * 0.030f));
            rig.shL = shL; rig.elL = elL; rig.wrL = wrL;
            rig.shR = shR; rig.elR = elR; rig.wrR = wrR;

            var thL = Node(hips, "thL", new Vector3(0f, 0f, -h * 0.120f));
            var knL = Node(thL, "knL", new Vector3(0f, -h * 0.18f, -h * 0.008f));
            var anL = Node(knL, "anL", new Vector3(0f, -h * 0.155f, -h * 0.014f));
            var thR = Node(hips, "thR", new Vector3(0f, 0f, h * 0.120f));
            var knR = Node(thR, "knR", new Vector3(0f, -h * 0.18f, h * 0.008f));
            var anR = Node(knR, "anR", new Vector3(0f, -h * 0.155f, h * 0.014f));
            rig.thL = thL; rig.knL = knL; rig.anL = anL;
            rig.thR = thR; rig.knR = knR; rig.anR = anR;

            var earL = Node(head, "earL", new Vector3(0f, h * 0.36f, -h * 0.14f));
            var earR = Node(head, "earR", new Vector3(0f, h * 0.36f, h * 0.14f));
            rig.earL = earL; rig.earR = earR;
            earL.localRotation = Quaternion.Euler(-10f, 0f, 0f);
            earR.localRotation = Quaternion.Euler(10f, 0f, 0f);

            var tail1 = Node(hips, "tail1", new Vector3(-h * 0.17f, h * 0.03f, 0f));
            var tail2 = Node(tail1, "tail2", new Vector3(-h * 0.11f, h * 0.015f, 0f));
            rig.tail1 = tail1; rig.tail2 = tail2;
            var weapon = Node(wrR, "weapon", Vector3.zero);
            rig.weapon = weapon;

            // ---------- 材质 ----------
            Color fur = d.fur, dark = d.dark, cream = d.cream, accent = d.accent;
            var mFur = Art.MatFur(fur, h * 0.010f);
            var mCream = Art.MatFur(cream, h * 0.008f);
            var mDark = Art.MatFur(dark, h * 0.008f);
            var mAccent = Art.MatFur(accent, h * 0.008f);
            var mInk = Art.Mat(new Color(0.16f, 0.10f, 0.11f), 0.3f, 0f, h * 0.006f);
            var mPink = Art.Mat(new Color(1f, 0.62f, 0.68f), 0.2f, 0f, h * 0.006f);
            var mGold = Art.Mat(new Color(0.96f, 0.78f, 0.34f), 0.5f, 0f, h * 0.006f);
            var mLeaf = Art.Mat(new Color(0.34f, 0.62f, 0.33f), 0.3f, 0f, h * 0.008f);
            var mWood = Art.Mat(new Color(0.44f, 0.29f, 0.19f), 0.2f, 0f, h * 0.006f);
            var mWhite = Art.Mat(new Color(1f, 0.99f, 0.96f), 0.2f, 0f, 0f);
            var mGlow = Art.Emissive(new Color(1f, 0.86f, 0.48f), 1.6f);
            var mMuzzle = Art.MatFur(cream, 0f);
            _all.AddRange(new[] { mFur, mCream, mDark, mAccent, mInk, mPink, mGold, mLeaf, mWood, mWhite, mGlow, mMuzzle });

            string id = d.id.ToString().ToLowerInvariant();
            var face = Resources.Load<Texture2D>("HeroFaces/" + id + "_face");
            var blink = Resources.Load<Texture2D>("HeroFaces/" + id + "_blink");
            var hurt = Resources.Load<Texture2D>("HeroFaces/" + id + "_hurt");
            var bodyTex = Resources.Load<Texture2D>("HeroFaces/" + id + "_body");

            var faceMat = Art.Mat(Color.white, 0.2f, 0f, h * 0.008f);
            faceMat.mainTexture = face != null ? face : Art.FabricTex();
            var bodyMat = Art.Mat(Color.white, 0.2f, 0f, h * 0.008f);
            bodyMat.mainTexture = bodyTex != null ? bodyTex : Art.FabricTex();
            if (bodyTex == null) bodyMat.color = fur;
            _all.Add(faceMat); _all.Add(bodyMat);
            rig.faceMat = faceMat; rig.faceOpen = face; rig.faceBlink = blink; rig.faceHurt = hurt;

            // ---------- 身体 ----------
            var bodyProfile = new[]
            {
                new Vector2(0f, -0.17f), new Vector2(0.105f, -0.165f), new Vector2(0.185f, -0.13f),
                new Vector2(0.226f, -0.06f), new Vector2(0.235f, 0.02f), new Vector2(0.222f, 0.12f),
                new Vector2(0.192f, 0.22f), new Vector2(0.152f, 0.30f), new Vector2(0.092f, 0.355f),
                new Vector2(0f, 0.375f)
            };
            for (int i = 0; i < bodyProfile.Length; i++) bodyProfile[i] *= h;
            var bodyMesh = Lathe(bodyProfile, 28, 0.94f, out var bodyVerts);
            MeshObj(hips, "body", bodyMesh, bodyMat, Vector3.zero);

            // ---------- 头 ----------
            var headMesh = Sphere(headR, headR * 0.96f, headR * 0.96f, 28, 22);
            MeshObj(head, "head", headMesh, faceMat, new Vector3(0f, h * 0.15f, 0f));

            // 3D 珠眼：深色玻璃珠 + 两枚高光，贴图只负责嘴/腮红/花纹
            var eyes = new GameObject("eyes").transform;
            eyes.SetParent(head, false);
            eyes.localPosition = new Vector3(0f, h * 0.15f, 0f);
            rig.eyes = eyes;
            for (int side = -1; side <= 1; side += 2)
            {
                var e = new Vector3(headR * 0.94f, 0f, side * headR * 0.33f);
                Ball(eyes, e, new Vector3(headR * 0.27f, headR * 0.31f, headR * 0.26f), mInk);
                Ball(eyes, e + new Vector3(headR * 0.26f, headR * 0.10f, headR * 0.04f),
                    Vector3.one * headR * 0.062f, mWhite);
                Ball(eyes, e + new Vector3(headR * 0.25f, -headR * 0.10f, headR * 0.03f),
                    Vector3.one * headR * 0.028f, mWhite);
            }
            Art.Batch(eyes);
            var nosePos = new Vector3(headR * 1.02f, h * 0.15f - headR * 0.24f, 0f);
            var noseMat = id == "rabbit" ? mPink : mInk;
            Ball(head, nosePos, new Vector3(headR * 0.15f, headR * 0.10f, headR * 0.17f), noseMat,
                Quaternion.Euler(0f, 0f, 20f));

            // ---------- 四肢（连续管 + CPU 蒙皮） ----------
            AddArm(rig, root, shL, elL, wrL, h, mFur, mCream, mAccent, true);
            AddArm(rig, root, shR, elR, wrR, h, mFur, mCream, mAccent, false);
            AddLeg(rig, root, thL, knL, anL, h, mFur, mCream, mAccent, mDark);
            AddLeg(rig, root, thR, knR, anR, h, mFur, mCream, mAccent, mDark);

            // 肩/髋关节球，盖住身体与管子的接缝
            Ball(shL, Vector3.zero, Vector3.one * h * 0.125f, mFur);
            Ball(shR, Vector3.zero, Vector3.one * h * 0.125f, mFur);
            Ball(thL, Vector3.zero, Vector3.one * h * 0.13f, mFur);
            Ball(thR, Vector3.zero, Vector3.one * h * 0.13f, mFur);

            // ---------- 尾巴 ----------
            BuildTail(rig, root, d, h, mFur, mCream, mDark);

            // ---------- 耳朵 ----------
            BuildEars(rig, d, h, headR, mFur, mCream, mPink, mDark);

            // ---------- 头饰/呆毛 ----------
            BuildHeadDecor(rig, d, h, headR, mFur, mDark, mPink, mGold, mLeaf);

            // ---------- 服装/配件 ----------
            BuildOutfit(rig, d, h, headR, mFur, mCream, mDark, mAccent, mGold, mLeaf, mWood, mPink, mInk, mGlow);

            // 统一合批挂在骨骼上的小件（贴图头/身/管是单独网格，不会被动到）
            Art.Batch(head); Art.Batch(earL); Art.Batch(earR); Art.Batch(eyes);
            Art.Batch(hips); Art.Batch(chest); Art.Batch(neck);
            Art.Batch(wrL); Art.Batch(wrR); Art.Batch(thL); Art.Batch(thR);
            Art.Batch(anL); Art.Batch(anR);

            rig.mats = _all.ToArray();
            rig.baseCols = new Color[_all.Count];
            for (int i = 0; i < _all.Count; i++) rig.baseCols[i] = _all[i].color;
            return rig;
        }

        // ================= 头/身/管 =================

        static Mesh Sphere(float rx, float ry, float rz, int seg, int rings)
        {
            var verts = new List<Vector3>(); var uvs = new List<Vector2>(); var tris = new List<int>();
            for (int j = 0; j <= rings; j++)
            {
                float theta = Mathf.PI * j / rings;
                float cy = Mathf.Cos(theta), sy = Mathf.Sin(theta);
                for (int i = 0; i <= seg; i++)
                {
                    float phi = -Mathf.PI + Mathf.PI * 2f * i / seg;
                    var p = new Vector3(sy * Mathf.Cos(phi) * rx, cy * ry, sy * Mathf.Sin(phi) * rz);
                    // 脸颊鼓起 + 下巴收窄
                    float ny = p.y / ry, nz = p.z / rz;
                    if (ny < 0.15f)
                    {
                        float cheek = Mathf.Exp(-((ny + 0.30f) * (ny + 0.30f) * 7f + (Mathf.Abs(nz) - 0.62f) * (Mathf.Abs(nz) - 0.62f) * 9f));
                        p.z += Mathf.Sign(p.z) * cheek * 0.055f * rx;
                    }
                    if (ny < -0.45f)
                    {
                        float k = Mathf.InverseLerp(-0.45f, -1f, ny);
                        p.x *= 1f - 0.10f * k; p.z *= 1f - 0.08f * k;
                    }
                    verts.Add(p);
                    uvs.Add(new Vector2(0.5f + phi / (Mathf.PI * 2f), 1f - theta / Mathf.PI));
                }
            }
            for (int j = 0; j < rings; j++)
                for (int i = 0; i < seg; i++)
                {
                    int a = j * (seg + 1) + i, b = a + seg + 1;
                    tris.Add(a); tris.Add(b); tris.Add(a + 1);
                    tris.Add(a + 1); tris.Add(b); tris.Add(b + 1);
                }
            return Finish(verts, uvs, tris, Vector3.zero, p => p);
        }

        static Mesh Lathe(Vector2[] profile, int seg, float zScale, out Vector3[] vertsOut)
        {
            var verts = new List<Vector3>(); var uvs = new List<Vector2>(); var tris = new List<int>();
            int rings = profile.Length;
            for (int j = 0; j < rings; j++)
            {
                float r = profile[j].x, y = profile[j].y;
                for (int i = 0; i <= seg; i++)
                {
                    float phi = -Mathf.PI + Mathf.PI * 2f * i / seg;
                    verts.Add(new Vector3(Mathf.Cos(phi) * r, y, Mathf.Sin(phi) * r * zScale));
                    uvs.Add(new Vector2(0.5f + phi / (Mathf.PI * 2f), j / (float)(rings - 1)));
                }
            }
            for (int j = 0; j < rings - 1; j++)
                for (int i = 0; i < seg; i++)
                {
                    int a = j * (seg + 1) + i, b = a + seg + 1;
                    tris.Add(a); tris.Add(b); tris.Add(a + 1);
                    tris.Add(a + 1); tris.Add(b); tris.Add(b + 1);
                }
            vertsOut = verts.ToArray();
            float yMid = (profile[0].y + profile[rings - 1].y) * 0.5f;
            return Finish(verts, uvs, tris, new Vector3(0f, yMid, 0f), p => new Vector3(p.x, 0f, p.z));
        }

        static Mesh Tube(Vector3[] pts, float[] radii, int sides, float vRepeat = 1f,
            float aspectX = 1f, float aspectZ = 1f, BoneWeight[] weights = null)
        {
            var verts = new List<Vector3>(); var uvs = new List<Vector2>(); var tris = new List<int>();
            int n = pts.Length;
            for (int i = 0; i < n; i++)
            {
                Vector3 tan = (pts[Mathf.Min(n - 1, i + 1)] - pts[Mathf.Max(0, i - 1)]).normalized;
                Vector3 right = Vector3.Cross(Vector3.up, tan);
                if (right.sqrMagnitude < 0.01f) right = Vector3.right;
                right.Normalize();
                Vector3 up2 = Vector3.Cross(tan, right).normalized;
                for (int s = 0; s <= sides; s++)
                {
                    float a = Mathf.PI * 2f * s / sides;
                    Vector3 off = (right * (Mathf.Cos(a) * aspectX) + up2 * (Mathf.Sin(a) * aspectZ)) * radii[i];
                    verts.Add(pts[i] + off);
                    uvs.Add(new Vector2(s / (float)sides, i / (float)(n - 1) * vRepeat));
                }
            }
            for (int i = 0; i < n - 1; i++)
                for (int s = 0; s < sides; s++)
                {
                    int a = i * (sides + 1) + s, b = a + sides + 1;
                    tris.Add(a); tris.Add(b); tris.Add(a + 1);
                    tris.Add(a + 1); tris.Add(b); tris.Add(b + 1);
                }
            var mesh = Finish(verts, uvs, tris, pts[0], p => p - ClosestOnPolyline(pts, p));
            if (weights != null) mesh.boneWeights = weights;
            return mesh;
        }

        static Vector3 ClosestOnPolyline(Vector3[] pts, Vector3 p)
        {
            float best = float.MaxValue; Vector3 bp = pts[0];
            for (int i = 0; i < pts.Length - 1; i++)
            {
                Vector3 a = pts[i], b = pts[i + 1], ab = b - a;
                float t = Mathf.Clamp01(Vector3.Dot(p - a, ab) / Mathf.Max(0.0001f, ab.sqrMagnitude));
                Vector3 q = a + ab * t;
                float d = (p - q).sqrMagnitude;
                if (d < best) { best = d; bp = q; }
            }
            return bp;
        }

        /// <summary>统一修正绕序并重算法线；outward 给出参考"外"方向。</summary>
        static Mesh Finish(List<Vector3> verts, List<Vector2> uvs, List<int> tris, Vector3 center, System.Func<Vector3, Vector3> outward)
        {
            var mesh = new Mesh { vertices = verts.ToArray(), uv = uvs.ToArray() };
            var t = tris.ToArray();
            // 找一个面积足够的三角形判断绕序
            for (int i = 0; i < t.Length; i += 3)
            {
                Vector3 a = verts[t[i]], b = verts[t[i + 1]], c = verts[t[i + 2]];
                Vector3 n = Vector3.Cross(b - a, c - a);
                if (n.sqrMagnitude < 1e-8f) continue;
                Vector3 cen = (a + b + c) / 3f;
                if (Vector3.Dot(n, outward(cen)) < 0f)
                    for (int k = 0; k < t.Length; k += 3) { int tmp = t[k + 1]; t[k + 1] = t[k + 2]; t[k + 2] = tmp; }
                break;
            }
            mesh.triangles = t;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }

        // ================= 四肢 =================

        static void AddArm(Art.Rig rig, Transform root, Transform sh, Transform el, Transform wr, float h,
            Material fur, Material cream, Material accent, bool left)
        {
            Vector3 a = root.InverseTransformPoint(sh.position), b = root.InverseTransformPoint(wr.position);
            int rings = 12;
            var pts = new Vector3[rings]; var radii = new float[rings];
            for (int i = 0; i < rings; i++)
            {
                float t = i / (rings - 1f);
                pts[i] = Vector3.Lerp(a, b, t);
                radii[i] = Mathf.Lerp(h * 0.085f, h * 0.062f, t) + Mathf.Sin(t * Mathf.PI) * h * 0.007f;
            }
            var bw = new BoneWeight[rings * 13];
            for (int i = 0; i < rings; i++)
            {
                float t = i / (rings - 1f);
                float wa = 1f - Mathf.SmoothStep(0.42f, 0.68f, t);
                for (int s = 0; s <= 12; s++)
                    bw[i * 13 + s] = new BoneWeight { boneIndex0 = 0, weight0 = wa, boneIndex1 = 1, weight1 = 1f - wa };
            }
            var mesh = Tube(pts, radii, 12, 2f, 1f, 1f, bw);
            var go = new GameObject(left ? "armL" : "armR");
            go.transform.SetParent(root, false);
            go.AddComponent<CpuLimb>().Setup(root, sh, el, mesh, fur, h);

            // 手 + 袖口
            var hand = new GameObject(left ? "handL" : "handR");
            hand.transform.SetParent(wr, false);
            Ball(hand.transform, new Vector3(h * 0.005f, -h * 0.052f, 0f),
                new Vector3(h * 0.145f, h * 0.118f, h * 0.118f), cream);
            float inner = left ? 1f : -1f;
            Ball(hand.transform, new Vector3(h * 0.052f, -h * 0.028f, inner * h * 0.048f),
                new Vector3(h * 0.058f, h * 0.064f, h * 0.048f), cream);
            Cyl(hand.transform, new Vector3(0f, h * 0.005f, 0f),
                new Vector3(h * 0.085f, h * 0.008f, h * 0.085f), accent);
            Art.Batch(hand.transform);
        }

        static void AddLeg(Art.Rig rig, Transform root, Transform th, Transform kn, Transform an, float h,
            Material fur, Material cream, Material accent, Material dark)
        {
            Vector3 a = root.InverseTransformPoint(th.position), b = root.InverseTransformPoint(an.position);
            int rings = 12;
            var pts = new Vector3[rings]; var radii = new float[rings];
            for (int i = 0; i < rings; i++)
            {
                float t = i / (rings - 1f);
                pts[i] = Vector3.Lerp(a, b, t);
                radii[i] = Mathf.Lerp(h * 0.092f, h * 0.075f, t) + Mathf.Sin(t * Mathf.PI) * h * 0.005f;
            }
            var bw = new BoneWeight[rings * 13];
            for (int i = 0; i < rings; i++)
            {
                float t = i / (rings - 1f);
                float wa = 1f - Mathf.SmoothStep(0.44f, 0.66f, t);
                for (int s = 0; s <= 12; s++)
                    bw[i * 13 + s] = new BoneWeight { boneIndex0 = 0, weight0 = wa, boneIndex1 = 1, weight1 = 1f - wa };
            }
            var mesh = Tube(pts, radii, 12, 2f, 1f, 1f, bw);
            var go = new GameObject(th.name == "thL" ? "legL" : "legR");
            go.transform.SetParent(root, false);
            go.AddComponent<CpuLimb>().Setup(root, th, kn, mesh, fur, h);

            var boot = new GameObject(th.name == "thL" ? "bootL" : "bootR");
            boot.transform.SetParent(an, false);
            Ball(boot.transform, new Vector3(h * 0.03f, -h * 0.045f, 0f),
                new Vector3(h * 0.172f, h * 0.096f, h * 0.135f), cream);
            Ball(boot.transform, new Vector3(h * 0.09f, -h * 0.055f, 0f),
                new Vector3(h * 0.09f, h * 0.068f, h * 0.112f), cream);
            Box(boot.transform, new Vector3(h * 0.038f, -h * 0.092f, 0f),
                new Vector3(h * 0.162f, h * 0.015f, h * 0.122f), dark);
            Cyl(boot.transform, new Vector3(0f, h * 0.004f, 0f),
                new Vector3(h * 0.108f, h * 0.010f, h * 0.102f), accent);
            Art.Batch(boot.transform);
        }

        // ================= 尾巴/耳朵/头饰 =================

        static void BuildTail(Art.Rig rig, Transform root, HeroDef d, float h, Material fur, Material cream, Material dark)
        {
            if (d.id == HeroId.Rabbit)
            {
                Ball(rig.tail1, new Vector3(-h * 0.02f, h * 0.0f, 0f), Vector3.one * h * 0.11f, cream);
                return;
            }
            if (d.id == HeroId.Hedgehog)
            {
                Ball(rig.tail1, new Vector3(-h * 0.02f, -h * 0.01f, 0f), Vector3.one * h * 0.07f, fur);
                return;
            }
            bool fox = d.id == HeroId.Fox;
            bool otter = d.id == HeroId.Otter;
            Vector3 p0 = new Vector3(-h * 0.17f, h * 0.43f, 0f);
            Vector3 p1 = p0 + new Vector3(-h * 0.09f, h * 0.005f, 0f);
            Vector3 p2 = p0 + new Vector3(-h * 0.20f, h * 0.05f, 0f);
            Vector3 p3 = p0 + new Vector3(-h * (fox ? 0.30f : 0.26f), h * (fox ? 0.16f : -0.02f), 0f);
            if (otter) { p2 = p0 + new Vector3(-h * 0.16f, -h * 0.03f, 0f); p3 = p0 + new Vector3(-h * 0.30f, -h * 0.10f, 0f); }
            var pts = new[] { p0, p1, p2, p3 };
            var radii = fox
                ? new[] { h * 0.09f, h * 0.11f, h * 0.11f, h * 0.075f }
                : otter ? new[] { h * 0.075f, h * 0.085f, h * 0.075f, h * 0.045f }
                : new[] { h * 0.075f, h * 0.08f, h * 0.07f, h * 0.045f };
            int rings = 4; int sides = 10;
            var bw = new BoneWeight[rings * (sides + 1)];
            for (int i = 0; i < rings; i++)
            {
                float t = i / (rings - 1f);
                float wa = 1f - Mathf.SmoothStep(0.3f, 0.8f, t);
                for (int s = 0; s <= sides; s++)
                    bw[i * (sides + 1) + s] = new BoneWeight { boneIndex0 = 0, weight0 = wa, boneIndex1 = 1, weight1 = 1f - wa };
            }
            var mesh = Tube(pts, radii, sides, 2f, otter ? 1.6f : 1f, otter ? 0.45f : 1f, bw);
            var go = new GameObject("tail");
            go.transform.SetParent(root, false);
            go.AddComponent<CpuLimb>().Setup(root, rig.tail1, rig.tail2, mesh, fur, h);
            if (fox) Ball(rig.tail2, new Vector3(-h * 0.09f, h * 0.11f, 0f), Vector3.one * h * 0.075f, cream);
            else if (!otter) Ball(rig.tail2, new Vector3(-h * 0.10f, -h * 0.02f, 0f), Vector3.one * h * 0.055f, cream);
            Art.Batch(rig.tail1); Art.Batch(rig.tail2);
        }

        static void BuildEars(Art.Rig rig, HeroDef d, float h, float headR, Material fur, Material cream, Material pink, Material dark)
        {
            var L = rig.earL; var R = rig.earR;
            if (d.id == HeroId.Rabbit)
            {
                LongEar(L, headR, fur, pink);
                LongEar(R, headR, fur, pink);
                return;
            }
            if (d.id == HeroId.Fox)
            {
                PointEar(L, headR, fur, pink);
                PointEar(R, headR, fur, pink);
                return;
            }
            float s = d.id == HeroId.Bear ? 1.25f : d.id == HeroId.Otter || d.id == HeroId.Hedgehog ? 0.82f : 1f;
            RoundEar(L, headR * s, fur, cream);
            RoundEar(R, headR * s, fur, cream);
        }

        static void RoundEar(Transform p, float r, Material fur, Material inner)
        {
            Ball(p, new Vector3(0f, r * 0.10f, 0f), new Vector3(r * 0.58f, r * 0.72f, r * 0.42f), fur);
            Ball(p, new Vector3(r * 0.46f, r * 0.08f, 0f), new Vector3(r * 0.14f, r * 0.42f, r * 0.28f), inner);
        }

        static void PointEar(Transform p, float r, Material fur, Material pink)
        {
            Cone(p, new Vector3(0f, r * 0.22f, 0f), new Vector3(r * 0.72f, r * 0.95f, r * 0.48f), fur,
                Quaternion.Euler(0f, 0f, -10f));
            Ball(p, new Vector3(r * 0.26f, r * 0.15f, 0f), new Vector3(r * 0.16f, r * 0.42f, r * 0.14f), pink);
        }

        static void LongEar(Transform p, float r, Material fur, Material pink)
        {
            Tube(p, new Vector3(0f, r * 0.74f, 0f), new Vector3(r * 0.50f, r * 0.92f, r * 0.38f), fur);
            Tube(p, new Vector3(r * 0.36f, r * 0.72f, 0f), new Vector3(r * 0.16f, r * 0.70f, r * 0.11f), pink);
        }

        static void BuildHeadDecor(Art.Rig rig, HeroDef d, float h, float headR, Material fur, Material dark, Material pink, Material gold, Material leaf)
        {
            var head = rig.head;
            Vector3 c = new Vector3(0f, h * 0.15f, 0f); // 头中心
            if (d.id == HeroId.Tiger)
            {
                Cone(head, c + new Vector3(headR * 0.12f, headR * 0.92f, headR * 0.10f),
                    new Vector3(headR * 0.26f, headR * 0.34f, headR * 0.26f), fur, Quaternion.Euler(0f, 0f, -24f));
                Cone(head, c + new Vector3(headR * 0.05f, headR * 0.95f, -headR * 0.12f),
                    new Vector3(headR * 0.20f, headR * 0.27f, headR * 0.20f), dark, Quaternion.Euler(0f, 0f, 12f));
            }
            else if (d.id == HeroId.Fox)
            {
                // 巫师帽
                var mHat = Art.Mat(new Color(0.48f, 0.33f, 0.78f), 0.25f, 0f, h * 0.008f);
                _all.Add(mHat);
                Cyl(head, c + new Vector3(0f, headR * 0.70f, 0f),
                    new Vector3(headR * 2.5f, headR * 0.035f, headR * 2.5f), mHat);
                Cyl(head, c + new Vector3(0f, headR * 0.78f, 0f),
                    new Vector3(headR * 2.25f, headR * 0.02f, headR * 2.25f), gold);
                Cone(head, c + new Vector3(0f, headR * 1.22f, 0f),
                    new Vector3(headR * 1.4f, headR * 1.0f, headR * 1.4f), mHat,
                    Quaternion.Euler(0f, 0f, -7f));
                Cone(head, c + new Vector3(headR * 0.42f, headR * 1.55f, 0f),
                    new Vector3(headR * 0.52f, headR * 0.45f, headR * 0.52f), mHat,
                    Quaternion.Euler(0f, 0f, -58f));
                Ball(head, c + new Vector3(headR * 0.55f, headR * 0.95f, headR * 0.32f), Vector3.one * headR * 0.13f, gold);
            }
            else if (d.id == HeroId.Rabbit)
            {
                // 花环
                for (int i = 0; i < 5; i++)
                {
                    float z = Mathf.Lerp(-headR * 0.48f, headR * 0.48f, i / 4f);
                    var p = c + new Vector3(headR * 0.34f, headR * 0.82f + Mathf.Cos((i - 2) / 4f * Mathf.PI) * headR * 0.07f, z);
                    Ball(head, p, Vector3.one * headR * 0.14f, gold);
                    for (int k = 0; k < 4; k++)
                    {
                        float a = k * Mathf.PI * 0.5f;
                        Ball(head, p + new Vector3(Mathf.Cos(a) * headR * 0.11f, headR * 0.02f, Mathf.Sin(a) * headR * 0.11f),
                            new Vector3(headR * 0.12f, headR * 0.08f, headR * 0.12f), pink);
                    }
                }
            }
            else if (d.id == HeroId.Bear)
            {
                Cone(head, c + new Vector3(headR * 0.10f, headR * 0.98f, 0f),
                    new Vector3(headR * 0.34f, headR * 0.38f, headR * 0.20f), leaf, Quaternion.Euler(0f, 0f, -20f));
            }
            else if (d.id == HeroId.Otter)
            {
                Cone(head, c + new Vector3(headR * 0.14f, headR * 0.95f, 0f),
                    new Vector3(headR * 0.22f, headR * 0.28f, headR * 0.22f), fur, Quaternion.Euler(0f, 0f, -18f));
                var bub = new GameObject("bubble");
                bub.transform.SetParent(head, false);
                bub.transform.localPosition = new Vector3(headR * 0.05f, h * 0.15f + headR * 1.12f, 0f);
                Ball(bub.transform, new Vector3(0f, headR * 0.18f, 0f), Vector3.one * headR * 0.32f,
                    Art.Emissive(new Color(0.55f, 0.86f, 1f), 0.6f));
                bub.AddComponent<Bobber>();
            }
            else if (d.id == HeroId.Hedgehog)
            {
                for (int i = -1; i <= 1; i++)
                    Cone(head, c + new Vector3(-headR * 0.12f, headR * 1.00f, i * headR * 0.20f),
                        new Vector3(headR * 0.16f, headR * 0.38f, headR * 0.16f), dark, Quaternion.Euler(0f, i * 12f, 25f));
                /* 两侧的刺要露在剪影外，正面/选人头像才认得出是刺猬 */
                for (int side = -1; side <= 1; side += 2)
                    for (int i = 0; i < 2; i++)
                        Cone(head, c + new Vector3(-headR * (0.22f + i * 0.16f), headR * (0.58f - i * 0.16f), side * headR * 0.78f),
                            new Vector3(headR * 0.18f, headR * 0.42f, headR * 0.18f), dark,
                            Quaternion.Euler(side * (58f + i * 8f), 0f, 24f));
            }
            head.localScale = d.id == HeroId.Bear ? new Vector3(1.06f, 0.99f, 1.05f)
                : d.id == HeroId.Fox ? new Vector3(0.96f, 1.02f, 0.94f)
                : Vector3.one;
            Art.Batch(head);
        }

        // ================= 服装/配件 =================

        static void BuildOutfit(Art.Rig rig, HeroDef d, float h, float headR,
            Material fur, Material cream, Material dark, Material accent, Material gold,
            Material leaf, Material wood, Material pink, Material ink, Material glow)
        {
            var hips = rig.hips; var chest = rig.chest; var wrR = rig.wrR; var wrL = rig.wrL;
            // 腰带（所有角色）
            Torus(hips, new Vector3(0f, h * 0.03f, 0f), h * 0.225f, h * 0.020f, dark);
            Box(hips, new Vector3(h * 0.215f, h * 0.03f, 0f), new Vector3(h * 0.05f, h * 0.04f, h * 0.025f), gold);

            switch (d.id)
            {
                case HeroId.Tiger:
                    Torus(chest, new Vector3(0f, h * 0.045f, 0f), h * 0.205f, h * 0.035f, accent);
                    Box(chest, new Vector3(h * 0.18f, h * 0.02f, -h * 0.10f),
                        new Vector3(h * 0.06f, h * 0.16f, h * 0.025f), accent, Quaternion.Euler(0f, 0f, 18f));
                    Box(chest, new Vector3(h * 0.16f, -h * 0.04f, -h * 0.11f),
                        new Vector3(h * 0.05f, h * 0.11f, h * 0.02f), accent, Quaternion.Euler(0f, 0f, -8f));
                    Box(hips, new Vector3(h * 0.20f, h * 0.20f, 0f),
                        new Vector3(h * 0.04f, h * 0.18f, h * 0.02f), wood, Quaternion.Euler(0f, 0f, 32f));
                    Torus(wrL, new Vector3(0f, h * 0.005f, 0f), h * 0.062f, h * 0.016f, accent);
                    Torus(wrR, new Vector3(0f, h * 0.005f, 0f), h * 0.062f, h * 0.016f, accent);
                    break;

                case HeroId.Fox:
                    // 法袍
                    Skirt(hips, h * 0.14f, h * 0.28f, h * -0.02f, h * -0.30f, accent, 22);
                    Torus(hips, new Vector3(0f, h * 0.035f, 0f), h * 0.22f, h * 0.018f, gold);
                    // 胸毛
                    Ball(chest, new Vector3(h * 0.15f, -h * 0.015f, 0f), new Vector3(h * 0.11f, h * 0.10f, h * 0.13f), cream);
                    // 挎包
                    Ball(hips, new Vector3(h * 0.05f, h * 0.06f, -h * 0.20f), new Vector3(h * 0.13f, h * 0.11f, h * 0.08f), wood);
                    // 法杖
                    var wp = new GameObject("weapon").transform;
                    wp.SetParent(wrR, false);
                    wp.localRotation = Quaternion.Euler(0f, 0f, 8f);
                    rig.weapon = wp;
                    Cyl(wp, new Vector3(0f, h * 0.10f, 0f), new Vector3(h * 0.03f, h * 0.30f, h * 0.03f), wood);
                    Cyl(wp, new Vector3(0f, h * 0.36f, 0f), new Vector3(h * 0.055f, h * 0.012f, h * 0.055f), gold);
                    Ball(wp, new Vector3(0f, h * 0.43f, 0f), Vector3.one * h * 0.095f, glow);
                    for (int i = 0; i < 4; i++)
                    {
                        float a = i * Mathf.PI * 0.5f;
                        Ball(wp, new Vector3(Mathf.Cos(a) * h * 0.075f, h * 0.48f, Mathf.Sin(a) * h * 0.075f),
                            Vector3.one * h * 0.024f, gold);
                    }
                    Art.Batch(wp);
                    break;

                case HeroId.Rabbit:
                    Skirt(hips, h * 0.15f, h * 0.26f, h * -0.02f, h * -0.20f, accent, 22);
                    Skirt(hips, h * 0.17f, h * 0.29f, h * -0.10f, h * -0.24f, cream, 22);
                    Torus(chest, new Vector3(0f, h * 0.02f, 0f), h * 0.135f, h * 0.012f, accent);
                    Ball(chest, new Vector3(h * 0.17f, h * 0.03f, -h * 0.06f), new Vector3(h * 0.08f, h * 0.055f, h * 0.07f), pink);
                    Ball(chest, new Vector3(h * 0.17f, h * 0.03f, h * 0.06f), new Vector3(h * 0.08f, h * 0.055f, h * 0.07f), pink);
                    Ball(chest, new Vector3(h * 0.19f, h * 0.03f, 0f), Vector3.one * h * 0.045f, gold);
                    var wpr = new GameObject("weapon").transform;
                    wpr.SetParent(wrR, false);
                    rig.weapon = wpr;
                    Cyl(wpr, new Vector3(0f, h * 0.08f, 0f), new Vector3(h * 0.024f, h * 0.20f, h * 0.024f), wood);
                    Art.Octa(wpr, new Vector3(0f, h * 0.29f, 0f), new Vector3(h * 0.15f, h * 0.20f, h * 0.15f), glow);
                    Art.Batch(wpr);
                    break;

                case HeroId.Bear:
                    Torus(hips, new Vector3(0f, h * 0.03f, 0f), h * 0.228f, h * 0.014f, wood);
                    // 叶披风
                    Ball(chest, new Vector3(-h * 0.15f, -h * 0.01f, 0f), new Vector3(h * 0.09f, h * 0.24f, h * 0.28f), leaf);
                    Ball(chest, new Vector3(h * 0.19f, h * 0.04f, 0f), Vector3.one * h * 0.055f, leaf);
                    // 叶盾（左手）
                    var wpl = new GameObject("weapon").transform;
                    wpl.SetParent(wrL, false);
                    wpl.localRotation = Quaternion.Euler(0f, -20f, 0f);
                    rig.weapon = wpl;
                    Cyl(wpl, new Vector3(h * 0.03f, -h * 0.04f, 0f),
                        new Vector3(h * 0.30f, h * 0.012f, h * 0.30f), leaf, Quaternion.Euler(0f, 0f, 90f));
                    Box(wpl, new Vector3(h * 0.04f, -h * 0.04f, 0f), new Vector3(h * 0.012f, h * 0.24f, h * 0.03f), accent);
                    Box(wpl, new Vector3(h * 0.04f, -h * 0.04f, 0f), new Vector3(h * 0.012f, h * 0.03f, h * 0.24f), accent);
                    Ball(wpl, new Vector3(h * 0.055f, -h * 0.04f, 0f), Vector3.one * h * 0.055f, gold);
                    Art.Batch(wpl);
                    break;

                case HeroId.Otter:
                    Skirt(chest, h * 0.20f, h * 0.21f, h * -0.10f, h * 0.10f, accent, 22);
                    Torus(chest, new Vector3(0f, h * 0.05f, 0f), h * 0.17f, h * 0.025f, accent);
                    Ball(chest, new Vector3(h * 0.16f, h * 0.0f, 0f), Vector3.one * h * 0.06f, gold);
                    break;

                case HeroId.Hedgehog:
                    // 背刺
                    for (int row = 0; row < 3; row++)
                        for (int i = -2; i <= 2; i++)
                        {
                            float y0 = h * (0.10f + row * 0.085f);
                            Cone(chest, new Vector3(-h * 0.19f - row * h * 0.012f, y0, i * h * 0.075f),
                                new Vector3(h * 0.07f, h * 0.19f, h * 0.07f), row % 2 == 0 ? dark : fur,
                                Quaternion.Euler(0f, i * 8f, 58f));
                        }
                    Torus(chest, new Vector3(0f, h * 0.16f, 0f), h * 0.175f, h * 0.015f, accent);
                    Box(chest, new Vector3(h * 0.175f, h * 0.16f, 0f), new Vector3(h * 0.035f, h * 0.035f, h * 0.02f), gold);
                    Ball(hips, new Vector3(-h * 0.02f, h * 0.03f, -h * 0.20f), new Vector3(h * 0.12f, h * 0.11f, h * 0.08f), wood);
                    break;
            }
        }

        static void Skirt(Transform parent, float rTop, float rBottom, float yTop, float yBottom, Material mat, int seg)
        {
            var prof = new[] { new Vector2(rTop, yTop), new Vector2(Mathf.Lerp(rTop, rBottom, 0.55f), Mathf.Lerp(yTop, yBottom, 0.55f)), new Vector2(rBottom, yBottom) };
            var mesh = Lathe(prof, seg, 0.96f, out _);
            MeshObj(parent, "skirt", mesh, mat, Vector3.zero);
        }

        // ================= 工具 =================

        static Transform Node(Transform parent, string name, Vector3 pos)
        {
            var g = new GameObject(name);
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            return g.transform;
        }

        static GameObject MeshObj(Transform parent, string name, Mesh mesh, Material mat, Vector3 pos)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = mat;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            mr.receiveShadows = true;
            return go;
        }

        static GameObject Ball(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Art.Prim(PrimitiveType.Sphere, p, pos, scale, m, q);
        static GameObject Box(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Art.Prim(PrimitiveType.Cube, p, pos, scale, m, q);
        static GameObject Cyl(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Art.Prim(PrimitiveType.Cylinder, p, pos, scale, m, q);
        static GameObject Tube(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Art.Prim(PrimitiveType.Capsule, p, pos, scale, m, q);
        static GameObject Cone(Transform p, Vector3 pos, Vector3 scale, Material m, Quaternion? q = null)
            => Art.Cone(p, pos, scale, m, q);

        static void Torus(Transform parent, Vector3 pos, float major, float minor, Material mat)
        {
            var go = MeshObj(parent, "torus", TorusMesh(major, minor, 24, 8), mat, pos);
            go.name = "torus";
        }

        static Mesh TorusMesh(float major, float minor, int segM, int segm)
        {
            var verts = new List<Vector3>(); var uvs = new List<Vector2>(); var tris = new List<int>();
            for (int i = 0; i <= segM; i++)
            {
                float phi = Mathf.PI * 2f * i / segM;
                var c = new Vector3(Mathf.Cos(phi) * major, 0f, Mathf.Sin(phi) * major);
                for (int j = 0; j <= segm; j++)
                {
                    float th = Mathf.PI * 2f * j / segm;
                    var dir = new Vector3(Mathf.Cos(phi) * Mathf.Cos(th), Mathf.Sin(th), Mathf.Sin(phi) * Mathf.Cos(th));
                    verts.Add(c + dir * minor);
                    uvs.Add(new Vector2(i / (float)segM, j / (float)segm));
                }
            }
            for (int i = 0; i < segM; i++)
                for (int j = 0; j < segm; j++)
                {
                    int a = i * (segm + 1) + j, b = a + segm + 1;
                    tris.Add(a); tris.Add(b); tris.Add(a + 1);
                    tris.Add(a + 1); tris.Add(b); tris.Add(b + 1);
                }
            return Finish(verts, uvs, tris, Vector3.zero, p =>
            {
                Vector3 flat = new Vector3(p.x, 0f, p.z);
                return p - flat.normalized * major;
            });
        }
    }
}
