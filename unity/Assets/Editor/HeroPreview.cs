using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace TapArena.EditorTools
{
    /// <summary>批量预览六位英雄，方便不装 APK 迭代模型。命令行：
    /// Unity.exe -batchmode -projectPath ... -executeMethod TapArena.EditorTools.HeroPreview.Render -quit</summary>
    public static class HeroPreview
    {
        static void RenderTo(Camera cam, int w, int h, string file)
        {
            var rt = new RenderTexture(w, h, 24, RenderTextureFormat.ARGB32);
            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            var tex = new Texture2D(w, h, TextureFormat.RGB24, false);
            tex.ReadPixels(new Rect(0, 0, w, h), 0, 0);
            tex.Apply();
            RenderTexture.active = null;
            cam.targetTexture = null;
            File.WriteAllBytes(Path.GetFullPath(file), tex.EncodeToPNG());
        }

        /// <summary>把实际 3D 模型渲染成选人/头像用的透明 PNG，替掉旧 2D 立绘。</summary>
        public static void RenderPortraits()
        {
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.62f, 0.70f, 0.82f);
            RenderSettings.ambientEquatorColor = new Color(0.52f, 0.58f, 0.50f);
            RenderSettings.ambientGroundColor = new Color(0.30f, 0.34f, 0.28f);
            RenderSettings.fog = false;

            var lampGo = new GameObject("sun");
            var lamp = lampGo.AddComponent<Light>();
            lamp.type = LightType.Directional;
            lamp.color = new Color(1f, 0.96f, 0.88f);
            lamp.intensity = 1.15f;
            lamp.shadows = LightShadows.Soft;
            lamp.shadowStrength = 0.45f;
            lampGo.transform.rotation = Quaternion.LookRotation(-Art.SunDir);

            var rimGo = new GameObject("rim");
            var rim = rimGo.AddComponent<Light>();
            rim.type = LightType.Directional;
            rim.color = new Color(0.72f, 0.86f, 1f);
            rim.intensity = 0.35f;
            rimGo.transform.rotation = Quaternion.Euler(18f, 208f, 0f);

            var camGo = new GameObject("cam");
            var cam = camGo.AddComponent<Camera>();
            cam.fieldOfView = 30f;
            cam.nearClipPlane = 1f;
            cam.farClipPlane = 3000f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0f, 0f, 0f, 0f);

            string dir = Path.GetFullPath("Assets/Resources/Portraits");
            Directory.CreateDirectory(dir);
            var all = HeroDef.All;
            for (int i = 0; i < all.Length; i++)
            {
                var root = new GameObject("portrait").transform;
                var rig = Art.BuildHero(all[i], root);
                rig.root.position = Vector3.zero;
                rig.root.rotation = Quaternion.Euler(0f, 70f, 0f);
                /* 头像是静止帧，给一点自然弯肘/屈膝，别像站军姿 */
                rig.shL.localRotation = Quaternion.Euler(-7f, 0f, 0f);
                rig.shR.localRotation = Quaternion.Euler(7f, 0f, 0f);
                rig.elL.localRotation = Quaternion.Euler(0f, 0f, 12f);
                rig.elR.localRotation = Quaternion.Euler(0f, 0f, 12f);
                rig.knL.localRotation = Quaternion.Euler(0f, 0f, -7f);
                rig.knR.localRotation = Quaternion.Euler(0f, 0f, -4f);
                rig.anL.localRotation = Quaternion.Euler(0f, 0f, 4f);
                rig.anR.localRotation = Quaternion.Euler(0f, 0f, 2f);
                foreach (var l in Object.FindObjectsOfType<CpuLimb>()) l.ForceUpdate();
                float h = all[i].height;
                cam.transform.position = new Vector3(0f, h * 0.90f, -h * 3.55f);
                cam.transform.LookAt(new Vector3(0f, h * 0.70f, 0f));

                var rt = new RenderTexture(512, 640, 24, RenderTextureFormat.ARGB32);
                cam.targetTexture = rt;
                cam.Render();
                RenderTexture.active = rt;
                var tex = new Texture2D(512, 640, TextureFormat.RGBA32, false);
                tex.ReadPixels(new Rect(0, 0, 512, 640), 0, 0);
                tex.Apply();
                RenderTexture.active = null;
                cam.targetTexture = null;
                string id = all[i].id.ToString().ToLowerInvariant();
                File.WriteAllBytes(Path.Combine(dir, id + ".png"), tex.EncodeToPNG());
                Object.DestroyImmediate(tex);
                Object.DestroyImmediate(rt);

                /* 头像特写：HUD 圆形头像与结算页用，脸要够大 */
                cam.fieldOfView = 30f;
                bool longEars = all[i].id == HeroId.Rabbit;
                cam.transform.position = new Vector3(0f, h * 1.02f, -h * (longEars ? 2.50f : 1.95f));
                cam.transform.LookAt(new Vector3(0f, h * (longEars ? 0.98f : 0.95f), 0f));
                var hrt = new RenderTexture(256, 256, 24, RenderTextureFormat.ARGB32);
                cam.targetTexture = hrt;
                cam.Render();
                RenderTexture.active = hrt;
                var htex = new Texture2D(256, 256, TextureFormat.RGBA32, false);
                htex.ReadPixels(new Rect(0, 0, 256, 256), 0, 0);
                htex.Apply();
                RenderTexture.active = null;
                cam.targetTexture = null;
                File.WriteAllBytes(Path.Combine(dir, id + "_head.png"), htex.EncodeToPNG());
                Object.DestroyImmediate(htex);
                Object.DestroyImmediate(hrt);
                Object.DestroyImmediate(root.gameObject);
            }
            AssetDatabase.Refresh();
            Debug.Log("[HeroPreview] wrote 6 portraits to Assets/Resources/Portraits");
        }

        public static void Render()
        {
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.58f, 0.68f, 0.80f);
            RenderSettings.ambientEquatorColor = new Color(0.48f, 0.56f, 0.46f);
            RenderSettings.ambientGroundColor = new Color(0.28f, 0.32f, 0.26f);
            RenderSettings.fog = false;

            var floorMat = new Material(Shader.Find("Sprites/Default"));
            var floor = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            floor.transform.position = new Vector3(0f, -2f, 0f);
            floor.transform.localScale = new Vector3(1600f, 2f, 900f);
            floor.GetComponent<Renderer>().sharedMaterial =
                new Material(Shader.Find("TapArena/Toon")) { color = new Color(0.55f, 0.72f, 0.48f) };
            Object.DestroyImmediate(floor.GetComponent<Collider>());

            var lampGo = new GameObject("sun");
            var lamp = lampGo.AddComponent<Light>();
            lamp.type = LightType.Directional;
            lamp.color = new Color(1f, 0.96f, 0.88f);
            lamp.intensity = 1.15f;
            lamp.shadows = LightShadows.Soft;
            lamp.shadowStrength = 0.5f;
            lampGo.transform.rotation = Quaternion.LookRotation(-Art.SunDir);

            var camGo = new GameObject("cam");
            var cam = camGo.AddComponent<Camera>();
            cam.fieldOfView = 36f;
            cam.nearClipPlane = 1f;
            cam.farClipPlane = 3000f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.62f, 0.76f, 0.83f);
            cam.transform.position = new Vector3(0f, 120f, -620f);
            cam.transform.LookAt(new Vector3(0f, 62f, 0f));

            var root = new GameObject("heroes").transform;
            var all = HeroDef.All;
            for (int i = 0; i < all.Length; i++)
            {
                float x = Mathf.Lerp(-400f, 400f, i / (float)(all.Length - 1));
                var rig = Art.BuildHero(all[i], root);
                rig.root.position = new Vector3(x, 0f, 0f);
                rig.root.rotation = Quaternion.Euler(0f, 90f, 0f);
            }

            var rt = new RenderTexture(1800, 900, 24, RenderTextureFormat.ARGB32);
            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            var tex = new Texture2D(1800, 900, TextureFormat.RGB24, false);
            tex.ReadPixels(new Rect(0, 0, 1800, 900), 0, 0);
            tex.Apply();
            RenderTexture.active = null;
            cam.targetTexture = null;
            File.WriteAllBytes(Path.GetFullPath("preview.png"), tex.EncodeToPNG());

            // 近景：熊（最大只）正面 + 3/4
            root.gameObject.SetActive(false);
            var closeRoot = new GameObject("close").transform;
            var near = Art.BuildHero(HeroDef.All[3], closeRoot);
            near.root.position = Vector3.zero;
            near.root.rotation = Quaternion.Euler(0f, 90f, 0f);
            cam.fieldOfView = 30f;
            float bh = HeroDef.All[3].height;
            cam.transform.position = new Vector3(0f, bh * 0.92f, -bh * 1.85f);
            cam.transform.LookAt(new Vector3(0f, bh * 0.78f, 0f));
            RenderTo(cam, 1000, 1000, "preview_close.png");

            near.root.rotation = Quaternion.Euler(0f, 62f, 0f);
            RenderTo(cam, 1000, 1000, "preview_close34.png");

            // 动作姿态：走路 / 攻击 / 施法（手动驱动骨骼 + 强制蒙皮）
            closeRoot.gameObject.SetActive(false);
            var poseRoot = new GameObject("pose").transform;
            var pr = Art.BuildHero(HeroDef.All[0], poseRoot);
            pr.root.position = Vector3.zero;
            pr.root.rotation = Quaternion.Euler(0f, 72f, 0f);
            float ph = HeroDef.All[0].height;
            cam.fieldOfView = 32f;
            cam.transform.position = new Vector3(0f, ph * 1.0f, -ph * 3.3f);
            cam.transform.LookAt(new Vector3(0f, ph * 0.56f, 0f));

            // walk
            pr.hips.localPosition += new Vector3(0f, -ph * 0.006f, 0f);
            pr.hips.localRotation = Quaternion.Euler(0f, -4f, 0f);
            pr.chest.localRotation = Quaternion.Euler(0f, 5f, -3f);
            pr.thL.localRotation = Quaternion.Euler(0f, 0f, 28f);
            pr.knL.localRotation = Quaternion.Euler(0f, 0f, -36f);
            pr.anL.localRotation = Quaternion.Euler(0f, 0f, 6f);
            pr.thR.localRotation = Quaternion.Euler(0f, 0f, -26f);
            pr.knR.localRotation = Quaternion.Euler(0f, 0f, -4f);
            pr.anR.localRotation = Quaternion.Euler(0f, 0f, 12f);
            pr.shL.localRotation = Quaternion.Euler(4f, 0f, -22f);
            pr.elL.localRotation = Quaternion.Euler(0f, 0f, 15f);
            pr.shR.localRotation = Quaternion.Euler(-4f, 0f, 24f);
            pr.elR.localRotation = Quaternion.Euler(0f, 0f, 20f);
            pr.head.localRotation = Quaternion.Euler(-4f, 18f, 4f);
            foreach (var l in Object.FindObjectsOfType<CpuLimb>()) l.ForceUpdate();
            RenderTo(cam, 1000, 1000, "pose_walk.png");

            // attack
            pr.hips.localRotation = Quaternion.Euler(0f, 12f, 0f);
            pr.chest.localRotation = Quaternion.Euler(0f, -18f, -8f);
            pr.thL.localRotation = Quaternion.Euler(0f, 0f, 6f);
            pr.thR.localRotation = Quaternion.Euler(0f, 0f, -12f);
            pr.shR.localRotation = Quaternion.Euler(-4f, 0f, 96f);
            pr.elR.localRotation = Quaternion.Euler(0f, 0f, 8f);
            pr.shL.localRotation = Quaternion.Euler(4f, 0f, 30f);
            pr.elL.localRotation = Quaternion.Euler(0f, 0f, 20f);
            pr.head.localRotation = Quaternion.Euler(0f, 6f, -8f);
            foreach (var l in Object.FindObjectsOfType<CpuLimb>()) l.ForceUpdate();
            RenderTo(cam, 1000, 1000, "pose_attack.png");
            Object.DestroyImmediate(poseRoot.gameObject);

            // 每位英雄一张头部特写
            Object.DestroyImmediate(closeRoot.gameObject);
            for (int i = 0; i < all.Length; i++)
            {
                var r2 = new GameObject("face").transform;
                var fr = Art.BuildHero(all[i], r2);
                fr.root.position = Vector3.zero;
                fr.root.rotation = Quaternion.Euler(0f, 90f, 0f);
                float hh = all[i].height;
                cam.fieldOfView = 30f;
                cam.transform.position = new Vector3(0f, hh * 1.0f, -hh * 1.35f);
                cam.transform.LookAt(new Vector3(0f, hh * 0.93f, 0f));
                RenderTo(cam, 640, 640, "face_" + all[i].id.ToString().ToLowerInvariant() + ".png");
                Object.DestroyImmediate(r2.gameObject);
            }

            Debug.Log("[HeroPreview] wrote preview.png / close / faces");
        }
    }
}
