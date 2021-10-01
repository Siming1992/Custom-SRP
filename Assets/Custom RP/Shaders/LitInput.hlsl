#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//纹理需要上传到GPU的内存里，这一步Unity会为我们做。着色器需要一个相关纹理的句柄，我们可以像定义一个uniform 值那样定义它，只是我们使用名为TEXTURE2D的宏参数。
TEXTURE2D(_BaseMap);
TEXTURE2D(_MaskMap);
TEXTURE2D(_NormalMap);
TEXTURE2D(_EmissionMap);
//我们还需要为纹理定义一个采样器状态，考虑到wrap 和filter的模式，该状态控制着色器应如何采样。通过SAMPLER宏实现，例如TEXTURE2D，但在名称前添加了sampler。
SAMPLER(sampler_Basemap);
TEXTURE2D(_DetailMap);
TEXTURE2D(_DetailNormalMap);
SAMPLER(sampler_DetailMap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4,_DetailMap_ST);
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4,_EmissionColor)
    UNITY_DEFINE_INSTANCED_PROP(float,_Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float,_Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float,_Occlusion)
    UNITY_DEFINE_INSTANCED_PROP(float,_Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float,_Fresnel)
    UNITY_DEFINE_INSTANCED_PROP(float,_DetailAlbedo)
    UNITY_DEFINE_INSTANCED_PROP(float,_DetailSmoothness)    
    UNITY_DEFINE_INSTANCED_PROP(float,_NormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float,_DetailNormalScale);
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,name)

struct InputConfig{
    float2 baseUV;
    float2 detailUV;
    bool useMask;
    bool useDetail;
};

InputConfig GetInputConfig(float2 baseUV,float2 detailUV = 0.0){
    InputConfig c;
    c.baseUV = baseUV;
    c.detailUV = detailUV;
    c.useMask = false;
    c.useDetail = false;
    return c;
}

float2 TransformBaseUV(float2 baseUV){
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float2 TransformDetailUV(float2 detailUV){
    float4 detailST = INPUT_PROP(_DetailMap_ST);
    return detailUV * detailST.xy + detailST.zw;
}

float4 GetDetail(InputConfig c){
    if(c.useDetail){
        float4 map = SAMPLE_TEXTURE2D(_DetailMap,sampler_DetailMap,c.detailUV);
        //值为0.5是中性的。较高的值应增加或变亮，而较低的值应减少或变暗。进行此工作的第一步是在GetDetail中将详细信息值范围从0~1转换为-1~1。
        return map * 2.0 - 1.0;
    }
    return 0.0;
}

float4 GetMask(InputConfig c){
    if(c.useMask){
        return SAMPLE_TEXTURE2D(_MaskMap,sampler_Basemap,c.baseUV);
    }
    return 1.0;    
}


float4 GetBase(InputConfig c){
    float4 map = SAMPLE_TEXTURE2D(_BaseMap,sampler_Basemap,c.baseUV);
    float4 color = INPUT_PROP(_BaseColor);
    
    if(c.useDetail){
        float detail = GetDetail(c).r * INPUT_PROP(_DetailAlbedo);
        float mask = GetMask(c).b;
        map.rgb = lerp(sqrt(map.rgb) ,detail < 0.0 ? 0.0 : 1.0 , abs(detail) * mask);
        map.rgb *= map.rgb;
    }
    
    return map * color;
}

float3 GetNormalTS(InputConfig c){
    float4 map = SAMPLE_TEXTURE2D(_NormalMap,sampler_Basemap,c.baseUV);
    float scale = INPUT_PROP(_NormalScale);
    float3 normal = DecodeNormal(map,scale);
    
    if(c.useDetail){
        map = SAMPLE_TEXTURE2D(_DetailNormalMap,sampler_DetailMap,c.detailUV);
        scale = INPUT_PROP(_DetailNormalScale) * GetMask(c).b;
        float3 detail = DecodeNormal(map,scale);
        normal = BlendNormalRNM(normal,detail);
    }
    
    return normal;
}

float3 GetEmission(InputConfig c){
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap,sampler_Basemap,c.baseUV);
    float4 color = INPUT_PROP(_EmissionColor);
    return map.rgb * color.rgb; 
}

float GetCutoff(InputConfig c){
    return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig c){
    float metallic =  INPUT_PROP(_Metallic);
    metallic *= GetMask(c).r;
    return metallic;
}

float GetOcclusion(InputConfig c){
    float strength = INPUT_PROP(_Occlusion);
    float occlusion = GetMask(c).g;
    occlusion = lerp(occlusion , 1.0 , strength);
    return occlusion;
}

float GetSmoothness(InputConfig c){
    float smoothness =  INPUT_PROP(_Smoothness);
    smoothness *= GetMask(c).a;
    
    if(c.useDetail){
        float detail = GetDetail(c).b * INPUT_PROP(_DetailSmoothness);
        float mask = GetMask(c).b;
        smoothness = lerp(smoothness , detail < 0.0 ? 0.0 : 1.0 , abs(detail) * mask);
    }
    
    return smoothness;
}

float GetFresnel(InputConfig c){
    return INPUT_PROP(_Fresnel);
}

#endif
