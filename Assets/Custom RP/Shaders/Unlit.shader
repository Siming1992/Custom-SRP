Shader "Costom RP/Unlit"
{
    Properties{
        _BaseMap("Texture",2D) = "white"{}
        [HDR] _BaseColor("Color",Color) = (1.0,1.0,1.0,1.0)
        _Cutoff("Alpha Cutoff",Range(0,1)) = 0.5
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping",Float) = 0
        //默认值表示我们使用不透明混合配置，源设置为1，表示完全添加，而目标设置为0，表示忽略
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("Src Blend",Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("Dst Blend",Float) = 0
        
        [Enum(Off,0,On,1)] _ZWrite("Z Write",Float) = 1
    }
    
    SubShader{
		HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl"
		#include "UnLitInput.hlsl"
		ENDHLSL
		
        Pass{
            //想使用着色器属性，可以通过将其放在方括号内来访问它们
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
        
            HLSLPROGRAM
            #pragma target 3.5
            //pragma 一词来自希腊语，指的是一种行动，或一些需要做的事情。
            #pragma multi_compile_instancing
            #pragma shader_feature _CLIPPING
            
            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment
            #include "UnlitPass.hlsl"
            
            ENDHLSL
        }
        
        Pass{
            Tags{"LightMode" = "ShadowCaster"}
            
            ColorMask 0
            
            HLSLPROGRAM
            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
            #pragma multi_compile_instancing
            
            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment            
            #include "ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "CustomShaderGUI"
}