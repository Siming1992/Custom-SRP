#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

//HLSL并没有类的概念。除了代码块的局部范围外，只有一个全局范围
#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

//纹理需要上传到GPU的内存里，这一步Unity会为我们做。着色器需要一个相关纹理的句柄，我们可以像定义一个uniform 值那样定义它，只是我们使用名为TEXTURE2D的宏参数。
TEXTURE2D(_BaseMap);
//我们还需要为纹理定义一个采样器状态，考虑到wrap 和filter的模式，该状态控制着色器应如何采样。通过SAMPLER宏实现，例如TEXTURE2D，但在名称前添加了sampler。
SAMPLER(sampler_BaseMap);

//#define UNITY_DEFINE_INSTANCED_PROP(type, var)  type var; 只是定义
//#define UNITY_ACCESS_INSTANCED_PROP(arr, var)   var

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float,_Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float,_Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float,_Smoothness)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

struct Attributes{
    float3 postionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varying{
    float4 positioCS : SV_POSITION;
    float3 postionWS : VAR_POSITION;
    float3 normalWS : VAR_NORMAL;
    //这里我们不需要添加特殊含义，只是传递的数据并不需要让GPU关注。但是，基于语法，我们仍然必须赋予它一些含义。所以可以给它添加任何 unused 的标识符，这里就简单地使用VAR_BASE_UV。
    float2 baseUV : VAR_BASE_UV;
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
    output.postionWS = TransformObjectToWorld(input.postionOS);
    output.positioCS = TransformWorldToHClip(output.postionWS);
    //使用SpaceTransforms中的TransformObjectToWorldNormal在LitPassVertex中将法线转换到世界空间。
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    return output;
}

float4 LitPassFragment(Varying input):SV_TARGET{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 basemap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.baseUV);
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_BaseColor);
    float4 base = basemap * baseColor;
    #if defined(_CLIPPING)
        clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Cutoff));
    #endif
    //尽管法线向量在顶点程序中为单位长，但跨三角形的线性插值会影响其长度。我们可以通过渲染一个和向量长度之间的差（放大十倍以使其更明显）来可视化该错误。
    //base.rgb = abs(length(input.normalWS) - 1.0) * 10;
    //base.rgb = normalize(input.normalWS);
    
    Surface surface;
    surface.position = input.postionWS;
    surface.normal = normalize(input.normalWS);
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.postionWS); 
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Metallic);
    surface.smoothness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Smoothness);
    
    #if defined(_PREMULTIPLY_ALPHA)
        BRDF brdf = GetBRDF(surface, true);
    #else
        BRDF brdf = GetBRDF(surface);
    #endif
    
    float3 color = GetLighting(surface,brdf);
    
    return float4(color,surface.alpha);
}

#endif
