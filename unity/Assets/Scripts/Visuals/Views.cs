using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    /// <summary>英雄表现层：把 Unit 的状态映射到骨架（逐帧插值，保证顺滑）。</summary>
    public class HeroView : MonoBehaviour
    {
        public Unit unit;
        public float yawOffset;      // 陈列台用：让英雄面向镜头
        Art.Rig rig;
        float _walkPhase, _bodyTwist, _headLag, _deathP, _flash, _squash = 1f;
        float _blinkT;

        public static HeroView Attach(Unit u, Art.Rig rig)
        {
            var v = rig.root.gameObject.AddComponent<HeroView>();
            v.unit = u;
            v.rig = rig;
            return v;
        }

        void Update()
        {
            if (unit == null || rig == null) return;
            float dt = Time.deltaTime;
            var t = rig;
            bool alive = unit.alive;

            transform.position = new Vector3(unit.pos.x,
                unit.alive ? Mathf.Max(0f, transform.position.y) : transform.position.y, unit.pos.z);
            float wantYaw = (unit.facing >= 0f ? 0f : 180f) + yawOffset;
            transform.rotation = Quaternion.Euler(0f, Mathf.LerpAngle(transform.rotation.eulerAngles.y, wantYaw,
                1f - Mathf.Exp(-12f * dt)), 0f);

            if (!alive)
            {
                _deathP = Mathf.Min(1f, _deathP + dt * 1.6f);
                transform.rotation = Quaternion.Euler(0f, transform.rotation.eulerAngles.y, -_deathP * 78f);
                transform.position += Vector3.down * dt * 14f;
                transform.localScale = Vector3.one * Mathf.Max(0.15f, 1f - _deathP * 0.35f);
                foreach (var m in t.mats) m.color = Color.Lerp(m.color, new Color(0.4f, 0.4f, 0.4f), dt * 2f);
                return;
            }

            if (_deathP > 0f)
            {
                /* 复活：弹起 + 恢复颜色 */
                _deathP = Mathf.Max(0f, _deathP - dt * 3.2f);
                transform.rotation = Quaternion.Euler(0f, transform.rotation.eulerAngles.y, -_deathP * 78f);
                transform.localScale = Vector3.one;
                for (int i = 0; i < t.mats.Length; i++) t.mats[i].color = t.baseCols[i];
            }

            /* ---- 步态 ---- */
            bool moving = unit.moving;
            _walkPhase += dt * (moving ? 8.2f : 0f);
            float swing = moving ? Mathf.Sin(_walkPhase) : 0f;
            float atk = unit.atkAnim > 0f ? 1f - unit.atkAnim / 0.26f : 0f;
            float cast = unit.castAnim > 0f ? 1f - unit.castAnim / 0.42f : 0f;
            float hurt = unit.hurtAnim > 0f ? unit.hurtAnim / 0.22f : 0f;
            float atkArc = Mathf.Sin(atk * Mathf.PI);

            /* ---- 躯干：转体、前倾、受击后仰 ---- */
            float wantTwist = atk > 0f ? Mathf.Lerp(-24f, 26f, atk) : (moving ? swing * 4f : 0f);
            _bodyTwist = Mathf.Lerp(_bodyTwist, wantTwist, 1f - Mathf.Exp(-16f * dt));
            var body = t.body;
            body.localRotation = Quaternion.Euler(
                hurt * 7f,                                   // 侧倾
                _bodyTwist,                                  // 扭转
                -atkArc * 9f + hurt * 12f + cast * 5f);      // 前倾（+Z 是后仰）
            float wantSquash = 1f + (moving ? Mathf.Abs(swing) * 0.04f : Mathf.Sin(Time.time * 1.6f) * 0.012f)
                               - hurt * 0.055f;
            _squash = Mathf.Lerp(_squash, wantSquash, 1f - Mathf.Exp(-14f * dt));
            body.localScale = new Vector3(1f / _squash, _squash, 1f / _squash);

            /* ---- 腿：前后摆（Z 轴），膝盖反向弯 ---- */
            float legAmp = moving ? 30f : 0f;
            SmoothEuler(t.legL, 0f, 0f, swing * legAmp + atkArc * 5f, 24f, dt);
            SmoothEuler(t.legR, 0f, 0f, -swing * legAmp - atkArc * 4f, 24f, dt);
            float kneeL = moving ? Mathf.Max(0f, swing) * 32f : 3f;
            float kneeR = moving ? Mathf.Max(0f, -swing) * 32f : 3f;
            SmoothEuler(t.shinL, 0f, 0f, -kneeL - atkArc * 4f, 24f, dt);
            SmoothEuler(t.shinR, 0f, 0f, -kneeR - atkArc * 2f, 24f, dt);

            /* ---- 手臂：走路对摆；攻击是蓄力→甩出，施法抬臂 ---- */
            float armSwing = moving ? swing * 22f : 0f;
            float zL = -armSwing, zR = armSwing;
            float elbowL = 12f, elbowR = 12f;

            if (atk > 0f)
            {
                if (atk < 0.35f)
                {
                    float k = atk / 0.35f;
                    zR = Mathf.Lerp(zR, -72f, k);
                    zL = Mathf.Lerp(zL, -34f, k);
                    elbowR = Mathf.Lerp(elbowR, 78f, k);
                    elbowL = Mathf.Lerp(elbowL, 42f, k);
                }
                else
                {
                    float k = Mathf.Clamp01((atk - 0.35f) / 0.65f);
                    float hit = Mathf.Sin(k * Mathf.PI * 0.92f);
                    zR = Mathf.Lerp(-72f, 98f, hit);
                    zL = Mathf.Lerp(-34f, 34f, hit);
                    elbowR = Mathf.Lerp(78f, 6f, k);
                    elbowL = Mathf.Lerp(42f, 14f, k);
                }
            }
            if (cast > 0f)
            {
                float k = Mathf.Sin(Mathf.Clamp01(cast) * Mathf.PI);
                zR = Mathf.Lerp(zR, 108f, k);
                zL = Mathf.Lerp(zL, 54f, k);
                elbowR = Mathf.Lerp(elbowR, 18f, k);
                elbowL = Mathf.Lerp(elbowL, 30f, k);
            }
            if (hurt > 0f)
            {
                zR = Mathf.Lerp(zR, 40f, hurt);
                zL = Mathf.Lerp(zL, -20f, hurt);
                elbowR = Mathf.Lerp(elbowR, 55f, hurt);
            }
            SmoothEuler(t.armL, 5f, 0f, zL, 22f, dt);
            SmoothEuler(t.armR, -5f, 0f, zR, 22f, dt);
            SmoothEuler(t.forearmL, 0f, 0f, elbowL, 22f, dt);
            SmoothEuler(t.forearmR, 0f, 0f, elbowR, 22f, dt);

            /* ---- 头：滞后跟随 + 转向镜头（让玩家看得见脸）+ 呼吸 ---- */
            _headLag = Mathf.Lerp(_headLag, -_bodyTwist * 0.4f, 1f - Mathf.Exp(-9f * dt));
            float lookYaw = 0f;
            var cam = CameraRig.I != null ? CameraRig.I.cam : null;
            if (cam != null)
            {
                Vector3 cd = cam.transform.position - t.head.position;
                float camYaw = Mathf.Atan2(-cd.z, cd.x) * Mathf.Rad2Deg;
                float k = moving ? 0.55f : 1f;
                if (atk > 0f || cast > 0f) k *= 0.45f;
                if (hurt > 0f) k *= 0.4f;
                lookYaw = Mathf.Clamp(Mathf.DeltaAngle(transform.eulerAngles.y + _bodyTwist, camYaw) * 0.5f, -30f, 30f) * k;
            }
            SmoothEuler(t.head, hurt * -8f,
                _headLag + lookYaw,
                -atkArc * 9f + cast * 12f - hurt * 5f + Mathf.Sin(Time.time * 1.5f) * 2.2f, 12f, dt);

            /* ---- 尾巴与耳朵：次级运动 ---- */
            if (t.tail != null)
                SmoothEuler(t.tail,
                    Mathf.Sin(Time.time * 2.4f) * 6f,
                    Mathf.Sin(Time.time * 2.1f) * 14f + _bodyTwist * 0.6f,
                    -hurt * 12f + atkArc * 10f, 14f, dt);
            if (t.earL != null)
                SmoothEuler(t.earL, -8f + Mathf.Sin(Time.time * 2.2f) * 5f - hurt * 16f, 0f, 0f, 14f, dt);
            if (t.earR != null)
                SmoothEuler(t.earR, 8f + Mathf.Sin(Time.time * 2.2f + 1.2f) * 5f - hurt * 16f, 0f, 0f, 14f, dt);

            /* ---- 眨眼 ---- */
            _blinkT += dt;
            float blink = 1f;
            if (_blinkT > 3.4f)
            {
                float k = (_blinkT - 3.4f) / 0.13f;
                if (k < 1f) blink = Mathf.Lerp(1f, 0.08f, Mathf.Sin(k * Mathf.PI));
                else _blinkT = 0f;
            }
            t.eyes.localScale = new Vector3(1f, blink, 1f);

            /* ---- 受击闪白 ---- */
            _flash = Mathf.Lerp(_flash, hurt, 1f - Mathf.Exp(-22f * dt));
            for (int i = 0; i < t.mats.Length; i++)
                t.mats[i].color = Color.Lerp(t.baseCols[i], Color.white, _flash * 0.75f);
        }

        static void SmoothEuler(Transform tr, float x, float y, float z, float rate, float dt)
        {
            if (tr == null) return;
            tr.localRotation = Quaternion.Slerp(tr.localRotation, Quaternion.Euler(x, y, z),
                1f - Mathf.Exp(-rate * dt));
        }
    }

    /// <summary>世界表现层：地图、道具、塔、小兵、弹道、减速区、英雄视图。</summary>
    public class WorldView : MonoBehaviour
    {
        public Arena arena;
        Transform _props, _units;
        readonly Dictionary<int, GameObject> _minionGo = new Dictionary<int, GameObject>();
        readonly Dictionary<int, GameObject> _structureGo = new Dictionary<int, GameObject>();
        readonly Dictionary<int, GameObject> _shotGo = new Dictionary<int, GameObject>();
        readonly List<GameObject> _zoneGo = new List<GameObject>();
        Material _zoneMat;

        public static WorldView Attach(Arena a, Transform parent)
        {
            var go = new GameObject("WorldView");
            go.transform.SetParent(parent, false);
            var v = go.AddComponent<WorldView>();
            v.arena = a;
            v.Build();
            return v;
        }

        void Build()
        {
            _props = new GameObject("Props").transform;
            _props.SetParent(transform, false);
            _units = new GameObject("Units").transform;
            _units.SetParent(transform, false);

            /* 地面 */
            var ground = new GameObject("Ground");
            ground.transform.SetParent(transform, false);
            var mf = ground.AddComponent<MeshFilter>();
            var mr = ground.AddComponent<MeshRenderer>();
            var mesh = new Mesh { name = "ground" };
            mesh.vertices = new[]
            {
                new Vector3(0f, 0f, 0f), new Vector3(Arena.MapW, 0f, 0f),
                new Vector3(Arena.MapW, 0f, Arena.MapH), new Vector3(0f, 0f, Arena.MapH)
            };
            mesh.uv = new[] { new Vector2(0, 0), new Vector2(1, 0), new Vector2(1, 1), new Vector2(0, 1) };
            mesh.triangles = new[] { 0, 2, 1, 0, 3, 2 };
            mesh.RecalculateNormals();
            mf.mesh = mesh;
            var mat = new Material(Art.ToonShader());
            var tex = Art.GroundTexture(1280, 683);
            tex.anisoLevel = 4;
            mat.mainTexture = tex;
            mat.color = Color.white;
            if (mat.HasProperty("_ShadeTint")) mat.SetColor("_ShadeTint", new Color(0.9f, 1f, 0.9f));
            if (mat.HasProperty("_RimStrength")) mat.SetFloat("_RimStrength", 0f);
            mr.sharedMaterial = mat;
            mr.receiveShadows = true;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

            /* 外圈大地：视野里不再出现虚空 */
            {
                var outer = GameObject.CreatePrimitive(PrimitiveType.Plane);
                var col = outer.GetComponent<Collider>();
                if (col != null) Destroy(col);
                outer.name = "OuterGround";
                outer.transform.SetParent(transform, false);
                outer.transform.localPosition = new Vector3(Arena.MapW * 0.5f, -2.5f, Arena.MapH * 0.5f);
                outer.transform.localScale = new Vector3(1400f, 1f, 900f);
                var omr = outer.GetComponent<MeshRenderer>();
                omr.sharedMaterial = Art.MatShared(new Color(0.30f, 0.47f, 0.31f), 0f);
                omr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                omr.receiveShadows = true;
            }

            /* 远景山与树线：把地图边缘藏进雾里 */
            {
                var backdrop = new GameObject("Backdrop").transform;
                backdrop.SetParent(transform, false);
                Art.Hills(backdrop, new Vector3(Arena.MapW * 0.5f, 0f, Arena.MapH * 0.5f), 1750f, 2400f, 26, 7127);
                StaticBatchingUtility.Combine(backdrop.gameObject);
            }

            /* 树 / 灌木 / 蘑菇 / 石头 / 草丛：避开兵线与据点 */
            var scenery = new GameObject("Scenery").transform;
            scenery.SetParent(transform, false);
            var rnd = new System.Random(20261101);
            System.Func<float, float, float> rr = (a, b) => a + (float)rnd.NextDouble() * (b - a);
            for (int i = 0; i < 58; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 360f) continue;
                if (Mathf.Abs(p.x - 1500f) < 300f) continue;
                if (Vector3.Distance(p, arena.baseBlue.pos) < 520f) continue;
                if (Vector3.Distance(p, arena.baseRed.pos) < 520f) continue;
                Art.Tree(scenery, p, rr(0.85f, 1.35f), i);
            }
            for (int i = 0; i < 30; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 260f || Mathf.Abs(p.x - 1500f) < 240f) continue;
                Art.Bush(scenery, p, rr(0.8f, 1.35f), i);
            }
            for (int i = 0; i < 34; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 190f) continue;
                Art.Mushroom(scenery, p, rr(0.75f, 1.25f),
                    i % 3 == 0 ? new Color(0.85f, 0.45f, 0.42f) : new Color(0.95f, 0.80f, 0.55f));
            }
            for (int i = 0; i < 26; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 200f) continue;
                Art.Rock(scenery, p, rr(0.8f, 1.4f), i);
            }
            for (int i = 0; i < 40; i++)
            {
                Vector3 p = new Vector3(rr(100f, Arena.MapW - 100f), 0f, rr(100f, Arena.MapH - 100f));
                float d = DistToLane(p);
                if (d < 150f || d > 300f) continue;
                Art.GrassTuft(scenery, p, rr(0.9f, 1.5f), i);
            }
            /* 兵线跨河的木桥 */
            Art.Bridge(scenery, new Vector3(1500f, -0.8f, 800f), 0f);
            StaticBatchingUtility.Combine(scenery.gameObject);

            /* 塔与水晶 */
            foreach (var t in arena.towersBlue) _structureGo[t.uid] = Art.Tower(_props, t.pos, true, t.level);
            foreach (var t in arena.towersRed) _structureGo[t.uid] = Art.Tower(_props, t.pos, false, t.level);
            _structureGo[arena.baseBlue.uid] = Art.Crystal(_props, arena.baseBlue.pos, true);
            _structureGo[arena.baseRed.uid] = Art.Crystal(_props, arena.baseRed.pos, false);

            /* 英雄 */
            foreach (var h in arena.heroes)
            {
                var rig = Art.BuildHero(h.def, _units);
                HeroView.Attach(h, rig);
                h.height = rig.height;
            }

            {
                var zs = Shader.Find("Sprites/Default");
                if (zs == null) { var zm = Resources.Load<Material>("TapArenaFx"); if (zm != null) zs = zm.shader; }
                _zoneMat = new Material(zs ?? Art.StdShader());
            }
            var ringTex = MakeDiscTexture();
            _zoneMat.mainTexture = ringTex;
        }

        static Texture2D MakeDiscTexture()
        {
            const int s = 96;
            var t = new Texture2D(s, s, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[s * s];
            for (int y = 0; y < s; y++)
                for (int x = 0; x < s; x++)
                {
                    float dx = (x + 0.5f) / s * 2f - 1f, dy = (y + 0.5f) / s * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float a = Mathf.Clamp01(1f - Mathf.Abs(d - 0.8f) * 7f) * 0.75f + Mathf.Clamp01(1f - d) * 0.2f;
                    px[y * s + x] = new Color32(255, 255, 255, (byte)(Mathf.Clamp01(a) * 255f));
                }
            t.SetPixels32(px); t.Apply();
            return t;
        }

        public float DistToLane(Vector3 p)
        {
            float best = float.MaxValue;
            var lane = Arena.Lane;
            for (int i = 0; i < lane.Length - 1; i++)
            {
                Vector3 a = lane[i], b = lane[i + 1];
                Vector2 ap = new Vector2(a.x, a.z), bp = new Vector2(b.x, b.z), pp = new Vector2(p.x, p.z);
                float t = Mathf.Clamp01(Vector2.Dot(pp - ap, bp - ap) / Vector2.Dot(bp - ap, bp - ap));
                float d = Vector2.Distance(pp, ap + (bp - ap) * t);
                if (d < best) best = d;
            }
            return best;
        }

        void LateUpdate()
        {
            if (arena == null) return;
            float dt = Time.deltaTime;

            /* 小兵：清理掉已经阵亡/被移除的模型，别留下满地尸体 */
            var liveMinions = new HashSet<int>();
            foreach (var m in arena.minions) if (m.alive) liveMinions.Add(m.uid);
            foreach (var kv in _minionGo)
                if (!liveMinions.Contains(kv.Key)) kv.Value.SetActive(false);

            foreach (var m in arena.minions)
            {
                if (!m.alive) continue;
                if (!_minionGo.TryGetValue(m.uid, out var go))
                {
                    go = Art.Minion(_units, m.team == Team.Blue);
                    _minionGo[m.uid] = go;
                }
                float hop = Mathf.Abs(Mathf.Sin(m.walkT * 8f)) * (m.moving ? 4.5f : 0f);
                go.transform.position = m.pos + Vector3.up * hop;
                go.transform.rotation = Quaternion.Euler(0f, m.facing >= 0f ? 0f : 180f, 0f);
                float sq = 1f + (m.atkAnim > 0f ? Mathf.Sin((1f - m.atkAnim / 0.22f) * Mathf.PI) * 0.14f : 0f);
                go.transform.localScale = new Vector3(1f / sq, sq, 1f / sq);
            }

            /* 塔 / 水晶 存活状态 */
            foreach (var kv in _structureGo)
            {
                Unit u = null;
                for (int i = 0; i < arena.units.Count; i++)
                    if (arena.units[i].uid == kv.Key) { u = arena.units[i]; break; }
                if (u == null) { kv.Value.SetActive(false); continue; }
                kv.Value.SetActive(u.alive);
            }

            /* 弹道 */
            var seen = new HashSet<int>();
            for (int i = 0; i < arena.shots.Count; i++)
            {
                var p = arena.shots[i];
                int key = i;
                seen.Add(key);
                if (!_shotGo.TryGetValue(key, out var go))
                {
                    go = Art.Prim(PrimitiveType.Sphere, _units, Vector3.zero,
                        Vector3.one * (p.bubble ? 26f : 14f), Art.Emissive(p.color, 1.8f));
                    var mr = go.GetComponent<MeshRenderer>();
                    mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                    _shotGo[key] = go;
                }
                go.SetActive(true);
                go.transform.position = p.pos;
                go.transform.localScale = Vector3.one * (p.bubble ? 26f : 14f);
            }
            foreach (var kv in _shotGo)
                if (!seen.Contains(kv.Key)) kv.Value.SetActive(false);

            /* 减速区：地面法阵 */
            while (_zoneGo.Count < arena.zones.Count)
            {
                var g = new GameObject("zone");
                g.transform.SetParent(transform, false);
                var mf = g.AddComponent<MeshFilter>();
                var quad = new Mesh();
                quad.vertices = new[] { new Vector3(-0.5f, 0, -0.5f), new Vector3(0.5f, 0, -0.5f), new Vector3(0.5f, 0, 0.5f), new Vector3(-0.5f, 0, 0.5f) };
                quad.uv = new[] { new Vector2(0, 0), new Vector2(1, 0), new Vector2(1, 1), new Vector2(0, 1) };
                quad.triangles = new[] { 0, 2, 1, 0, 3, 2 };
                quad.RecalculateNormals();
                mf.mesh = quad;
                var mr = g.AddComponent<MeshRenderer>();
                mr.sharedMaterial = new Material(_zoneMat) { mainTexture = _zoneMat.mainTexture };
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                _zoneGo.Add(g);
            }
            for (int i = 0; i < _zoneGo.Count; i++)
            {
                bool on = i < arena.zones.Count;
                _zoneGo[i].SetActive(on);
                if (!on) continue;
                var z = arena.zones[i];
                _zoneGo[i].transform.position = z.pos + Vector3.up * 2.4f;
                _zoneGo[i].transform.localScale = new Vector3(z.r * 2f, 1f, z.r * 2f);
                var mr = _zoneGo[i].GetComponent<MeshRenderer>();
                float k = 1f - z.t / z.life;
                mr.material.color = new Color(z.color.r, z.color.g, z.color.b, 0.55f * k);
            }
        }
    }
}
