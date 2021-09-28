#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

TEXTURE2D(unity_Lightmap);      //光照贴图纹理叫 unity_Lightmap，包含在Core RP Library中的EnityLighting.hlsl里
SAMPLER(samplerunity_Lightmap);

TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

TEXTURECUBE(unity_SpecCube0);
SAMPLER(samplerunity_SpecCube0);

//探针代理集数据以3D float格式的纹理存储，称为unity_ProbeVolumeSH。
TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

#if defined(LIGHTMAP_ON)
    #define GI_ATTRIBUTE_DATA float2 lightMapUV : TEXCOORD1;
    #define GI_VARYINGS_DATA float2 lightMapUV : VAR_LIGHT_MAP_UV;
    //如果每个宏的末尾（除最后一行）都标有反斜杠，则可以将宏定义分成多行。
    #define TRANSFER_GI_DATA(input,output)  \
        output.lightMapUV = input.lightMapUV * \
        unity_LightmapST.xy + unity_LightmapST.zw;
    #define GI_FRAGMENT_DATA(input) input.lightMapUV
#else
    #define GI_ATTRIBUTE_DATA
    #define GI_VARYINGS_DATA
    #define TRANSFER_GI_DATA(input,output)
    #define GI_FRAGMENT_DATA(input) 0.0
#endif

struct GI{
    float3 diffuse;
    float3 specular;
    ShadowMask shadowMask;
};

//该函数在有光照贴图时调用SampleSingleLightmap，否则返回零。在GetGI中使用它来设置漫射光。
float3 SampleLightMap(float2 lightMapUV){
    #if defined(LIGHTMAP_ON)
        return SampleSingleLightmap(            //SampleSingleLightmap 函数包含在 EnityLighting.hlsl
            TEXTURE2D_ARGS(unity_Lightmap,samplerunity_Lightmap),lightMapUV,
            float4(1.0,1.0,0.0,0.0),
            #if defined(UNITY_LIGHTMAP_FULL_HDR)
                false,
            #else
                true,
            #endif
            float4(LIGHTMAP_HDR_MULTIPLIER,LIGHTMAP_HDR_EXPONENT,0.0,0.0)
        );
    #else
        return 0.0;
    #endif
}
//如果此对象正在使用光照贴图，则返回零。否则，返回零和SampleSH9的最大值。
    float3 SampleLightProbe(Surface surfaceWS){
    #if defined(LIGHTMAP_ON)
        return 0.0;
    #else
        if(unity_ProbeVolumeParams.x){
            return SampleProbeVolumeSH4(
                TEXTURE3D_ARGS(unity_ProbeVolumeSH,samplerunity_ProbeVolumeSH),
                surfaceWS.position,surfaceWS.normal,
                unity_ProbeVolumeWorldToObject,
                unity_ProbeVolumeParams.y,unity_ProbeVolumeParams.z,
                unity_ProbeVolumeMin.xyz,unity_ProbeVolumeSizeInv.xyz
            );
        }else{    
            float4 coefficients[7];    
            coefficients[0] = unity_SHAr;
            coefficients[1] = unity_SHAg;
            coefficients[2] = unity_SHAb;
            coefficients[3] = unity_SHBr;
            coefficients[4] = unity_SHBg;
            coefficients[5] = unity_SHBb;
            coefficients[6] = unity_SHC;
            return max(0.0,SampleSH9(coefficients,surfaceWS.normal));
        }
    #endif
}

float4 SampleBakeShadows(float2 lightMapUV,Surface surfaceWS){
    #if defined (LIGHTMAP_ON)
        return SAMPLE_TEXTURE2D(
            unity_ShadowMask,samplerunity_ShadowMask,lightMapUV
        );
    #else
        if(unity_ProbeVolumeParams.x){
            return SampleProbeOcclusion(
                TEXTURE3D_ARGS(unity_ProbeVolumeSH,samplerunity_ProbeVolumeSH),
                surfaceWS.position,unity_ProbeVolumeWorldToObject,
                unity_ProbeVolumeParams.y,unity_ProbeVolumeParams.z,
                unity_ProbeVolumeMin.xyz,unity_ProbeVolumeSizeInv.xyz
            );
        }
        else{
            return unity_ProbesOcclusion;
        }
    #endif
}

float3 SampleEnvironment(Surface surfaceWS , BRDF brdf){
    float3 uvw = reflect(-surfaceWS.viewDirection,surfaceWS.normal);        //立方体贴图的采样是通过一个方向完成的，这里是从相机到表面反射的表面的视图方向。
    float mip = PerceptualRoughnessToMipmapLevel(brdf.perceptualRoughness);     //PerceptualRoughnessToMipmapLevel被定义在ImageBasedLighting.hlsl
    float4 environment = SAMPLE_TEXTURECUBE_LOD(
        unity_SpecCube0,samplerunity_SpecCube0,uvw,mip
    );
    return DecodeHDREnvironment(environment,unity_SpecCube0_HDR);
}

GI GetGI(float2 lightMapUV,Surface surfaceWS , BRDF brdf){
    GI gi;
    gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surfaceWS);
    gi.specular = SampleEnvironment(surfaceWS,brdf);
    gi.shadowMask.always = false;
    gi.shadowMask.distance = false;
    gi.shadowMask.shadows = 1.0;
    
    #if defined(_SHADOW_MASK_ALWAYS)
        gi.shadowMask.always = true;
        gi.shadowMask.shadows = SampleBakeShadows(lightMapUV,surfaceWS);
    #elif defined(_SHADOW_MASK_DISTANCE)
        gi.shadowMask.distance = true;
        gi.shadowMask.shadows = SampleBakeShadows(lightMapUV,surfaceWS);
    #endif
    return gi;
}

#endif
