#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "UnityInput.hlsl"

#define UNITY_MATRIX_M unity_ObjectToWorld;
#define UNITY_MATRIX_I_M unity_WorldToObject;

#define UNITY_MATRIX_V unity_MatrixV;
#define UNITY_MATRIX_VP unity_MatrixVP;
#define UNITY_MATRIX_P glstate_matrix_projection;
//UnityInstancing仅在定义SHADOWS_SHADOWMASK时才执行此操作。因此，在包含UnityInstancing之前在Common中需要时定义它
#if defined(_SHADOW_MASK_ALWAYS) || defined (_SHADOW_MASK_DISTANCE)
    #define SHADOWS_SHADOWMASK
#endif
//UnityInstancing.hlsl的作用是重新定义这些宏来访问实例数据数组。
//但是要进行这项工作，需要知道当前正在渲染的对象的索引。索引是通过顶点数据提供的，因此需要使其可用。UnityInstancing.hlsl定义了宏来简化此过程，但是它假定顶点函数具有struct参数。
//包括UNITY_TRANSFER_INSTANCE_ID UNITY_VERTEX_INPUT_INSTANCE_ID
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

float Square (float x) {
	return x * x;
}

float DistanceSquared(float3 pA , float3 pB){
    return dot(pA - pB,pA - pB);
}

void ClipLOD(float2 positionCS,float fade){
    #if defined(LOD_FADE_CROSSFADE)
        float dither = InterleavedGradientNoise(positionCS.xy,0);
        clip(fade + (fade < 0.0 ? dither : -dither));
    #endif
}

//DXT5nm是什么意思？
//DXT5（也称为BC3）是一种压缩格式，将纹理划分为4×4像素的块。每个块都有两种颜色近似，每个像素可进行插值。用于颜色的位数在每个通道中有所不同。R和B分别获得5位，G获得6位，而A获得8位。这就是X坐标移至A通道的原因之一。另一个原因是RGB通道获得一个查找表，而A通道获得其自己的查找表。这样可以使X和Y分量保持隔离。
//当DXT5用于存储法线向量时，称为DXT5nm。但是，当使用高压缩质量时，Unity更喜欢BC7压缩。此模式的工作原理相同，但每个通道的位数可能会有所不同。因此，不需要移动X通道。最终纹理的结局更大，因为两个通道都使用了更多位，从而提高了纹理质量。
float3 DecodeNormal(float4 sample,float scale){
    #if defined(UNITY_NO_DXT5nm)
        return UnpackNormalRGB(sample,scale)
    #else
        return UnpackNormalmapRGorAG(sample,scale);
    #endif
}

float3 NormalTangentToWorld(float3 normalTS,float3 normalWS,float4 tangentWS){
    float3x3 tangentToWorld =
        CreateTangentToWorld(normalWS,tangentWS.xyz,tangentWS.w);
    return TransformTangentToWorld(normalTS,tangentToWorld); 
}

#endif