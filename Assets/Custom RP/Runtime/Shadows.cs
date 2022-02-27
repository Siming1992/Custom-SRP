using UnityEngine.Rendering;
using UnityEngine;

public class Shadows
{
    private const string _bufferName = "Shadows";
    private const int maxShadowedDirectionalLightCount = 4;
    private const int maxShadowedOtherLightCount = 16;
    private const int maxCascades = 4;

    private int _ShadowDirectionalLightCount = 0;
    private int _ShadowOtherLightCount = 0;

    private static string[] _directionalFilterKeywords =
    {
        "_DIRECTIONAL_PCF3",
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };

    private static string[] _otherFilterKeywords =
    {
        "_OTHER_PCF3",
        "_OTHER_PCF5",
        "_OTHER_PCF7",
    };

    private static string[] _cascadeBlendKeywords =
    {
        "_CASCADE_BLEND_SOFT",
        "_CASCADE_BLEND_DITHER"
    };

    private static int _dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");
    private static int _dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");
    private static int _otherShadowAtlasId = Shader.PropertyToID("_OtherShadowAtlas");
    private static int _otherShadowMatricesId = Shader.PropertyToID("_OtherShadowMatrices");
    private static int _otherShadowTilesId = Shader.PropertyToID("_OtherShadowTiles");
    private static int _cascadeCountId = Shader.PropertyToID("_CascadeCount");
    private static int _cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres");
    private static int _shadowAtlasSizeID = Shader.PropertyToID("_ShadowAtlasSize");
    private static int _cascadeDataId = Shader.PropertyToID("_CascadeData");
    private static int _shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");
    private static int _shadowPancakingId = Shader.PropertyToID("_ShadowPancaking");
    
    static Vector4[] _cascadeCullingSpheres = new Vector4[maxCascades];
    static Vector4[] _cascadeData = new Vector4[maxCascades];
    static Vector4[] _otherShadowTiles = new Vector4[maxShadowedOtherLightCount];
    static Matrix4x4[] _dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];
    static Matrix4x4[] _otherShadowMatrices = new Matrix4x4[maxShadowedOtherLightCount];

    private static string[] _shadowMaskKeywords =
    {
        "_SHADOW_MASK_ALWAYS",
        "_SHADOW_MASK_DISTANCE",
    };

    private bool useShadowMask;
    
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
        public float slopeScaleBias;
        public float nearPlaneOffset;
    }
    
    ShadowedDirectionalLight[] _shadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    struct ShadowedOtherLight
    {
        public int visibleLightIndex;
        public float slopeScaleBias;
        public float normalBias;
        public bool isPoint;
    }
    
    ShadowedOtherLight[] _shadowedOtherLights = new ShadowedOtherLight[maxShadowedOtherLightCount];
    
    CommandBuffer _buffer = new CommandBuffer()
    {
        name = _bufferName
    };

    private ScriptableRenderContext _context;
    private CullingResults _cullingResults;
    private ShadowSettings _shadowSettings;
    private Vector4 _atlasSizes;
    public void Setup(ScriptableRenderContext context , CullingResults cullingResults , ShadowSettings shadowSettings)
    {
        _context = context;
        _cullingResults = cullingResults;
        _shadowSettings = shadowSettings;
        _ShadowDirectionalLightCount = 0;
        _ShadowOtherLightCount = 0;
        
        useShadowMask = false;
    }

    public Vector4 ReserveDirectionalShadows(Light light,int visibleLightIndex)
    {
        if (_ShadowDirectionalLightCount < maxShadowedDirectionalLightCount                 //如果还有空间，存储灯光的课件索引并增加计数
            && light.shadows != LightShadows.None && light.shadowStrength > 0f              //阴影只能保留给有阴影的灯光，如果灯光的阴影模式设置为None或者强度为零，则忽略
            /* && _cullingResults.GetShadowCasterBounds(visibleLightIndex,out Bounds b) */)       //除了以上两点，可见光最终可能不会影响任何投射阴影的对象，这可能是因为他们没有配置，或者是因为光线仅影响了超出最大阴影距离的对象，我们可以通过在剔除结果上调用GetShadowCasterBounds以获得可见光索引来进行检查。它具有边界的第二个输出参数（我们不需要），并返回边界是否有效。如果不是，则没有阴影可渲染，因此应将其忽略。
        {
            float maskChannel = -1;
            LightBakingOutput lightBaking = light.bakingOutput;
            //如果遇到其光照贴图烘焙类型设置为“mixed ”且其混合照明模式设置为“shadow mask”的光源，则说明我们正在使用阴影遮罩。
            if (lightBaking.lightmapBakeType == LightmapBakeType.Mixed && lightBaking.mixedLightingMode == MixedLightingMode.Shadowmask)
            {
                useShadowMask = true;
                maskChannel = lightBaking.occlusionMaskChannel;
            }

            if (!_cullingResults.GetShadowCasterBounds(visibleLightIndex,out Bounds b))
            {
                return new Vector4(-light.shadowStrength,0f,0f,maskChannel);
            }
            
            _shadowedDirectionalLights[_ShadowDirectionalLightCount] 
                = new ShadowedDirectionalLight()
                {
                    visibleLightIndex = visibleLightIndex,
                    slopeScaleBias = light.shadowBias,            //请记住，我们对这些灯光设置的解释与其原始目的有所不同。它们曾经是剪辑空间深度偏差和世界空间收缩法线偏差。因此，当你创建新光源时，除非调整偏差，否则你会得到严重的Peter-Panning。
                    nearPlaneOffset = light.shadowNearPlane
                };
            return new Vector4(light.shadowStrength,
                _shadowSettings._directional.cascadeCount * _ShadowDirectionalLightCount++,light.shadowBias,maskChannel
                );
        }
        return new Vector4(0f,0f,0f,-1f);
    }

    public Vector4 ReserveOtherShadows(Light light , int visibleLightIndex)
    {
        if (light.shadows == LightShadows.None || light.shadowStrength <= 0f)
        {
            return new Vector4(0f,0f,0f,-1f);
        }

        float maskChannel = -1f;
        LightBakingOutput lightBaking = light.bakingOutput;
        if (lightBaking.lightmapBakeType == LightmapBakeType.Mixed && lightBaking.mixedLightingMode == MixedLightingMode.Shadowmask)
        {
            useShadowMask = true;
            maskChannel = lightBaking.occlusionMaskChannel;
        }

        bool isPoint = light.type == LightType.Point;
        //点光源的阴影与聚光灯的阴影类似。
        //不同之处在于点光源不限于圆锥体，因此我们需要将它们的阴影渲染到立方体贴图。这是通过分别为立方体的所有六个面渲染阴影来完成的。
        //因此，为了实时阴影的目的，我们将一个点光源视为六个光源。它将占据阴影图集中的六个图块。
        //这意味着我们可以同时支持最多两个点光源的实时阴影，因为它们会占用 16 个可用图块中的 12 个。如果可用的图块少于六个，则点光源无法获得实时阴影。
        int newLightCount = _ShadowOtherLightCount + (isPoint ? 6 : 1);
        
        if (newLightCount >= maxShadowedOtherLightCount || !_cullingResults.GetShadowCasterBounds(visibleLightIndex,out Bounds b))
        {
            return new Vector4(-light.shadowStrength, 0f, 0f, maskChannel);
        }
        _shadowedOtherLights[_ShadowOtherLightCount] = new ShadowedOtherLight()
        {
            visibleLightIndex = visibleLightIndex,
            slopeScaleBias = light.shadowBias,            
            normalBias = light.shadowNormalBias,
            isPoint = isPoint
        };
        Vector4 data = new Vector4(light.shadowStrength, _ShadowOtherLightCount++, isPoint ? 1f : 0f, maskChannel);
        _ShadowOtherLightCount = newLightCount;
        return data;
    }

    public void Render()
    {
        if (_ShadowDirectionalLightCount > 0 )
        {
            RenderDirectionalShadows();
        }
        else
        {
            _buffer.GetTemporaryRT(_dirShadowAtlasId,1,1,32,FilterMode.Point,RenderTextureFormat.Shadowmap);
        }

        if (_ShadowOtherLightCount > 0)
        {
            RenderOtherShadows();
        }
        else
        {
            _buffer.SetGlobalTexture(_otherShadowAtlasId,_dirShadowAtlasId);
        }
        
        _buffer.BeginSample(_bufferName);
        SetKeywords(_shadowMaskKeywords, useShadowMask ? QualitySettings.shadowmaskMode == ShadowmaskMode.Shadowmask ? 0 : 1 : -1);
        
        _buffer.SetGlobalInt(_cascadeCountId,_ShadowDirectionalLightCount > 0 ? _shadowSettings._directional.cascadeCount : 0);
        float f = 1f - _shadowSettings._directional.cascadeFade;
        _buffer.SetGlobalVector(_shadowDistanceFadeId,
            new Vector4(1 / _shadowSettings._maxDistance, 1 / _shadowSettings.distanceFade, 1f / (1f - f * f)));
        _buffer.SetGlobalVector(_shadowAtlasSizeID,_atlasSizes);
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows()
    {
        int atlasSize = (int)_shadowSettings._directional.atlasSize;
        _atlasSizes.x = atlasSize;
        _atlasSizes.y = 1 / atlasSize;
        _buffer.GetTemporaryRT(_dirShadowAtlasId,atlasSize,atlasSize,
        32,FilterMode.Bilinear,RenderTextureFormat.Shadowmap
        );
        _buffer.SetRenderTarget(_dirShadowAtlasId,RenderBufferLoadAction.DontCare,RenderBufferStoreAction.Store);
        _buffer.ClearRenderTarget(true,false,Color.clear);
        _buffer.SetGlobalFloat(_shadowPancakingId,1f);
        _buffer.BeginSample(_bufferName);
        ExecuteBuffer();
        int tiles = _ShadowDirectionalLightCount * _shadowSettings._directional.cascadeCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;
        for (int i = 0; i < _ShadowDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i,split,tileSize);
        }
        _buffer.SetGlobalVectorArray(_cascadeCullingSpheresId,_cascadeCullingSpheres);
        _buffer.SetGlobalVectorArray(_cascadeDataId,_cascadeData);
        _buffer.SetGlobalMatrixArray(_dirShadowMatricesId,_dirShadowMatrices);
        SetKeywords(_directionalFilterKeywords, (int) _shadowSettings._directional.filter - 1);
        SetKeywords(_cascadeBlendKeywords, (int) _shadowSettings._directional.cascadeBlendMode - 1);
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }
    
    void RenderDirectionalShadows(int index,int split,int tileSize)
    {
        ShadowedDirectionalLight light = _shadowedDirectionalLights[index];

        var shadowSetting = new ShadowDrawingSettings(_cullingResults, light.visibleLightIndex){
            useRenderingLayerMaskTest = true
        };

        int cascadeCount = _shadowSettings._directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = _shadowSettings._directional.CascadeRatios;
        
        //ComputeDirectionalShadowMatricesAndCullingPrimitives
//定向光被假定为无限远，没有真实位置。因此，我们要做的是找出与灯光方向匹配的视图和投影矩阵，并为我们提供一个剪辑空间立方体，该立方体与包含可见光阴影的摄像机可见区域重叠。
//这个不用自己去实现，我们可以使用culling results的ComputeDirectionalShadowMatricesAndCullingPrimitives方法为我们完成此工作，并为其传递9个参数。
//第一个参数是可见光指数。接下来的三个参数是两个整数和一个Vector3，它们控制阴影级联。然后是纹理尺寸，我们需要使用平铺尺寸。第六个参数是靠近平面的阴影，我们现在将其忽略并将其设置为零。
//以上这些是输入参数，其余三个是输出参数。首先是视图矩阵，然后是投影矩阵，最后一个参数是ShadowSplitData结构。

        float cullingFactor = Mathf.Max(0f, 0.8f - _shadowSettings._directional.cascadeFade);
        float tileScale = 1f / split;
        
        for (int i = 0; i < cascadeCount; i++)
        {
            _cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex,i,cascadeCount,ratios, tileSize,light.nearPlaneOffset,
                out Matrix4x4 viewMatrix,out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;
            shadowSetting.splitData = splitData;
            if (index == 0)    //我们只需要对第一个光源执行此操作，因为所有光源的级联都是等效的。
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }
            int tileIndex = tileOffset + i;
            _dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix,     //通过将灯光的阴影 投影矩阵和视图矩阵 相乘，可以创建从世界空间到灯光空间的转换矩阵。
                SetTileViewport(tileIndex,split,tileSize),tileScale);    
            _buffer.SetViewProjectionMatrices(viewMatrix,projectionMatrix);
            _buffer.SetGlobalDepthBias(0f,light.slopeScaleBias);
            ExecuteBuffer();
            _context.DrawShadows(ref shadowSetting);    //DrawShadows仅渲染有ShadowCaster pass的材质
            _buffer.SetGlobalDepthBias(0f,0f);
        }
    }

    void RenderOtherShadows()
    {
        int atlasSize = (int)_shadowSettings._other.atlasSize;
        _atlasSizes.z = atlasSize;
        _atlasSizes.w = 1f / atlasSize;
        _buffer.GetTemporaryRT(_otherShadowAtlasId,atlasSize,atlasSize,
            32,FilterMode.Bilinear,RenderTextureFormat.Shadowmap
        );
        _buffer.SetRenderTarget(_otherShadowAtlasId,RenderBufferLoadAction.DontCare,RenderBufferStoreAction.Store);
        _buffer.ClearRenderTarget(true,false,Color.clear);
        _buffer.SetGlobalFloat(_shadowPancakingId,0f);
        _buffer.BeginSample(_bufferName);
        ExecuteBuffer();
        int tiles = _ShadowOtherLightCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;
        for (int i = 0; i < _ShadowOtherLightCount;)
        {
            if (_shadowedOtherLights[i].isPoint)
            {
                RenderPointShadows(i, split, tileSize);
                i += 6;
            }
            else
            {
                RenderSpotShadows(i, split, tileSize);
                i++;
            }
        }
        _buffer.SetGlobalMatrixArray(_otherShadowMatricesId,_otherShadowMatrices);
        _buffer.SetGlobalVectorArray(_otherShadowTilesId,_otherShadowTiles);
        SetKeywords(_otherFilterKeywords, (int) _shadowSettings._other.filter - 1);
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }

    void RenderSpotShadows(int index, int split , int tileSize)
    {
        ShadowedOtherLight light = _shadowedOtherLights[index];
        var shadowSettings = new ShadowDrawingSettings(_cullingResults,light.visibleLightIndex){
            useRenderingLayerMaskTest = true
        };
        _cullingResults.ComputeSpotShadowMatricesAndCullingPrimitives(
            light.visibleLightIndex, out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
            out ShadowSplitData splitData);
        shadowSettings.splitData = splitData;
        float texelSize = 2f / (tileSize * projectionMatrix.m00);
        float filterSize = texelSize * ((float) _shadowSettings._other.filter + 1f);
        float bias = light.normalBias * filterSize * 1.4142136f;
        Vector2 offset = SetTileViewport(index, split, tileSize);
        float tileScale = 1f / split;
        SetOtherTileData(index, offset, tileScale, bias);
        _otherShadowMatrices[index] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix,
            offset, tileScale);
        _buffer.SetViewProjectionMatrices(viewMatrix,projectionMatrix);
        _buffer.SetGlobalDepthBias(0f,light.slopeScaleBias);
        ExecuteBuffer();
        _context.DrawShadows(ref shadowSettings);
        _buffer.SetGlobalDepthBias(0f, 0f);
    }

    void RenderPointShadows(int index, int split , int tileSize)
    {
        ShadowedOtherLight light = _shadowedOtherLights[index];
        var shadowSettings = new ShadowDrawingSettings(_cullingResults, light.visibleLightIndex) {
            useRenderingLayerMaskTest = true
        };
        
        float texelSize = 2f / tileSize;
        float filterSize = texelSize * ((float) _shadowSettings._other.filter + 1f);
        float bias = light.normalBias * filterSize * 1.4142136f;
        float tileScale = 1f / split;
        float fovBias = Mathf.Atan(1f + bias + filterSize) * Mathf.Rad2Deg * 2f - 90f;
        
        for (int i = 0; i < 6; i++)
        {
            _cullingResults.ComputePointShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, (CubemapFace) i, fovBias, out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData);
            viewMatrix.m11 = -viewMatrix.m11;
            viewMatrix.m12 = -viewMatrix.m12;
            viewMatrix.m13 = -viewMatrix.m13;
            shadowSettings.splitData = splitData;
            int tileIndex = index + i;
            Vector2 offset = SetTileViewport(tileIndex, split, tileSize);
            SetOtherTileData(tileIndex, offset, tileScale, bias);
            _otherShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix,
                offset, tileScale);
            _buffer.SetViewProjectionMatrices(viewMatrix,projectionMatrix);
            _buffer.SetGlobalDepthBias(0f,light.slopeScaleBias);
            ExecuteBuffer();
            _context.DrawShadows(ref shadowSettings);
            _buffer.SetGlobalDepthBias(0f, 0f);
        }
    }
    
    void SetOtherTileData(int index,Vector2 offset , float scale , float bias)
    {
        float border = _atlasSizes.w * 0.5f;
        Vector4 data;
        data.x = offset.x * scale + border;
        data.y = offset.y * scale + border;
        data.z = scale - border - border;
        data.w = bias;
        _otherShadowTiles[index] = data;
    }

    void SetKeywords(string[] keywords ,int enabledIndex)
    {
        for (int i = 0; i < keywords.Length; i++)
        {
            if (i == enabledIndex)
            {
                _buffer.EnableShaderKeyword(keywords[i]);
            }
            else
            {
                _buffer.DisableShaderKeyword(keywords[i]);
            }
        }
    }

    void SetCascadeData(int index,Vector4 cullingSphere,float tileSize)
    {
        float texelSize = 2f * cullingSphere.w / tileSize;    //通过将剔除球的直径除以图块大小，可以在SetCascadeData中找到纹理像素的大小。将其存储在级联数据向量的Y分量中。
        float filterSize = texelSize * ((float)_shadowSettings._directional.filter + 1);    //增加过滤器大小会使阴影更平滑，但也会导致粉刺再次出现。我们必须增加正常偏差以匹配过滤器大小。我们可以通过将 texel 大小乘以 1 加上过滤器模式来自动执行此操作
        cullingSphere.w -= filterSize;    //增加采样区域也意味着我们可以在级联的剔除范围之外进行采样。我们可以通过在平方之前将球体的半径减小过滤器大小来避免这种情况。
        cullingSphere.w *= cullingSphere.w;            //我们需要着色器中的球体来检查表面碎片是否位于其中，这可以通过将距球体中心的平方距离与其半径进行比较来实现。因此，让我们存储平方半径，这样就不必在着色器中计算它了。
        _cascadeCullingSpheres[index] = cullingSphere;
        _cascadeData[index] = new Vector4(1f / cullingSphere.w,filterSize * 1.4142136f);    //纹理像素是正方形。在最坏的情况下，我们最终不得不沿着正方形的对角线偏移，因此让我们按√2进行缩放。
    }

    Vector2 SetTileViewport(int index,int split,float tileSize)
    {
        Vector2 offset = new Vector2(index % split , index /split);
        _buffer.SetViewport(new Rect(
            offset.x * tileSize,offset.y * tileSize,tileSize,tileSize
            ));
        return offset;
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m,Vector2 offset , float scale)
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
        _buffer.ReleaseTemporaryRT(_dirShadowAtlasId);
        if (_ShadowOtherLightCount > 0)
        {
            _buffer.ReleaseTemporaryRT(_otherShadowAtlasId);
        }
        ExecuteBuffer();
    }

    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
}

