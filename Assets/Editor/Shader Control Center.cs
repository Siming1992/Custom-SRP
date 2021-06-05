using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
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
    static void TestMenu11()
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
    
    static string DictionaryToJson(Dictionary<string,string> dict)
    {
        var entries = dict.Select(d =>
            string.Format("\"{0}\": [{1}]", d.Key, string.Join(",", d.Value)));
        return "{" + string.Join(",\n", entries) + "}";
    }
}