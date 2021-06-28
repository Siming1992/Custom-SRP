#ifndef CUSTOM_SHADOWCASTER_PASS_INCLUDED
#define CUSTOM_SHADOWCASTER_PASS_INCLUDED

//HLSL并没有类的概念。除了代码块的局部范围外，只有一个全局范围
#include "../ShaderLibrary/Common.hlsl"

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
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

struct Attributes{
    float3 positionCS : POSITION;
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varying{
    float4 positionCS : SV_POSITION;
    //这里我们不需要添加特殊含义，只是传递的数据并不需要让GPU关注。但是，基于语法，我们仍然必须赋予它一些含义。所以可以给它添加任何 unused 的标识符，这里就简单地使用VAR_BASE_UV。
    float2 baseUV : VAR_BASE_UV;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// - UNITY_SETUP_INSTANCE_ID        Should be used at the very beginning of the vertex shader / fragment shader,
//                                  so that succeeding code can have access to the global unity_InstanceID.
//                                  Also procedural function is called to setup instance data.
// - UNITY_TRANSFER_INSTANCE_ID     Copy instance ID from input struct to output struct. Used in vertex shader.

Varying ShadowCasterPassVertex(Attributes input){
    Varying output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    float3 postionWS = TransformObjectToWorld(input.positionCS);
    output.positionCS = TransformWorldToHClip(postionWS);
    //将顶点位置固定到近平面(解决Shadow Pancaking)
    //我们通过获取剪辑空间Z和W坐标的最大值或定义UNITY_REVERSED_Z时的最小值来做到这一点。要将正确的符号用于W坐标，请乘以UNITY_NEAR_CLIP_VALUE。
    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z , output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
        output.positionCS.z = max(output.positionCS.z , output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
    
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    return output;
}

void ShadowCasterPassFragment(Varying input){
    UNITY_SETUP_INSTANCE_ID(input);
    float4 basemap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.baseUV);
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_BaseColor);
    float4 base = basemap * baseColor;
    #if defined(_SHADOWS_CLIP)
        clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Cutoff));
    #elif defined(_SHADOWS_DITHER)
		float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
		clip(base.a - dither);
    #endif
}

#endif
