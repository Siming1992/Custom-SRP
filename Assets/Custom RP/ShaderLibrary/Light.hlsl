#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4

CBUFFER_START(_CustomLight)
    int _DirectionalLightCount;
    float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

struct Light {
    float3 color;
    float3 direction;
    float attenuation;
};

int GetDirectionalLightCount(){
    return _DirectionalLightCount;
}

DirectionalShadowData GetDirectionalShadowData(int lightIndex,ShadowData shadowData){
    DirectionalShadowData data;
    data.strength =  _DirectionalLightShadowData[lightIndex].x ;//* shadowData.strength;     //_DirectionalLightShadowData在Shadows.cs的ReserveDirectionalShadows方法中赋值
    data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
    data.normalBias = _DirectionalLightShadowData[lightIndex].z;
    data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
    return data;
}

Light GetDirectionalLight(int index , Surface surfaceWS , ShadowData shadowData){
    Light light ;
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;
    DirectionalShadowData dirShadowData = GetDirectionalShadowData(index,shadowData);
    light.attenuation = GetDirectionalShadowAttenuation(dirShadowData,shadowData,surfaceWS);
    //light.attenuation = shadowData.cascadeIndex*0.25;             //我们可以用级联索引（除以四）代替阴影衰减，使它们更容易被识别。
    return light;
}

#endif