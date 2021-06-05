using UnityEngine;
using UnityEngine.Rendering;


[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")]
public class CustomRenderPiplineAsset : RenderPipelineAsset
{
    [SerializeField]
    bool useDynamicBatching = true, useGPUInstancing = true,useSRPBatcher = true;

    [SerializeField] private ShadowSettings shadowSettings = default;
    //Tips：先重写完再调用，否则创建的是默认的pipline
    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderPipline(useDynamicBatching,useGPUInstancing,useSRPBatcher,shadowSettings);
    }
}
