using System;
using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// 读取 Blender 导出的低多边形分件 JSON，按骨骼合成一张带权重的
    /// SkinnedMesh。每个顶点刚性绑定到一根骨骼，动画仍由 HeroView 驱动；
    /// 一个英雄一张网格、一支材质，绘制开销比逐件挂 Mesh 低。
    /// </summary>
    public static class LowPolyHero
    {
        [Serializable]
        class Part
        {
            public string bone;
            public string color;
            public bool emissive;
            public float strength;
            public float[] verts;
            public int[] faces;
        }

        [Serializable]
        class Model
        {
            public string id;
            public float height;
            public float headR;
            public Part[] parts;
        }

        static readonly string[] BoneNames =
        {
            "hips", "chest", "neck", "head", "earL", "earR", "eyes",
            "shL", "elL", "wrL", "shR", "elR", "wrR", "weapon",
            "thL", "knL", "anL", "thR", "knR", "anR", "tail1", "tail2"
        };

        public static Art.Rig Build(HeroDef d, Transform parent)
        {
            string id = d.id.ToString().ToLowerInvariant();
            var ta = Resources.Load<TextAsset>("LowPoly/" + id);
            if (ta == null) return HeroBuilder.Build(d, parent);
            Model model = null;
            try { model = JsonUtility.FromJson<Model>(ta.text); }
            catch (Exception e) { Debug.LogWarning("[TapArena] lowpoly json " + id + " " + e.Message); }
            if (model == null || model.parts == null || model.parts.Length == 0)
                return HeroBuilder.Build(d, parent);

            var rig = BuildRig(d, parent, model);
            var bones = new Transform[BoneNames.Length];
            var boneIndex = new Dictionary<string, int>(BoneNames.Length);
            for (int i = 0; i < BoneNames.Length; i++)
            {
                bones[i] = Find(rig, BoneNames[i]);
                if (bones[i] != null) boneIndex[BoneNames[i]] = i;
            }

            var verts = new List<Vector3>(4096);
            var normals = new List<Vector3>(4096);
            var colors = new List<Color>(4096);
            var weights = new List<BoneWeight>(4096);
            var tris = new List<int>(8192);

            Vector3[] pv = new Vector3[3];
            foreach (var part in model.parts)
            {
                if (part == null || part.faces == null || part.verts == null) continue;
                if (!boneIndex.TryGetValue(part.bone ?? "", out int bi)) continue;
                var b = bones[bi];
                Color c;
                if (!ColorUtility.TryParseHtmlString("#" + (part.color ?? "FFFFFF").TrimStart('#'), out c)) c = Color.white;
                if (part.emissive) c = Color.Lerp(c, Color.white, 0.25f);
                Matrix4x4 bind = rig.root.worldToLocalMatrix * b.localToWorldMatrix;
                for (int f = 0; f + 2 < part.faces.Length; f += 3)
                {
                    for (int k = 0; k < 3; k++)
                    {
                        int vi = part.faces[f + k] * 3;
                        if (vi + 2 >= part.verts.Length) { pv[k] = pv[0]; continue; }
                        pv[k] = bind.MultiplyPoint3x4(new Vector3(
                            part.verts[vi], part.verts[vi + 1], part.verts[vi + 2]));
                    }
                    Vector3 n = Vector3.Cross(pv[1] - pv[0], pv[2] - pv[0]);
                    if (n.sqrMagnitude < 1e-10f) continue;
                    n.Normalize();
                    int baseIndex = verts.Count;
                    for (int k = 0; k < 3; k++)
                    {
                        verts.Add(pv[k]);
                        normals.Add(n);
                        colors.Add(c);
                        weights.Add(new BoneWeight { boneIndex0 = bi, weight0 = 1f });
                    }
                    tris.Add(baseIndex); tris.Add(baseIndex + 1); tris.Add(baseIndex + 2);
                }
            }

            if (verts.Count == 0) return HeroBuilder.Build(d, parent);

            var mesh = new Mesh { name = "lowpoly_" + id };
            mesh.SetVertices(verts);
            mesh.SetNormals(normals);
            mesh.SetColors(colors);
            mesh.boneWeights = weights.ToArray();
            mesh.SetTriangles(tris, 0);
            var bindposes = new Matrix4x4[bones.Length];
            for (int i = 0; i < bones.Length; i++)
                bindposes[i] = bones[i] != null
                    ? bones[i].worldToLocalMatrix * rig.root.localToWorldMatrix
                    : Matrix4x4.identity;
            mesh.bindposes = bindposes;
            mesh.RecalculateBounds();

            var go = new GameObject("lowpolyMesh");
            go.transform.SetParent(rig.root, false);
            var smr = go.AddComponent<SkinnedMeshRenderer>();
            smr.sharedMesh = mesh;
            smr.bones = bones;
            smr.rootBone = rig.root;
            smr.quality = SkinQuality.Bone1;
            smr.updateWhenOffscreen = true;
            smr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            smr.receiveShadows = true;

            var mat = MakeMaterial(d);
            smr.sharedMaterial = mat;
            Debug.Log($"[TapArena] lowpoly {id} verts={verts.Count} shader={(mat.shader != null ? mat.shader.name : "null")}");
            rig.mats = new[] { mat };
            rig.baseCols = new[] { Color.white };
            rig.faceMat = null;
            rig.faceOpen = null;
            rig.faceBlink = null;
            rig.faceHurt = null;
            return rig;
        }

        static Material MakeMaterial(HeroDef d)
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
            if (m.HasProperty("_Outline")) m.SetFloat("_Outline", d.height * 0.0045f);
            if (m.HasProperty("_OutlineColor")) m.SetColor("_OutlineColor", new Color(0.13f, 0.08f, 0.09f));
            if (m.HasProperty("_RimStrength")) m.SetFloat("_RimStrength", 0.24f);
            if (m.HasProperty("_Flash")) m.SetFloat("_Flash", 0f);
            return m;
        }

        static Art.Rig BuildRig(HeroDef d, Transform parent, Model model)
        {
            _ = model;
            float h = d.height;
            var rig = new Art.Rig
            {
                height = h,
                headR = h * 0.29f,
                headCenterY = h * 0.93f
            };
            var root = new GameObject("hero").transform;
            root.SetParent(parent, false);
            rig.root = root;

            var hips = Node(root, "hips", new Vector3(0f, h * 0.40f, 0f));
            var chest = Node(hips, "chest", new Vector3(0f, h * 0.26f, 0f));
            var neck = Node(chest, "neck", new Vector3(0f, h * 0.12f, 0f));
            var head = Node(neck, "head", Vector3.zero);
            var eyes = Node(head, "eyes", new Vector3(0f, h * 0.15f, 0f));
            rig.hips = hips; rig.chest = chest; rig.neck = neck; rig.head = head; rig.eyes = eyes;

            var shL = Node(chest, "shL", new Vector3(h * 0.02f, h * 0.005f, -h * 0.245f));
            var elL = Node(shL, "elL", new Vector3(0f, -h * 0.14f, -h * 0.010f));
            var wrL = Node(elL, "wrL", new Vector3(0f, -h * 0.13f, -h * 0.030f));
            var shR = Node(chest, "shR", new Vector3(h * 0.02f, h * 0.005f, h * 0.245f));
            var elR = Node(shR, "elR", new Vector3(0f, -h * 0.14f, h * 0.010f));
            var wrR = Node(elR, "wrR", new Vector3(0f, -h * 0.13f, h * 0.030f));
            var weapon = Node(wrR, "weapon", new Vector3(0f, h * 0.12f, h * 0.02f));
            rig.shL = shL; rig.elL = elL; rig.wrL = wrL;
            rig.shR = shR; rig.elR = elR; rig.wrR = wrR;
            rig.weapon = weapon;

            var thL = Node(hips, "thL", new Vector3(0f, 0f, -h * 0.120f));
            var knL = Node(thL, "knL", new Vector3(0f, -h * 0.18f, -h * 0.008f));
            var anL = Node(knL, "anL", new Vector3(0f, -h * 0.155f, -h * 0.014f));
            var thR = Node(hips, "thR", new Vector3(0f, 0f, h * 0.120f));
            var knR = Node(thR, "knR", new Vector3(0f, -h * 0.18f, h * 0.008f));
            var anR = Node(knR, "anR", new Vector3(0f, -h * 0.155f, h * 0.014f));
            rig.thL = thL; rig.knL = knL; rig.anL = anL;
            rig.thR = thR; rig.knR = knR; rig.anR = anR;

            var earL = Node(head, "earL", new Vector3(0f, h * 0.36f, -h * 0.14f));
            var earR = Node(head, "earR", new Vector3(0f, h * 0.36f, h * 0.14f));
            earL.localRotation = Quaternion.Euler(-10f, 0f, 0f);
            earR.localRotation = Quaternion.Euler(10f, 0f, 0f);
            rig.earL = earL; rig.earR = earR;

            var tail1 = Node(hips, "tail1", new Vector3(-h * 0.17f, h * 0.03f, 0f));
            var tail2 = Node(tail1, "tail2", new Vector3(-h * 0.11f, h * 0.015f, 0f));
            rig.tail1 = tail1; rig.tail2 = tail2;
            return rig;
        }

        static Transform Find(Art.Rig r, string name)
        {
            switch (name)
            {
                case "hips": return r.hips;
                case "chest": return r.chest;
                case "neck": return r.neck;
                case "head": return r.head;
                case "eyes": return r.eyes;
                case "earL": return r.earL;
                case "earR": return r.earR;
                case "shL": return r.shL;
                case "elL": return r.elL;
                case "wrL": return r.wrL;
                case "shR": return r.shR;
                case "elR": return r.elR;
                case "wrR": return r.wrR;
                case "weapon": return r.weapon;
                case "thL": return r.thL;
                case "knL": return r.knL;
                case "anL": return r.anL;
                case "thR": return r.thR;
                case "knR": return r.knR;
                case "anR": return r.anR;
                case "tail1": return r.tail1;
                case "tail2": return r.tail2;
                default: return null;
            }
        }

        static Transform Node(Transform parent, string name, Vector3 pos)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            return go.transform;
        }
    }
}
