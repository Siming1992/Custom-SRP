#ifndef CUSTOM_SHADOWCASTER_PASS_INCLUDED
#define CUSTOM_SHADOWCASTER_PASS_INCLUDED

struct Attributes{
    float3 positionCS : POSITION;
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varying{
    float4 positionCS : SV_POSITION;
    //这里我们不需要添加特殊含义，只是传递的数据并不需要让GPU关注。但是，基于语法，我们仍然必须赋予它一些含义。所以可以给它添加任何 unused 的标识符，这里就简单地使用VAR_BASE_UV。
    float2 baseUV : VAR_BASE_UV;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// - UNITY_SETUP_INSTANCE_ID        Should be used at the very beginning of the vertex shader / fragment shader,
//                                  so that succeeding code can have access to the global unity_InstanceID.
//                                  Also procedural function is called to setup instance data.
// - UNITY_TRANSFER_INSTANCE_ID     Copy instance ID from input struct to output struct. Used in vertex shader.

Varying ShadowCasterPassVertex(Attributes input){
    Varying output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    float3 postionWS = TransformObjectToWorld(input.positionCS);
    output.positionCS = TransformWorldToHClip(postionWS);
    //将顶点位置固定到近平面(解决Shadow Pancaking)
    //我们通过获取剪辑空间Z和W坐标的最大值或定义UNITY_REVERSED_Z时的最小值来做到这一点。要将正确的符号用于W坐标，请乘以UNITY_NEAR_CLIP_VALUE。
    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z , output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
        output.positionCS.z = max(output.positionCS.z , output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
    
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

void ShadowCasterPassFragment(Varying input){
    UNITY_SETUP_INSTANCE_ID(input);
    float4 base = GetBase(input.baseUV);
    #if defined(_SHADOWS_CLIP)
        clip(base.a - GetCutoff(input.baseUV));
    #elif defined(_SHADOWS_DITHER)
		float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
		clip(base.a - dither);
    #endif
}

#endif
