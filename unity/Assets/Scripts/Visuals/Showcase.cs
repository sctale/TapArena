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

            /* 草地圆盘：两层，边缘不会正好卡在镜头前 */
            var outer = Art.Prim(PrimitiveType.Cylinder, _root, new Vector3(0f, -8f, 0f),
                new Vector3(2800f, 4f, 2180f), Art.MatShared(new Color(0.30f, 0.47f, 0.31f), 0f));
            outer.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var disc = Art.Prim(PrimitiveType.Cylinder, _root, new Vector3(0f, -2f, 0f),
                new Vector3(1900f, 3f, 1500f), Art.MatShared(new Color(0.40f, 0.61f, 0.38f), 0f));
            var mr = disc.GetComponent<MeshRenderer>();
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

            /* 远景山把地平线垫住 */
            Art.Hills(_root, new Vector3(0f, 0f, 0f), 1250f, 1750f, 16, 991, 0.75f);

            /* 六位英雄排成弧形，每人脚下一个小石台，脸朝镜头 */
            var all = HeroDef.All;
            for (int i = 0; i < all.Length; i++)
            {
                float a = Mathf.Lerp(-0.62f, 0.62f, i / (float)(all.Length - 1));
                Vector3 p = new Vector3(Mathf.Sin(a) * 400f, 0f, Mathf.Cos(a) * 300f);
                PrimPodium(p, all[i].accent);
                var rig = Art.BuildHero(all[i], _root);
                rig.root.position = p;
                rig.root.rotation = Quaternion.Euler(0f, 90f + Mathf.Sin(a) * 16f, 0f);
                var u = new Unit
                {
                    heroId = all[i].id, def = all[i], kind = UnitKind.Hero, team = Team.Blue,
                    hp = all[i].hp, maxHp = all[i].hp, pos = p, facing = 1f,
                    radius = all[i].radius, height = all[i].height,
                    atkAnim = 0f, castAnim = 0f, hurtAnim = 0f, walkT = 0f, moving = false,
                };
                var hv = HeroView.Attach(u, rig);
                hv.yawOffset = 90f + Mathf.Sin(a) * 16f;
            }

            /* 两侧的树、蘑菇和花丛 */
            Art.Tree(_root, new Vector3(-760f, 0f, 40f), 1.35f, 0);
            Art.Tree(_root, new Vector3(780f, 0f, 10f), 1.2f, 1);
            Art.Tree(_root, new Vector3(-900f, 0f, 480f), 1.05f, 2);
            Art.Tree(_root, new Vector3(920f, 0f, 430f), 1.0f, 0);
            Art.Mushroom(_root, new Vector3(-420f, 0f, -120f), 1.0f, new Color(0.9f, 0.6f, 0.5f));
            Art.Mushroom(_root, new Vector3(520f, 0f, -120f), 0.85f, new Color(0.95f, 0.8f, 0.55f));
            for (int i = 0; i < 26; i++)
            {
                float a2 = i / 26f * Mathf.PI * 2f;
                var q = new Vector3(Mathf.Cos(a2) * (600f + (i % 4) * 80f), 0f, Mathf.Sin(a2) * (360f + (i % 3) * 50f));
                if (q.z < -300f && Mathf.Abs(q.x) < 700f) continue;
                Art.Bush(_root, q, 0.7f + (i % 3) * 0.12f, i);
            }
            /* 台上撒一些小草丛，画面不空 */
            for (int i = 0; i < 20; i++)
            {
                float a3 = i / 20f * Mathf.PI * 2f + 0.2f;
                var q = new Vector3(Mathf.Cos(a3) * (430f + (i % 3) * 120f), 0f, Mathf.Sin(a3) * (250f + (i % 4) * 70f));
                if (Mathf.Abs(q.x) < 420f && q.z > 100f) continue;
                Art.GrassTuft(_root, q, 0.8f + (i % 3) * 0.25f, i);
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

        void PrimPodium(Vector3 p, Color accent)
        {
            var stone = Art.MatShared(new Color(0.90f, 0.86f, 0.78f), 0.5f);
            var top = Art.Prim(PrimitiveType.Cylinder, _root, p + new Vector3(0f, -3f, 0f),
                new Vector3(150f, 6f, 150f), stone);
            top.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var ring = Art.Prim(PrimitiveType.Cylinder, _root, p + new Vector3(0f, 0.15f, 0f),
                new Vector3(108f, 0.5f, 108f), Art.MatShared(accent, 0f));
            ring.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
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
            cam.transform.position = new Vector3(Mathf.Sin(sway) * 110f, 200f, -455f - Mathf.Cos(sway) * 20f);
            cam.transform.LookAt(new Vector3(-130f, 55f, 200f));
        }
    }
}
