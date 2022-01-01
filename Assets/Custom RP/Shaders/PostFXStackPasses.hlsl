#ifndef CUSTOM_POST_FX_PASSES_INCLUDED
#define CUSTOM_POST_FX_PASSES_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

TEXTURE2D(_PostFXSource);
TEXTURE2D(_PostFXSource2);
SAMPLER(sampler_linear_clamp);

//https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
// Texture size
// {TextureName}_TexelSize - a float4 property contains texture size information:
// x contains 1.0/width
// y contains 1.0/height
// z contains width
// w contains height
float4 _PostFXSource_TexelSize;

float4 GetSourceTexelSize(){
    return _PostFXSource_TexelSize;
}

float4 GetSource(float2 screenUV) {
    //因为我们的缓冲区永远不会有mip映射，我们可以通过用SAMPLE_TEXTURE2D_LOD替换SAMPLE_TEXTURE2D来回避自动mip映射选择，添加一个额外的参数来强制选择mip映射级别为0。
	return SAMPLE_TEXTURE2D_LOD(_PostFXSource, sampler_linear_clamp, screenUV, 0);
}

float4 GetSource2(float2 screenUV) {
	return SAMPLE_TEXTURE2D_LOD(_PostFXSource2, sampler_linear_clamp, screenUV, 0);
}

float4 GetSourceBicubic(float2 screenUV){
    return SampleTexture2DBicubic(TEXTURE2D_ARGS(_PostFXSource,sampler_linear_clamp),screenUV,_PostFXSource_TexelSize.zwxy,1.0,0.0);
}

struct Varyings {
	float4 positionCS : SV_POSITION;
	float2 screenUV : VAR_SCREEN_UV;
};

Varyings DefaultPassVertex(uint vertexID : SV_VertexID){
    Varyings output;
    //创建一个默认的顶点通道，只有一个顶点标识符作为参数。它是一个无符号整数uint——具有SV_VertexID语义。
    //使用 ID 生成顶点位置和 UV 坐标。X 坐标为 -1、-1、3。Y 坐标为 -1、3、-1。要使可见 UV 坐标覆盖 0-1 范围，请使用 0, 0, 2 表示 U，使用 0, 2, 0 表示 V。
    output.positionCS = float4(
		vertexID <= 1 ? -1.0 : 3.0,
		vertexID == 1 ? 3.0 : -1.0,
        0.0,1.0
    );
    output.screenUV = float2(
		vertexID <= 1 ? 0.0 : 2.0,
		vertexID == 1 ? 2.0 : 0.0
    );
    if(_ProjectionParams.x < 0.0){
        output.screenUV.y = 1.0 - output.screenUV.y;
    }
    return output;
}

float4 _BloomThreshold;

// w = max(s ,b - t)/max(b,0.00001)
// s = min(max(0 , b - t + tk) , 2tk)² / 4tk + 0.00001
// x=t | y=- t + tk | z=2tk | w= 1/4tk + 0.00001
float3 ApplyBloomThreshold(float3 color){
    float brightness = Max3(color.r,color.g,color.b);
    float soft = brightness + _BloomThreshold.y;
    soft = clamp(soft,0.0,_BloomThreshold.z);
    soft = soft * soft * _BloomThreshold.w;
    float contribution = max(soft , brightness - _BloomThreshold.x);
    contribution /= max(brightness,0.0001);
    return color *  contribution;
}

float4 BloomPrefilterPassFragment(Varyings input) : SV_TARGET{
    float3 color = ApplyBloomThreshold(GetSource(input.screenUV).rgb);
    return float4(color , 1.0);
}


float4 BloomPrefilterFirefliesPassFragment (Varyings input) : SV_TARGET {
	float3 color = 0.0;
	float weightSum = 0.0;
	float2 offsets[] = {
		float2(0.0, 0.0),
		float2(-1.0, -1.0), float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
	};
	for (int i = 0; i < 5; i++) {
		float3 c =
			GetSource(input.screenUV + offsets[i] * GetSourceTexelSize().xy * 2.0).rgb;
		c = ApplyBloomThreshold(c);
		float w = 1.0 / (Luminance(c) + 1.0);
		color += c * w;
		weightSum += w;
	}
	color /= weightSum;
	return float4(color, 1.0);
}

bool _BloomBicubicUpsampling;
float _BloomIntensity;

float4 BloomAddPassFragment(Varyings input) : SV_TARGET{
    float3 lowRes ;
    if(_BloomBicubicUpsampling){
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    }else{
        lowRes = GetSource(input.screenUV).rgb;
    }
    
    float3 highRes = GetSource2(input.screenUV).rgb;
    return float4(lowRes * _BloomIntensity + highRes , 1.0);
}


float4 BloomScatterPassFragment(Varyings input) : SV_TARGET{
    float3 lowRes ;
    if (_BloomBicubicUpsampling){
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    }
    else {
        lowRes = GetSource(input.screenUV).rgb;
    }    
    float3 highRes = GetSource2(input.screenUV).rgb;
	return float4(lerp(highRes, lowRes, _BloomIntensity), 1.0);
}

float4 BloomScatterFinalPassFragment(Varyings input) : SV_TARGET{
    float3 lowRes ;
    if(_BloomBicubicUpsampling){
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    }else{
        lowRes = GetSource(input.screenUV).rgb;
    }
    
    float3 highRes = GetSource2(input.screenUV).rgb;
    lowRes += highRes - ApplyBloomThreshold(highRes);
	return float4(lerp(highRes, lowRes, _BloomIntensity), 1.0);
}

float4 BloomHorizontalPassFragment(Varyings input) : SV_TARGET{
    float3 color = 0.0;
    float offsets[] = {-4.0,-3.0,-2.0,-1.0,0.0,1.0,2.0,3.0,4.0};
    float weights[] = {0.01621622, 0.05405405, 0.12162162, 0.19459459, 0.22702703,
		0.19459459, 0.12162162, 0.05405405, 0.01621622};
    for(int i = 0; i < 9; i ++){
        //我们已经在该通道中使用双线性过滤进行下采样。它的九个样本中的每一个平均为 2×2 源像素
        float offset = offsets[i] * 2.0 * GetSourceTexelSize().x;
        color += GetSource(input.screenUV + float2(offset,0.0)).rgb * weights[i];   
    }
    return float4(color,1.0);
}

float4 BloomVerticalPassFragment(Varyings input) : SV_TARGET{
    float3 color = 0.0;
    float offsets[] = {-3.23076923, -1.38461538, 0.0, 1.38461538, 3.23076923};
    float weights[] = {0.07027027, 0.31621622, 0.22702703, 0.31621622, 0.07027027};
    for(int i = 0; i < 5; i ++){
        float offset = offsets[i] * GetSourceTexelSize().y;
        color += GetSource(input.screenUV + float2(0.0,offset)).rgb * weights[i];   
    }
    return float4(color,1.0);
}

float4 CopyPassFragment (Varyings input) : SV_TARGET {
	return GetSource(input.screenUV);
}

float4 ToneMappingReinhardPassFragment(Varyings input) : SV_TARGET {
    float4 color = GetSource(input.screenUV);
    color.rgb = min(color.rgb, 60.0);   // Reinhard : c/(1+ c)
    color.rgb /= color.rgb + 1.0;
    return color;
}

float4 ToneMappingNeutralPassFragment (Varyings input) : SV_TARGET {
	float4 color = GetSource(input.screenUV);
	color.rgb = min(color.rgb, 60.0);
	color.rgb = NeutralTonemap(color.rgb);
	return color;
}

float4 ToneMappingACESPassFragment (Varyings input) : SV_TARGET {
	float4 color = GetSource(input.screenUV);
	color.rgb = min(color.rgb, 60.0);
	color.rgb = AcesTonemap(unity_to_ACES(color.rgb));
	return color;
}

#endif
