using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEngine.Profiling;

public partial class CameraRenderer
{
    partial void DrawUnsupportedShaders();
    partial void DrawGizmos();
    partial void PrepareForSceneWindow();
    partial void PrepareBuffer();
    
#if UNITY_EDITOR
    static ShaderTagId[] _legacyShaderTagIds =
    {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM"),
    };
    static Material _errorMaterial;
    private string SampleName { get; set; }

    partial void DrawGizmos()
    {
        if (Handles.ShouldRenderGizmos())
        {
            _context.DrawGizmos(_camera,GizmoSubset.PreImageEffects);
            _context.DrawGizmos(_camera,GizmoSubset.PostImageEffects);
        }
    }

    partial void PrepareForSceneWindow()
    {
        if (_camera.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(_camera);
        }   
    }

    partial void PrepareBuffer()
    {
        Profiler.BeginSample("Editor Only");
        _buffer.name = SampleName = _camera.name;
        Profiler.EndSample();
    }

    partial void DrawUnsupportedShaders()
    {
        if (_errorMaterial == null)
        {
            _errorMaterial = new Material(Shader.Find("Hidden/InternalErrorShader"));
        }
        var drawingSettings = new DrawingSettings(_legacyShaderTagIds[0],new SortingSettings(_camera))
        {
            overrideMaterial = _errorMaterial
        };
        for (int i = 0; i < _legacyShaderTagIds.Length; i++)
        {
            drawingSettings.SetShaderPassName(i,_legacyShaderTagIds[i]);
        }
        var filteringSettings = FilteringSettings.defaultValue;
        
        _context.DrawRenderers(_cullingResults,ref drawingSettings,ref filteringSettings);
    }
#else
    string SampleName = _bufferName;
#endif
}
