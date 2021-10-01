#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

//HLSL并没有类的概念。除了代码块的局部范围外，只有一个全局范围
//#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

//#define UNITY_DEFINE_INSTANCED_PROP(type, var)  type var; 只是定义
//#define UNITY_ACCESS_INSTANCED_PROP(arr, var)   var

struct Attributes{
    float3 positionCS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 baseUV : TEXCOORD0;
    GI_ATTRIBUTE_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varying{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float3 normalWS : VAR_NORMAL;
    #if defined(_NORMAL_MAP)
        float4 tangentWS : VAR_TANGENT;
    #endif
    //这里我们不需要添加特殊含义，只是传递的数据并不需要让GPU关注。但是，基于语法，我们仍然必须赋予它一些含义。所以可以给它添加任何 unused 的标识符，这里就简单地使用VAR_BASE_UV。
    float2 baseUV : VAR_BASE_UV;
	#if defined(_DETAIL_MAP)
        float2 detailUV : VAR_DETAIL_UV;
    #endif
    GI_VARYINGS_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


// - UNITY_SETUP_INSTANCE_ID        Should be used at the very beginning of the vertex shader / fragment shader,
//                                  so that succeeding code can have access to the global unity_InstanceID.
//                                  Also procedural function is called to setup instance data.
// - UNITY_TRANSFER_INSTANCE_ID     Copy instance ID from input struct to output struct. Used in vertex shader.

Varying LitPassVertex(Attributes input){
    Varying output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    TRANSFER_GI_DATA(input,output);
    output.positionWS = TransformObjectToWorld(input.positionCS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    //使用SpaceTransforms中的TransformObjectToWorldNormal在LitPassVertex中将法线转换到世界空间。
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    #if defined(_NORMAL_MAP)
        output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz),input.tangentOS.w);
    #endif
    
    output.baseUV = TransformBaseUV(input.baseUV);
    #if defined(_DETAIL_MAP)
        output.detailUV = TransformDetailUV(input.baseUV);
    #endif
    return output;
}

float4 LitPassFragment(Varying input):SV_TARGET{
    UNITY_SETUP_INSTANCE_ID(input);
    ClipLOD(input.positionCS.xy,unity_LODFade.x);   
    InputConfig config = GetInputConfig(input.baseUV);
    #if defined(_MASK_MAP)
        config.useMask = true;
    #endif
    
    #if defined(_DETAIL_MAP)
        config.detailUV = input.detailUV;
        config.useDetail = true;
    #endif
    
    float4 base = GetBase(config);
    #if defined(_CLIPPING)
        clip(base.a - GetCutoff(input.baseUV));
    #endif
    //尽管法线向量在顶点程序中为单位长，但跨三角形的线性插值会影响其长度。我们可以通过渲染一个和向量长度之间的差（放大十倍以使其更明显）来可视化该错误。
    //base.rgb = abs(length(input.normalWS) - 1.0) * 10;
    //base.rgb = normalize(input.normalWS);
    
    Surface surface;
    surface.position = input.positionWS;
    #if defined(_NORMAL_MAP)
        surface.normal = NormalTangentToWorld(
            GetNormalTS(config),input.normalWS,input.tangentWS
            );
        surface.interpolatedNormal = input.normalWS;
    #else        
		surface.normal = normalize(input.normalWS);
		surface.interpolatedNormal = surface.normal;
    #endif
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS); 
    surface.depth = -TransformWorldToView(input.positionWS).z;   //通过TransformWorldToView从世界空间转换为视图空间，并取负Z坐标,由于此转换只是相对于世界空间的旋转和偏移，因此视图空间和世界空间的深度相同。
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface.metallic = GetMetallic(config);
    surface.smoothness = GetSmoothness(config);
    surface.occlusion = GetOcclusion(config);
    surface.fresnelStrength = GetFresnel(config);
    surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);  //该函数在给定屏幕空间XY位置的情况下生成旋转的平铺抖动模式。在片段函数中，其等于剪辑空间的XY位置。它还需要使用第二个参数对其进行动画处理，我们不需要该参数，并且可以将其保留为零。

    #if defined(_PREMULTIPLY_ALPHA)
        BRDF brdf = GetBRDF(surface, true);
    #else
        BRDF brdf = GetBRDF(surface);
    #endif
    
    GI gi = GetGI(GI_FRAGMENT_DATA(input),surface,brdf);        //GI_FRAGMENT_DATA(input) 在GI.hlsl中定义为 input.lightMapUV
    float3 color = GetLighting(surface,brdf,gi);
    color += GetEmission(config);
    
    return float4(color,surface.alpha);
}

#endif
