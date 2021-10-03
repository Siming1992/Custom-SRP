using UnityEngine;
using UnityEngine.Rendering;


[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset
{
    [SerializeField]
    bool useDynamicBatching = true, useGPUInstancing = true,useSRPBatcher = true,useLightsPerObject = true;

    [SerializeField] private ShadowSettings shadowSettings = default;
    //Tips：先重写完再调用，否则创建的是默认的pipline
    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderPipeline(useDynamicBatching,useGPUInstancing,useSRPBatcher,useLightsPerObject,shadowSettings);
    }
}
