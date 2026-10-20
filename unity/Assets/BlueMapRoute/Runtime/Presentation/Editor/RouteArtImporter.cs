using UnityEditor;using UnityEngine;
namespace BlueMapMigration.Editor
{
    // The original route capture PNGs contain premultiplied RGB. Preserve every
    // byte: default platform compression or transparent RGB bleeding changes it.
    public sealed class RouteArtImporter:AssetPostprocessor
    {
        private void OnPreprocessTexture()
        {
            if(!assetPath.StartsWith("Assets/BlueMapRoute/Runtime/Presentation/Resources/BlueMapRouteArt/",System.StringComparison.Ordinal))return;
            var importer=(TextureImporter)assetImporter;
            importer.textureType=TextureImporterType.Default;importer.sRGBTexture=true;importer.isReadable=true;
            importer.mipmapEnabled=false;importer.filterMode=FilterMode.Point;importer.wrapMode=TextureWrapMode.Clamp;
            importer.npotScale=TextureImporterNPOTScale.None;importer.alphaIsTransparency=false;importer.alphaSource=TextureImporterAlphaSource.FromInput;
            importer.maxTextureSize=8192;importer.textureCompression=TextureImporterCompression.Uncompressed;
            var platform=importer.GetDefaultPlatformTextureSettings();platform.format=TextureImporterFormat.RGBA32;platform.textureCompression=TextureImporterCompression.Uncompressed;platform.maxTextureSize=8192;importer.SetPlatformTextureSettings(platform);
            importer.SetPlatformTextureSettings(new TextureImporterPlatformSettings{name="Standalone",overridden=true,format=TextureImporterFormat.RGBA32,textureCompression=TextureImporterCompression.Uncompressed,maxTextureSize=8192});
        }
    }
}
