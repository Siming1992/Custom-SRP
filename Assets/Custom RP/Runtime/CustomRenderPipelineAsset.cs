using UnityEngine;
using UnityEngine.Rendering;


[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset
{
    [SerializeField] private bool allowHDR;
    
    [SerializeField]
    bool useDynamicBatching = true, useGPUInstancing = true,useSRPBatcher = true,useLightsPerObject = true;

    [SerializeField] private ShadowSettings shadowSettings = default;

    [SerializeField] private PostFXSettings _postFxSettings = default;
    //Tips：先重写完再调用，否则创建的是默认的pipline
    
    public enum ColorLUTResolution { _16 = 16, _32 = 32, _64 = 64 }
    [SerializeField]
    ColorLUTResolution colorLUTResolution = ColorLUTResolution._32;
    
    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderPipeline(allowHDR, useDynamicBatching, useGPUInstancing, useSRPBatcher,
            useLightsPerObject, shadowSettings, _postFxSettings, (int) colorLUTResolution);
    }
}
