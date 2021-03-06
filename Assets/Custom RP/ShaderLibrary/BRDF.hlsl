#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

struct BRDF{
    float3 diffuse;
    float3 specular;
    float roughness;
    float perceptualRoughness;
    float fresnel;
};

//实际上，一些光还会从电介质表面反射回来，从而使其具有亮点。
//非金属的反射率有所不同，但平均约为0.04。让我们将其定义为最小反射率，并添加一个OneMinusReflectivity函数，该函数将范围从0~1调整为0~0.96。此范围调整与Universal RP的方法匹配。
//define 后面带 ； 是不可以的，编译会把；也编译进去
#define MIN_REFLECTIVITY 0.04       

float OneMinusReflectivity(float metallic){
    float range = 1.0 - MIN_REFLECTIVITY;
    return range - metallic * range;
}

BRDF GetBRDF(Surface surface,bool applyAlphaToDiffuse = false){
    BRDF brdf;
    float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
    //表现为当金属度为1时，漫反射结果几乎为0（只显示漫反射的话为黑色）；
    brdf.diffuse = surface.color * oneMinusReflectivity;
    if(applyAlphaToDiffuse){
        brdf.diffuse *= surface.alpha;
    }
    brdf.specular = lerp(MIN_REFLECTIVITY,surface.color,surface.metallic);
    
	brdf.perceptualRoughness =
		PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);          //PerceptualSmoothnessToPerceptualRoughness -> 1.0 - surface.smoothness
	brdf.roughness = PerceptualRoughnessToRoughness(brdf.perceptualRoughness);  //PerceptualRoughnessToRoughness -> brdf.perceptualRoughness * brdf.perceptualRoughness
	//我们对菲涅耳使用一个变种的Schlick近似。在理想情况下，它用纯白色代替镜面反射的BRDF颜色，但粗糙度可以防止出现反射。我们通过将表面平滑度和反射率加在一起，得出最终颜色，最大值为1。由于是灰度，因此可以在BRDF上添加单个值就足够了。
	brdf.fresnel = saturate(surface.smoothness + 1 - oneMinusReflectivity);
    return brdf;
}

float SpecularStrength (Surface surface, BRDF brdf, Light light) {
	float3 h = SafeNormalize(light.direction + surface.viewDirection);
	float nh2 = Square(saturate(dot(surface.normal, h)));
	float lh2 = Square(saturate(dot(light.direction, h)));
	float r2 = Square(brdf.roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

float3 DirectBRDF (Surface surface, BRDF brdf, Light light) {
	return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}

float3 IndirectBRDF(Surface surface, BRDF brdf,float3 diffuse,float3 specular){
    float fresnelStrength = surface.fresnelStrength * Pow4(1.0 - saturate(dot(surface.normal,surface.viewDirection))); //我们通过获取表面法线和视图方向的点积，从1中减去该点积，并将结果提高到四次方来求出菲涅耳效应的强度。
    float3 reflection = specular * lerp(brdf.specular,brdf.fresnel,fresnelStrength);
    reflection /= brdf.roughness * brdf.roughness + 1.0 ;
    return (diffuse * brdf.diffuse + reflection) * surface.occlusion;
}

#endif