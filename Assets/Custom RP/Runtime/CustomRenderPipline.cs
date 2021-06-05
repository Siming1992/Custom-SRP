using UnityEngine;
using UnityEngine.Rendering;

public class CustomRenderPipline : RenderPipeline
{
    private bool useDynamicBatching, useGPUInstancing;

    //这里Camera Renderer大致相当于URP的scriptable renderer
    CameraRenderer _renderer = new CameraRenderer();

    private ShadowSettings _shadowSettings;
    
    public CustomRenderPipline(bool useDynamicBatching,bool useGpuInstancing,bool useSRPBatcher,ShadowSettings shadowSettings)
    {
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGpuInstancing;
        _shadowSettings = shadowSettings;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        //最终颜色已经应用了光源的强度，但是默认情况下Unity不会将其转换为线性空间。我们必须将GraphicsSettings.lightsUseLinearIntensity设置为true，
        GraphicsSettings.lightsUseLinearIntensity = true;
    }
    
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach (var camera in cameras)
        {
            _renderer.Render(context,camera,useDynamicBatching,useGPUInstancing,_shadowSettings);
        }
    }
}
