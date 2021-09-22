#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

float3 InComingLight(Surface surface , Light light){
    return saturate(dot(surface.normal,light.direction) * light.attenuation) * light.color;
}

float3 GetLighting(Surface surface ,BRDF brdf, Light light){
    return InComingLight(surface,light) * DirectBRDF(surface,brdf,light);
}

float3 GetLighting(Surface surfaceWS , BRDF brdf , GI gi){
    ShadowData shadowData = GetShadowData(surfaceWS);
    shadowData.shadowMask = gi.shadowMask;
    //return gi.shadowMask.shadows.rgb;     //  调试shadowMask信息
    
    float3 color = gi.diffuse * brdf.diffuse;
    for(int i = 0 ; i < GetDirectionalLightCount(); i ++){
        Light light = GetDirectionalLight(i,surfaceWS,shadowData);
        color += GetLighting(surfaceWS,brdf,light);
    }
    return color;
}

#endif