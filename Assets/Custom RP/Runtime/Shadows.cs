using UnityEngine.Rendering;
using UnityEngine;

public class Shadows
{
    private const string _bufferName = "Shadows";
    private const int maxShadowedDirectionalLightCount = 1;

    private int _ShadowDirectionalLightCount = 0;

    private static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");
    
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
    }
    
    ShadowedDirectionalLight[] _shadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    CommandBuffer _buffer = new CommandBuffer()
    {
        name = _bufferName
    };

    private ScriptableRenderContext _context;
    private CullingResults _cullingResults;
    private ShadowSettings _shadowSettings;

    public void Setup(ScriptableRenderContext context , CullingResults cullingResults , ShadowSettings shadowSettings)
    {
        _context = context;
        _cullingResults = cullingResults;
        _shadowSettings = shadowSettings;
        _ShadowDirectionalLightCount = 0;
    }

    public void ReserveDirectionalShadows(Light light,int visibleLightIndex)
    {
        if (_ShadowDirectionalLightCount < maxShadowedDirectionalLightCount                 //如果还有空间，存储灯光的课件索引兵增加技术
            && light.shadows != LightShadows.None && light.shadowStrength > 0f              //阴影只能保留给有阴影的灯光，如果灯光的阴影模式设置为None或者强度为零，则忽略
            && _cullingResults.GetShadowCasterBounds(visibleLightIndex,out Bounds b))       //除了以上两点，可见光最终可能不会影响任何投射阴影的对象，这可能是因为他们没有配置，或者是因为光线仅影响了超出最大阴影距离的对象，我们可以通过在剔除结果上调用GetShadowCasterBounds以获得可见光索引来进行检查。它具有边界的第二个输出参数（我们不需要），并返回边界是否有效。如果不是，则没有阴影可渲染，因此应将其忽略。
        {
            _shadowedDirectionalLights[_ShadowDirectionalLightCount++] 
                = new ShadowedDirectionalLight()
                {
                    visibleLightIndex = visibleLightIndex
                };
        }
    }

    public void Render()
    {
        if (_ShadowDirectionalLightCount > 0 )
        {
            RenderDirectionalShadows();
        }
    }

    void RenderDirectionalShadows()
    {
        int atlasSize = (int)_shadowSettings._directional.atlasSize;
        _buffer.GetTemporaryRT(dirShadowAtlasId,atlasSize,atlasSize,
        32,FilterMode.Bilinear,RenderTextureFormat.Shadowmap
        );
        _buffer.SetRenderTarget(dirShadowAtlasId,RenderBufferLoadAction.DontCare,RenderBufferStoreAction.Store);
        _buffer.ClearRenderTarget(true,false,Color.clear);
        _buffer.BeginSample(_bufferName);
        ExecuteBuffer();
        for (int i = 0; i < _ShadowDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i,atlasSize);
        }
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows(int index,int tileSize)
    {
        ShadowedDirectionalLight light = _shadowedDirectionalLights[index];
        
        var shadowSetting = new ShadowDrawingSettings(_cullingResults,light.visibleLightIndex);
        _cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
            light.visibleLightIndex,0,1,Vector3.zero, tileSize,0f,
            out Matrix4x4 viewMatrix,out Matrix4x4 projectionMatrix,
            out ShadowSplitData splitData
            );
        shadowSetting.splitData = splitData;
        _buffer.SetViewProjectionMatrices(viewMatrix,projectionMatrix);
        ExecuteBuffer();
        _context.DrawShadows(ref shadowSetting);    //DrawShadows仅渲染有ShadowCaster pass的材质
    }

    public void Cleanup()
    {
        if (_ShadowDirectionalLightCount > 0)
        {
            _buffer.ReleaseTemporaryRT(dirShadowAtlasId);
            ExecuteBuffer();
        }
    }

    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
}
