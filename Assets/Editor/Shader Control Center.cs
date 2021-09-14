using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Sprites;
using UnityEngine;


public class ShaderControlCenter : EditorWindow
{
    // string myString = "Hello World";
    // bool groupEnabled;
    // bool myBool = true;
    // float myFloat = 1.23f;
    
    private static Dictionary<string,string> ShaderKey= new Dictionary<string, string>();
    
    // 将名为"My Window"的菜单项添加到 Window 菜单
    // [MenuItem("Window/ShaderControlCenter")]
    public static void ShowWindow()
    {
        //显示现有窗口实例。如果没有，请创建一个。
        EditorWindow.GetWindow(typeof(ShaderControlCenter));
    }
    
    void OnGUI()
    {
        // GUILayout.Label ("Base Settings", EditorStyles.boldLabel);
        // myString = EditorGUILayout.TextField ("Text Field", myString);
        //
        // groupEnabled = EditorGUILayout.BeginToggleGroup ("Optional Settings", groupEnabled);
        //
        // myBool = EditorGUILayout.Toggle ("Toggle", myBool);
        //
        // myFloat = EditorGUILayout.Slider ("Slider", myFloat, -3, 3);
        //
        // // EditorUtility.DisplayProgressBar("设置AssetName名称", "正在设置AssetName名称中ßß...", 0.50f);
        // // EditorUtility.ClearProgressBar();
        //
        // EditorGUILayout.EndToggleGroup ();
    }
    
    //%f代表ctrl+f快捷键 &代表alt  #代表shift
    [MenuItem("Assets/Check the material")]
    static void CheckTheMaterial()
    {
        Debug.Log("查看材质球");
        UnityEngine.Object[] files=Selection.GetFiltered(typeof(UnityEngine.Object), SelectionMode.DeepAssets);
        foreach (var file in files)
        {
            if (file.GetType() == typeof(Material))
            {
                var material = file as Material;
                // Debug.Log("Material :" + material.name + "|\nShader :" + material.shader.name);
                if (ShaderKey.ContainsKey(material.shader.name))
                {
                    ShaderKey[material.shader.name] = ShaderKey[material.shader.name] + "\n    " + material.name;
                }
                else
                {
                    ShaderKey.Add(material.shader.name,"\n    " + material.name);
                }
            }
        }

        string json = DictionaryToJson(ShaderKey);
        File.WriteAllText(Application.dataPath +  "/ShaderKey.json", json);
    }
    
    [MenuItem("Assets/Generate The Atlas",true)]
    static bool CheckType()
    {
        if(Selection.activeObject)
        {
            return Selection.activeObject.GetType() == typeof(Sprite);
        }
        return false;
    }
    [MenuItem("Assets/Generate The Atlas")]
    static void GenerateTheAtlas()
    {
        Sprite sprite = Selection.activeObject as Sprite;
        if(!sprite)
        {
            return;
        }
        
        string atlasName;
        Texture2D texture;
        Packer.GetAtlasDataForSprite(sprite,out atlasName,out texture);
        
        Texture2D png = DuplicateTexture(texture);
        string path = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory) + "/" + atlasName + ".png";
        Debug.Log("图片生成路径：" + path);
        
        byte[] dataBytes = png.EncodeToPNG();
        
        // 将字节保存成图片，这个路径只能在PC端对图片进行读写操作
        File.WriteAllBytes(path, dataBytes);
    }
    
    private static Texture2D DuplicateTexture(Texture2D source) {
        RenderTexture renderTex = RenderTexture.GetTemporary(
            source.width,
            source.height,
            0,
            RenderTextureFormat.Default,
            RenderTextureReadWrite.Linear);
 
        Graphics.Blit(source, renderTex);
        RenderTexture previous = RenderTexture.active;
        RenderTexture.active = renderTex;
        Texture2D readableText = new Texture2D(source.width, source.height);
        readableText.ReadPixels(new Rect(0, 0, renderTex.width, renderTex.height), 0, 0);
        readableText.Apply();
        RenderTexture.active = previous;
        RenderTexture.ReleaseTemporary(renderTex);
        return readableText;
    }

    static string DictionaryToJson(Dictionary<string,string> dict)
    {
        var entries = dict.Select(d =>
            string.Format("\"{0}\": [{1}]", d.Key, string.Join(",", d.Value)));
        return "{" + string.Join(",\n", entries) + "}";
    }
    
    
    static Dictionary<string, int> keywordRenderQueueModifier = new Dictionary<string, int>();
    static Dictionary<int, string> QueueMatDic = new Dictionary<int, string>();
    [MenuItem("Assets/Sort Mat By Keywords")]
    static void OutPutMaterial()
    {
        ResetMaterial();
        UnityEngine.Object[] MatAry=Selection.GetFiltered(typeof(UnityEngine.Material), SelectionMode.DeepAssets);

        // var ary = MatAry.OrderBy(item =>
        // {
        //     return item.name.Contains("destroyed");
        // }).ToList();
        
        foreach (var mat in MatAry)
        {
            Material newMat = mat as Material;
            if (newMat.shaderKeywords.Length > 0)
            {
                var keywords = newMat.shader.name + ":";
 
                foreach (var s in newMat.shaderKeywords)
                    keywords += s + ",";
 
                //Debug.Log(string.Format($"{newMat.shader.name} has additional keywords: {keywords}"));
                //Debug.Log(keywords);

                if (!keywordRenderQueueModifier.ContainsKey(keywords))
                {
                    keywordRenderQueueModifier.Add(keywords, keywordRenderQueueModifier.Count + 1);
                }
 
                //Debug.Log(string.Format($"keywordRenderQueueModifier[{newMat.shader.name}][{keywords}]={keywordRenderQueueModifier[keywords]}"));//[newMat.shader.name]
                if (newMat.name.Contains("destroyed"))
                {
                    newMat.renderQueue += keywordRenderQueueModifier[keywords] + 100;
                }
                else
                {
                    newMat.renderQueue += keywordRenderQueueModifier[keywords];
                }
                
                if (QueueMatDic.ContainsKey(newMat.renderQueue))
                {
                    QueueMatDic[newMat.renderQueue] = QueueMatDic[newMat.renderQueue] + "," + newMat.name;
                }
                else
                {
                    QueueMatDic.Add(newMat.renderQueue,newMat.name);
                }
            }
        }

        foreach (var QueueMat in QueueMatDic)
        {
            Debug.Log(QueueMat.Key + ":" + QueueMat.Value);
        }
    }

    [MenuItem("Assets/Reset Material RenderQueue")]
    static void ResetMaterial()
    {
        UnityEngine.Object[] MatAry=Selection.GetFiltered(typeof(UnityEngine.Material), SelectionMode.DeepAssets);
        
        foreach (var mat in MatAry)
        {
            Material newMat = mat as Material;
            newMat.renderQueue = newMat.shader.renderQueue;
        }
    }
}
