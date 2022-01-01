using UnityEngine;
using UnityEngine.Rendering;

public partial class CustomRenderPipeline : RenderPipeline
{
    private bool _allowHDR;
    
    private bool useDynamicBatching, useGPUInstancing,useLightsPerObject;

    //这里Camera Renderer大致相当于URP的scriptable renderer
    CameraRenderer _renderer = new CameraRenderer();

    private ShadowSettings _shadowSettings;

    private PostFXSettings _postFxSettings;
    public CustomRenderPipeline(bool allowHDR, bool useDynamicBatching,bool useGpuInstancing,bool useSRPBatcher,bool useLightsPerObject,ShadowSettings shadowSettings,PostFXSettings postFxSettings)
    {
        this._allowHDR = allowHDR;
        _postFxSettings = postFxSettings;
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGpuInstancing;
        this._shadowSettings = shadowSettings;
        this.useLightsPerObject = useLightsPerObject;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        //最终颜色已经应用了光源的强度，但是默认情况下Unity不会将其转换为线性空间。我们必须将GraphicsSettings.lightsUseLinearIntensity设置为true，
        GraphicsSettings.lightsUseLinearIntensity = true;
        InitializeForEditor();
    }
    
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach (var camera in cameras)
        {
            _renderer.Render(context,camera,_allowHDR,useDynamicBatching,useGPUInstancing,useLightsPerObject,_shadowSettings,_postFxSettings);
        }
    }
}
