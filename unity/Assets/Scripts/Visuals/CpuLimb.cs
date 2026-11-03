using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// 两骨 CPU 蒙皮：把一根连续的锥形管在肘/膝处平滑弯折，避免"一节节木偶"的接缝。
    /// 网格顶点在 hero 根空间；每帧用两根骨骼的形变矩阵混合，法线一起更新，描边才跟得上。
    /// </summary>
    public class CpuLimb : MonoBehaviour
    {
        public Transform root;
        public Transform boneA;
        public Transform boneB;

        Mesh _mesh;
        Vector3[] _rest, _work;
        Vector3[] _restN, _workN;
        BoneWeight[] _weights;
        Matrix4x4 _bindA, _bindB;

        public void Setup(Transform root, Transform a, Transform b, Mesh mesh, Material mat, float height)
        {
            this.root = root;
            boneA = a;
            boneB = b;
            _mesh = mesh;
            _rest = mesh.vertices;
            _restN = mesh.normals;
            _weights = mesh.boneWeights;
            _work = new Vector3[_rest.Length];
            _workN = new Vector3[_rest.Length];
            _bindA = (root.worldToLocalMatrix * a.localToWorldMatrix).inverse;
            _bindB = b != null ? (root.worldToLocalMatrix * b.localToWorldMatrix).inverse : _bindA;

            var mf = gameObject.AddComponent<MeshFilter>();
            mf.sharedMesh = mesh;
            var mr = gameObject.AddComponent<MeshRenderer>();
            mr.sharedMaterial = mat;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            mr.receiveShadows = true;
            mesh.MarkDynamic();
            mesh.bounds = new Bounds(new Vector3(0f, height * 0.3f, 0f), Vector3.one * height * 4f);
        }

        public void ForceUpdate() { Deform(); }

        void LateUpdate() { Deform(); }

        void Deform()
        {
            if (root == null || boneA == null || _mesh == null) return;
            Matrix4x4 ra = root.worldToLocalMatrix * boneA.localToWorldMatrix * _bindA;
            Matrix4x4 rb = boneB != null ? root.worldToLocalMatrix * boneB.localToWorldMatrix * _bindB : ra;

            for (int i = 0; i < _rest.Length; i++)
            {
                var w = _weights[i];
                float wa = w.weight0, wb = w.weight1;
                if (wa + wb < 0.001f) { wa = 1f; wb = 0f; }
                Vector3 p = ra.MultiplyPoint3x4(_rest[i]) * wa;
                if (wb > 0.0001f) p += rb.MultiplyPoint3x4(_rest[i]) * wb;
                _work[i] = p;

                Vector3 n = ra.MultiplyVector(_restN[i]) * wa;
                if (wb > 0.0001f) n += rb.MultiplyVector(_restN[i]) * wb;
                _workN[i] = n.sqrMagnitude > 1e-8f ? n.normalized : _restN[i];
            }
            _mesh.vertices = _work;
            _mesh.normals = _workN;
        }
    }
}
