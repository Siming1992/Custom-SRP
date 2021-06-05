
using System.Collections.Generic;
using UnityEngine;

public class FindKeyWords : MonoBehaviour
{
    public Material[] Materials;

    Dictionary<string,int> keywordRenderQueueModifier = new Dictionary<string, int>();
    
    private void Start()
    {
        foreach (var material in Materials)
        {
            KeyWordLog(material);
        }
    }

    void KeyWordLog(Material mat)
    {
        
        if (mat.shaderKeywords.Length > 0)
        {
            var keywords = "";
 
            foreach (var shaderKeyword in mat.shaderKeywords)
                keywords += shaderKeyword + ",";
            
            Debug.Log(string.Format($"{mat.shader.name} has additional keywords: {keywords}"));
            //
            // if (!keywordRenderQueueModifier.ContainsKey(keywords))
            //     keywordRenderQueueModifier.Add(keywords, keywordRenderQueueModifier.Count + 1);
            //
            // Debug.Log(string.Format($"keywordRenderQueueModifier[{mat.shader.name}][{keywords}]={keywordRenderQueueModifier[mat.shader.name][keywords]}"));
            // mat.renderQueue += keywordRenderQueueModifier[keywords];
        }
    }
}
