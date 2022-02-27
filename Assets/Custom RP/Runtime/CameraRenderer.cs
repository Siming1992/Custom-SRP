using System;
using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    private ScriptableRenderContext _context;
    private Camera _camera;

    static ShaderTagId _unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
    static ShaderTagId _litShaderTagId = new ShaderTagId("CustomLit");
    static CameraSettings _defaultCameraSettings = new CameraSettings();

    private static int _frameBufferId = Shader.PropertyToID("_CameraFrameBuffer");

    //上下文会延迟实际的渲染，直到我们提交它为止。
    //在此之前，我们对其进行配置并向其添加命令以供后续的执行。某些任务（例如绘制天空盒）提供了专属方法，但其他命令则必须通过单独的命令缓冲区（command buffer）间接执行。我们需要用这样的缓冲区来绘制场景中的其他几何图形。
    //给缓冲区起一个名字，以便我们在frame debugger中识别它。
    private const string _bufferName = "Siming Render Camera";

    //某些任务（例如绘制天空盒）提供了专属方法，但其他命令则必须通过单独的命令缓冲区（command buffer）间接执行。
    private CommandBuffer _buffer = new CommandBuffer
    {
        name = _bufferName,
    };

    Lighting _lighting = new Lighting();

    PostFXStack _postFxStack = new PostFXStack();

    private bool _useHDR;
    public void Render(ScriptableRenderContext context, Camera camera, bool allowHDR, bool useDynamicBatching, bool useGpuInstancing, bool useLightsPerObject, ShadowSettings shadowSettings, PostFXSettings postFXSettings, int colorLUTResolution)
    {
        _context = context;
        _camera = camera;

        var crpCamera = camera.GetComponent<CustomRenderPipelineCamera>();
        CameraSettings cameraSettings = crpCamera ? crpCamera.Settings : _defaultCameraSettings;

        if (cameraSettings.overridePostFX)
            postFXSettings = cameraSettings.postFXSettings;

        PrepareBuffer();
        //因为是给场景添加几何体，所以需在裁剪之前完成
        PrepareForSceneWindow();
        //在“Render”中的“Setup”之前调用Cull，如果失败则中止
        if (!Cull(shadowSettings._maxDistance))
        {
            return;
        }

        _useHDR = allowHDR && camera.allowHDR;

        _buffer.BeginSample(SampleName);
        ExecuteBuffer();
        _lighting.SetUp(context, _cullingResults, shadowSettings, useLightsPerObject,
            cameraSettings.maskLights ? cameraSettings.renderingLayerMask : -1);
        _postFxStack.Setup(context, camera, postFXSettings, _useHDR, colorLUTResolution, cameraSettings.finalBlendMode);
        _buffer.EndSample(SampleName);
        Setup();
        DrawVisibleGeometry(useDynamicBatching, useGpuInstancing, useLightsPerObject, cameraSettings.renderingLayerMask);
        DrawUnsupportedShaders();
        DrawGizmosBeforeFX();
        if (_postFxStack.IsActive)
        {
            _postFxStack.Render(_frameBufferId);
        }
        DrawGizmosAfterFX();
        Cleanup();
        Submit();
    }

    private CullingResults _cullingResults;
    bool Cull(float maxShadowDistance)
    {
        if (_camera.TryGetCullingParameters(out ScriptableCullingParameters parameters))
        {
            parameters.shadowDistance = Mathf.Min(maxShadowDistance, _camera.farClipPlane);
            _cullingResults = _context.Cull(ref parameters);
            return true;
        }
        return false;
    }

    // 我们必须设置视图投影矩阵。
    // 此转换矩阵将摄像机的位置和方向（视图矩阵）与摄像机的透视或正投影（投影矩阵）结合在一起。
    // 在着色器中称为unity_MatrixVP，这是绘制几何图形时使用的着色器属性之一。
    // 选择一个Draw Call后，可以在帧调试器的ShaderProperties部分中检查此矩阵。

    //我们必须通过SetupCameraProperties方法将摄像机的属性应用于上下文。
    void Setup()
    {
        _context.SetupCameraProperties(_camera);
        CameraClearFlags flags = _camera.clearFlags;

        if (_postFxStack.IsActive)
        {
            if (flags > CameraClearFlags.Color)
            {
                flags = CameraClearFlags.Color;
            }

            //帧调试器将显示默认的HDR格式为R16G16B16A16_SFloat，这意味着它是RGBA缓冲区，每通道16位，因此每像素64位，是LDR缓冲区大小的两倍。在这种情况下，每个值都是线性空间中的有符号的float，而不是固定为0~1。
            _buffer.GetTemporaryRT(_frameBufferId, _camera.pixelWidth, _camera.pixelHeight, 32, FilterMode.Bilinear,
                _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
            _buffer.SetRenderTarget(_frameBufferId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        }

        //我们在开始自己的样本之前清除多余的嵌套。这样两个相邻的渲染相机示例范围被合并，否则它会显示嵌套在另一级别的Render Camera中。
        _buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth,
            flags == CameraClearFlags.Color,
            flags == CameraClearFlags.Color ? _camera.backgroundColor.linear : Color.clear
            );

        _buffer.BeginSample(SampleName);    //这里设置的名字只会在Profiler中显示，在frame debugger中只会显示CommandBuffer.name(也就是_bufferName:"Siming Render Camera")
        ExecuteBuffer();
    }

    void DrawVisibleGeometry(bool useDynamicBatching, bool useGPUInstancing, bool useLightsPerObject, int renderingLayerMask)
    {
        PerObjectData lightsPerObjectFlag = useLightsPerObject
            ? PerObjectData.LightData | PerObjectData.LightIndices
            : PerObjectData.None;

        var sortingSettings = new SortingSettings(_camera);
        {
            //先渲染不透明物体，SortingCriteria.CommonOpaque会按照从前向后的顺序绘制
            sortingSettings.criteria = SortingCriteria.CommonOpaque;
        }

        var drawingSettings = new DrawingSettings(_unlitShaderTagId, sortingSettings)
        {
            enableDynamicBatching = useDynamicBatching,
            enableInstancing = useGPUInstancing,
            perObjectData = PerObjectData.ReflectionProbes |
                            PerObjectData.Lightmaps | PerObjectData.ShadowMask |
                            PerObjectData.LightProbe | PerObjectData.LightProbeProxyVolume |
                            PerObjectData.OcclusionProbe |    //Unity还将ShadowMask数据烘焙到光探针中，我们将其称为遮挡探针（Occlusion Probes）
                            PerObjectData.OcclusionProbeProxyVolume |
                            lightsPerObjectFlag
        };
        drawingSettings.SetShaderPassName(1, _litShaderTagId);

        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque, renderingLayerMask: (uint)renderingLayerMask);

        _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
        _context.DrawSkybox(_camera);

        //SortingCriteria.CommonTransparent会按照从后往前绘制透明物体
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
        //_context.DrawUIOverlay(_camera);
    }

    void Cleanup()
    {
        _lighting.Cleanup();
        if (_postFxStack.IsActive)
        {
            _buffer.ReleaseTemporaryRT(_frameBufferId);
        }
    }

    //我们向上下文发出的命令都是缓冲的。必须通过在上下文上调用Submit来提交排队的工作才会执行。
    void Submit()
    {
        _buffer.EndSample(SampleName);
        ExecuteBuffer();
        _context.Submit();
    }

    //要执行缓冲区，需以缓冲区为参数在上下文上调用ExecuteCommandBuffer。
    //这会从缓冲区复制命令但并不会清除它，如果要重用它的话，就必须在之后明确地执行该操作。因为执行和清除总是一起完成的，所以添加同时执行这两种方法的方法很方便。
    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
}
