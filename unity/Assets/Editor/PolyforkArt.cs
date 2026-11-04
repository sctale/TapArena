using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace TapArena.EditorTools
{
    /// <summary>
    /// 用游戏里的 Polyfork 模型渲染选人 2D 立绘、卡片 bust 和 HUD 头部头像。
    /// 立绘/bust 带渐变背景，头部保留透明通道。
    /// </summary>
    public static class PolyforkArt
    {
        static Camera cam;
        static Transform artRoot;
        static GameObject backdrop;
        static Texture2D glow;
        static Color glowColor;

        public static void Render(bool exit = true)
        {
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.64f, 0.70f, 0.82f);
            RenderSettings.ambientEquatorColor = new Color(0.54f, 0.54f, 0.50f);
            RenderSettings.ambientGroundColor = new Color(0.30f, 0.28f, 0.25f);
            RenderSettings.fog = false;

            var keyGo = new GameObject("key");
            var key = keyGo.AddComponent<Light>();
            key.type = LightType.Directional;
            key.color = new Color(1f, 0.95f, 0.84f);
            key.intensity = 1.14f;
            key.shadows = LightShadows.None;
            keyGo.transform.rotation = Quaternion.LookRotation(-Art.SunDir);

            var fillGo = new GameObject("fill");
            var fill = fillGo.AddComponent<Light>();
            fill.type = LightType.Directional;
            fill.color = new Color(0.80f, 0.90f, 1f);
            fill.intensity = 0.32f;
            fillGo.transform.rotation = Quaternion.Euler(12f, 38f, 0f);

            var rimGo = new GameObject("rim");
            var rim = rimGo.AddComponent<Light>();
            rim.type = LightType.Directional;
            rim.color = new Color(1f, 0.86f, 0.66f);
            rim.intensity = 0.42f;
            rimGo.transform.rotation = Quaternion.Euler(20f, 205f, 0f);

            var camGo = new GameObject("cam");
            cam = camGo.AddComponent<Camera>();
            cam.fieldOfView = 28f;
            cam.nearClipPlane = 0.5f;
            cam.farClipPlane = 4000f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.06f, 0.13f, 0.11f, 1f);
            cam.allowHDR = false;
            cam.allowMSAA = true;

            Directory.CreateDirectory(Path.GetFullPath("Assets/Resources/Splash"));
            Directory.CreateDirectory(Path.GetFullPath("Assets/Resources/Portraits"));

            var all = HeroDef.All;
            foreach (var d in all)
            {
                string id = d.id.ToString().ToLowerInvariant();
                artRoot = new GameObject("art").transform;
                var rig = Art.BuildHero(d, artRoot);
                rig.root.position = Vector3.zero;
                rig.root.rotation = Quaternion.Euler(0f, 64f, 0f);
                PoseIdle(rig, d, 0.24f);
                var smr = rig.polyModel.GetComponentInChildren<SkinnedMeshRenderer>(true);
                var mat = smr != null ? smr.sharedMaterial : null;
                if (mat != null)
                {
                    mat.color = new Color(1.02f, 1.02f, 1.02f);
                    if (mat.HasProperty("_Outline")) mat.SetFloat("_Outline", 0f);
                    if (mat.HasProperty("_RimStrength")) mat.SetFloat("_RimStrength", 0.14f);
                }

                Physics.SyncTransforms();
                Bounds b = ModelBounds(rig);
                MakeGlow(d);
                MakeBackdrop(b, d);

                /* 768x1152 立绘 */
                FrameFull(b, 768f / 1152f, 1.02f);
                Render(768, 1152, "Assets/Resources/Splash/" + id + "_splash.png", false);

                /* 512x512 卡片 */
                FrameUpper(rig, b, 0.82f);
                Render(512, 512, "Assets/Resources/Splash/" + id + "_bust.png", false);

                /* 256x256 透明头部 */
                FrameHead(rig, b, 1.0f);
                cam.backgroundColor = new Color(0f, 0f, 0f, 0f);
                if (backdrop != null) backdrop.SetActive(false);
                Render(256, 256, "Assets/Resources/Portraits/" + id + "_head.png", true);
                cam.backgroundColor = new Color(0.06f, 0.13f, 0.11f, 1f);
                if (backdrop != null) backdrop.SetActive(true);

                Object.DestroyImmediate(artRoot.gameObject);
            }

            AssetDatabase.Refresh();
            Debug.Log("PFPORTRAIT RESULT=PASS");
            if (exit) EditorApplication.Exit(0);
        }

        static void PoseIdle(Art.Rig rig, HeroDef d, float t)
        {
            var idle = rig.polyIdle;
            if (idle != null) idle.SampleAnimation(rig.polyModel, idle.length * t);
            if (rig.head != null)
                rig.head.localRotation = rig.head.localRotation * Quaternion.Euler(-2f, 12f, 0f);
            if (rig.earL != null)
                rig.earL.localRotation = rig.earL.localRotation * Quaternion.Euler(3f, 0f, 0f);
            if (rig.earR != null)
                rig.earR.localRotation = rig.earR.localRotation * Quaternion.Euler(-2f, 0f, 0f);
            if (rig.shL != null)
                rig.shL.localRotation = rig.shL.localRotation * Quaternion.Euler(-8f, 0f, 0f);
            if (rig.thL != null)
                rig.thL.localRotation = rig.thL.localRotation * Quaternion.Euler(3f, 0f, 0f);
        }

        static Bounds ModelBounds(Art.Rig rig)
        {
            var smr = rig.polyModel.GetComponentInChildren<SkinnedMeshRenderer>(true);
            return smr != null ? smr.bounds : new Bounds(rig.root.position + Vector3.up * rig.height * 0.5f,
                new Vector3(rig.height, rig.height, rig.height));
        }

        static void MakeGlow(HeroDef d)
        {
            if (glow != null) Object.DestroyImmediate(glow);
            const int S = 256;
            glow = new Texture2D(S, S, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            Color edge = new Color(0.07f, 0.15f, 0.12f);
            Color mid = Color.Lerp(edge, d.accent, 0.52f);
            Color core = Color.Lerp(d.accent, new Color(1f, 0.96f, 0.86f), 0.58f);
            var px = new Color[S * S];
            for (int y = 0; y < S; y++)
                for (int x = 0; x < S; x++)
                {
                    float u = (x + 0.5f) / S * 2f - 1f;
                    float v = (y + 0.5f) / S * 2f - 1f;
                    float r = Mathf.Sqrt(u * u * 0.92f + v * v * 0.52f);
                    float halo = Mathf.Pow(Mathf.Clamp01(1f - r * 0.78f), 1.8f);
                    float coreK = Mathf.Pow(Mathf.Clamp01(1f - r * 1.55f), 2.6f);
                    Color c = Color.Lerp(edge, mid, halo);
                    c = Color.Lerp(c, core, coreK * 0.70f);
                    float vign = Mathf.Clamp01(1f - Mathf.Max(Mathf.Abs(u), Mathf.Abs(v)) * 0.22f);
                    px[y * S + x] = new Color(c.r * vign, c.g * vign, c.b * vign, 1f);
                }
            glow.SetPixels(px);
            glow.Apply();
            glowColor = d.accent;
        }

        static void MakeBackdrop(Bounds b, HeroDef d)
        {
            if (backdrop != null) Object.DestroyImmediate(backdrop);
            backdrop = GameObject.CreatePrimitive(PrimitiveType.Quad);
            Object.DestroyImmediate(backdrop.GetComponent<Collider>());
            backdrop.name = "backdrop";
            var sh = Shader.Find("Unlit/Texture");
            var mat = new Material(sh) { hideFlags = HideFlags.DontSave };
            mat.mainTexture = glow;
            backdrop.GetComponent<MeshRenderer>().sharedMaterial = mat;
            backdrop.transform.position = new Vector3(b.center.x, b.center.y, b.max.z + 240f);
        }

        static void FitBackdrop()
        {
            if (backdrop == null) return;
            float dist = Mathf.Abs(cam.transform.position.z - backdrop.transform.position.z);
            float h = 2f * dist * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 1.35f;
            float w = h * cam.aspect * 1.35f;
            backdrop.transform.localScale = new Vector3(w, h, 1f);
            backdrop.transform.rotation = Quaternion.Euler(0f, 0f, 0f);
        }

        static void FrameFull(Bounds b, float aspect, float fit)
        {
            float vFov = 28f;
            cam.fieldOfView = vFov;
            cam.aspect = aspect;
            float hFov = 2f * Mathf.Atan(Mathf.Tan(vFov * 0.5f * Mathf.Deg2Rad) * aspect) * Mathf.Rad2Deg;
            float needH = b.extents.x * 2f * fit;
            float needV = b.extents.y * 2f * fit;
            float distH = needH * 0.5f / Mathf.Tan(hFov * 0.5f * Mathf.Deg2Rad);
            float distV = needV * 0.5f / Mathf.Tan(vFov * 0.5f * Mathf.Deg2Rad);
            float dist = Mathf.Max(distH, distV) + b.extents.z;
            Vector3 aim = b.center + Vector3.up * b.size.y * 0.02f;
            cam.transform.position = new Vector3(aim.x, aim.y + b.size.y * 0.10f, aim.z - dist);
            cam.transform.LookAt(aim);
            FitBackdrop();
        }

        static void FrameUpper(Art.Rig rig, Bounds b, float fit)
        {
            cam.aspect = 1f;
            Vector3 aim = b.center + Vector3.up * b.size.y * 0.08f;
            float size = Mathf.Max(b.size.y * 0.95f, rig.headR * 4.8f);
            float dist = size * 0.5f / Mathf.Tan(14f * Mathf.Deg2Rad) * fit;
            cam.transform.position = new Vector3(aim.x, aim.y + size * 0.04f, aim.z - dist);
            cam.transform.LookAt(aim);
            FitBackdrop();
        }

        static void FrameHead(Art.Rig rig, Bounds b, float fit)
        {
            cam.aspect = 1f;
            Vector3 aim = rig.head != null ? rig.head.position : b.center + Vector3.up * b.extents.y * 0.4f;
            aim += Vector3.up * rig.headR * 0.30f;
            float dist = Mathf.Max(rig.headR * 4.2f, b.size.y * 0.30f) * fit;
            cam.transform.position = new Vector3(aim.x, aim.y + rig.headR * 0.10f, aim.z - dist);
            cam.transform.LookAt(aim);
        }

        static void Render(int w, int h, string file, bool alpha)
        {
            var rt = new RenderTexture(w, h, 24, RenderTextureFormat.ARGB32);
            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            var tex = new Texture2D(w, h, alpha ? TextureFormat.RGBA32 : TextureFormat.RGB24, false);
            tex.ReadPixels(new Rect(0, 0, w, h), 0, 0);
            tex.Apply();
            RenderTexture.active = null;
            cam.targetTexture = null;
            File.WriteAllBytes(Path.GetFullPath(file), tex.EncodeToPNG());
            Object.DestroyImmediate(tex);
            Object.DestroyImmediate(rt);
        }
    }
}
