#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//在C＃类中，这将定义一个字段，但是在这里它被称为 uniform 值。它由GPU每次绘制时设置，对于该绘制期间所有顶点和片段函数的调用都将保持不变
CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
    float4x4 unity_WorldToObject;
    float4 unity_LODFade;
    real4 unity_WorldTransformParams;
    //光照贴图，
    float4 unity_LightmapST;
    float4 unity_DynamicLightmapST; //即使已弃用，也请在其后添加unityDynamicLightmapST，否则SRP批处理程序的兼容性可能会中断。
    //分别代表红色，绿色和蓝色光的多项式的分量。它们的名称为unity_SH ，为A，B或C。前两个具有三个版本，后缀为r，g和b
    float4 unity_SHAr;
    float4 unity_SHAg;
    float4 unity_SHAb;
    float4 unity_SHBr;
    float4 unity_SHBg;
    float4 unity_SHBb;
    float4 unity_SHC;
    //LPPVs
    float4 unity_ProbeVolumeParams;
    float4x4 unity_ProbeVolumeWorldToObject;
    float4 unity_ProbeVolumeSizeInv;
    float4 unity_ProbeVolumeMin;
    float4 unity_ProbesOcclusion;   //Unity还将ShadowMask数据烘焙到光探针中，我们将其称为遮挡探针（Occlusion Probes）
CBUFFER_END

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

float3 _WorldSpaceCameraPos;

#endif