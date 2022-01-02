using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(menuName = "Rendering/Custom Post FX Settings")]
public class PostFXSettings : ScriptableObject
{
    [SerializeField] Shader _shader = default;

    [System.NonSerialized] Material _material;

    public Material Material
    {
        get {
            if (_material == null && _shader != null)
            {
                _material = new Material(_shader);
                _material.hideFlags = HideFlags.HideAndDontSave;
            }
            return _material;
        }
    }
    
    [System.Serializable]
    public struct BloomSettings
    {
        [Range(0f, 16f)] public int maxIterations;
        [Min(1f)] public int downscaleLimit;
        public bool bicubicUpsampling;
        [Min(0f)] public float threshold;
        [Range(0f, 1f)] public float thresholdKnee;
        [Min(0f)] public float intensity;
        public bool fadeFireflies;

        public enum Mode
        {
            Additive,
            Scattering
        }

        public Mode mode;
        [Range(0.05f, 0.95f)] public float scatter;
    }

    [SerializeField] private BloomSettings bloom = new BloomSettings {
        scatter = 0.7f
    };
    public BloomSettings Bloom => bloom;
    
    [System.Serializable]
    public struct ToneMappingSettings
    {
        public enum Mode
        {
            None,
            ACES,
            Neutral,
            Reinhard
        }

        public Mode mode;
    }

    [SerializeField] private ToneMappingSettings toneMapping = default;

    public ToneMappingSettings ToneMapping => toneMapping;

    [Serializable]
    public struct ColorAdjustmentsSettings
    {
        /// <summary>
        /// 曝光度，即不受限制的浮动
        /// </summary>
        public float postExposure;
        /// <summary>
        /// 对比度
        /// </summary>
        [Range(-100f, 100f)] public float contrast;
        [ColorUsage(false, true)] public Color colorFilter;
        /// <summary>
        /// 色相偏移
        /// </summary>
        [Range(-180f, 180f)] public float hueShift;
        /// <summary>
        /// 饱和度
        /// </summary>
        [Range(-100f, 100f)] public float saturation;
    }

    [SerializeField] ColorAdjustmentsSettings colorAdjustments = new ColorAdjustmentsSettings
    {
        colorFilter = Color.white        //默认值都为零，除了颜色过滤器应该是白色。这些设置不会改变图像。
    };

    public ColorAdjustmentsSettings ColorAdjustments => colorAdjustments;
    
    [Serializable]
    public struct WhiteBalanceSettings
    {
        [Range(-100f, 100f)] public float temperature, tint;
    }

    [SerializeField] private WhiteBalanceSettings whiteBalance = default;

    public WhiteBalanceSettings WhiteBalance => whiteBalance;
    
    
    [Serializable]
    public struct SplitToningSettings
    {
        [ColorUsage(false)] public Color shadows, highlights;
        [Range(-100f, 100f)] public float balance;
    }

    [SerializeField] SplitToningSettings splitToning = new SplitToningSettings
    {
        shadows = Color.gray,
        highlights = Color.gray
    };

    public SplitToningSettings SplitToning => splitToning;
    
    [Serializable]
    public struct ChannelMixerSettings
    {
        public Vector3 red, green, blue;
    }
    
    [SerializeField] ChannelMixerSettings channelMixer = new ChannelMixerSettings
    {
        red = Vector3.right,
        green = Vector3.up,
        blue = Vector3.forward
    };

    public ChannelMixerSettings ChannelMixer => channelMixer;
    
    [Serializable] 
    public struct ShadowsMidtonesHighlightsSettings
    {
        [ColorUsage(false, true)] public Color shadows, midtones, highlights;
        
        [Range(0f, 2f)]
        public float shadowsStart, shadowsEnd, highlightsStart, highLightsEnd;
    }
    
    [SerializeField] ShadowsMidtonesHighlightsSettings shadowsMidtonesHighlights = new ShadowsMidtonesHighlightsSettings
    {
        shadows = Color.white,
        midtones = Color.white,
        highlights = Color.white,
        shadowsEnd = 0.3f,
        highlightsStart = 0.55f,
        highLightsEnd = 1f
    };

    public ShadowsMidtonesHighlightsSettings ShadowsMidtonesHighlights => shadowsMidtonesHighlights;
}
