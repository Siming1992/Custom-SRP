#ifndef CUSTOM_META_PASS_INCLUDED
#define CUSTOM_META_PASS_INCLUDED

//由于间接漫反射光会从表面反射，因此应该受到这些表面的漫反射率的影响。
//我们需要知道表面的漫反射率，因此我们必须在MetaPassFragment中获取其BRDF数据。因此，我们必须包含BRDF，还要加上Surface, Shadows 和Light 

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"

bool4 unity_MetaFragmentControl;
float unity_OneOverOutputBoost;
float unity_MaxOutputValue;

struct Attributes{
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    float2 lightMapUV :TEXCOORD1;
};

struct Varyings{
    float4 positionCS : SV_POSITION;
    float2 baseUV : VAR_BASE_UV;
};

Varyings MetaPassVertex(Attributes input){
    Varyings output;
    input.positionOS.xy = input.lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
    input.positionOS.z = input.positionOS.z > 0.0 ? FLT_MIN : 0.0;
    output.positionCS = TransformWorldToHClip(input.positionOS);
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

float4 MetaPassFragment(Varyings input) : SV_TARGET{
    float4 base = GetBase(input.baseUV);
    Surface surface;
    ZERO_INITIALIZE(Surface,surface);   //将表面初始化为零
    surface.color = base.rgb;
    surface.metallic = GetMetallic(input.baseUV);
    surface.smoothness = GetSmoothness(input.baseUV);
    BRDF brdf = GetBRDF(surface);
    float4 meta = 0.0;
    if(unity_MetaFragmentControl.x){
        meta = float4(brdf.diffuse , 1.0);
        meta.rgb += brdf.specular * brdf.roughness * 0.5;
        meta.rgb = min(
            PositivePow(meta.rgb,unity_OneOverOutputBoost),unity_MaxOutputValue
        );
    }else if(unity_MetaFragmentControl.y){              //unity_MetaFragmentControl.y 由 MaterialEditor.LightmapEmissionProperty()控制
        meta = float4(GetEmission(input.baseUV),1.0);
    }
    
    return meta;
}

#endif
