using UnityEngine;

public class MeshBall : MonoBehaviour
{
    private static int baseColorID = Shader.PropertyToID("_BaseColor");
    private static int metallicId = Shader.PropertyToID("_Metellic");
    private static int smoothnessId = Shader.PropertyToID("_Smoothness");

    [SerializeField] private Mesh _mesh = default;

    [SerializeField] private Material _material = default;
    
    private Matrix4x4[] _matrices = new Matrix4x4[1023];
    private Vector4[] _baseColors = new Vector4[1023];
    private float[] metallic = new float[1023];
    private float[] smoothness = new float[1023];

    private MaterialPropertyBlock _block;

    private void Awake()
    {
        for (int i = 0; i < _matrices.Length; i++)
        {
            _matrices[i] = Matrix4x4.TRS(Random.insideUnitSphere * 10 ,Quaternion.identity, Vector3.one);
            _baseColors[i] = new Vector4(Random.value,Random.value,Random.value,Random.Range(0.5f,1f));
            metallic[i] = Random.value < 0.25 ? 1f : 0f;
            smoothness[i] = Random.Range(0.05f, 0.95f);
        }
    }

    private void Update()
    {
        if (_block == null)
        {
            _block = new MaterialPropertyBlock();
            _block.SetVectorArray(baseColorID,_baseColors);
            _block.SetFloatArray(metallicId, metallic);
            _block.SetFloatArray(smoothnessId, smoothness);
        }
        Graphics.DrawMeshInstanced(_mesh,0,_material,_matrices,1023,_block);
    }
}
