using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;


public class CustomShaderGUI : ShaderGUI
{
    private MaterialEditor _materialEditor;
    private Object[] _materials;
    private MaterialProperty[] _properties;

    private bool _showPresets;
    
    public enum ShadowMode
    {
        On,Clip,Dither,Off
    }

    public ShadowMode shadowModes
    {
        set
        {
            if (SetProperty("_Shadows",(float)value))
            {
                SetKeyword("_SHADOWS_CLIP", value == ShadowMode.Clip);
                SetKeyword("_SHADOWS_DITHER", value == ShadowMode.Dither);
            }
        }
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUI.BeginChangeCheck();
        base.OnGUI(materialEditor,properties);
        _materialEditor = materialEditor;
        _materials = materialEditor.targets;
        _properties = properties;
        
		BakedEmission();
        
        EditorGUILayout.Space();
        _showPresets = EditorGUILayout.Foldout(_showPresets, "Presets", true);
        if (_showPresets)
        {
            OpaquePreset();
            ClipPreset();
            FadePreset();
            TransparentPreset();   
        }
        if (EditorGUI.EndChangeCheck()) {
            SetShadowCasterPass();
            CopyLightMappingProperties();
        }
    }

    void CopyLightMappingProperties()
    {
        MaterialProperty mainTex = FindProperty("_MainTex", _properties, false);
        MaterialProperty baseMap = FindProperty("_BaseMap", _properties, false);
        if (mainTex != null && baseMap != null)
        {
            mainTex.textureValue = baseMap.textureValue;
            mainTex.textureScaleAndOffset = baseMap.textureScaleAndOffset;
        }
        MaterialProperty color = FindProperty("_Color",_properties,false);
        MaterialProperty baseColor = FindProperty("_BaseColor",_properties,false);
        if (color != null && baseColor != null)
        {
            color.colorValue = baseColor.colorValue;
        }
    }

    void BakedEmission () {
        EditorGUI.BeginChangeCheck();
        _materialEditor.LightmapEmissionProperty();        //仅影响自发光的烘焙
        //Unity会积极尝试避免在烘焙时使用单独的emission通道。如果材质的emission 设置为零的话，还会直接将其忽略。
        //但是，它没有限制单个对象的材质属性。通过更改emission mode，被选定的材质的globalIlluminationFlags属性的默MaterialGlobalIlluminationFlags.EmissiveIsBlack标志，可以覆盖该结果。这意味着你仅应在需要时才启用“Baked ”选项。
        if (EditorGUI.EndChangeCheck()) {
            foreach (Material m in _materialEditor.targets) {
                m.globalIlluminationFlags &=
                    ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }
    }
    
    void SetShadowCasterPass()
    {
        MaterialProperty shadows = FindProperty("_Shadows", _properties, false);
        if (shadows == null || shadows.hasMixedValue)
        {
            return;
        }
        bool enabled = shadows.floatValue < (float)ShadowMode.Off;
        foreach (Material m in _materials) {
            m.SetShaderPassEnabled("ShadowCaster", enabled);
        }
    }

    void SetKeyword(string keyword,bool enabled)
    {
        if (enabled)
        {
            foreach (Material material in _materials)
            {
                material.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material material in _materials)
            {
                material.DisableKeyword(keyword);
            }
        }
    }

    //要设置属性，我们首先必须在数组中找到它，为此我们可以使用ShaderGUI.FindPropery方法，并为其传递一个名称和属性数组。然后，通过分配其floatValue属性来调整其值。使用名称和值参数将其封装在方便的SetProperty方法中。
    bool SetProperty(string name ,float value)
    {
        MaterialProperty property = FindProperty(name, _properties,false);
        if (property != null)
        {
            property.floatValue = value;
            return true;
        }
        return false;
    }

    void SetProperty(string name ,string keyword , bool value)
    {
        if (SetProperty(name, value ? 1f : 0f))
        {
            SetKeyword(keyword, value);
        }
    }

    bool PresetButton(string name)
    {
        if (GUILayout.Button(name))
        {
            _materialEditor.RegisterPropertyChangeUndo(name);
            return true;
        }
        return false;
    }

    void OpaquePreset()
    {
        if (PresetButton("Opaque"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            Srcblend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.Geometry;
        }
    }

    void ClipPreset()
    {
        if (PresetButton("Clip"))
        {
            Clipping = true;
            PremultiplyAlpha = false;
            Srcblend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.AlphaTest;
        }
    }

    void FadePreset()
    {
        if (PresetButton("Fade"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            Srcblend = BlendMode.SrcAlpha;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
        }
    }

    void TransparentPreset()
    {
        if (HasPremultipAlpha && PresetButton("Transparent"))
        {
            Clipping = false;
            PremultiplyAlpha = true;
            Srcblend = BlendMode.One;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
        }
    }

    bool HasProperty(string name) => FindProperty(name, _properties, false) != null;
    private bool HasPremultipAlpha => HasProperty("_PremulAlpha");
    
    private bool Clipping
    {
        set => SetProperty("_Clipping", "_CLIPPING", value);
    }

    private bool PremultiplyAlpha
    {
        set => SetProperty("_PremulAlpha", "_PREMULTIPLY_ALPHA", value);
    }

    private BlendMode Srcblend
    {
        set => SetProperty("_SreBlend", (float) value);
    }

    private BlendMode DstBlend
    {
        set => SetProperty("_DstBlend", (float) value);
    }

    private bool ZWrite
    {
        set => SetProperty("_ZWrite", value ? 1f : 0f);
    }

    RenderQueue RenderQueue
    {
        set
        {
            foreach (Material mat in _materials)
            {
                mat.renderQueue = (int) value;
            }
        }
    }
}
