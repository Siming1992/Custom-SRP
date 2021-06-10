using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{
    private const int _maxDirLightCount = 4;

    private static int _dirLightCountId = Shader.PropertyToID("_DirectionalLightCount");
    private static int _dirLightColorsID = Shader.PropertyToID("_DirectionalLightColors");
    private static int _dirLightDirectionsID = Shader.PropertyToID("_DirectionalLightDirections");
    private static int _dirLightShadowDataID = Shader.PropertyToID("_DirectionalLightShadowData");
    
    static Vector4[] _dirLightColors = new Vector4[_maxDirLightCount];
    static Vector4[] _dirLightDirections = new Vector4[_maxDirLightCount];
    static Vector4[] _dirLightShadowData = new Vector4[_maxDirLightCount];
    
    private const string _bufferName = "Lighting";

    private CommandBuffer _buffer = new CommandBuffer() {name = _bufferName};
    private CullingResults _cullingResults = new CullingResults();
    
    Shadows _shadows = new Shadows();

    public void SetUp(ScriptableRenderContext context,CullingResults cullingResults,ShadowSettings shadowSettings)
    {
        _cullingResults = cullingResults;
        _buffer.BeginSample(_bufferName);
        _shadows.Setup(context,cullingResults,shadowSettings);
        SetupLights();
        _shadows.Render();
        _buffer.EndSample(_bufferName);
        context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
    
    void SetupLights () {
        NativeArray<VisibleLight> visibleLights = _cullingResults.visibleLights;
        int dirLightCount = 0;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            if (visibleLight.lightType == LightType.Directional)
            {
                SetupDirectionalLight(dirLightCount++, ref visibleLight);
                if (dirLightCount >= _maxDirLightCount)
                {
                    break;
                }   
            }
        }
        _buffer.SetGlobalInt(_dirLightCountId , visibleLights.Length);
        _buffer.SetGlobalVectorArray(_dirLightColorsID ,_dirLightColors);
        _buffer.SetGlobalVectorArray(_dirLightDirectionsID ,_dirLightDirections);
        _buffer.SetGlobalVectorArray(_dirLightShadowDataID,_dirLightShadowData);
    }

    void SetupDirectionalLight(int index ,ref VisibleLight visibleLight)
    {
        _dirLightColors[index] = visibleLight.finalColor;
        //可以通过VisibleLight.localToWorldMatrix属性找到前向矢量。它是矩阵的第三列，必须再次取反。
        _dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        _dirLightShadowData[index] = _shadows.ReserveDirectionalShadows(visibleLight.light, index);
    }

    public void Cleanup()
    {
        _shadows.Cleanup();
    }
}
