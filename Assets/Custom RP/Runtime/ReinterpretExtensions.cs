using System.Runtime.InteropServices;

//Light.renderingLayerMask���Խ���λ���빫��Ϊint��������ת�������л�������룬�Ӷ���light setup�����и�����
//�޷�ֱ�ӽ��������鷢�͵�GPU��������Ǳ�����ĳ�ַ�ʽ��int���½���Ϊ�����������������ת��������C���޷�ֱ��ʹ��asuint��Ч�

//����C����ǿ���͵ģ���������޷���HLSL�����򵥵����½���C���е����ݡ����ǿ���ͨ��ʹ�ò����ṹ���������������͡�
//ͨ����int���ReinterpretAsFloat��չ���������ش˷�����Ϊ�˷�������һ����̬��ReinterpretExtensions�ࡣ
public static class ReinterpretExtensions{
	//Ϊ�˽���ת��Ϊ���½��ͣ�������Ҫʹ�ṹ�������ֶ��ص����Ա����ǹ�����ͬ�����ݡ����ǿ��Եģ���Ϊ�������͵Ĵ�С��Ϊ�ĸ��ֽڡ�
	//����ͨ����StructLayout���Ը��ӵ����ͣ�����ΪLayoutKind.Explicit����ʹ�ṹ�Ĳ�����ȷ��
	[StructLayout(LayoutKind.Explicit)]
	struct IntFloat
	{
		//Ȼ�����ǽ�FieldOffset������ӵ����ֶ��У���ָʾӦ���ֶ����ݷ����ںδ���������ƫ�ƶ�����Ϊ�㣬�Ա������ص�����Щ��������System.Runtime.InteropServices�����ռ䡣
		[FieldOffset(0)]
		public int intValue;
		[FieldOffset(0)]
		public float floatValue;
	}

	//���ڣ��ýṹ��int��float�ֶα�ʾ��ͬ�����ݣ������Ͳ�ͬ���������Ա���λ����������ȱ��������Ⱦ���������ڿ�������������
	public static float ReinterpretAsFloat(this int value)
	{
		IntFloat converter = default;
		converter.intValue = value;
		return converter.floatValue;
	}
}
