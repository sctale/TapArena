"""Polyfork Nature & Forest Kit -> Unity FBX (props only).

Run with Blender headless:
  blender -b -P tools/polyfork_props.py

Reads tools/polyfork_manifest.json, downloads only the listed free GLBs,
strips helper meshes, applies the game's unit scale, stores a cheap contact
shade in vertex alpha (the LowPoly shader multiplies albedo by it), and
exports one flat-shaded mesh per prop.

Licence: the models may ship inside the game, but the GLB/FBX files themselves
must not be redistributed. ArtSource/ and Resources/PolyforkProps/ are gitignored.
"""
import bpy
import json
import math
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tools", "polyfork_manifest.json")
SRC = os.path.join(ROOT, "unity", "ArtSource", "PolyforkProps")
OUT = os.path.join(ROOT, "unity", "Assets", "Resources", "PolyforkProps")
UA = "TapArena/3.2 (+https://github.com/sctale/TapArena)"


def load_manifest():
    with open(MANIFEST, "r", encoding="utf-8") as f:
        return json.load(f)


def ensure_glb(asset_id):
    path = os.path.join(SRC, asset_id + ".glb")
    if os.path.exists(path) and os.path.getsize(path) > 1024:
        return path
    os.makedirs(SRC, exist_ok=True)
    url = "https://polyfork.dev/cdn/" + asset_id + ".glb"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    print(f"[props] download {url}")
    with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
        data = r.read()
        f.write(data)
    if len(data) < 1024:
        raise RuntimeError("downloaded file too small: " + url)
    return path


def clean_scene():
    for ob in list(bpy.context.scene.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def remove_helpers(meshes):
    for ob in list(bpy.context.scene.objects):
        if ob.type == "MESH" and (ob.name.startswith("Icosphere") or ob.name.startswith("Sphere")):
            bpy.data.objects.remove(ob, do_unlink=True)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def ensure_color(obj):
    mesh = obj.data
    if not mesh.color_attributes:
        attr = mesh.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
        for i in range(len(attr.data)):
            attr.data[i].color = (1.0, 1.0, 1.0, 1.0)
        return attr
    attr = mesh.color_attributes.get("Color")
    if attr is None:
        attr = mesh.color_attributes[0]
        attr.name = "Color"
    mesh.color_attributes.active_color_name = "Color"
    if hasattr(mesh.color_attributes, "render_color_index"):
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    return attr


def contact_shade(obj):
    """Darken the bottom of each prop and store the factor in vertex alpha.

    A full Cycles AO bake is unreliable on per-corner byte colours and costs
    minutes across the whole kit; this vertical contact shade is deterministic,
    cheap, and reads well under the three-tone LowPoly shader.
    """
    mesh = obj.data
    if len(mesh.vertices) == 0:
        return
    zs = [v.co.z for v in mesh.vertices]
    zmin, zmax = min(zs), max(zs)
    span = max(0.0001, zmax - zmin)
    attr = ensure_color(obj)
    if attr.domain == "POINT":
        data = attr.data
        for i, v in enumerate(mesh.vertices):
            h = (v.co.z - zmin) / span
            a = 0.74 + 0.26 * pow(max(0.0, h), 0.65)
            c = data[i].color
            data[i].color = (c[0], c[1], c[2], a)
    else:
        data = attr.data
        for i, loop in enumerate(mesh.loops):
            v = mesh.vertices[loop.vertex_index]
            h = (v.co.z - zmin) / span
            a = 0.74 + 0.26 * pow(max(0.0, h), 0.65)
            c = data[i].color
            data[i].color = (c[0], c[1], c[2], a)


def join_meshes(meshes, name):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in meshes:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


def convert(item, units_per_meter):
    asset_id = item["id"]
    name = item["name"]
    glb = ensure_glb(asset_id)
    clean_scene()
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=glb)
    meshes = remove_helpers(None)
    if not meshes:
        raise RuntimeError("no mesh in " + asset_id)
    obj = join_meshes(meshes, name)
    obj.parent = None
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (units_per_meter, units_per_meter, units_per_meter)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    contact_shade(obj)

    os.makedirs(OUT, exist_ok=True)
    fbx = os.path.join(OUT, name + ".fbx")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"MESH"},
        bake_anim=False,
        mesh_smooth_type="OFF",
        colors_type="SRGB",
        prioritize_active_color=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
    )
    tris = sum(max(0, len(p.vertices) - 2) for p in obj.data.polygons)
    print(f"[props] {name:16s} tris={tris:5d} size={os.path.getsize(fbx)}")


def main():
    manifest = load_manifest()
    units = float(manifest.get("units_per_meter", 46))
    items = list(manifest.get("props", []))
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    for item in items:
        if only and item["name"] != only:
            continue
        convert(item, units)
    print(f"[props] RESULT=PASS count={len(items)} out={OUT}")


main()
