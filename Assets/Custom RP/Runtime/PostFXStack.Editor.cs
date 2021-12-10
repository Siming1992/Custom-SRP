using UnityEngine;
using UnityEditor;

public partial class PostFXStack
{
    partial void ApplySceneViewState();
#if UNITY_EDITOR
    partial void ApplySceneViewState()
    {
        if (_camera.cameraType == CameraType.SceneView && !SceneView.currentDrawingSceneView.sceneViewState.showImageEffects)
        {
            _postFxSettings = null;
        }
    }
#endif
}
