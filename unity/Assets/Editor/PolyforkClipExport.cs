using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace TapArena.EditorTools
{
    /// <summary>
    /// Polyfork FBX 里的动画不能直接按路径稳定加载，这里把 Idle/Walk/Run
    /// 复制成独立的 .anim 资源，运行时用 Resources.Load 取。
    /// </summary>
    public static class PolyforkClipExport
    {
        static readonly string[] Assets =
        {
            "lion-base", "red-fox-5c3bc0", "forest-rabbit-ea2da0",
            "black-bear-adbdc7", "frog-base", "cat-base"
        };

        public static void Run()
        {
            string clipDir = "Assets/Resources/Polyfork/Clips";
            if (!AssetDatabase.IsValidFolder(clipDir))
                AssetDatabase.CreateFolder("Assets/Resources/Polyfork", "Clips");

            foreach (string asset in Assets)
            {
                string fbx = "Assets/Resources/Polyfork/" + asset + ".fbx";
                var importer = AssetImporter.GetAtPath(fbx) as ModelImporter;
                if (importer == null) { Debug.LogError("PFCLIP missing " + fbx); continue; }
                importer.importAnimation = true;
                importer.animationType = ModelImporterAnimationType.Generic;
                importer.animationCompression = ModelImporterAnimationCompression.Off;
                importer.importCameras = false;
                importer.importLights = false;
                importer.importBlendShapes = false;
                importer.SaveAndReimport();

                var clips = AssetDatabase.LoadAllAssetsAtPath(fbx).OfType<AnimationClip>().ToArray();
                foreach (var wanted in new[] { "Idle", "Walk", "Run" })
                {
                    var clip = clips.FirstOrDefault(c => c.name.EndsWith(wanted) && !c.name.StartsWith("__preview__"))
                               ?? clips.FirstOrDefault(c => c.name.EndsWith(wanted));
                    if (clip == null) { Debug.LogError($"PFCLIP {asset} missing {wanted}"); continue; }
                    string path = $"{clipDir}/{asset}_{wanted.ToLowerInvariant()}.anim";
                    AssetDatabase.DeleteAsset(path);
                    var copy = Object.Instantiate(clip);
                    copy.name = asset + "_" + wanted.ToLowerInvariant();
                    copy.wrapMode = WrapMode.Loop;
                    copy.legacy = true;
                    AssetDatabase.CreateAsset(copy, path);
                    Debug.Log($"PFCLIP {asset} {wanted} {clip.length:F2}s -> {path}");
                }
            }
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("PFCLIP RESULT=PASS");
            EditorApplication.Exit(0);
        }
    }
}
