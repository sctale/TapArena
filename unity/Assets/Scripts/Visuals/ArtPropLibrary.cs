using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// 新美术资产的运行时入口。原创资产在 GameArt/，Polyfork 派生资产在
    /// PolyforkProps/；两者都缺失时调用方回退到 Art.Tree 等程序化实现。
    ///
    /// FBX 根节点在 Unity 里带 -90° X 旋转：Polyfork 道具本身是 Z-up，保留它
    /// 即可直立；自制 GameArt 是按 Y-up 建的，需要在内部再 +90° 抵消。外面
    /// 再包一层 holder，调用方只改 holder 的位置/朝向/缩放，不会破坏轴修正。
    /// </summary>
    public static class ArtPropLibrary
    {
        static readonly Dictionary<string, GameObject> _cache = new Dictionary<string, GameObject>();
        static readonly Dictionary<string, GameObject> _structures = new Dictionary<string, GameObject>();
        static Material _sceneryMat, _structMat;

        static Material SceneryMat()
        {
            if (_sceneryMat != null) return _sceneryMat;
            _sceneryMat = new Material(Art.LowPolyShared(false)) { hideFlags = HideFlags.DontSave };
            _sceneryMat.color = new Color(0.82f, 0.82f, 0.82f, 1f);
            return _sceneryMat;
        }

        static Material StructMat()
        {
            if (_structMat != null) return _structMat;
            _structMat = new Material(Art.LowPolyShared(true)) { hideFlags = HideFlags.DontSave };
            _structMat.color = new Color(0.72f, 0.72f, 0.70f, 1f);
            if (_structMat.HasProperty("_Outline")) _structMat.SetFloat("_Outline", 0.45f);
            return _structMat;
        }

        static GameObject Load(string path)
        {
            if (_cache.TryGetValue(path, out var go) && go != null) return go;
            go = Resources.Load<GameObject>(path);
            _cache[path] = go;
            return go;
        }

        public static bool Has(string name)
        {
            return Load("PolyforkProps/" + name) != null || Load("GameArt/Props/" + name) != null;
        }

        static GameObject Holder(string name, Transform parent, Vector3 pos, float yaw, float scale)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localRotation = Quaternion.Euler(0f, yaw, 0f);
            go.transform.localScale = Vector3.one * scale;
            return go;
        }

        static GameObject Model(GameObject prefab, Transform holder, float xRot, Vector3 offset)
        {
            var inner = new GameObject("model");
            inner.transform.SetParent(holder, false);
            inner.transform.localPosition = offset;
            inner.transform.localRotation = Quaternion.Euler(xRot, 0f, 0f);
            var model = Object.Instantiate(prefab);
            model.transform.SetParent(inner.transform, false);
            model.transform.localPosition = Vector3.zero;
            return inner;
        }

        public static GameObject Spawn(string name, Transform parent, Vector3 pos,
            float scale = 1f, float yaw = 0f)
        {
            var poly = Load("PolyforkProps/" + name);
            if (poly != null)
            {
                var h = Holder(name, parent, pos, yaw, scale);
                Model(poly, h.transform, 0f, Vector3.zero);
                Dress(h, SceneryMat(), false, false);
                return h;
            }
            var game = Load("GameArt/Props/" + name);
            if (game != null)
            {
                var h = Holder(name, parent, pos, yaw, scale);
                /* showcase_ground 和地图一样是 Z-up；moss_mound 是 Y-up。 */
                Model(game, h.transform, name == "showcase_ground" ? 0f : 90f, Vector3.zero);
                Dress(h, SceneryMat(), false, false);
                return h;
            }
            return null;
        }

        public static GameObject Structure(string name, Transform parent, Vector3 pos, float yaw = 0f)
        {
            GameObject prefab;
            if (!_structures.TryGetValue(name, out prefab) || prefab == null)
            {
                prefab = Resources.Load<GameObject>("GameArt/Structures/" + name);
                _structures[name] = prefab;
            }
            if (prefab == null) return null;
            var h = Holder(name, parent, pos, yaw, 1f);
            Model(prefab, h.transform, 90f, Vector3.zero);
            Dress(h, StructMat(), true, true);
            return h;
        }

        public static GameObject Minion(bool blue, Transform parent, Vector3 pos)
        {
            var prefab = Resources.Load<GameObject>("GameArt/Minions/minion_" + (blue ? "blue" : "red"));
            if (prefab == null) return null;
            var h = Holder(blue ? "minion_blue" : "minion_red", parent, pos, 0f, 1f);
            Model(prefab, h.transform, 90f, Vector3.zero);
            Dress(h, StructMat(), true, true);
            return h;
        }

        public static GameObject Map(string name)
        {
            var prefab = Resources.Load<GameObject>("GameArt/Map/" + name);
            if (prefab == null) return null;
            var h = Holder("map_" + name, null, Vector3.zero, 0f, 1f);
            /* 自制地图在 Blender 里以 (0..3000, 0..1600) 建；FBX 轴转换后落在负象限。 */
            Model(prefab, h.transform, 0f, new Vector3(3000f, 0f, 1600f));
            Dress(h, SceneryMat(), false, name == "ground");
            return h;
        }

        public static void Dress(GameObject go, Material mat, bool shadows, bool receive)
        {
            if (go == null || mat == null) return;
            var rs = go.GetComponentsInChildren<Renderer>(true);
            for (int i = 0; i < rs.Length; i++)
            {
                var r = rs[i];
                if (r is SkinnedMeshRenderer smr) smr.sharedMaterial = mat;
                else r.sharedMaterial = mat;
                r.shadowCastingMode = shadows
                    ? UnityEngine.Rendering.ShadowCastingMode.On
                    : UnityEngine.Rendering.ShadowCastingMode.Off;
                r.receiveShadows = receive;
            }
        }

        /// <summary>
        /// 把 root 下的静态网格按材质合并成 1 个批次，并销毁原来的道具对象。
        /// StaticBatchingUtility.Combine 在本工程里仍留下大量 Renderer；这里自己做，
        /// 可以把场景 renderer 从 200+ 降到每象限 1–2 个。
        /// </summary>
        public static void CombineStatic(Transform root)
        {
            if (root == null) return;
            var groups = new Dictionary<Material, List<CombineInstance>>();
            var rs = root.GetComponentsInChildren<MeshRenderer>(true);
            for (int i = 0; i < rs.Length; i++)
            {
                var mr = rs[i];
                var mf = mr.GetComponent<MeshFilter>();
                if (mf == null || mf.sharedMesh == null || mr.sharedMaterial == null) continue;
                var ci = new CombineInstance
                {
                    mesh = mf.sharedMesh,
                    transform = root.worldToLocalMatrix * mr.transform.localToWorldMatrix,
                    subMeshIndex = 0,
                };
                if (!groups.TryGetValue(mr.sharedMaterial, out var list))
                {
                    list = new List<CombineInstance>();
                    groups[mr.sharedMaterial] = list;
                }
                list.Add(ci);
                mr.enabled = false;
            }
            foreach (var kv in groups)
            {
                var go = new GameObject("combined_" + kv.Key.name);
                go.transform.SetParent(root, false);
                var mesh = new Mesh { name = go.name };
                mesh.CombineMeshes(kv.Value.ToArray(), true, true);
                mesh.RecalculateBounds();
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                var mr = go.AddComponent<MeshRenderer>();
                mr.sharedMaterial = kv.Key;
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                mr.receiveShadows = false;
            }
            for (int i = root.childCount - 1; i >= 0; i--)
            {
                var c = root.GetChild(i);
                if (c.name.StartsWith("combined_")) continue;
                c.gameObject.SetActive(false);
                Object.Destroy(c.gameObject);
            }
        }
    }
}
