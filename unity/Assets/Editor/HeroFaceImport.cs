using UnityEditor;
using UnityEngine;

namespace TapArena.EditorTools
{
    /// <summary>脸部/身体贴图不要被 DXT 压出色带；球形 UV 需要 Repeat。</summary>
    public class HeroFaceImport : AssetPostprocessor
    {
        void OnPreprocessTexture()
        {
            string path = assetPath.Replace('\\', '/');
            if (!path.Contains("Resources/HeroFaces")) return;
            var ti = (TextureImporter)assetImporter;
            ti.textureType = TextureImporterType.Default;
            ti.sRGBTexture = true;
            ti.mipmapEnabled = true;
            ti.wrapMode = TextureWrapMode.Repeat;
            ti.filterMode = FilterMode.Bilinear;
            ti.textureCompression = TextureImporterCompression.Uncompressed;
            ti.maxTextureSize = 1024;
            ti.alphaSource = TextureImporterAlphaSource.None;
            ti.npotScale = TextureImporterNPOTScale.None;
        }
    }
}
