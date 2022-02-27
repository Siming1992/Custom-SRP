#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

float3 InComingLight(Surface surface , Light light){
    return saturate(dot(surface.normal,light.direction) * light.attenuation) * light.color;
}

float3 GetLighting(Surface surface ,BRDF brdf, Light light){
    return InComingLight(surface,light) * DirectBRDF(surface,brdf,light);
}

bool RenderingLayersOverlap(Surface surface, Light light)
{
    return (surface.renderingLayerMask & light.renderingLayerMask) != 0;
}

float3 GetLighting(Surface surfaceWS , BRDF brdf , GI gi){
    ShadowData shadowData = GetShadowData(surfaceWS);
    shadowData.shadowMask = gi.shadowMask;
    //return gi.shadowMask.shadows.rgb;     //  调试shadowMask信息
    
    float3 color = IndirectBRDF(surfaceWS , brdf , gi.diffuse ,gi.specular);
    for(int i = 0 ; i < GetDirectionalLightCount(); i ++){
        Light light = GetDirectionalLight(i,surfaceWS,shadowData);        
        /*我们不能将检查放在另一个GetLighting函数中吗？
        可以，这样会减少代码量。 但是，在这种情况下， 着色器编译器不会生成分支。如果不需要的话， 灯光总是会被计算和丢弃。
        你可以使用UNITY_BRANCH强制分支， 但是如果跳过灯光时返回零，则仍然可以得到不必要的添加。 这个问题当然也可以被解决解决， 但是此时代码变得有些臃肿。*/
        if (RenderingLayersOverlap(surfaceWS, light))
        {
            color += GetLighting(surfaceWS, brdf, light);
        }
    }
    #if defined(_LIGHTS_PER_OBJECT)
        for(int j = 0;j < min(unity_LightData.y,8) ;j++){
            int lightIndex = unity_LightIndices[(uint)j/4][(uint)j%4];
            Light light = GetOtherLight(lightIndex,surfaceWS,shadowData);
		    if (RenderingLayersOverlap(surfaceWS, light)) {
			    color += GetLighting(surfaceWS, brdf, light);
            }
        }
    #else
        for(int j = 0 ; j < GetOtherLightCount(); j++){
        Light light = GetOtherLight(j, surfaceWS, shadowData);
        if (RenderingLayersOverlap(surfaceWS, light))
        {
            color += GetLighting(surfaceWS, brdf, light);
        }
    }
    #endif
    
    return color;
}

#endif