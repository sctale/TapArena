using UnityEngine;

namespace TapArena
{
    /// <summary>全屏泛光/暗角。帧率吃紧时自动停用，不影响可玩性。</summary>
    [RequireComponent(typeof(Camera))]
    public class PostFx : MonoBehaviour
    {
        public Material mat;
        Camera _cam;
        float _acc;
        int _frames;
        bool _on = true;
        int _low;

        void Awake() { _cam = GetComponent<Camera>(); }

        void Update()
        {
            if (!_on || mat == null) return;
            /* 每 2 秒测一次，连续两次低于 44fps 就关掉后处理保流畅 */
            _acc += Time.unscaledDeltaTime;
            _frames++;
            if (_acc >= 2f)
            {
                float fps = _frames / _acc;
                if (fps < 44f)
                {
                    _low++;
                    if (_low >= 2)
                    {
                        _on = false;
                        Debug.Log($"[TapArena] 帧率 {fps:F0}，关闭后处理保流畅");
                    }
                }
                else _low = 0;
                _acc = 0f;
                _frames = 0;
            }
        }

        void OnRenderImage(RenderTexture src, RenderTexture dst)
        {
            if (mat == null || !_on) { Graphics.Blit(src, dst); return; }
            Graphics.Blit(src, dst, mat);
        }
    }

    /// <summary>
    /// 首页/选人界面的 3D 陈列台：草地圆盘 + 六位英雄站一排 + 树。
    /// 用一个独立相机慢慢摇，让选人界面背后是活的画面而不是纯色。
    /// </summary>
    public class Showcase : MonoBehaviour
    {
        public Camera cam;
        Transform _root;
        float _t;

        public static Showcase Create(Transform parent)
        {
            var go = new GameObject("Showcase");
            go.transform.SetParent(parent, false);
            var s = go.AddComponent<Showcase>();
            s.Build();
            return s;
        }

        void Build()
        {
            var camGo = new GameObject("ShowcaseCamera");
            camGo.transform.SetParent(transform, false);
            cam = camGo.AddComponent<Camera>();
            cam.fieldOfView = 38f;
            cam.nearClipPlane = 8f;
            cam.farClipPlane = 6000f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.78f, 0.86f, 0.80f);
            cam.depth = -2;
            cam.enabled = false;
            var post = camGo.AddComponent<PostFx>();
            post.mat = Resources.Load<Material>("TapArenaGlow");

            _root = new GameObject("ShowcaseWorld").transform;
            _root.SetParent(transform, false);

            /* 林间空地：优先用烘焙的苔藓地台，缺失时退回两层草地圆盘 */
            var disc = ArtPropLibrary.Spawn("showcase_ground", _root, Vector3.zero, 1f, 0f);
            if (disc == null)
            {
                var outer = Art.Prim(PrimitiveType.Cylinder, _root, new Vector3(0f, -8f, 0f),
                    new Vector3(2800f, 4f, 2180f), Art.MatShared(new Color(0.30f, 0.47f, 0.31f), 0f));
                outer.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                var inner = Art.Prim(PrimitiveType.Cylinder, _root, new Vector3(0f, -2f, 0f),
                    new Vector3(1900f, 3f, 1500f), Art.MatShared(new Color(0.40f, 0.61f, 0.38f), 0f));
                inner.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            }

            /* 远景山把地平线垫住 */
            Art.Hills(_root, new Vector3(0f, 0f, 0f), 1250f, 1750f, 16, 991, 0.75f);

            /* 六位英雄站在苔藓土丘上，脸朝镜头 */
            var all = HeroDef.All;
            for (int i = 0; i < all.Length; i++)
            {
                float a = Mathf.Lerp(-0.62f, 0.62f, i / (float)(all.Length - 1));
                Vector3 p = new Vector3(Mathf.Sin(a) * 360f, 30f, Mathf.Cos(a) * 300f);
                SpawnMound(new Vector3(p.x, 0f, p.z));
                var rig = Art.BuildHero(all[i], _root);
                rig.root.position = p;
                rig.root.rotation = Quaternion.Euler(0f, 90f + Mathf.Sin(a) * 16f, 0f);
                var u = new Unit
                {
                    uid = i + 1, heroId = all[i].id, def = all[i], kind = UnitKind.Hero, team = Team.Blue,
                    hp = all[i].hp, maxHp = all[i].hp, pos = p, facing = 1f,
                    radius = all[i].radius, height = all[i].height,
                    atkAnim = 0f, castAnim = 0f, hurtAnim = 0f, walkT = 0f, moving = false,
                };
                if (rig.polyModel != null)
                {
                    var pv = PolyHeroView.Attach(u, rig);
                    pv.yawOffset = 90f + Mathf.Sin(a) * 16f;
                }
                else
                {
                    var hv = HeroView.Attach(u, rig);
                    hv.yawOffset = 90f + Mathf.Sin(a) * 16f;
                }
            }

            /* 背景树线 + 近景灌木/灯笼/井 */
            HomeProp("tall_pine", new Vector3(-760f, 0f, 640f), 1.15f, 0f);
            HomeProp("tall_pine", new Vector3(780f, 0f, 680f), 1.0f, 0f);
            HomeProp("birch", new Vector3(-980f, 0f, 520f), 1.0f, 0f);
            HomeProp("maple", new Vector3(960f, 0f, 500f), 1.0f, 0f);
            HomeProp("log_cabin", new Vector3(-1080f, 0f, 820f), 0.85f, 20f);
            HomeProp("stone_well", new Vector3(-520f, 0f, 90f), 1.0f, 0f);
            HomeProp("lantern_post", new Vector3(-230f, 0f, 80f), 1.0f, 0f);
            HomeProp("lantern_post", new Vector3(260f, 0f, 90f), 1.0f, 0f);
            for (int i = 0; i < 18; i++)
            {
                float a2 = i / 18f * Mathf.PI * 2f;
                var q = new Vector3(Mathf.Cos(a2) * (620f + (i % 4) * 70f), 0f, Mathf.Sin(a2) * (380f + (i % 3) * 50f));
                if (q.z < -300f && Mathf.Abs(q.x) < 700f) continue;
                HomeProp(i % 3 == 0 ? "fern" : "round_bush", q, 0.9f + (i % 3) * 0.1f, a2 * Mathf.Rad2Deg);
            }
            for (int i = 0; i < 16; i++)
            {
                float a3 = i / 16f * Mathf.PI * 2f + 0.2f;
                var q = new Vector3(Mathf.Cos(a3) * (430f + (i % 3) * 110f), 0f, Mathf.Sin(a3) * (250f + (i % 4) * 60f));
                if (Mathf.Abs(q.x) < 420f && q.z > 80f) continue;
                HomeProp(i % 4 == 0 ? "wildflower" : "grass_tuft", q, 1.0f + (i % 3) * 0.2f, a3 * Mathf.Rad2Deg);
            }

            /* 灯光只照陈列台 */
            var lamp = new GameObject("ShowcaseSun");
            lamp.transform.SetParent(transform, false);
            var l = lamp.AddComponent<Light>();
            l.type = LightType.Directional;
            l.color = new Color(1f, 0.96f, 0.86f);
            l.intensity = 1.1f;
            l.shadows = LightShadows.Soft;
            l.shadowStrength = 0.55f;
            lamp.transform.rotation = Quaternion.LookRotation(-Art.SunDir);
            lamp.SetActive(false);
            _lamp = l;
            _lampGo = lamp;
        }

        void SpawnMound(Vector3 p)
        {
            if (ArtPropLibrary.Spawn("moss_mound", _root, p, 1f, Random.Range(0f, 360f)) != null) return;
            var stone = Art.MatShared(new Color(0.34f, 0.52f, 0.30f), 0f);
            Art.Prim(PrimitiveType.Cylinder, _root, p + new Vector3(0f, -4f, 0f),
                new Vector3(140f, 8f, 120f), stone)
                .GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        }

        void HomeProp(string name, Vector3 p, float s, float yaw)
        {
            if (ArtPropLibrary.Spawn(name, _root, p, s, yaw) != null) return;
            if (name.Contains("pine") || name.Contains("birch") || name.Contains("maple"))
                Art.Tree(_root, p, s, 0);
            else if (name.Contains("bush") || name.Contains("fern"))
                Art.Bush(_root, p, s, 0);
            else if (name.Contains("grass") || name.Contains("flower"))
                Art.GrassTuft(_root, p, s, 0);
        }

        Light _lamp;
        GameObject _lampGo;

        public void SetVisible(bool on)
        {
            cam.enabled = on;
            _lampGo.SetActive(on);
            _root.gameObject.SetActive(on);
        }

        void LateUpdate()
        {
            if (!cam.enabled) return;
            _t += Time.unscaledDeltaTime;
            float sway = Mathf.Sin(_t * 0.22f) * 0.16f;
            cam.transform.position = new Vector3(Mathf.Sin(sway) * 90f, 196f, -405f - Mathf.Cos(sway) * 18f);
            cam.transform.LookAt(new Vector3(-20f, 55f, 200f));
        }
    }
}
