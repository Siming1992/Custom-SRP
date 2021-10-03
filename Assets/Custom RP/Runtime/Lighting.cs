using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{
    private const int _maxDirLightCount = 4;
    /// <summary>
    /// 与定向灯一样，我们只能支持有限数量的其他灯光。场景通常包含很多不定向的灯光，因为它们的有效范围有限。
    /// 通常，对于任何给定的帧，所有其他光的子集都是可见的。因此，我们可以支持的最大值适用于单个帧，而不适用于整个场景。
    /// 如果最终我们看到的可见光比最大数量更多，则将被忽略掉。Unity会根据重要性对可见光列表进行排序，因此只要可见光不发生变化，哪些灯被忽略就是一致的。
    /// 但是，如果确实发生变化（由于相机移动或其他更改），则可能会导致明显的光过爆的情况。因此，我们不能使用太低的最大值。现在，让我们同时允许多达64个的其他光源，设置为Lighting中的另一个常量。
    /// </summary>
    private const int _maxOtherLightCount = 64;

    private static int _dirLightCountId = Shader.PropertyToID("_DirectionalLightCount");
    private static int _dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors");
    private static int _dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections");
    private static int _dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData");
    
    static Vector4[] _dirLightColors = new Vector4[_maxDirLightCount];
    static Vector4[] _dirLightDirections = new Vector4[_maxDirLightCount];
    static Vector4[] _dirLightShadowData = new Vector4[_maxDirLightCount];

    private static int _otherLightCountId = Shader.PropertyToID("_OtherLightCount");
    private static int _otherLightColorsId = Shader.PropertyToID("_OtherLightColors");
    private static int _otherLightPositionsId = Shader.PropertyToID("_OtherLightPositions");
    private static int _otherLightDirectionsId = Shader.PropertyToID("_OtherLightDirections");
    private static int _otherLightSpotAnglesId = Shader.PropertyToID("_OtherLightSpotAngles");
    private static int _otherLightShadowDataId = Shader.PropertyToID("_OhterLightShadowData");
    
    static Vector4[] _otherLightColors = new Vector4[_maxOtherLightCount];
    static Vector4[] _otherLightPositions = new Vector4[_maxOtherLightCount];
    static Vector4[] _otherLightDirections = new Vector4[_maxOtherLightCount];
    static Vector4[] _otherLightSpotAngles = new Vector4[_maxOtherLightCount];
    static Vector4[] _otherLightShadowData = new Vector4[_maxOtherLightCount];

    private static string lightsPerObjectKeyword = "_LIGHTS_PER_OBJECT";
    
    private const string _bufferName = "Lighting";

    private CommandBuffer _buffer = new CommandBuffer() {name = _bufferName};
    private CullingResults _cullingResults = new CullingResults();
    
    Shadows _shadows = new Shadows();

    public void SetUp(ScriptableRenderContext context,CullingResults cullingResults,ShadowSettings shadowSettings,bool useLightsPerObject)
    {
        _cullingResults = cullingResults;
        _buffer.BeginSample(_bufferName);
        _shadows.Setup(context,cullingResults,shadowSettings);
        SetupLights(useLightsPerObject);
        _shadows.Render();
        _buffer.EndSample(_bufferName);
        context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
    
    void SetupLights (bool useLightsPerObject)
    {
        NativeArray<int> indexMap = useLightsPerObject ? _cullingResults.GetLightIndexMap(Allocator.Temp) : default;
        NativeArray<VisibleLight> visibleLights = _cullingResults.visibleLights;
        int dirLightCount = 0 ,otherLightCount = 0;
        int i;
        for (i = 0; i < visibleLights.Length; i++)
        {
            int newindex = -1;
            VisibleLight visibleLight = visibleLights[i];
            switch (visibleLight.lightType)
            {
                case LightType.Directional:
                    if (dirLightCount < _maxDirLightCount) {
                        SetupDirectionalLight(dirLightCount++, ref visibleLight);
                    }
                    break;
                case LightType.Point:
                    if (otherLightCount < _maxOtherLightCount)
                    {
                        newindex = otherLightCount;
                        SetupPointLight(otherLightCount++, ref visibleLight);
                    }
                    break;
                case LightType.Spot:
                    if (otherLightCount < _maxOtherLightCount)
                    {
                        newindex = otherLightCount;
                        SetupSpotLight(otherLightCount++,ref visibleLight);
                    }
                    break;
            }

            if (useLightsPerObject)
            {
                indexMap[i] = newindex;
            }
        }

        if (useLightsPerObject)
        {
            for (; i < indexMap.Length; i++)
            {
                indexMap[i] = -1;
            }
            _cullingResults.SetLightIndexMap(indexMap);
            indexMap.Dispose();
            Shader.EnableKeyword(lightsPerObjectKeyword);
        }
        else
        {
            Shader.DisableKeyword(lightsPerObjectKeyword);
        }
        
        _buffer.SetGlobalInt(_dirLightCountId , dirLightCount);
        if (dirLightCount > 0)
        {
            _buffer.SetGlobalVectorArray(_dirLightColorsId ,_dirLightColors);
            _buffer.SetGlobalVectorArray(_dirLightDirectionsId ,_dirLightDirections);
            _buffer.SetGlobalVectorArray(_dirLightShadowDataId,_dirLightShadowData);   
        }

        _buffer.SetGlobalInt(_otherLightCountId,otherLightCount);
        if (otherLightCount > 0)
        {
            _buffer.SetGlobalVectorArray(_otherLightColorsId,_otherLightColors);
            _buffer.SetGlobalVectorArray(_otherLightPositionsId,_otherLightPositions);
            _buffer.SetGlobalVectorArray(_otherLightDirectionsId,_otherLightDirections);
            _buffer.SetGlobalVectorArray(_otherLightSpotAnglesId,_otherLightSpotAngles);
            _buffer.SetGlobalVectorArray(_otherLightShadowDataId,_otherLightShadowData);
        }
    }

    void SetupDirectionalLight(int index ,ref VisibleLight visibleLight)
    {
        _dirLightColors[index] = visibleLight.finalColor;
        //可以通过VisibleLight.localToWorldMatrix属性找到前向矢量。它是矩阵的第三列，必须再次取反。
        _dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        _dirLightShadowData[index] = _shadows.ReserveDirectionalShadows(visibleLight.light, index);
    }

    void SetupPointLight(int index, ref VisibleLight visibleLight)
    {
        _otherLightColors[index] = visibleLight.finalColor;
        Vector4 position = visibleLight.localToWorldMatrix.GetColumn(3);
        //https://catlikecoding.com/unity/tutorials/custom-srp/point-and-spot-lights/   公式推导 1.5 Light Range
        position.w = 1 / Mathf.Max(visibleLight.range * visibleLight.range , 0.0001f);
        _otherLightPositions[index] = position;
        _otherLightSpotAngles[index] = new Vector4(0f,1f);
        
        Light light = visibleLight.light;
        _otherLightShadowData[index] = _shadows.ReserveOtherShadows(light, index);
    }

    void SetupSpotLight(int index, ref VisibleLight visibleLight)
    {
        _otherLightColors[index] = visibleLight.finalColor;
        Vector4 position = visibleLight.localToWorldMatrix.GetColumn(3);
        position.w = 1 / Mathf.Max(visibleLight.range * visibleLight.range , 0.0001f);
        _otherLightPositions[index] = position;
        _otherLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);

        Light light = visibleLight.light;
        float innerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * light.innerSpotAngle);
        float outerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * visibleLight.spotAngle);
        //https://catlikecoding.com/unity/tutorials/custom-srp/point-and-spot-lights/    公式推导 2.2 Spot Angle
        float angleRangeInv = 1 / Mathf.Max(innerCos - outerCos, 0.001f);
        _otherLightSpotAngles[index] = new Vector4(angleRangeInv, -outerCos * angleRangeInv);

        _otherLightShadowData[index] = _shadows.ReserveOtherShadows(light, index);
    }

    public void Cleanup()
    {
        _shadows.Cleanup();
    }
}
