using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public partial class PostFXStack
{
    private const string _bufferName = "Post FX";
    CommandBuffer _buffer = new CommandBuffer()
    {
        name = _bufferName
    };

    private ScriptableRenderContext _context;
    private Camera _camera;
    private PostFXSettings _postFxSettings;

    public bool IsActive => _postFxSettings != null;

    private const int _maxBloomPyramidLevels = 16;

    private int _bloomPyramidId;

    enum Pass
    {
        BloomPrefilter,
        BloomCombine,
        BloomHorizontal,
        BloomVertical,
        Copy
    }

    private int _bloomBucibicUpsamplingId = Shader.PropertyToID("_BloomBicubicUpsampling");
    private int _bloomPrefilterId = Shader.PropertyToID("_BloomPrefilterId");
    private int _fxSourceId = Shader.PropertyToID("_PostFXSource");
    private int _fxSource2Id = Shader.PropertyToID("_PostFXSource2");
    private int _bloomThresholdId = Shader.PropertyToID("_BloomThreshold");
    private int _bloomIntensityId = Shader.PropertyToID("_BloomIntensity");

    public PostFXStack()
    {
        _bloomPyramidId = Shader.PropertyToID("_BloomPyramid0");
        for (int i = 0; i < _maxBloomPyramidLevels * 2; i++)
        {
            Shader.PropertyToID("_BloomPyramid" + i);
        }
    }

    public void Setup(ScriptableRenderContext context,Camera camera,PostFXSettings postFxSettings)
    {
        _context = context;
        _camera = camera;
        _postFxSettings = camera.cameraType <= CameraType.SceneView ? postFxSettings : null;
        ApplySceneViewState();
    }

    public void Render(int sourceId)
    {
        // _buffer.Blit(sourceId,BuiltinRenderTextureType.CameraTarget);
        // Draw(sourceId, BuiltinRenderTextureType.CameraTarget, Pass.Copy);
        DoBloom(sourceId);
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();    //我们不需要手动开始和结束缓冲区样本，因为我们可以完全替换目标位置，因此不需要调用ClearRenderTarget。
    }

    void Draw(RenderTargetIdentifier from,RenderTargetIdentifier to,Pass pass)
    {
        _buffer.SetGlobalTexture(_fxSourceId, from);
        _buffer.SetRenderTarget(to, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        _buffer.DrawProcedural(Matrix4x4.identity, _postFxSettings.Material, (int) pass, MeshTopology.Triangles, 3);
    }

    void DoBloom(int sourceId)
    {
        _buffer.BeginSample("Bloom");
        PostFXSettings.BloomSettings bloom = _postFxSettings.Bloom;
        int width = _camera.pixelWidth / 2, height = _camera.pixelHeight / 2;
        if (bloom.maxIterations == 0 || bloom.intensity <= 0 || height < bloom.downscaleLimit || width < bloom.downscaleLimit)
        {
            Draw(sourceId, BuiltinRenderTextureType.CameraTarget, Pass.Copy);
            _buffer.EndSample("Bloom");
            return;
        }

        // w = max(s ,b - t)/max(b,0.00001)
        // s = min(max(0 , b - t + tk) , 2tk)² / 4tk + 0.00001
        Vector4 threshold;
        threshold.x = Mathf.GammaToLinearSpace(bloom.threshold);    //t
        threshold.y = threshold.x * bloom.thresholdKnee;            
        threshold.z = 2f * threshold.y;                            //2tk
        threshold.w = 0.25f / (threshold.y + 0.00001f);            //1 / 4tk + 0.00001
        threshold.y -= threshold.x;                                //-t+tk
        _buffer.SetGlobalVector(_bloomThresholdId, threshold);
        
        RenderTextureFormat format = RenderTextureFormat.Default;
        _buffer.GetTemporaryRT(_bloomPrefilterId, width, height, 0, FilterMode.Bilinear, format);
        Draw(sourceId, _bloomPrefilterId, Pass.BloomPrefilter);
        width /= 2;
        height /= 2;
        
        int fromID = _bloomPrefilterId, toId = _bloomPyramidId + 1;
        int i;
        for (i = 0; i < bloom.maxIterations; i++)
        {
            if (height < bloom.downscaleLimit * 2 || width < bloom.downscaleLimit * 2)
            {
                break;
            }

            int midId = toId - 1;
            _buffer.GetTemporaryRT(midId, width, height, 0, FilterMode.Bilinear, format);
            _buffer.GetTemporaryRT(toId, width, height, 0, FilterMode.Bilinear, format);
            //这里Horizontal是从fromID来的，使用了双线性过滤进行了降采样
            Draw(fromID, midId, Pass.BloomHorizontal);
            //而执行Vertical时则是从midID获得，分辨率相同，并没有进行降采样
            Draw(midId, toId, Pass.BloomVertical);
            fromID = toId;
            toId += 2;
            width /= 2;
            height /= 2;
        }

        _buffer.ReleaseTemporaryRT(_bloomPrefilterId);
        _buffer.SetGlobalFloat(_bloomBucibicUpsamplingId, bloom.bicubicUpsampling ? 1f : 0f);
        // Draw(fromID, BuiltinRenderTextureType.CameraTarget, Pass.Copy);
        _buffer.SetGlobalFloat(_bloomIntensityId, 1f);
        if (i > 1)
        {
            _buffer.ReleaseTemporaryRT(fromID -1);
            toId -= 5;
            for (i -= 1; i > 0; i--)
            {
                _buffer.SetGlobalTexture(_fxSource2Id,toId + 1);
                Draw(fromID, toId, Pass.BloomCombine);
                _buffer.ReleaseTemporaryRT(fromID);
                _buffer.ReleaseTemporaryRT(toId + 1);
                fromID = toId;
                toId -= 2;
            }
        }
        else
        {
            _buffer.ReleaseTemporaryRT(_bloomPyramidId);
        }

        _buffer.SetGlobalFloat(_bloomIntensityId, bloom.intensity);
        _buffer.SetGlobalTexture(_fxSource2Id, sourceId);
        Draw(fromID, BuiltinRenderTextureType.CameraTarget, Pass.BloomCombine);
        _buffer.ReleaseTemporaryRT(fromID);    
        _buffer.EndSample("Bloom");
    }
}
