"""Polyfork GLB -> Unity FBX.

Run with Blender headless:
  blender -b -P tools/polyfork_to_fbx.py

Downloads the six free models from polyfork.dev when missing, then exports
FBX files with authored Idle/Walk/Run actions into
unity/Assets/Resources/Polyfork.

Polyfork licence: free for commercial projects, no attribution; the models may
ship inside a game, but the files themselves must not be redistributed. Both
the downloaded GLBs and the converted FBXs are therefore gitignored.
"""
import bpy
import os
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "unity", "ArtSource", "Polyfork")
OUT = os.path.join(ROOT, "unity", "Assets", "Resources", "Polyfork")
ASSETS = [
    "lion-base",
    "red-fox-5c3bc0",
    "forest-rabbit-ea2da0",
    "black-bear-adbdc7",
    "frog-base",
    "cat-base",
]
UA = "TapArena/3.1 (+https://github.com/sctale/TapArena)"


def ensure_glb(asset):
    path = os.path.join(SRC, asset + ".glb")
    if os.path.exists(path) and os.path.getsize(path) > 1024:
        return path
    os.makedirs(SRC, exist_ok=True)
    url = "https://polyfork.dev/cdn/" + asset + ".glb"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    print(f"[polyfork] download {url}")
    with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
        f.write(r.read())
    return path


def descendants(root):
    out = []
    stack = [root]
    while stack:
        ob = stack.pop()
        out.append(ob)
        stack.extend(ob.children)
    return out


def convert(asset):
    glb = ensure_glb(asset)
    fbx = os.path.join(OUT, asset + ".fbx")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=glb)

    roots = [o for o in bpy.context.scene.objects if o.parent is None and o.type in {"EMPTY", "ARMATURE"}]
    roots = [o for o in roots if o.name not in {"Icosphere"}]
    if not roots:
        raise RuntimeError("no import root for " + asset)
    root = roots[0]

    keep = set(descendants(root))
    for ob in list(bpy.context.scene.objects):
        if ob not in keep:
            bpy.data.objects.remove(ob, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    for ob in keep:
        if ob.name in bpy.context.view_layer.objects:
            ob.select_set(True)
    bpy.context.view_layer.objects.active = root

    actions = sorted(a.name for a in bpy.data.actions)
    print(f"[polyfork] {asset} objects={len(keep)} actions={actions}")

    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        bake_anim=True,
        bake_anim_use_all_actions=True,
        bake_anim_force_startend_keying=True,
        bake_anim_use_nla_strips=False,
        add_leaf_bones=False,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
    )
    print(f"[polyfork] wrote {fbx} {os.path.getsize(fbx)} bytes")


for a in ASSETS:
    convert(a)
