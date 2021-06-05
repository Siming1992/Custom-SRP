#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT 4

CBUFFER_START(_CustomLight)
    int _DirectionalLightCount;
    float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT];
    float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT];
    //float3 _DirectionalLightColor;
    //float3 _DirectionalLightDirection;
CBUFFER_END

struct Light {
    float3 color;
    float3 direction;
};

int GetDirectionalLightCount(){
    return _DirectionalLightCount;
}

Light GetDirectionalLight(int index){
    Light light ;
    light.color = _DirectionalLightColors[index];
    light.direction = _DirectionalLightDirections[index];
    return light;
}

#endif