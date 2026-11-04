"""Polyfork animal + Blender costume -> Unity FBX.

Run with Blender headless:
  blender -b -P tools/polyfork_to_fbx.py

Downloads the six free animals, adds the TapArena costume pieces as rigid
vertex groups on the authored skeleton, joins everything into one SkinnedMesh,
and exports FBX with the authored Idle/Walk/Run actions.

Polyfork licence: the models may ship inside the game, but the files themselves
must not be redistributed. ArtSource/ and Resources/Heroes/ are gitignored.
"""
import bpy
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.append(HERE)
import polyfork_costumes

MANIFEST = os.path.join(ROOT, "tools", "polyfork_manifest.json")
SRC = os.path.join(ROOT, "unity", "ArtSource", "Polyfork")
OUT = os.path.join(ROOT, "unity", "Assets", "Resources", "Heroes")
UA = "TapArena/3.2 (+https://github.com/sctale/TapArena)"


def ensure_glb(asset):
    path = os.path.join(SRC, asset + ".glb")
    if os.path.exists(path) and os.path.getsize(path) > 1024:
        return path
    os.makedirs(SRC, exist_ok=True)
    url = "https://polyfork.dev/cdn/" + asset + ".glb"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    print(f"[hero] download {url}")
    with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
        f.write(r.read())
    return path


def remove_helpers():
    for ob in list(bpy.context.scene.objects):
        if ob.type == "MESH" and ob.name.startswith("Icosphere"):
            bpy.data.objects.remove(ob, do_unlink=True)


def pick(asset):
    arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
    if arm is None or not meshes:
        raise RuntimeError("missing armature/body for " + asset)
    body = max(meshes, key=lambda o: len(o.data.vertices))
    for ob in meshes:
        if ob != body:
            bpy.data.objects.remove(ob, do_unlink=True)
    return arm, body


def body_height(body):
    return max(0.01, float(body.dimensions.z))


def action_ranges():
    out = {}
    for a in sorted(bpy.data.actions, key=lambda a: a.name):
        fr = a.frame_range
        out[a.name] = [round(float(fr[0]), 2), round(float(fr[1]), 2)]
    return out


def convert(item):
    asset = item["id"]
    glb = ensure_glb(asset)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=glb)
    remove_helpers()
    arm, body = pick(asset)

    # Measure the animal before accessories so a tall hat does not shrink it.
    height = body_height(body)
    parts = polyfork_costumes.build(asset, arm, height)
    if parts:
        bpy.ops.object.select_all(action="DESELECT")
        body.select_set(True)
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()

    # Keep exactly one color layer named Color.
    if not body.data.color_attributes:
        attr = body.data.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
        for i in range(len(attr.data)):
            attr.data[i].color = (1.0, 1.0, 1.0, 1.0)
    body.data.color_attributes.active_color_name = "Color"

    os.makedirs(OUT, exist_ok=True)
    fbx = os.path.join(OUT, asset + ".fbx")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        bake_anim=True,
        bake_anim_use_all_actions=True,
        bake_anim_force_startend_keying=True,
        bake_anim_use_nla_strips=False,
        add_leaf_bones=False,
        mesh_smooth_type="OFF",
        colors_type="SRGB",
        prioritize_active_color=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
    )
    tris = sum(max(0, len(p.vertices) - 2) for p in body.data.polygons)
    meta = {
        "bodyHeight": round(height, 4),
        "bones": len(arm.data.bones),
        "tris": tris,
        "actions": action_ranges(),
    }
    print(f"[hero] {asset:26s} bones={meta['bones']} tris={tris} bodyH={height:.2f} "
          f"actions={meta['actions']} size={os.path.getsize(fbx)}")
    return asset, meta


def main():
    with open(MANIFEST, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    meta = {}
    for item in manifest.get("heroes", []):
        if only and item["id"] != only:
            continue
        asset, m = convert(item)
        meta[asset] = m
    meta_path = os.path.join(OUT, "hero_meta.json")
    old = {}
    if os.path.exists(meta_path):
        try:
            old = json.load(open(meta_path, "r", encoding="utf-8"))
            if "heroes" in old:
                old = {h["id"]: {k: v for k, v in h.items() if k != "id"} for h in old["heroes"]}
        except Exception:
            old = {}
    old.update(meta)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump({"heroes": [dict(id=k, **v) for k, v in sorted(old.items())]}, f,
                  ensure_ascii=False, indent=2)
    print(f"[hero] RESULT=PASS heroes={len(meta)} out={OUT}")


main()
