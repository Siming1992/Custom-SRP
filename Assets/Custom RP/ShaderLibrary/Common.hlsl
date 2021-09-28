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

#endif