#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#if defined(_DIRECTIONAL_PCF3)
	#define DIRECTIONAL_FILTER_SAMPLES 4
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
	#define DIRECTIONAL_FILTER_SAMPLES 9
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
	#define DIRECTIONAL_FILTER_SAMPLES 16
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

//由于图集不是常规的纹理，因此我们可以通过TEXTURE2D_SHADOW宏对其进行定义，即使它对我们支持的平台没有影响，也要使其清晰可见。
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
//实际上，只有一种合适的方法可以对阴影贴图进行采样，因此我们可以定义一个明确的采样器状态，而不是依赖Unity推导的渲染纹理状态。可以内联定义采样器状态，方法是在其名称中创建一个带有特定单词的状态。我们可以使用sampler_linear_clamp_compare。我们还为其定义一个简写的SHADOW_SAMPLER宏。
#define SHADOW_SAMPLER sampler_linear_clamp_compare
//我们将使用一个特殊的SAMPLER_CMP宏来定义采样器状态，因为这确实定义了一种不同的方式来采样阴影贴图，因为常规的双线性过滤对深度数据没有意义。
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadow)
    int _CascadeCount;
    float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    float4 _CascadeData[MAX_CASCADE_COUNT];
    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];  //如果修改数组长度，Unity将抱怨着色器的数组大小已更改，但无法使用新的大小。这是因为一旦着色器声明了固定数组，就无法在同一会话期间在GPU上更改其大小。我们需要重新启动Unity才能对其进行初始化。
	float4 _ShadowAtlasSize;
    float4 _ShadowDistanceFade;    
CBUFFER_END

struct ShadowMask{
    bool always;
    bool distance;
    float4 shadows;
};

struct ShadowData{
    int cascadeIndex;
    float cascadeBlend;
    float strength;
    ShadowMask shadowMask;
};

float FadedShadowStrength(float distance , float scale , float fade){
    return saturate((1.0 - distance * scale) * fade);
}

ShadowData GetShadowData(Surface surfaceWS){
    ShadowData data;
    data.shadowMask.always = false;
    data.shadowMask.distance = false;
    data.shadowMask.shadows = 1.0;
    data.cascadeBlend = 1.0;
    data.strength = FadedShadowStrength(surfaceWS.depth , _ShadowDistanceFade.x , _ShadowDistanceFade.y);
    
    int i;
    for(i = 0 ; i < _CascadeCount ; i++){
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surfaceWS.position , sphere.xyz);
        if(distanceSqr < sphere.w){
            float fada = FadedShadowStrength(distanceSqr,_CascadeData[i].x,_ShadowDistanceFade.z);
            if(i == _CascadeCount - 1){
                data.strength *= fada;
            }
            else{
                data.cascadeBlend = fada;
            }
            break;
        }
    }
    if(i == _CascadeCount){
        data.strength = 0.0;
    }
    #if defined(_CASCADE_BLEND_DITHER)
        else if(data.cascadeBlend < surfaceWS.dither){
            i += 1;
        }
    #endif
    #if !defined(_CASCADE_BLEND_SOFT)
        data.cascadeBlend = 1.0;
    #endif
    data.cascadeIndex = i;
    return data;
}

struct DirectionalShadowData{
    float strength;
    int tileIndex;
    float normalBias;
    int shadowMaskChannel;
};

//该函数通过SAMPLE_TEXTURE2D_SHADOW宏对阴影图集进行采样，并向其传递图集，阴影采样器以及阴影纹理空间中的位置（这是一个对应的参数）。
//当坐标的z值小于阴影映射纹理中的深度值时，SAMPLE_TEXTURE2D_SHADOW返回1，这意味着该点距离光源更近，不在阴影中。否则，该宏返回值为0意味着该点在阴影中。因为采样器在双线性插值之前执行比较，所以阴影的边缘将混合阴影映射纹理的纹素。
float SampleDirectionalShadowAtlas (float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

float FilterDirectionalShadow(float3 positionSTS){
    #if defined(DIRECTIONAL_FILTER_SETUP)
        real weights[DIRECTIONAL_FILTER_SAMPLES];
        real2 positions[DIRECTIONAL_FILTER_SAMPLES];
        float4 size = _ShadowAtlasSize.yyxx;
		DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);   
        float shadow = 0;
		for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
			shadow += weights[i] * SampleDirectionalShadowAtlas(
				float3(positions[i].xy, positionSTS.z)
			);
        }
        return shadow;
    #else
        return SampleDirectionalShadowAtlas(positionSTS);
    #endif
}

float GetCascadedShadow(DirectionalShadowData directional ,ShadowData global, Surface surfaceWS){    
    float3 normalBias = surfaceWS.normal * (directional.normalBias * _CascadeData[global.cascadeIndex].y);
    float3 positionSTS = mul(       //STS = shadow tile space   阴影图块空间
        _DirectionalShadowMatrices[directional.tileIndex],
        float4(surfaceWS.position + normalBias ,1.0)
    ).xyz;
    float shadow = FilterDirectionalShadow(positionSTS);
    if(global.cascadeBlend < 1.0){
        normalBias = surfaceWS.normal * (directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
        positionSTS = mul(
            _DirectionalShadowMatrices[directional.tileIndex + 1],
            float4(surfaceWS.position + normalBias ,1.0)
        ).xyz;
        shadow = lerp(FilterDirectionalShadow(positionSTS),shadow,global.cascadeBlend);
    }
    return shadow;
}

float GetBakedShadow(ShadowMask mask,int channel){
    float shadow = 1.0;
    if(mask.always || mask.distance){
        if(channel >= 0){
            shadow = mask.shadows[channel];
        }
    }
    return shadow;
}

float GetBakedShadow(ShadowMask mask,int channel , float strength){
    if(mask.always || mask.distance){
        return lerp(1.0,GetBakedShadow(mask,channel),strength);
    }
    return 1.0;
}

float MixBakedAndRealTimeShadows(ShadowData global,float shadow,int shadowMaskChannel ,float strength){
    float baked = GetBakedShadow(global.shadowMask,shadowMaskChannel);
    if(global.shadowMask.always){
        shadow = lerp(1.0,shadow,global.strength);
        shadow = min(baked,shadow);
        return lerp(1.0,shadow,strength);
    }
    if(global.shadowMask.distance){
        shadow = lerp(baked,shadow,global.strength);
        return lerp(1.0,shadow,strength);
    }
    return lerp(1.0,shadow,strength * global.strength);
}

float GetDirectionalShadowAttenuation(DirectionalShadowData directional ,ShadowData global, Surface surfaceWS){
    #if !defined(_RECEIVE_SHADOWS)
		return 1.0;
	#endif
	
	float shadow;
    if(directional.strength * global.strength <= 0){
        shadow = GetBakedShadow(global.shadowMask,directional.shadowMaskChannel ,abs(directional.strength));
    }
    else{
        shadow = GetCascadedShadow(directional,global,surfaceWS);
        shadow = MixBakedAndRealTimeShadows(global,shadow,directional.shadowMaskChannel,directional.strength);
    }
    
    return shadow;
}

#endif