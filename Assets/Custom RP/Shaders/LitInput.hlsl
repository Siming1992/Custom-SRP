#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//纹理需要上传到GPU的内存里，这一步Unity会为我们做。着色器需要一个相关纹理的句柄，我们可以像定义一个uniform 值那样定义它，只是我们使用名为TEXTURE2D的宏参数。
TEXTURE2D(_BaseMap);
TEXTURE2D(_EmissionMap);
//我们还需要为纹理定义一个采样器状态，考虑到wrap 和filter的模式，该状态控制着色器应如何采样。通过SAMPLER宏实现，例如TEXTURE2D，但在名称前添加了sampler。
SAMPLER(sampler_Basemap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4,_EmissionColor)
    UNITY_DEFINE_INSTANCED_PROP(float,_Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float,_Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float,_Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float,_Fresnel)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

float2 TransformBaseUV(float2 baseUV){
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float4 GetBase(float2 baseUV){
    float4 map = SAMPLE_TEXTURE2D(_BaseMap,sampler_Basemap,baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_BaseColor);
    return map * color;
}

float3 GetEmission(float2 baseUV){
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap,sampler_Basemap,baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_EmissionColor);
    return map.rgb * color.rgb; 
}

float GetCutoff(float2 baseUV){
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Cutoff);
}

float GetMetallic(float2 baseUV){
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Metallic);
}

float GetSmoothness(float2 baseUV){
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Smoothness);
}

float GetFresnel(float2 baseUV){
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Fresnel);
}

#endif
