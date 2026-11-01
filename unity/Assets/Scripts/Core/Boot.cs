using UnityEngine;

namespace TapArena
{
    /// <summary>启动器：不依赖场景内容，运行时把相机、灯光、UI、世界全部建起来。</summary>
    public class Boot : MonoBehaviour
    {
        public static Boot I;
        public static bool Paused;

        Transform _worldRoot;
        Transform _follow;
        float _overT = -1f;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void StaticInit()
        {
            var go = new GameObject("Boot");
            DontDestroyOnLoad(go);
            go.AddComponent<Boot>();
        }

        void Awake()
        {
            I = this;
            Screen.orientation = ScreenOrientation.LandscapeLeft;
            Screen.autorotateToLandscapeLeft = true;
            Screen.autorotateToLandscapeRight = false;
            Screen.autorotateToPortrait = false;
            Screen.autorotateToPortraitUpsideDown = false;
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            QualitySettings.shadowDistance = 700f;
            QualitySettings.shadowResolution = ShadowResolution.Medium;

            /* 相机 */
            var camGo = new GameObject("MainCamera");
            camGo.transform.SetParent(transform, false);
            var cam = camGo.AddComponent<Camera>();
            cam.fieldOfView = 42f;
            cam.nearClipPlane = 12f;
            cam.farClipPlane = 6000f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.78f, 0.86f, 0.80f);
            cam.allowHDR = true;
            camGo.AddComponent<AudioListener>();
            camGo.AddComponent<CameraRig>();
            var glowMat = Resources.Load<Material>("TapArenaGlow");
            var post = camGo.AddComponent<PostFx>();
            post.mat = glowMat;

            /* 天空穹顶：一直存在，首页陈列台也用它当背景 */
            Art.SkyDome(transform, new Vector3(Arena.MapW * 0.5f, -30f, Arena.MapH * 0.5f), 3400f);

            /* 灯光与氛围 */
            var sunGo = new GameObject("Sun");
            sunGo.transform.SetParent(transform, false);
            var sun = sunGo.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = new Color(1f, 0.94f, 0.80f);
            sun.intensity = 1.15f;
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = 0.66f;
            sun.shadowBias = 0.05f;
            sun.shadowNormalBias = 0.35f;
            sunGo.transform.rotation = Quaternion.LookRotation(-Art.SunDir);
            _sun = sun;

            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.52f, 0.62f, 0.74f);
            RenderSettings.ambientEquatorColor = new Color(0.35f, 0.45f, 0.37f);
            RenderSettings.ambientGroundColor = new Color(0.14f, 0.18f, 0.15f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogColor = new Color(0.80f, 0.86f, 0.78f);
            RenderSettings.fogStartDistance = 1500f;
            RenderSettings.fogEndDistance = 3300f;

            /* 音效 */
            var audio = gameObject.AddComponent<AudioSource>();
            audio.playOnAwake = false;
            audio.spatialBlend = 0f;
            Sfx.Init(audio);

            _worldRoot = new GameObject("World").transform;
            _worldRoot.SetParent(transform, false);
            Fx.Init(_worldRoot);

            gameObject.AddComponent<InputHub>();
            gameObject.AddComponent<Hud>();

            var follow = new GameObject("Follow").transform;
            follow.SetParent(transform, false);
            follow.position = new Vector3(1500f, 0f, 800f);
            _follow = follow;
            CameraRig.I.SetTarget(follow, follow.position);
            CameraRig.I.Snap();

            /* 首页/选人的 3D 陈列台 */
            _showcase = Showcase.Create(transform);
            _showcase.SetVisible(true);
            cam.enabled = false;
            if (_sun != null) _sun.enabled = false;

            GameFlow.screen = UiScreen.Home;
        }

        Light _sun;
        Showcase _showcase;
        float _fpsAcc;
        int _fpsFrames;

        public static void ShowMainWorld(bool on)
        {
            var i = I;
            if (i == null) return;
            if (CameraRig.I != null) CameraRig.I.cam.enabled = on;
            if (i._sun != null) i._sun.enabled = on;
            if (i._showcase != null) i._showcase.SetVisible(!on);
        }

        public static void StartBattle(HeroId hero)
        {
            I.BeginBattle(hero);
        }

        void BeginBattle(HeroId hero)
        {
            ClearWorld();
            GameFlow.picked = hero;
            var arena = Arena.Create(hero, _worldRoot);
            WorldView.Attach(arena);
            _follow.position = arena.player.pos;
            CameraRig.I.SetTarget(_follow, _follow.position);
            CameraRig.I.Snap();
            GameFlow.screen = UiScreen.Battle;
            ShowMainWorld(true);
            _overT = -1f;
            Sfx.Play("cast");
        }

        public static void ToHome()
        {
            I.ClearWorld();
            GameFlow.screen = UiScreen.Home;
            ShowMainWorld(false);
            CameraRig.I.SetTarget(null, new Vector3(1500f, 0f, 800f));
            CameraRig.I.Snap();
        }

        void ClearWorld()
        {
            Arena.I = null;
            for (int i = _worldRoot.childCount - 1; i >= 0; i--)
                Destroy(_worldRoot.GetChild(i).gameObject);
            Fx.Texts.Clear();
            Fx.Banners.Clear();
            Paused = false;
            Time.timeScale = 1f;
        }

        public static void Pause(bool on)
        {
            Paused = on;
            Time.timeScale = on ? 0f : 1f;
        }

        void Update()
        {
            Fx.Step(Time.deltaTime);

            var a = Arena.I;
            if (a == null) return;

            /* 每 5 秒往 logcat 打一行帧率，验收时不用猜 */
            _fpsAcc += Time.unscaledDeltaTime;
            _fpsFrames++;
            if (_fpsAcc >= 5f)
            {
                Debug.Log($"[TapArena] fps={_fpsFrames / _fpsAcc:F1}");
                _fpsAcc = 0f;
                _fpsFrames = 0;
            }

            if (a.player != null)
            {
                Vector3 want = a.player.pos;
                _follow.position = Vector3.Lerp(_follow.position, want, 1f - Mathf.Exp(-14f * Time.deltaTime));
            }

            /* 结束后 2.4 秒切结算，让击杀/爆炸播完 */
            if (a.over && GameFlow.screen == UiScreen.Battle)
            {
                if (_overT < 0f) _overT = 0f;
                _overT += Time.unscaledDeltaTime;
                if (_overT > 2.4f) GameFlow.screen = UiScreen.Result;
            }

            /* Android 返回键 = 暂停 */
            if (Input.GetKeyDown(KeyCode.Escape) && GameFlow.screen == UiScreen.Battle) Pause(!Paused);
        }
    }
}
