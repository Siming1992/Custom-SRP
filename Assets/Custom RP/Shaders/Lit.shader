Shader "Costom RP/Lit"
{
    Properties{
        _BaseMap("Texture",2D) = "white"{}
        _BaseColor("Color",Color) = (0.5,0.5,0.5,1.0)
        _Cutoff("Alpha Cutoff",Range(0,1)) = 0.5
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping",Float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
        [KeywordEnum(On,Clip,Dither,Off)] _Shadows("Shadows",Float) = 0
        
		[Toggle(_MASK_MAP)] _MaskMapToggle ("Mask Map", Float) = 0
        [NoScaleOffset] _MaskMap("Mask (MODS)",2D) = "white" {}     //代表 Metallic, Occlusion, Detail, and Smoothness, stored in the RGBA channels in that order.
        _Metallic("Metallic",Range(0,1)) = 0
        _Occlusion("Occlusion" , Range(0,1)) = 1
        _Smoothness("Smoothness",Range(0,1)) = 0.5
        _Fresnel("Fresnel",Range(0,1)) = 1
        
		[Toggle(_NORMAL_MAP)] _NormalMapToggle ("Normal Map", Float) = 0
        [NoScaleOffset] _NormalMap("Normals" , 2D) = "bump"{}
        _NormalScale("Normal Scale" , Range(0,1)) = 1 
        [NoScaleOffset] _EmissionMap("Emission" , 2D) = "white"{}
        [HDR] _EmissionColor("Emission",Color) = (0.0,0.0,0.0,0.0)
        
		[Toggle(_DETAIL_MAP)] _DetailMapToggle ("Detail Maps", Float) = 0
        _DetailMap ("Detail" , 2D) = "linearGrey"{}     //ANySNx格式(不理解)，这意味着它在R中存储albedo，在B中存储smoothness，并在AG中存储细节法向矢量的XY分量。我们的贴图不会包含法线向量,仅使用RB通道        
        //为什么不合并两个贴图？
        //虽然这样效率更高，但生成这样的贴图却更加困难。生成Mip贴图时，应将法向矢量与其他数据通道区别对待，而Unity的纹理导入器无法做到这一点。而且，在使Mip贴图淡化时，Unity会忽略Alpha通道，因此该通道中的数据将不会正确变淡。因此，需要在Unity外部或使用脚本自行生成Mip映射。即便那样，我们仍然需要手动解码法线数据，而不是依赖UnpackNormalmapRGorAG。
        [NoScaleOffset] _DetailNormalMap("Detail Normals" , 2D) = "bump"{}  
        _DetailAlbedo("Detail Albedo" , Range(0,1)) = 1
        _DetailSmoothness("Detail Smoothness" , Range(0,1)) = 1
        _DetailNormalScale("Detail Normal Scale" , Range(0,1)) = 1
        
        [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha",Float) = 0
        
        //默认值表示我们使用不透明混合配置，源设置为1，表示完全添加，而目标设置为0，表示忽略
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("Src Blend",Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("Dst Blend",Float) = 0
        
        [Enum(Off,0,On,1)] _ZWrite("Z Write",Float) = 1

		[HideInInspector] _MainTex("Texture for Lightmap", 2D) = "white" {}
		[HideInInspector] _Color("Color for Lightmap", Color) = (0.5, 0.5, 0.5, 1.0)
    }
    
    SubShader{
		HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl"
		#include "LitInput.hlsl"
		ENDHLSL

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
            #pragma shader_feature _CLIPPING
			#pragma shader_feature _RECEIVE_SHADOWS
            #pragma shader_feature _PREMULTIPLY_ALPHA
            
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _MASK_MAP
            #pragma shader_feature _DETAIL_MAP
            
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
            #pragma multi_compile_instancing
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ _LIGHTS_PER_OBJECT
            
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #include "LitPass.hlsl"
            
            ENDHLSL
        }
        
        Pass{
            Tags{"LightMode" = "ShadowCaster"}
            
            ColorMask 0
            
            HLSLPROGRAM
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
            #pragma multi_compile_instancing
            
            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment            
            #include "ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        Pass{
            Tags{
                "LightMode" = "Meta"
            }
                
            Cull Off
            
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex MetaPassVertex
            #pragma fragment MetaPassFragment
            #include "MetaPass.hlsl"
            ENDHLSL
        }
    }
    
    //这告诉Unity编辑器使用CustomShaderGUI类的实例来绘制使用Lit着色器的材质的检查器。
    CustomEditor "CustomShaderGUI"
}