using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
    private static int BaseColorId = Shader.PropertyToID("_BaseColor");
    private static int cutoffId = Shader.PropertyToID("_Cutoff");
    private static int MetallicID = Shader.PropertyToID("_Metallic");
    private static int SmoothnessID = Shader.PropertyToID("_Smoothness");
    private static int emissionColorID = Shader.PropertyToID("_EmissionColor");

    [SerializeField] private Color baseColor = Color.white;

    [SerializeField, ColorUsage(false, true)]
    private Color emissionColor = Color.black;

    private static MaterialPropertyBlock _block;

    [SerializeField, Range(0f, 1f)] private float alphaCutoff = 0.5f;
    [SerializeField, Range(0f, 1f)] private float metallic = 0.5f;
    [SerializeField, Range(0f, 1f)] private float smoothness = 0.5f;
    private void Awake()
    {
        OnValidate();
    }

    private void OnValidate()
    {
        if (_block == null)
        {
            _block = new MaterialPropertyBlock();
        }
        
        _block.SetColor(BaseColorId,baseColor);
        _block.SetFloat(cutoffId,alphaCutoff);
        _block.SetFloat(MetallicID,metallic);
        _block.SetFloat(SmoothnessID,smoothness);
        _block.SetColor(emissionColorID,emissionColor);
        GetComponent<Renderer>().SetPropertyBlock(_block);
    }
}
