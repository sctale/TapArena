#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace TapArena.EditorTools
{
    /// <summary>
    /// CLI 构建入口。场景不用手工保存：运行时由 Boot 自举整个世界，
    /// 所以这里只要一个空场景 + 正确的 PlayerSettings 就能出包。
    /// 用法：
    ///   Unity.exe -batchmode -quit -projectPath &lt;proj&gt; -buildTarget Android \
    ///     -executeMethod TapArena.EditorTools.BuildScript.BuildAndroid
    /// </summary>
    public static class BuildScript
    {
        const string ScenePath = "Assets/Scenes/Main.unity";
        const string Version = "3.0.0";

        /// <summary>
        /// headless 下 Unity 会把 Gradle 的 JVM 堆算成 0（-Xmx0m）直接崩，
        /// 所以正式出包走"导出 Gradle 工程 → 外部 gradlew 构建"这条路。
        /// </summary>
        [MenuItem("TapArena/Export Android Gradle Project")]
        public static void ExportAndroidProject()
        {
            EnsureScene();
            ConfigurePlayer();
            ConfigureAndroidTools();

            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;
            const string outDir = "Builds/AndroidProject";
            Directory.CreateDirectory(outDir);
            var opts = new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = outDir,
                target = BuildTarget.Android,
                options = BuildOptions.None,
            };
            var report = BuildPipeline.BuildPlayer(opts);
            Debug.Log($"[TapArena] EXPORT_RESULT={report.summary.result} errors={report.summary.totalErrors} dir={outDir}");
            if (Application.isBatchMode)
                EditorApplication.Exit(report.summary.result == BuildResult.Succeeded ? 0 : 1);
        }

        [MenuItem("TapArena/Build Android APK")]
        public static void BuildAndroid()
        {
            var report = Build(BuildTarget.Android, "Builds/TapArena.apk");
            if (Application.isBatchMode)
                EditorApplication.Exit(report.summary.result == BuildResult.Succeeded ? 0 : 1);
        }

        [MenuItem("TapArena/Build Windows")]
        public static void BuildWindows()
        {
            var report = Build(BuildTarget.StandaloneWindows64, "Builds/Windows/TapArena.exe");
            if (Application.isBatchMode)
                EditorApplication.Exit(report.summary.result == BuildResult.Succeeded ? 0 : 1);
        }

        static BuildReport Build(BuildTarget target, string output)
        {
            EnsureScene();
            ConfigurePlayer();
            if (target == BuildTarget.Android) ConfigureAndroidTools();

            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? "Builds");
            var opts = new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = output,
                target = target,
                options = BuildOptions.None,
            };
            var report = BuildPipeline.BuildPlayer(opts);
            Debug.Log($"[TapArena] BUILD_RESULT={report.summary.result} size={report.summary.totalSize} " +
                      $"errors={report.summary.totalErrors} output={output}");
            return report;
        }

        static void EnsureScene()
        {
            if (!File.Exists(ScenePath))
            {
                Directory.CreateDirectory("Assets/Scenes");
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                EditorSceneManager.SaveScene(scene, ScenePath);
                AssetDatabase.Refresh();
                Debug.Log("[TapArena] created scene " + ScenePath);
            }

            var list = new System.Collections.Generic.List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
            if (!list.Exists(s => s.path == ScenePath))
            {
                list.Add(new EditorBuildSettingsScene(ScenePath, true));
                EditorBuildSettings.scenes = list.ToArray();
            }
        }

        static void ConfigureAndroidTools()
        {
            // 换机可复用：优先读环境变量
            string sdk = System.Environment.GetEnvironmentVariable("TAPARENA_ANDROID_SDK")
                         ?? @"C:\Users\HAOHAO\AppData\Local\Android\Sdk";
            string ndk = System.Environment.GetEnvironmentVariable("TAPARENA_ANDROID_NDK")
                         ?? Path.Combine(sdk, "ndk", "27.2.12479018");
            string jdk = System.Environment.GetEnvironmentVariable("TAPARENA_ANDROID_JDK")
                         ?? @"C:\Program Files\Unity\Hub\Editor\6000.3.10f1\Editor\Data\PlaybackEngines\AndroidPlayer\OpenJDK";
            UnityEditor.Android.AndroidExternalToolsSettings.sdkRootPath = sdk;
            UnityEditor.Android.AndroidExternalToolsSettings.ndkRootPath = ndk;
            UnityEditor.Android.AndroidExternalToolsSettings.jdkRootPath = jdk;
            // headless 下 Unity 会把 Gradle JVM 堆算成 0（-Xmx0m）直接起崩
            UnityEditor.Android.AndroidExternalToolsSettings.maxJvmHeapSize = 4096;
            UnityEditor.Android.AndroidExternalToolsSettings.stopGradleDaemonsOnExit = true;
            Debug.Log($"[TapArena] Android tools sdk={sdk} ndk={ndk} jdk={jdk}");
        }

        /// <summary>
        /// UI 全是运行时代码创建，shader 剥离会让 IMGUI/贴图变品红。
        /// 做法：Resources 里放两个 UI 材质按引用带进包，运行时由 Hud 显式赋上。
        /// （不要改 ProjectSettings/GraphicsSettings.asset —— 实测会让批处理编辑器崩溃。）
        /// </summary>
        static void EnsureUiMaterials()
        {
            const string resDir = "Assets/Resources";
            Directory.CreateDirectory(resDir);
            EnsureMat(resDir + "/TapArenaUiText.mat", "UI/Default Font");
            EnsureMat(resDir + "/TapArenaUiImage.mat", "UI/Default");
            EnsureMat(resDir + "/TapArenaBase.mat", "Standard");
            EnsureMat(resDir + "/TapArenaFx.mat", "Sprites/Default");
            EnsureMat(resDir + "/TapArenaGlow.mat", "TapArena/Glow");
            EnsureMat(resDir + "/TapArenaToon.mat", "TapArena/Toon");
            EnsureMat(resDir + "/TapArenaLowPoly.mat", "TapArena/LowPoly");
            EnsureMat(resDir + "/TapArenaSky.mat", "TapArena/Sky");
            AssetDatabase.Refresh();
        }

        static void EnsureMat(string path, string shaderName)
        {
            if (File.Exists(path)) return;
            var sh = Shader.Find(shaderName);
            if (sh == null) { Debug.LogWarning("[TapArena] shader not found: " + shaderName); return; }
            var mat = new Material(sh);
            AssetDatabase.CreateAsset(mat, path);
            Debug.Log("[TapArena] created material " + path);
        }

        static void ConfigurePlayer()
        {
            EnsureUiMaterials();
            ConfigureSigning();

            PlayerSettings.companyName = "sctale";
            PlayerSettings.productName = "萌兽峡谷";
            PlayerSettings.bundleVersion = Version;
            PlayerSettings.Android.bundleVersionCode = 24;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.sctale.taparena");
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel25;
            // Strip Engine Code 会把原生 MonoBehaviour(class 115) 剥掉，IMGUI 每帧建
            // RuntimeTextSettings 会疯狂抛异常；按 Unity 提示关掉引擎裁剪。
            PlayerSettings.stripEngineCode = false;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;
            PlayerSettings.colorSpace = ColorSpace.Linear;
            EditorUserBuildSettings.buildAppBundle = false;

            var appIcon = AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/Art/AppIcon.png");
            if (appIcon != null)
            {
                try
                {
                    var sizes = PlayerSettings.GetIconSizesForTargetGroup(BuildTargetGroup.Android, IconKind.Application);
                    var icons = new Texture2D[sizes.Length];
                    for (int i = 0; i < icons.Length; i++) icons[i] = appIcon;
                    PlayerSettings.SetIconsForTargetGroup(BuildTargetGroup.Android, icons, IconKind.Application);
                    Debug.Log($"[TapArena] app icon set ({icons.Length} slots)");
                }
                catch (System.Exception e)
                {
                    Debug.LogWarning("[TapArena] app icon set failed: " + e.Message);
                }
            }
        }

        /// <summary>
        /// 复用 Web 版那把 keystore（同签名才能覆盖安装）：配置写在仓库根的 keystore.properties。
        /// </summary>
        static void ConfigureSigning()
        {
            try
            {
                string repo = Path.GetFullPath(Path.Combine(Application.dataPath, "..", ".."));
                string props = Path.Combine(repo, "keystore.properties");
                string ks = Path.Combine(repo, "keystore", "taparena-release.keystore");
                if (!File.Exists(props) || !File.Exists(ks))
                {
                    Debug.LogWarning("[TapArena] 没找到 keystore.properties / keystore，将使用调试签名");
                    return;
                }
                string pass = null, alias = null, aliasPass = null;
                foreach (var line in File.ReadAllLines(props))
                {
                    int i = line.IndexOf('=');
                    if (i <= 0) continue;
                    string k = line.Substring(0, i).Trim(), v = line.Substring(i + 1).Trim();
                    if (k == "storePassword") pass = v;
                    else if (k == "keyAlias") alias = v;
                    else if (k == "keyPassword") aliasPass = v;
                }
                PlayerSettings.Android.useCustomKeystore = true;
                PlayerSettings.Android.keystoreName = ks;
                PlayerSettings.Android.keystorePass = pass;
                PlayerSettings.Android.keyaliasName = alias;
                PlayerSettings.Android.keyaliasPass = aliasPass;
                Debug.Log($"[TapArena] 使用 release keystore: {ks} alias={alias}");
            }
            catch (System.Exception e)
            {
                Debug.LogWarning("[TapArena] 签名配置失败：" + e.Message);
            }
        }
    }
}
#endif
