#ifndef CUSTOM_POST_FX_PASSES_INCLUDED
#define CUSTOM_POST_FX_PASSES_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

TEXTURE2D(_PostFXSource);
TEXTURE2D(_PostFXSource2);
SAMPLER(sampler_linear_clamp);

//https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
// Texture size
// {TextureName}_TexelSize - a float4 property contains texture size information:
// x contains 1.0/width
// y contains 1.0/height
// z contains width
// w contains height
float4 _PostFXSource_TexelSize;

float4 GetSourceTexelSize(){
    return _PostFXSource_TexelSize;
}

float4 GetSource(float2 screenUV) {
    //因为我们的缓冲区永远不会有mip映射，我们可以通过用SAMPLE_TEXTURE2D_LOD替换SAMPLE_TEXTURE2D来回避自动mip映射选择，添加一个额外的参数来强制选择mip映射级别为0。
	return SAMPLE_TEXTURE2D_LOD(_PostFXSource, sampler_linear_clamp, screenUV, 0);
}

float4 GetSource2(float2 screenUV) {
	return SAMPLE_TEXTURE2D_LOD(_PostFXSource2, sampler_linear_clamp, screenUV, 0);
}

float4 GetSourceBicubic(float2 screenUV){
    return SampleTexture2DBicubic(TEXTURE2D_ARGS(_PostFXSource,sampler_linear_clamp),screenUV,_PostFXSource_TexelSize.zwxy,1.0,0.0);
}

struct Varyings {
	float4 positionCS : SV_POSITION;
	float2 screenUV : VAR_SCREEN_UV;
};

Varyings DefaultPassVertex(uint vertexID : SV_VertexID){
    Varyings output;
    //创建一个默认的顶点通道，只有一个顶点标识符作为参数。它是一个无符号整数uint——具有SV_VertexID语义。
    //使用 ID 生成顶点位置和 UV 坐标。X 坐标为 -1、-1、3。Y 坐标为 -1、3、-1。要使可见 UV 坐标覆盖 0-1 范围，请使用 0, 0, 2 表示 U，使用 0, 2, 0 表示 V。
    output.positionCS = float4(
		vertexID <= 1 ? -1.0 : 3.0,
		vertexID == 1 ? 3.0 : -1.0,
        0.0,1.0
    );
    output.screenUV = float2(
		vertexID <= 1 ? 0.0 : 2.0,
		vertexID == 1 ? 2.0 : 0.0
    );
    if(_ProjectionParams.x < 0.0){
        output.screenUV.y = 1.0 - output.screenUV.y;
    }
    return output;
}

float4 _BloomThreshold;

// w = max(s ,b - t)/max(b,0.00001)
// s = min(max(0 , b - t + tk) , 2tk)² / 4tk + 0.00001
// x=t | y=- t + tk | z=2tk | w= 1/4tk + 0.00001
float3 ApplyBloomThreshold(float3 color){
    float brightness = Max3(color.r,color.g,color.b);
    float soft = brightness + _BloomThreshold.y;
    soft = clamp(soft,0.0,_BloomThreshold.z);
    soft = soft * soft * _BloomThreshold.w;
    float contribution = max(soft , brightness - _BloomThreshold.x);
    contribution /= max(brightness,0.0001);
    return color *  contribution;
}

float4 BloomPrefilterPassFragment(Varyings input) : SV_TARGET{
    float3 color = ApplyBloomThreshold(GetSource(input.screenUV).rgb);
    return float4(color , 1.0);
}


float4 BloomPrefilterFirefliesPassFragment (Varyings input) : SV_TARGET {
	float3 color = 0.0;
	float weightSum = 0.0;
	float2 offsets[] = {
		float2(0.0, 0.0),
		float2(-1.0, -1.0), float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
	};
	for (int i = 0; i < 5; i++) {
		float3 c =
			GetSource(input.screenUV + offsets[i] * GetSourceTexelSize().xy * 2.0).rgb;
		c = ApplyBloomThreshold(c);
		float w = 1.0 / (Luminance(c) + 1.0);
		color += c * w;
		weightSum += w;
	}
	color /= weightSum;
	return float4(color, 1.0);
}

bool _BloomBicubicUpsampling;
float _BloomIntensity;

float4 BloomAddPassFragment(Varyings input) : SV_TARGET{
    float3 lowRes ;
    if(_BloomBicubicUpsampling){
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    }else{
        lowRes = GetSource(input.screenUV).rgb;
    }
    
    float3 highRes = GetSource2(input.screenUV).rgb;
    return float4(lowRes * _BloomIntensity + highRes , 1.0);
}


float4 BloomScatterPassFragment(Varyings input) : SV_TARGET{
    float3 lowRes ;
    if (_BloomBicubicUpsampling){
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    }
    else {
        lowRes = GetSource(input.screenUV).rgb;
    }    
    float3 highRes = GetSource2(input.screenUV).rgb;
	return float4(lerp(highRes, lowRes, _BloomIntensity), 1.0);
}

float4 BloomScatterFinalPassFragment(Varyings input) : SV_TARGET{
    float3 lowRes ;
    if(_BloomBicubicUpsampling){
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    }else{
        lowRes = GetSource(input.screenUV).rgb;
    }
    
    float3 highRes = GetSource2(input.screenUV).rgb;
    lowRes += highRes - ApplyBloomThreshold(highRes);
	return float4(lerp(highRes, lowRes, _BloomIntensity), 1.0);
}

float4 BloomHorizontalPassFragment(Varyings input) : SV_TARGET{
    float3 color = 0.0;
    float offsets[] = {-4.0,-3.0,-2.0,-1.0,0.0,1.0,2.0,3.0,4.0};
    float weights[] = {0.01621622, 0.05405405, 0.12162162, 0.19459459, 0.22702703,
		0.19459459, 0.12162162, 0.05405405, 0.01621622};
    for(int i = 0; i < 9; i ++){
        //我们已经在该通道中使用双线性过滤进行下采样。它的九个样本中的每一个平均为 2×2 源像素
        float offset = offsets[i] * 2.0 * GetSourceTexelSize().x;
        color += GetSource(input.screenUV + float2(offset,0.0)).rgb * weights[i];   
    }
    return float4(color,1.0);
}

float4 BloomVerticalPassFragment(Varyings input) : SV_TARGET{
    float3 color = 0.0;
    float offsets[] = {-3.23076923, -1.38461538, 0.0, 1.38461538, 3.23076923};
    float weights[] = {0.07027027, 0.31621622, 0.22702703, 0.31621622, 0.07027027};
    for(int i = 0; i < 5; i ++){
        float offset = offsets[i] * GetSourceTexelSize().y;
        color += GetSource(input.screenUV + float2(0.0,offset)).rgb * weights[i];   
    }
    return float4(color,1.0);
}

float4 CopyPassFragment (Varyings input) : SV_TARGET {
	return GetSource(input.screenUV);
}

float4 _ColorAdjustments;
float4 _ColorFilter;
float4 _WhiteBalance;
float4 _SplitToningShadows,_SplitToningHighlights;
float4 _ChannelMixerRed, _ChannelMixerGreen, _ChannelMixerBlue;
float4 _SMHShadows, _SMHMidtones, _SMHHighlights, _SMHRange;

float Luminance (float3 color, bool useACES) {
	return useACES ? AcesLuminance(color) : Luminance(color);
}

//后曝光的原理是，它模仿相机的曝光，但是在所有其他后效果之后，紧接所有其他颜色分级之前应用。这是一种不现实的艺术工具，可用于调整曝光而不会影响其他效果（例如Bloom）。
float3 ColorGradePostExposure(float3 color){
    return color * _ColorAdjustments.x;
}

//什么是LMS颜色空间？它将颜色描述为人眼中三种感光锥类型的响应。
float3 ColorGradeWhiteBalance(float3 color){
    color = LinearToLMS(color);
    color *= _WhiteBalance.rgb;
    return LMSToLinear(color);
}

//对比度
float3 ColorGradingContrast(float3 color, bool useACES) {
	color = useACES ? ACES_to_ACEScc(unity_to_ACES(color)) : LinearToLogC(color);    //为了获得最佳结果，此覆盖在Log C中，而不是在线性色彩空间中完成。我们可以使用Color Core Library文件中的LinearToLogC函数将线性转换为Log C，然后使用LogCToLinear函数将其转换为LogC。
    color = (color - ACEScc_MIDGRAY ) * _ColorAdjustments.y + ACEScc_MIDGRAY;
	return useACES ? ACES_to_ACEScg(ACEScc_to_ACES(color)) : LogCToLinear(color);
}

//滤色器
float3 ColorGradeColorFilter(float3 color){
    return color * _ColorFilter.rgb;  //只需将其与颜色相乘即可。
}

//色调分离，为画面的亮灰色和暗灰色调色
float3 ColorGradeSplitToning(float3 color, bool useACES){
    color = PositivePow(color, 1.0 / 2.2);
    float t = saturate(Luminance(saturate(color),useACES) + _SplitToningShadows.w);
    float3 shadows = lerp(0.5,_SplitToningShadows.rgb,1-t);
    float3 highlights = lerp(0.5,_SplitToningHighlights.rgb,t);
    color = SoftLight(color,shadows);
    color = SoftLight(color,highlights);
    return PositivePow(color,2.2);
}

//通道混合器效果可以修改每个输入颜色通道对输出通道整体混合的影响。例如，如果增加绿色通道对红色通道整体混合的影响，则最终图像中所有绿色（包括中性/单色）的区域都将偏红色。
float3 ColorGradingChannelMixer(float3 color){
    return mul(
        float3x3(_ChannelMixerRed.rgb, _ChannelMixerGreen.rgb, _ChannelMixerBlue.rgb),
        color
    );
}

float3 ColorGradingShadowsMidtonesHighlights(float3 color, bool useACES){
	float luminance = Luminance(color,useACES);
	float shadowsWeight = 1.0 - smoothstep(_SMHRange.x, _SMHRange.y, luminance);
	float highlightsWeight = smoothstep(_SMHRange.z, _SMHRange.w, luminance);
	float midtonesWeight = 1.0 - shadowsWeight - highlightsWeight;
	return
		color * _SMHShadows.rgb * shadowsWeight +
		color * _SMHMidtones.rgb * midtonesWeight +
		color * _SMHHighlights.rgb * highlightsWeight;
}

//色相偏移
float3 ColorGradingHueShift(float3 color){
    //颜色的色调是通过将颜色格式从 RGB 转换为 HSV 来调整的RgbToHsv
    color = RgbToHsv(color);
    float hue = color.x + _ColorAdjustments.z;    //  色调
    //通过 将色调偏移添加到 H，然后通过 转换回来HsvToRgb。因为色调是在 0-1 色轮上定义的，如果它超出范围，我们必须将其环绕。我们可以使用RotateHue它,将调整后的色调、零和 1 作为参数传递给它。
    color.x = RotateHue(hue, 0.0, 1.0);
    return HsvToRgb(color);
}

//饱和度
float3 ColorGradingSaturation(float3 color, bool useACES){
    float luminance = Luminance(color,useACES);
    return (color - luminance) * _ColorAdjustments.w + luminance;
}

float3 ColorGrade(float3 color, bool useACES = false){
    //color = min(color.rgb, 60.0);
    color = ColorGradePostExposure(color);
    color = ColorGradeWhiteBalance(color);
    color = ColorGradingContrast(color, useACES);
    color = ColorGradeColorFilter(color);    //滤镜，它适用于负值，因此我们可以在消除它们之前应用它。
    color = max(color , 0.0);
    color = ColorGradeSplitToning(color, useACES);
    color = ColorGradingChannelMixer(color);
    color = max(color , 0.0);
    color = ColorGradingShadowsMidtonesHighlights(color, useACES);
    color = ColorGradingHueShift(color);    //这必须发生在消除负值之后。
    color = ColorGradingSaturation(color, useACES);
    return max(useACES ? ACEScg_to_ACES(color) : color, 0.0);
}

float4 _ColorGradingLUTParameters;
bool _ColorGradingLUTInLogC;

float3 GetColorGradedLUT (float2 uv, bool useACES = false) {
	float3 color = GetLutStripValue(uv, _ColorGradingLUTParameters);
	//我们得到的 LUT 矩阵在线性颜色空间中，只覆盖 0-1 范围。为了支持 HDR，我们必须扩展这个范围。我们可以通过将输入颜色解释为在 Log C 空间中来做到这一点。这将范围扩展到略低于 59。
	return ColorGrade(_ColorGradingLUTInLogC? LogCToLinear(color):color, useACES);    
}

float4 ColorGradingNonePassFragment(Varyings input) : SV_TARGET {
	float3 color = GetColorGradedLUT(input.screenUV);
	return float4(color, 1.0);
}

float4 ColorGradingACESPassFragment (Varyings input) : SV_TARGET {
	float3 color = GetColorGradedLUT(input.screenUV, true);
	color = AcesTonemap(color);
	return float4(color, 1.0);
}

float4 ColorGradingNeutralPassFragment (Varyings input) : SV_TARGET {
	float3 color = GetColorGradedLUT(input.screenUV);
	color = NeutralTonemap(color);
	return float4(color, 1.0);
}

float4 ColorGradingReinhardPassFragment(Varyings input) : SV_TARGET {
	float3 color = GetColorGradedLUT(input.screenUV);
	color /= color + 1.0;     // Reinhard : c/(1+ c)
	return float4(color, 1.0);
}

TEXTURE2D (_ColorGradingLUT);

float3 ApplyColorGradingLUT (float3 color) {
	return ApplyLut2D(
		TEXTURE2D_ARGS(_ColorGradingLUT, sampler_linear_clamp),
		saturate(_ColorGradingLUTInLogC ? LinearToLogC(color) : color),
		_ColorGradingLUTParameters.xyz
	);
}

float4 FinalPassFragment (Varyings input) : SV_TARGET {
	float4 color = GetSource(input.screenUV);
	color.rgb = ApplyColorGradingLUT(color.rgb);
	return color;
}

#endif
