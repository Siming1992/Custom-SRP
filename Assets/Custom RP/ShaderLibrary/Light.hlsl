#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_OTHER_LIGHT_COUNT 64

CBUFFER_START(_CustomLight)
    int _DirectionalLightCount;
    float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
    
    int _OtherLightCount;
    float4 _OtherLightColors[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightPositions[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightDirections[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightSpotAngles[MAX_OTHER_LIGHT_COUNT];
    float4 _OhterLightShadowData[MAX_OTHER_LIGHT_COUNT];
CBUFFER_END

struct Light {
    float3 color;
    float3 direction;
    float attenuation;
};

int GetDirectionalLightCount(){
    return _DirectionalLightCount;
}

int GetOtherLightCount(){
    return _OtherLightCount;
}

DirectionalShadowData GetDirectionalShadowData(int lightIndex,ShadowData shadowData){
    DirectionalShadowData data;
    data.strength =  _DirectionalLightShadowData[lightIndex].x ;//* shadowData.strength;     //_DirectionalLightShadowData在Shadows.cs的ReserveDirectionalShadows方法中赋值
    data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
    data.normalBias = _DirectionalLightShadowData[lightIndex].z;
    data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
    return data;
}

OtherShadowData GetOtherShadowData(int lightIndex , ShadowData shadowData){
    OtherShadowData data;
    data.strength = _OhterLightShadowData[lightIndex].x;
    data.shadowMaskChannel = _OhterLightShadowData[lightIndex].w;
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

Light GetOtherLight(int index, Surface surfaceWS,ShadowData shadowData){
    Light light;
    light.color = _OtherLightColors[index].rgb;
    float3 ray = _OtherLightPositions[index].xyz - surfaceWS.position;
    light.direction = normalize(ray);
    float distanceSqr = max(dot(ray,ray),0.00001);
    //max(0,1−(d2 /r2)2)2
    float rangeAttenuation = Square(
        saturate(1.0 - Square(distanceSqr * _OtherLightPositions[index].w))
    );
    float4 spotAngle = _OtherLightSpotAngles[index];
    float spotAttenuation = Square(saturate(dot(_OtherLightDirections[index].xyz , light.direction) * spotAngle.x + spotAngle.y));
    OtherShadowData otherShadowData = GetOtherShadowData(index , shadowData);
    light.attenuation = GetOtherShadowAttenuation(otherShadowData,shadowData,surfaceWS) *  
        spotAttenuation * rangeAttenuation / distanceSqr;
    return light;
}

#endif