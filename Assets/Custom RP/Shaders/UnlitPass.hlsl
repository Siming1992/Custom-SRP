#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED

struct Attributes{
    float3 postionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varying{
    float4 positioCS : SV_POSITION;
    //这里我们不需要添加特殊含义，只是传递的数据并不需要让GPU关注。但是，基于语法，我们仍然必须赋予它一些含义。所以可以给它添加任何 unused 的标识符，这里就简单地使用VAR_BASE_UV。
    float2 baseUV : VAR_BASE_UV;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// - UNITY_SETUP_INSTANCE_ID        Should be used at the very beginning of the vertex shader / fragment shader,
//                                  so that succeeding code can have access to the global unity_InstanceID.
//                                  Also procedural function is called to setup instance data.
// - UNITY_TRANSFER_INSTANCE_ID     Copy instance ID from input struct to output struct. Used in vertex shader.

Varying UnlitPassVertex(Attributes input){
    Varying output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    float3 postionWS = TransformObjectToWorld(input.postionOS);
    output.positioCS = TransformWorldToHClip(postionWS);
    
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

float4 UnlitPassFragment(Varying input):SV_TARGET{
    UNITY_SETUP_INSTANCE_ID(input);
    
	InputConfig config = GetInputConfig(input.baseUV);
    float4 base = GetBase(config);
    #if defined(_CLIPPING)
        clip(base.a - GetCutoff(config);
    #endif
    return base;
}

#endif
