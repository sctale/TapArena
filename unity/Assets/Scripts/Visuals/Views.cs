using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    /// <summary>世界表现层：地图、道具、塔、小兵、弹道、减速区、英雄视图。</summary>
    public class WorldView : MonoBehaviour
    {
        public Arena arena;
        Transform _props, _units;
        readonly Dictionary<int, GameObject> _minionGo = new Dictionary<int, GameObject>();
        readonly Dictionary<int, GameObject> _structureGo = new Dictionary<int, GameObject>();
        readonly Dictionary<int, Unit> _structureUnit = new Dictionary<int, Unit>();
        readonly Dictionary<int, GameObject> _shotGo = new Dictionary<int, GameObject>();
        readonly List<GameObject> _zoneGo = new List<GameObject>();
        readonly List<MeshRenderer> _zoneMr = new List<MeshRenderer>();
        readonly HashSet<int> _live = new HashSet<int>();
        readonly HashSet<int> _seen = new HashSet<int>();
        Material _zoneMat, _projMat;
        MaterialPropertyBlock _zoneMpb, _projMpb;

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
            _zoneMpb = new MaterialPropertyBlock();
            _projMpb = new MaterialPropertyBlock();

            BuildMap();
            BuildScenery();
            BuildStructures();

            /* 英雄 */
            foreach (var h in arena.heroes)
            {
                var rig = Art.BuildHero(h.def, _units);
                if (rig.polyModel != null) PolyHeroView.Attach(h, rig);
                else HeroView.Attach(h, rig);
                h.height = rig.height;
            }

            var zs = Shader.Find("Sprites/Default");
            if (zs == null) { var zm = Resources.Load<Material>("TapArenaFx"); if (zm != null) zs = zm.shader; }
            _zoneMat = new Material(zs ?? Art.StdShader()) { hideFlags = HideFlags.DontSave };
            _zoneMat.mainTexture = MakeDiscTexture();

            _projMat = Art.Emissive(Color.white, 1.8f);
            _projMat.enableInstancing = false;
            int rc = 0;
            var rs = GetComponentsInChildren<Renderer>(true);
            for (int i = 0; i < rs.Length; i++)
                if (rs[i].enabled && rs[i].gameObject.activeInHierarchy) rc++;
            Debug.Log("[TapArena] renderers=" + rc);
        }

        void BuildMap()
        {
            var ground = ArtPropLibrary.Map("ground");
            if (ground != null)
            {
                ground.transform.SetParent(transform, false);
                ground.transform.localPosition = Vector3.zero;
                var gm = ground.GetComponentInChildren<MeshRenderer>();
                if (gm != null) gm.receiveShadows = true;
            }
            else
            {
                var go = new GameObject("Ground");
                go.transform.SetParent(transform, false);
                var mf = go.AddComponent<MeshFilter>();
                var mr = go.AddComponent<MeshRenderer>();
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
            }

            var water = ArtPropLibrary.Map("water");
            if (water != null)
            {
                water.transform.SetParent(transform, false);
                water.transform.localPosition = Vector3.zero;
            }

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
                ArtPropLibrary.CombineStatic(backdrop);
            }
        }

        void BuildScenery()
        {
            var scenery = new GameObject("Scenery").transform;
            scenery.SetParent(transform, false);
            var quads = new Transform[4];
            for (int i = 0; i < 4; i++)
            {
                var q = new GameObject("Scenery" + i).transform;
                q.SetParent(scenery, false);
                quads[i] = q;
            }
            var rnd = new System.Random(20261101);
            System.Func<float, float, float> rr = (a, b) => a + (float)rnd.NextDouble() * (b - a);

            for (int i = 0; i < 58; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 360f) continue;
                if (Mathf.Abs(p.x - 1500f) < 300f) continue;
                if (Vector3.Distance(p, arena.baseBlue.pos) < 520f) continue;
                if (Vector3.Distance(p, arena.baseRed.pos) < 520f) continue;
                /* 近镜头一侧只用矮树/灌木，远侧用高松剪影。 */
                string name = p.z < 800f
                    ? (i % 3 == 0 ? "round_bush" : "young_pine")
                    : (i % 5 == 0 ? "birch" : i % 5 == 1 ? "maple" : i % 5 == 2 ? "oak" : "tall_pine");
                float s = rr(0.85f, 1.25f);
                if (ArtPropLibrary.Spawn(name, Quad(quads, p), p, s, rr(0f, 360f)) == null)
                    Art.Tree(Quad(quads, p), p, s, i);
            }
            for (int i = 0; i < 30; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 260f || Mathf.Abs(p.x - 1500f) < 240f) continue;
                string name = i % 2 == 0 ? "round_bush" : "fern";
                if (ArtPropLibrary.Spawn(name, Quad(quads, p), p, rr(0.9f, 1.3f), rr(0f, 360f)) == null)
                    Art.Bush(Quad(quads, p), p, rr(0.8f, 1.35f), i);
            }
            for (int i = 0; i < 34; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 190f) continue;
                if (ArtPropLibrary.Spawn("toadstool", Quad(quads, p), p, rr(1.1f, 1.9f), rr(0f, 360f)) == null)
                    Art.Mushroom(Quad(quads, p), p, rr(0.75f, 1.25f),
                        i % 3 == 0 ? new Color(0.85f, 0.45f, 0.42f) : new Color(0.95f, 0.80f, 0.55f));
            }
            for (int i = 0; i < 26; i++)
            {
                Vector3 p = new Vector3(rr(80f, Arena.MapW - 80f), 0f, rr(80f, Arena.MapH - 80f));
                if (DistToLane(p) < 200f) continue;
                string name = i % 7 == 0 ? "rock_spire" : i % 3 == 0 ? "large_boulder" : i % 2 == 0 ? "medium_rock" : "small_rock";
                if (ArtPropLibrary.Spawn(name, Quad(quads, p), p, rr(0.8f, 1.3f), rr(0f, 360f)) == null)
                    Art.Rock(Quad(quads, p), p, rr(0.8f, 1.4f), i);
            }
            for (int i = 0; i < 40; i++)
            {
                Vector3 p = new Vector3(rr(100f, Arena.MapW - 100f), 0f, rr(100f, Arena.MapH - 100f));
                float d = DistToLane(p);
                if (d < 150f || d > 300f) continue;
                string name = i % 4 == 0 ? "wildflower" : "grass_tuft";
                if (ArtPropLibrary.Spawn(name, Quad(quads, p), p, rr(1.0f, 1.6f), rr(0f, 360f)) == null)
                    Art.GrassTuft(Quad(quads, p), p, rr(0.9f, 1.5f), i);
            }

            /* 地标：让地图有方向感 */
            SpawnLandmark(quads, "log_cabin", new Vector3(2540f, 0f, 340f), 0.9f, 24f);
            SpawnLandmark(quads, "lookout_tower", new Vector3(470f, 0f, 1240f), 0.78f, 8f);
            SpawnLandmark(quads, "stone_well", new Vector3(350f, 0f, 980f), 1.0f, 0f);
            SpawnLandmark(quads, "stone_well", new Vector3(2650f, 0f, 620f), 1.0f, 0f);

            /* 兵线两侧的引导物 */
            for (int i = 0; i < 6; i++)
            {
                float x = 500f + i * 400f;
                var p = new Vector3(x, 0f, 930f);
                if (ArtPropLibrary.Spawn("lantern_post", Quad(quads, p), p, 1.0f, 0f) == null)
                    Art.GrassTuft(Quad(quads, p), p, 1.0f, i);
            }
            for (int i = 0; i < 4; i++)
            {
                var p = new Vector3(320f + i * 60f, 0f, 1040f);
                ArtPropLibrary.Spawn("fence", Quad(quads, p), p, 1.0f, 90f);
            }
            SpawnLandmark(quads, "trail_sign", new Vector3(700f, 0f, 980f), 1.0f, 0f);
            SpawnLandmark(quads, "fallen_log", new Vector3(1020f, 0f, 960f), 1.0f, 30f);
            SpawnLandmark(quads, "tree_stump", new Vector3(2040f, 0f, 960f), 1.2f, 0f);

            /* 河边的水草与睡莲 */
            for (int i = 0; i < 8; i++)
            {
                float z = 180f + i * 90f;
                float cx = 1500f + (z - 800f) * 0.16f + Mathf.Sin(z * 0.012f) * 34f;
                Vector3 p = new Vector3(cx + (i % 2 == 0 ? 40f : -50f), 0f, z);
                ArtPropLibrary.Spawn(i % 3 == 0 ? "lily_pad" : "cattail", Quad(quads, p), p,
                    rr(0.9f, 1.3f), rr(0f, 360f));
            }

            /* 基地外圈的蘑菇与灯笼，让水晶祭坛有“森林营地”感 */
            for (int b = 0; b < 2; b++)
            {
                Vector3 c = b == 0 ? arena.baseBlue.pos : arena.baseRed.pos;
                for (int i = 0; i < 6; i++)
                {
                    float a = i / 6f * Mathf.PI * 2f + (b == 0 ? 0.2f : 0.7f);
                    Vector3 p = c + new Vector3(Mathf.Cos(a) * 190f, 0f, Mathf.Sin(a) * 150f);
                    if (DistToLane(p) < 150f) continue;
                    ArtPropLibrary.Spawn("toadstool", Quad(quads, p), p, rr(1.3f, 2.0f), rr(0f, 360f));
                }
                Vector3 lp = c + new Vector3(b == 0 ? -250f : 250f, 0f, 170f);
                ArtPropLibrary.Spawn("lantern_post", Quad(quads, lp), lp, 1.0f, 0f);
            }

            /* 兵线跨河的木桥 */
            var bridgePos = new Vector3(1500f, 0f, 800f);
            if (ArtPropLibrary.Spawn("log_bridge", Quad(quads, bridgePos), bridgePos, 1.1f, 0f) == null)
                Art.Bridge(scenery, new Vector3(1500f, -0.8f, 800f), 0f);

            for (int i = 0; i < 4; i++) ArtPropLibrary.CombineStatic(quads[i]);
        }

        Transform Quad(Transform[] quads, Vector3 p)
        {
            int i = (p.x < Arena.MapW * 0.5f ? 0 : 1) + (p.z < Arena.MapH * 0.5f ? 0 : 2);
            return quads[i];
        }

        void SpawnLandmark(Transform[] quads, string name, Vector3 p, float scale, float yaw)
        {
            if (ArtPropLibrary.Spawn(name, Quad(quads, p), p, scale, yaw) != null) return;
            if (name == "stone_well") Art.Rock(Quad(quads, p), p, 1.2f, 1);
        }

        void BuildStructures()
        {
            foreach (var t in arena.towersBlue) AddStructure(t, true, true);
            foreach (var t in arena.towersRed) AddStructure(t, false, true);
            AddStructure(arena.baseBlue, true, false);
            AddStructure(arena.baseRed, false, false);
        }

        void AddStructure(Unit u, bool blue, bool tower)
        {
            string name = tower
                ? "tower_" + (blue ? "blue" : "red") + "_" + (u.level == 1 ? "inner" : "outer")
                : "crystal_" + (blue ? "blue" : "red");
            var go = ArtPropLibrary.Structure(name, _props, u.pos);
            if (go == null)
                go = tower ? Art.Tower(_props, u.pos, blue, u.level) : Art.Crystal(_props, u.pos, blue);
            _structureGo[u.uid] = go;
            _structureUnit[u.uid] = u;
            if (tower) AddTowerOccluder(go);
            Decor(go, !tower);
        }

        void Decor(GameObject go, bool crystal)
        {
            if (go == null) return;
            var ts = go.GetComponentsInChildren<Transform>(true);
            for (int i = 0; i < ts.Length; i++)
            {
                var t = ts[i];
                string n = t.name.ToLowerInvariant();
                if (crystal && n == "crystal" && t.GetComponent<Spinner>() == null)
                    t.gameObject.AddComponent<Spinner>();
                if ((n.StartsWith("flag") || n == "top_flag") && t.GetComponent<Waver>() == null)
                    t.gameObject.AddComponent<Waver>();
            }
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

            /* 小兵：清理掉已经阵亡/被移除的模型 */
            _live.Clear();
            for (int i = 0; i < arena.minions.Count; i++)
                if (arena.minions[i].alive) _live.Add(arena.minions[i].uid);
            foreach (var kv in _minionGo)
                if (!_live.Contains(kv.Key)) kv.Value.SetActive(false);

            for (int i = 0; i < arena.minions.Count; i++)
            {
                var m = arena.minions[i];
                if (!m.alive) continue;
                if (!_minionGo.TryGetValue(m.uid, out var go) || go == null)
                {
                    go = ArtPropLibrary.Minion(m.team == Team.Blue, _units, m.pos);
                    if (go == null) go = Art.Minion(_units, m.team == Team.Blue);
                    _minionGo[m.uid] = go;
                }
                float hop = Mathf.Abs(Mathf.Sin(m.walkT * 8f)) * (m.moving ? 4.5f : 0f);
                go.transform.position = m.pos + Vector3.up * hop;
                go.transform.rotation = Quaternion.Euler(0f, m.facing >= 0f ? 0f : 180f, 0f);
                float sq = 1f + (m.atkAnim > 0f ? Mathf.Sin((1f - m.atkAnim / 0.22f) * Mathf.PI) * 0.14f : 0f);
                go.transform.localScale = new Vector3(1f / sq, sq, 1f / sq);
                go.SetActive(true);
            }

            /* 塔 / 水晶 存活状态 */
            foreach (var kv in _structureGo)
            {
                var u = _structureUnit.TryGetValue(kv.Key, out var unit) ? unit : null;
                kv.Value.SetActive(u != null && u.alive);
            }

            /* 弹道：按 viewId 绑定，避免列表压缩时串位 */
            _seen.Clear();
            for (int i = 0; i < arena.shots.Count; i++)
            {
                var p = arena.shots[i];
                if (!p.alive) continue;
                _seen.Add(p.viewId);
                if (!_shotGo.TryGetValue(p.viewId, out var go) || go == null)
                {
                    go = Art.Prim(PrimitiveType.Sphere, _units, Vector3.zero,
                        Vector3.one, _projMat);
                    var mr0 = go.GetComponent<MeshRenderer>();
                    mr0.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                    _shotGo[p.viewId] = go;
                }
                go.SetActive(true);
                go.transform.position = p.pos;
                go.transform.localScale = Vector3.one * (p.bubble ? 26f : 14f);
                var mr = go.GetComponent<MeshRenderer>();
                _projMpb.SetColor("_Color", p.color);
                _projMpb.SetColor("_EmissionColor", p.color * 1.8f);
                mr.SetPropertyBlock(_projMpb);
            }
            foreach (var kv in _shotGo)
                if (!_seen.Contains(kv.Key)) kv.Value.SetActive(false);

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
                mr.sharedMaterial = _zoneMat;
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                _zoneGo.Add(g);
                _zoneMr.Add(mr);
            }
            for (int i = 0; i < _zoneGo.Count; i++)
            {
                bool on = i < arena.zones.Count;
                _zoneGo[i].SetActive(on);
                if (!on) continue;
                var z = arena.zones[i];
                _zoneGo[i].transform.position = z.pos + Vector3.up * 2.4f;
                _zoneGo[i].transform.localScale = new Vector3(z.r * 2f, 1f, z.r * 2f);
                float k = 1f - z.t / z.life;
                _zoneMpb.SetColor("_Color", new Color(z.color.r, z.color.g, z.color.b, 0.55f * k));
                _zoneMr[i].SetPropertyBlock(_zoneMpb);
            }
        }

        void AddTowerOccluder(GameObject tower)
        {
            if (tower == null) return;
            var top = new List<Transform>();
            CollectTop(tower.transform, top);
            if (top.Count == 0) return;
            var oc = tower.GetComponent<TowerOccluder>();
            if (oc == null) oc = tower.AddComponent<TowerOccluder>();
            oc.top = top.ToArray();
        }

        void CollectTop(Transform t, List<Transform> top)
        {
            for (int i = 0; i < t.childCount; i++)
            {
                var c = t.GetChild(i);
                if (c.localPosition.y >= 72f) top.Add(c);
                else CollectTop(c, top);
            }
        }
    }

    /// <summary>玩家靠近塔时把蘑菇伞盖平滑缩成小盖，避免挡住角色，同时保留塔的轮廓。</summary>
    public class TowerOccluder : MonoBehaviour
    {
        public Transform[] top;
        public float hideRadius = 215f;
        public float showRadius = 248f;
        public float small = 0.30f;
        public float sink = 26f;
        bool _hidden;
        float _k = 1f;
        Vector3[] _pos;
        Vector3[] _scale;

        void Start()
        {
            _pos = new Vector3[top.Length];
            _scale = new Vector3[top.Length];
            for (int i = 0; i < top.Length; i++)
            {
                if (top[i] == null) continue;
                _pos[i] = top[i].localPosition;
                _scale[i] = top[i].localScale;
            }
        }

        void LateUpdate()
        {
            var a = Arena.I;
            bool hide = false;
            if (a != null && a.player != null)
            {
                float d = Vector3.Distance(a.player.pos, transform.position);
                hide = _hidden ? d < showRadius : d < hideRadius;
            }
            if (hide != _hidden) _hidden = hide;

            float target = hide ? small : 1f;
            _k = Mathf.Lerp(_k, target, 1f - Mathf.Exp(-8f * Time.deltaTime));
            float t = Mathf.InverseLerp(1f, small, _k);
            for (int i = 0; i < top.Length; i++)
            {
                var c = top[i];
                if (c == null) continue;
                c.localScale = _scale[i] * _k;
                c.localPosition = _pos[i] + Vector3.down * (t * sink);
            }
        }
    }
}
