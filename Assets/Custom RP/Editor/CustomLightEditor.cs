using UnityEngine;
using UnityEditor;

[CanEditMultipleObjects]    //提供CanEditMultipleObjects，以便与选定的多个光源一起使用
[CustomEditorForRenderPipeline(typeof(Light),typeof(CustomRenderPipelineAsset))]
public class CustomLightEditor : LightEditor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (!settings.lightType.hasMultipleDifferentValues && (LightType)settings.lightType.enumValueIndex == LightType.Spot)
        {
            settings.DrawInnerAndOuterSpotAngle();
            settings.ApplyModifiedProperties();
        }
    }
}
