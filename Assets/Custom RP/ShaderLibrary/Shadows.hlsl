#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

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
    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];  //如果修改数组长度，Unity将抱怨着色器的数组大小已更改，但无法使用新的大小。这是因为一旦着色器声明了固定数组，就无法在同一会话期间在GPU上更改其大小。我们需要重新启动Unity才能对其进行初始化。
CBUFFER_END

struct ShadowData{
    int cascadeIndex;
};

ShadowData GetShadowData(Surface surfaceWS){
    ShadowData data;
    int i;
    for(i = 0 ; i < _CascadeCount ; i++){
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surfaceWS.position , sphere.xyz);
        if(distanceSqr < sphere.w){
            break;
        }
    }
    data.cascadeIndex = i;
    return data;
}

struct DirectionalShadowData{
    float strength;
    int tileIndex;
};

//该函数通过SAMPLE_TEXTURE2D_SHADOW宏对阴影图集进行采样，并向其传递图集，阴影采样器以及阴影纹理空间中的位置（这是一个对应的参数）。
float SampleDirectionalShadowAtlas (float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

float GetDirectionalShadowAttenuation(DirectionalShadowData directional , Surface surfaceWS){
    if(directional.strength <= 0){
        return 1.0;
    }
    float3 positionSTS = mul(
        _DirectionalShadowMatrices[directional.tileIndex],
        float4(surfaceWS.position,1.0)
    ).xyz;
    float shadow = SampleDirectionalShadowAtlas(positionSTS);
    return lerp(1.0,shadow,directional.strength);
}

#endif