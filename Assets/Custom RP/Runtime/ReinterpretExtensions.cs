using System.Runtime.InteropServices;

//Light.renderingLayerMask属性将其位掩码公开为int，并且在转换过程中会出现乱码，从而在light setup方法中浮动。
//无法直接将整数数组发送到GPU，因此我们必须以某种方式将int重新解释为浮点数，而无需进行转换，但是C＃无法直接使用asuint等效项。

//由于C＃是强类型的，因此我们无法像HLSL那样简单地重新解释C＃中的数据。我们可以通过使用并集结构来重命名数据类型。
//通过向int添加ReinterpretAsFloat扩展方法来隐藏此方法。为此方法创建一个静态的ReinterpretExtensions类。
public static class ReinterpretExtensions{
	//为了将其转换为重新解释，我们需要使结构的两个字段重叠，以便它们共享相同的数据。这是可以的，因为两种类型的大小均为四个字节。
	//我们通过将StructLayout属性附加到类型（设置为LayoutKind.Explicit）来使结构的布局明确。
	[StructLayout(LayoutKind.Explicit)]
	struct IntFloat
	{
		//然后，我们将FieldOffset属性添加到其字段中，以指示应将字段数据放置在何处。将两个偏移都设置为零，以便它们重叠。这些属性来自System.Runtime.InteropServices命名空间。
		[FieldOffset(0)]
		public int intValue;
		[FieldOffset(0)]
		public float floatValue;
	}

	//现在，该结构的int和float字段表示相同的数据，但解释不同。这样可以保持位掩码完整无缺，并且渲染层掩码现在可以正常工作。
	public static float ReinterpretAsFloat(this int value)
	{
		IntFloat converter = default;
		converter.intValue = value;
		return converter.floatValue;
	}
}
