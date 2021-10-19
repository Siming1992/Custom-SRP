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

#if defined(_OTHER_PCF3)
	#define OTHER_FILTER_SAMPLES 4
	#define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_OTHER_PCF5)
	#define OTHER_FILTER_SAMPLES 9
	#define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_OTHER_PCF7)
	#define OTHER_FILTER_SAMPLES 16
	#define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_SHADOWED_OTHER_LIGHT_COUNT 16
#define MAX_CASCADE_COUNT 4

//由于图集不是常规的纹理，因此我们可以通过TEXTURE2D_SHADOW宏对其进行定义，即使它对我们支持的平台没有影响，也要使其清晰可见。
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
TEXTURE2D_SHADOW(_OtherShadowAtlas);
//实际上，只有一种合适的方法可以对阴影贴图进行采样，因此我们可以定义一个明确的采样器状态，而不是依赖Unity推导的渲染纹理状态。可以内联定义采样器状态，方法是在其名称中创建一个带有特定单词的状态。我们可以使用sampler_linear_clamp_compare。我们还为其定义一个简写的SHADOW_SAMPLER宏。
#define SHADOW_SAMPLER sampler_linear_clamp_compare
//我们将使用一个特殊的SAMPLER_CMP宏来定义采样器状态，因为这确实定义了一种不同的方式来采样阴影贴图，因为常规的双线性过滤对深度数据没有意义。
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadow)
    int _CascadeCount;
    float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    float4 _CascadeData[MAX_CASCADE_COUNT];
    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];  //如果修改数组长度，Unity将抱怨着色器的数组大小已更改，但无法使用新的大小。这是因为一旦着色器声明了固定数组，就无法在同一会话期间在GPU上更改其大小。我们需要重新启动Unity才能对其进行初始化。
    float4x4 _OtherShadowMatrices[MAX_SHADOWED_OTHER_LIGHT_COUNT];
    float4 _OtherShadowTiles[MAX_SHADOWED_OTHER_LIGHT_COUNT];
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
    if(i == _CascadeCount && _CascadeCount > 0){
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

struct OtherShadowData{
    float strength;
    int tileIndex;
    bool isPoint;
    int shadowMaskChannel;
    //要根据与光平面的距离对其进行缩放(法线偏差)，我们需要知道世界空间的光位置和光斑方向
    float3 lightPositionWS;
    float3 lightDirectionWS;
    float3 spotDirectionWS;
};

//该函数通过SAMPLE_TEXTURE2D_SHADOW宏对阴影图集进行采样，并向其传递图集，阴影采样器以及阴影纹理空间中的位置（这是一个对应的参数）。
//当坐标的z值小于阴影映射纹理中的深度值时，SAMPLE_TEXTURE2D_SHADOW返回1，这意味着该点距离光源更近，不在阴影中。否则，该宏返回值为0意味着该点在阴影中。因为采样器在双线性插值之前执行比较，所以阴影的边缘将混合阴影映射纹理的纹素。
float SampleDirectionalShadowAtlas (float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

float SampleOtherShadowAtlas(float3 positionSTS , float3 bounds){
    positionSTS.xy = clamp(positionSTS.xy , bounds.xy , bounds.xy + bounds.z);
	return SAMPLE_TEXTURE2D_SHADOW(
		_OtherShadowAtlas, SHADOW_SAMPLER, positionSTS
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

float FilterOtherShadow(float3 positionSTS , float3 bounds){
    #if defined(OTHER_FILTER_SETUP)
        real weights[OTHER_FILTER_SAMPLES];
        real2 positions[OTHER_FILTER_SAMPLES];
        float4 size = _ShadowAtlasSize.wwzz;
		OTHER_FILTER_SETUP(size, positionSTS.xy, weights, positions);   
        float shadow = 0;
		for (int i = 0; i < OTHER_FILTER_SAMPLES; i++) {
			shadow += weights[i] * SampleOtherShadowAtlas(
				float3(positions[i].xy, positionSTS.z) , bounds
			);
        }
        return shadow;
    #else
        return SampleOtherShadowAtlas(positionSTS , bounds);
    #endif
}

float GetCascadedShadow(DirectionalShadowData directional ,ShadowData global, Surface surfaceWS){    
    float3 normalBias = surfaceWS.interpolatedNormal * (directional.normalBias * _CascadeData[global.cascadeIndex].y);
    float3 positionSTS = mul(       //STS = shadow tile space   阴影图块空间
        _DirectionalShadowMatrices[directional.tileIndex],
        float4(surfaceWS.position + normalBias ,1.0)
    ).xyz;
    float shadow = FilterDirectionalShadow(positionSTS);
    if(global.cascadeBlend < 1.0){
        normalBias = surfaceWS.interpolatedNormal * (directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
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

static const float3 pointShadowPlanes[6] = {
  float3(-1.0,0.0,0.0),
  float3(1.0,0.0,0.0),
  float3(0.0,-1.0,0.0),  
  float3(0.0,1.0,0.0), 
  float3(0.0,0.0,-1.0),  
  float3(0.0,0.0,1.0), 
};

float GetOtherShadow(OtherShadowData other ,ShadowData global, Surface surfaceWS){
    float tileIndex = other.tileIndex;
    float3 lightPlane = other.spotDirectionWS;
    if(other.isPoint){
        float faceOffset = CubeMapFaceID(-other.lightDirectionWS);
        tileIndex += faceOffset;
        lightPlane = pointShadowPlanes[faceOffset];
    }
    float4 tileData = _OtherShadowTiles[tileIndex];
    float3 surfaceToLight = other.lightPositionWS - surfaceWS.position;
    float distanceToLightPlane = dot(surfaceToLight,lightPlane);
	float3 normalBias = surfaceWS.interpolatedNormal * (distanceToLightPlane * tileData.w);
	float4 positionSTS = mul(
		_OtherShadowMatrices[tileIndex],
		float4(surfaceWS.position + normalBias, 1.0)
	);
	return FilterOtherShadow(positionSTS.xyz / positionSTS.w , tileData.xyz);
}

float GetOtherShadowAttenuation(OtherShadowData other,ShadowData global,Surface surfaceWS){
    #if !defined(_RECEIVE_SHADOWS)
        return 1.0;
    #endif
    float shadow;
    
    //全局强度用于确定我们是否可以跳过采样实时阴影，因为我们超出了阴影距离或超出了最大的级联球体。
    //但是，级联仅适用于定向阴影。它们对其他光线没有意义，因为它们的位置是固定的，因此它们的阴影贴图不会随着视图移动。
    //话虽如此，以相同的方式淡出所有阴影是个好主意，否则我们最终可能会在屏幕上的某些区域没有方向性阴影但有其他阴影。因此，我们将对所有内容使用相同的全局阴影强度。
    if(other.strength * global.strength <= 0){
        shadow = GetBakedShadow(global.shadowMask,other.shadowMaskChannel,abs(other.strength));
    }else{
        shadow = GetOtherShadow(other,global,surfaceWS);
        shadow = MixBakedAndRealTimeShadows(global,shadow,other.shadowMaskChannel,other.strength);
    }
    return shadow;
}

#endif