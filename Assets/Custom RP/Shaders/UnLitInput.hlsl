#ifndef CUSTOM_UNLIT_INPUT_INCLUDED
#define CUSTOM_UNLIT_INPUT_INCLUDED

//纹理需要上传到GPU的内存里，这一步Unity会为我们做。着色器需要一个相关纹理的句柄，我们可以像定义一个uniform 值那样定义它，只是我们使用名为TEXTURE2D的宏参数。
TEXTURE2D(_BaseMap);
//我们还需要为纹理定义一个采样器状态，考虑到wrap 和filter的模式，该状态控制着色器应如何采样。通过SAMPLER宏实现，例如TEXTURE2D，但在名称前添加了sampler。
SAMPLER(sampler_Basemap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float,_Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

struct InputConfig{
    float2 baseUV;
};

InputConfig GetInputConfig (float2 baseUV) {
	InputConfig c;
	c.baseUV = baseUV;
	return c;
}

float2 TransformBaseUV(float2 baseUV){
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float2 TransformDetailUV (float2 detailUV) {
	return 0.0;
}

float4 GetMask (InputConfig c) {
	return 1.0;
}

float4 GetDetail (InputConfig c) {
	return 0.0;
}

float4 GetBase(InputConfig c){
    float4 map = SAMPLE_TEXTURE2D(_BaseMap,sampler_Basemap,c.baseUV);
    float4 color = INPUT_PROP(_BaseColor);
    return map * color;
}

float3 GetNormalTS (InputConfig c) {
	return float3(0.0, 0.0, 1.0);
}

float3 GetEmission(InputConfig c){
    return GetBase(c).rgb;
}

float GetCutoff(InputConfig c){
    return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig c){
    return 0.0;
}

float GetSmoothness(InputConfig c){
    return 0.0;
}

float GetFresnel(InputConfig c){
    return 0.0;
}

#endif
