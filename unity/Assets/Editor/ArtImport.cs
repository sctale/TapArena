#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEngine;

namespace TapArena.EditorTools
{
    /// <summary>
    /// 美术资产导入/校验入口。用法：
    ///   Unity.exe -batchmode -quit -projectPath unity \
    ///     -executeMethod TapArena.EditorTools.ArtImport.Run
    /// 它会先套用 FBX 导入设置，再导出 .anim 与 2D 立绘，最后打印预算。
    /// </summary>
    public static class ArtImport
    {
        static readonly string[] Props =
        {
            "tall_pine", "young_pine", "maple", "oak", "birch", "dead_tree",
            "round_bush", "fern", "grass_tuft", "wildflower", "toadstool",
            "medium_rock", "small_rock", "large_boulder", "rock_spire",
            "tree_stump", "fallen_log", "lily_pad", "cattail", "water_blob",
            "log_bridge", "fence", "lantern_post", "trail_sign",
            "log_cabin", "lookout_tower", "stone_well"
        };

        [MenuItem("TapArena/Import Art Assets")]
        public static void Run()
        {
            int ok = 0, fail = 0;
            foreach (var name in Props)
            {
                if (Import("Assets/Resources/PolyforkProps/" + name + ".fbx", true, false)) ok++;
                else fail++;
            }
            foreach (var dir in new[] { "Assets/Resources/Heroes", "Assets/Resources/GameArt/Structures", "Assets/Resources/GameArt/Minions", "Assets/Resources/GameArt/Map", "Assets/Resources/GameArt/Props" })
            {
                if (!Directory.Exists(dir)) continue;
                bool animated = dir.Contains("/Heroes");
                foreach (var f in Directory.GetFiles(dir, "*.fbx"))
                {
                    string p = f.Replace('\\', '/');
                    if (Import(p, false, animated)) ok++;
                    else fail++;
                }
            }

            AssetDatabase.Refresh();
            PolyforkClipExport.Run(false);
            PolyforkArt.Render(false);
            AssetDatabase.SaveAssets();
            Debug.Log($"[ART] RESULT={(fail == 0 ? "PASS" : "FAIL")} ok={ok} fail={fail}");
            if (Application.isBatchMode)
                EditorApplication.Exit(fail == 0 ? 0 : 1);
        }

        static bool Import(string path, bool readable, bool animated)
        {
            var importer = AssetImporter.GetAtPath(path) as ModelImporter;
            if (importer == null)
            {
                Debug.LogError("[ART] missing " + path);
                return false;
            }
            importer.materialImportMode = ModelImporterMaterialImportMode.None;
            importer.importCameras = false;
            importer.importLights = false;
            importer.importBlendShapes = false;
            importer.isReadable = readable;
            importer.meshCompression = ModelImporterMeshCompression.Medium;
            importer.optimizeMesh = true;
            importer.importAnimation = animated;
            if (animated)
            {
                importer.animationType = ModelImporterAnimationType.Generic;
                importer.animationCompression = ModelImporterAnimationCompression.Optimal;
                importer.animationRotationError = 0.5f;
                importer.animationPositionError = 0.5f;
                importer.animationScaleError = 0.5f;
                importer.resampleCurves = true;
            }
            importer.SaveAndReimport();
            var smr = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (smr == null)
            {
                Debug.LogError("[ART] load failed " + path);
                return false;
            }
            return true;
        }
    }
}
#endif
