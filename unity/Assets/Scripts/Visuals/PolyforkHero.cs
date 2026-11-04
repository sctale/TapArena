using System;
using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// Polyfork 的低多边形四足角色：FBX 自带 Idle/Walk/Run，没有可脚本驱动的
    /// 双足骨架，所以这里只负责把模型、材质和骨骼引用交给 PolyHeroView。
    /// 资源缺失时回退到上一版 Blender LowPoly JSON，保证游戏仍能启动。
    /// </summary>
    public static class PolyforkHero
    {
        public static string ModelId(HeroId id)
        {
            switch (id)
            {
                case HeroId.Tiger: return "lion-base";
                case HeroId.Fox: return "red-fox-5c3bc0";
                case HeroId.Rabbit: return "forest-rabbit-ea2da0";
                case HeroId.Bear: return "black-bear-adbdc7";
                case HeroId.Otter: return "frog-base";
                case HeroId.Hedgehog: return "cat-base";
                default: return null;
            }
        }

        public static Art.Rig Build(HeroDef d, Transform parent)
        {
            string id = ModelId(d.id);
            var prefab = string.IsNullOrEmpty(id) ? null : Resources.Load<GameObject>("Polyfork/" + id);
            if (prefab == null)
            {
                Debug.LogWarning("[TapArena] Polyfork model missing for " + d.id + ", falling back");
                return LowPolyHero.Build(d, parent);
            }

            var wrapper = new GameObject("hero").transform;
            wrapper.SetParent(parent, false);
            var facing = new GameObject("facing").transform;
            facing.SetParent(wrapper, false);
            facing.localRotation = Quaternion.Euler(0f, 90f, 0f); // Polyfork 面朝 +Z，游戏朝 +X

            var model = UnityEngine.Object.Instantiate(prefab, facing);
            model.name = "poly:" + id;
            model.transform.localPosition = Vector3.zero;
            model.transform.localRotation = Quaternion.identity;

            /* FBX 里可能混入非蒙皮网格，只留 SkinnedMeshRenderer。 */
            foreach (var mr in model.GetComponentsInChildren<MeshRenderer>(true))
                if (mr.GetComponent<SkinnedMeshRenderer>() == null)
                    UnityEngine.Object.Destroy(mr.gameObject);
            foreach (var an in model.GetComponentsInChildren<Animator>(true))
                UnityEngine.Object.Destroy(an);
            foreach (var an in model.GetComponentsInChildren<Animation>(true))
                UnityEngine.Object.Destroy(an);

            var smr = model.GetComponentInChildren<SkinnedMeshRenderer>(true);
            if (smr == null || smr.sharedMesh == null)
            {
                UnityEngine.Object.Destroy(wrapper.gameObject);
                Debug.LogWarning("[TapArena] Polyfork skinned mesh missing for " + id + ", falling back");
                return LowPolyHero.Build(d, parent);
            }

            /* 按设计身高缩放，脚底落到 y=0。 */
            Bounds b = smr.bounds;
            if (b.size.y < 0.01f) b.size = Vector3.one;
            float scale = d.height / b.size.y;
            model.transform.localScale = Vector3.one * scale;
            Physics.SyncTransforms();
            b = smr.bounds;
            float footY = wrapper.InverseTransformPoint(b.min).y;
            model.transform.localPosition = new Vector3(0f, -footY, 0f);
            Physics.SyncTransforms();

            Material mat = MakeMaterial(d, scale);
            smr.sharedMaterial = mat;
            smr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            smr.receiveShadows = true;
            smr.updateWhenOffscreen = true;

            var rig = new Art.Rig
            {
                root = wrapper,
                height = d.height,
                headR = d.radius * 0.55f,
                headCenterY = d.height * 0.78f,
                mats = new[] { mat },
                baseCols = new[] { Color.white },
                faceMat = null,
                polyModel = model,
                polyFacing = facing,
                polyId = id,
                polyIdle = Resources.Load<AnimationClip>("Polyfork/Clips/" + id + "_idle"),
                polyWalk = Resources.Load<AnimationClip>("Polyfork/Clips/" + id + "_walk"),
                polyRun = Resources.Load<AnimationClip>("Polyfork/Clips/" + id + "_run"),
            };

            var hips = Bone(model.transform, "Hips") ?? wrapper;
            var chest = Bone(model.transform, "Chest") ?? Bone(model.transform, "Spine") ?? hips;
            var neck = Bone(model.transform, "Neck") ?? chest;
            var head = Bone(model.transform, "Head") ?? neck;
            rig.hips = hips;
            rig.chest = chest;
            rig.neck = neck;
            rig.head = head;
            rig.eyes = null;
            rig.earL = Bone(model.transform, "LeftEar");
            rig.earR = Bone(model.transform, "RightEar");
            rig.tail1 = Bone(model.transform, "Tail");
            rig.tail2 = Bone(model.transform, "TailTip");
            rig.shL = Bone(model.transform, "LeftFrontUpLeg") ?? Bone(model.transform, "LeftFrontLeg");
            rig.elL = Bone(model.transform, "LeftFrontElbow") ?? Bone(model.transform, "LeftFrontLeg");
            rig.wrL = Bone(model.transform, "LeftFrontLeg") ?? Bone(model.transform, "LeftFrontFoot");
            rig.shR = Bone(model.transform, "RightFrontUpLeg") ?? Bone(model.transform, "RightFrontLeg");
            rig.elR = Bone(model.transform, "RightFrontElbow") ?? Bone(model.transform, "RightFrontLeg");
            rig.wrR = Bone(model.transform, "RightFrontLeg") ?? Bone(model.transform, "RightFrontFoot");
            rig.thL = Bone(model.transform, "LeftHindUpLeg") ?? hips;
            rig.knL = Bone(model.transform, "LeftHindLeg") ?? rig.thL;
            rig.anL = Bone(model.transform, "LeftHindHock") ?? Bone(model.transform, "LeftHindFoot") ?? rig.knL;
            rig.thR = Bone(model.transform, "RightHindUpLeg") ?? hips;
            rig.knR = Bone(model.transform, "RightHindLeg") ?? rig.thR;
            rig.anR = Bone(model.transform, "RightHindHock") ?? Bone(model.transform, "RightHindFoot") ?? rig.knR;
            rig.weapon = head;
            rig.headCenterY = wrapper.InverseTransformPoint(head.position).y;

            Debug.Log($"[TapArena] polyfork {id} scale={scale:F2} tris={(smr.sharedMesh.GetIndexCount(0) / 3)} " +
                      $"clips={(rig.polyIdle != null)}/{(rig.polyWalk != null)}/{(rig.polyRun != null)}");
            return rig;
        }

        static Transform Bone(Transform root, string name)
        {
            if (root == null) return null;
            if (root.name == name) return root;
            for (int i = 0; i < root.childCount; i++)
            {
                var hit = Bone(root.GetChild(i), name);
                if (hit != null) return hit;
            }
            return null;
        }

        static Material MakeMaterial(HeroDef d, float scale)
        {
            var baseMat = Resources.Load<Material>("TapArenaLowPoly");
            Material m;
            if (baseMat != null) m = new Material(baseMat) { hideFlags = HideFlags.DontSave };
            else
            {
                var sh = Shader.Find("TapArena/LowPoly");
                if (sh == null) sh = Art.ToonShader();
                m = new Material(sh) { hideFlags = HideFlags.DontSave };
            }
            m.color = Color.white;
            if (m.HasProperty("_Outline")) m.SetFloat("_Outline", 0.36f / Mathf.Max(0.01f, scale));
            if (m.HasProperty("_OutlineColor")) m.SetColor("_OutlineColor", new Color(0.10f, 0.07f, 0.06f));
            if (m.HasProperty("_RimStrength")) m.SetFloat("_RimStrength", 0.20f);
            if (m.HasProperty("_Flash")) m.SetFloat("_Flash", 0f);
            return m;
        }
    }
}
