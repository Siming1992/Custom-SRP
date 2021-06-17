using UnityEngine.Rendering;
using UnityEngine;

public class Shadows
{
    private const string _bufferName = "Shadows";
    private const int maxShadowedDirectionalLightCount = 4;
    private const int maxCascades = 4;

    private int _ShadowDirectionalLightCount = 0;

    private static int _dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");
    private static int _dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");
    private static int _cascadeCountId = Shader.PropertyToID("_CascadeCount");
    private static int _cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres");
    
    static Vector4[] _cascadeCullingSpheres = new Vector4[maxCascades];
    static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];
    
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

    public Vector2 ReserveDirectionalShadows(Light light,int visibleLightIndex)
    {
        if (_ShadowDirectionalLightCount < maxShadowedDirectionalLightCount                 //如果还有空间，存储灯光的课件索引并增加计数
            && light.shadows != LightShadows.None && light.shadowStrength > 0f              //阴影只能保留给有阴影的灯光，如果灯光的阴影模式设置为None或者强度为零，则忽略
            && _cullingResults.GetShadowCasterBounds(visibleLightIndex,out Bounds b))       //除了以上两点，可见光最终可能不会影响任何投射阴影的对象，这可能是因为他们没有配置，或者是因为光线仅影响了超出最大阴影距离的对象，我们可以通过在剔除结果上调用GetShadowCasterBounds以获得可见光索引来进行检查。它具有边界的第二个输出参数（我们不需要），并返回边界是否有效。如果不是，则没有阴影可渲染，因此应将其忽略。
        {
            _shadowedDirectionalLights[_ShadowDirectionalLightCount] 
                = new ShadowedDirectionalLight()
                {
                    visibleLightIndex = visibleLightIndex
                };
            return new Vector2(light.shadowStrength,
                _shadowSettings._directional.cascadeCount * _ShadowDirectionalLightCount++
                );
        }
        return Vector2.zero;
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
        _buffer.GetTemporaryRT(_dirShadowAtlasId,atlasSize,atlasSize,
        32,FilterMode.Bilinear,RenderTextureFormat.Shadowmap
        );
        _buffer.SetRenderTarget(_dirShadowAtlasId,RenderBufferLoadAction.DontCare,RenderBufferStoreAction.Store);
        _buffer.ClearRenderTarget(true,false,Color.clear);
        _buffer.BeginSample(_bufferName);
        ExecuteBuffer();
        int tiles = _ShadowDirectionalLightCount * _shadowSettings._directional.cascadeCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;
        for (int i = 0; i < _ShadowDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i,split,tileSize);
        }
        _buffer.SetGlobalInt(_cascadeCountId,_shadowSettings._directional.cascadeCount);
        _buffer.SetGlobalVectorArray(_cascadeCullingSpheresId,_cascadeCullingSpheres);
        _buffer.SetGlobalMatrixArray(_dirShadowMatricesId,dirShadowMatrices);
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows(int index,int split,int tileSize)
    {
        ShadowedDirectionalLight light = _shadowedDirectionalLights[index];

        var shadowSetting = new ShadowDrawingSettings(_cullingResults, light.visibleLightIndex);

        int cascadeCount = _shadowSettings._directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = _shadowSettings._directional.CascadeRatios;
        
        //ComputeDirectionalShadowMatricesAndCullingPrimitives
//定向光被假定为无限远，没有真实位置。因此，我们要做的是找出与灯光方向匹配的视图和投影矩阵，并为我们提供一个剪辑空间立方体，该立方体与包含可见光阴影的摄像机可见区域重叠。
//这个不用自己去实现，我们可以使用culling results的ComputeDirectionalShadowMatricesAndCullingPrimitives方法为我们完成此工作，并为其传递9个参数。
//第一个参数是可见光指数。接下来的三个参数是两个整数和一个Vector3，它们控制阴影级联。然后是纹理尺寸，我们需要使用平铺尺寸。第六个参数是靠近平面的阴影，我们现在将其忽略并将其设置为零。
//以上这些是输入参数，其余三个是输出参数。首先是视图矩阵，然后是投影矩阵，最后一个参数是ShadowSplitData结构。

        for (int i = 0; i < cascadeCount; i++)
        {
            _cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex,i,cascadeCount,ratios, tileSize,0f,
                out Matrix4x4 viewMatrix,out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            shadowSetting.splitData = splitData;
            if (index == 0)    //我们只需要对第一个光源执行此操作，因为所有光源的级联都是等效的。
            {
                Vector4 cullingSphere = splitData.cullingSphere;
                cullingSphere.w *= cullingSphere.w;
                _cascadeCullingSpheres[i] = cullingSphere;
            }
            int tileIndex = tileOffset + i;
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix,     //通过将灯光的阴影 投影矩阵和视图矩阵 相乘，可以创建从世界空间到灯光空间的转换矩阵。
                SetTileViewport(tileIndex,split,tileSize),split);    
            _buffer.SetViewProjectionMatrices(viewMatrix,projectionMatrix);
            ExecuteBuffer();
            _context.DrawShadows(ref shadowSetting);    //DrawShadows仅渲染有ShadowCaster pass的材质
        }
    }

    Vector2 SetTileViewport(int index,int split,float tileSize)
    {
        Vector2 offset = new Vector2(index % split , index /split);
        _buffer.SetViewport(new Rect(
            offset.x * tileSize,offset.y * tileSize,tileSize,tileSize
            ));
        return offset;
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m,Vector2 offset , int split)
    {
        /// 为什么Z缓冲区要反转？
        /// 最直观的是，0代表零深度，1代表最大深度。OpenGL就是这样做的。但是由于深度缓存器中精度的方式受到限制以及非线性存储的事实，我们通过反转来更好地利用这些位。其他图形API使用了反向方法。通常，我们不需要担心这个，除非我们明确使用Clip 空间。
        /// 如果当前平台使用反转深度缓冲区（在近平面处，值范围从 1 开始；在远平面处，值范围从 0 开始），则该属性为 true；如果是正常的深度缓冲区（0 为近，1 为远），则该属性为 false。（只读）
        if (SystemInfo.usesReversedZBuffer)    
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }

        float scale = 1f / split;
        /// 在立方体内部定义剪辑空间，其坐标从-1到1，中心为零。
        /// 但是纹理坐标和深度从零到一。我们可以通过将XYZ尺寸缩放和偏移一半来将这种转换烘焙到矩阵中。
        /// 使用矩阵乘法来执行此操作，但是它会导致大量与0之间的乘法，或者不必要的加法运算。因此，让我们直接调整矩阵
        /// 最后，我们需要应用图块的偏移量和比例。
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        
        return m;
    }

    public void Cleanup()
    {
        if (_ShadowDirectionalLightCount > 0)
        {
            _buffer.ReleaseTemporaryRT(_dirShadowAtlasId);
            ExecuteBuffer();
        }
    }

    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
}
