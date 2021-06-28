Shader "Costom RP/Lit"
{
    Properties{
        _BaseMap("Texture",2D) = "white"{}
        _BaseColor("Color",Color) = (0.5,0.5,0.5,1.0)
        _Cutoff("Alpha Cutoff",Range(0,1)) = 0.5
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping",Float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
        [KeywordEnum(On,Clip,Dither,Off)] _Shadows("Shadows",Float) = 0
        
        _Metallic("Metallic",Range(0,1)) = 0
        _Smoothness("Smoothness",Range(0,1)) = 0.5
        
        [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha",Float) = 0
        
        //默认值表示我们使用不透明混合配置，源设置为1，表示完全添加，而目标设置为0，表示忽略
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("Src Blend",Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("Dst Blend",Float) = 0
        
        [Enum(Off,0,On,1)] _ZWrite("Z Write",Float) = 1
    }
    
    SubShader{
        Pass{
            Tags{
                "LightMode" = "CustomLit"
            }
        
            //想使用着色器属性，可以通过将其放在方括号内来访问它们
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
        
            HLSLPROGRAM
            #pragma target 3.5
            //pragma 一词来自希腊语，指的是一种行动，或一些需要做的事情。
            #pragma multi_compile_instancing
            #pragma shader_feature _CLIPPING
			#pragma shader_feature _RECEIVE_SHADOWS
            #pragma shader_feature _PREMULTIPLY_ALPHA
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #include "LitPass.hlsl"
            
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
    
    //这告诉Unity编辑器使用CustomShaderGUI类的实例来绘制使用Lit着色器的材质的检查器。
    CustomEditor "CustomShaderGUI"
}