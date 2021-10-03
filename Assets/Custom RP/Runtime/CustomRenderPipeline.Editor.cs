using Unity.Collections;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;
using LightType = UnityEngine.LightType;

public partial class CustomRenderPipeline
{
    partial void InitializeForEditor();
    #if UNITY_EDITOR
    partial void InitializeForEditor()
    {
        Lightmapping.SetDelegate(_lightsDelegate);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        Lightmapping.ResetDelegate();
    }
    //告诉 Unity 使用不同的衰减,方法是提供一个委托给一个应该在 Unity 在编辑器中执行光照贴图之前调用的方法。
    private static Lightmapping.RequestLightsDelegate _lightsDelegate =
        (Light[] lights, NativeArray<LightDataGI> output) =>
        {
            var lightdata = new LightDataGI();
            for (int i = 0; i < lights.Length; i++)
            {
                Light light = lights[i];
                switch (light.type)
                {
                    case LightType.Directional:
                        var directionLight = new DirectionalLight();
                        LightmapperUtils.Extract(light, ref directionLight);
                        lightdata.Init(ref directionLight);
                        break;
                    case LightType.Point:
                        var pointLight = new PointLight();
                        LightmapperUtils.Extract(light, ref pointLight);
                        lightdata.Init(ref pointLight);
                        break;
                    case LightType.Spot:
                        var spotLight = new SpotLight();
                        LightmapperUtils.Extract(light, ref spotLight);
                        spotLight.innerConeAngle = light.innerSpotAngle * Mathf.Deg2Rad;
                        spotLight.angularFalloff = AngularFalloffType.AnalyticAndInnerAngle;
                        lightdata.Init(ref spotLight);
                        break;
                    case LightType.Area:
                        var rectangleLight = new RectangleLight();
                        LightmapperUtils.Extract(light, ref rectangleLight);
                        rectangleLight.mode = LightMode.Baked;
                        lightdata.Init(ref rectangleLight);
                        break;
                    default:
                        lightdata.InitNoBake(light.GetInstanceID());
                        break;
                }
                lightdata.falloff = FalloffType.InverseSquared;
                output[i] = lightdata;
            }
        };
#endif
}
