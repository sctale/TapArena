"""TapArena's original low-poly game art: map, mushrooms towers, crystals,
minions and the home clearing. Run headless:

  blender -b -P tools/blender_game_art.py

All colours are vertex colours; there are no textures. Models are authored in
game units (1 unit ~ 2.16 cm), flat shaded, origin on the ground. FBX goes to
unity/Assets/Resources/GameArt/ and is committed (original work).
"""
import bpy
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "unity", "Assets", "Resources", "GameArt")
MAP_W, MAP_H = 3000.0, 1600.0

GRASS = (0.30, 0.51, 0.25, 1)
MEADOW = (0.47, 0.70, 0.34, 1)
SOIL = (0.65, 0.52, 0.37, 1)
SOIL_EDGE = (0.50, 0.40, 0.28, 1)
ROCK = (0.53, 0.52, 0.49, 1)
BARK = (0.46, 0.34, 0.22, 1)
BARK_DARK = (0.31, 0.23, 0.15, 1)
WATER = (0.25, 0.56, 0.66, 1)
WATER_EDGE = (0.40, 0.62, 0.55, 1)
CREAM = (0.95, 0.90, 0.80, 1)
GOLD = (1.0, 0.80, 0.38, 1)
MOSS = (0.30, 0.52, 0.28, 1)
MOSS_LIGHT = (0.45, 0.67, 0.36, 1)
INK = (0.12, 0.16, 0.13, 1)
BLUE = (0.38, 0.76, 0.88, 1)
RED = (0.90, 0.48, 0.42, 1)
BLUE_LIGHT = (0.62, 0.92, 1.0, 1)
RED_LIGHT = (1.0, 0.78, 0.62, 1)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24


def clamp(v):
    return max(0.0, min(1.0, v))


def paint(obj, color, shift=0.0):
    mesh = obj.data
    attr = mesh.color_attributes.get("Color")
    if attr is None:
        attr = mesh.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    c = (clamp(color[0] + shift), clamp(color[1] + shift), clamp(color[2] + shift), color[3])
    for d in attr.data:
        d.color = c
    mesh.color_attributes.active_color_name = "Color"


def make(kind, name, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), color=CREAM, **kw):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("verts", 12),
            radius=kw.get("radius", 0.5), depth=kw.get("depth", 1.0), location=loc, rotation=rot)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("verts", 8),
            radius1=kw.get("radius", 0.5), depth=kw.get("depth", 1.0), location=loc, rotation=rot)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("seg", 12), ring_count=kw.get("rings", 6),
            radius=kw.get("radius", 0.5), location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    paint(obj, color, kw.get("shift", 0.0))
    return obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def reorigin(obj, target=(0.0, 0.0, 0.0)):
    """Move the object origin to target while keeping world geometry in place."""
    dx = obj.location.x - target[0]
    dy = obj.location.y - target[1]
    dz = obj.location.z - target[2]
    for v in obj.data.vertices:
        v.co.x += dx
        v.co.y += dy
        v.co.z += dz
    obj.location = target


def mesh_obj(name, verts, faces, color_fn):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    attr = mesh.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        c = color_fn(poly.center)
        for li in poly.loop_indices:
            attr.data[li].color = c
    mesh.color_attributes.active_color_name = "Color"
    return obj


def export(name, objs, folder="Props", root=None):
    os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    if root is not None:
        root.select_set(True)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root if root is not None else objs[0]
    path = os.path.join(OUT, folder, name + ".fbx")
    types = {"EMPTY", "MESH"} if root is not None else {"MESH"}
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types=types,
        bake_anim=False, mesh_smooth_type="OFF", colors_type="SRGB",
        prioritize_active_color=True, apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z", axis_up="Y")
    tris = sum(sum(max(0, len(p.vertices) - 2) for p in o.data.polygons)
               for o in objs if o.type == "MESH")
    print(f"[art] {folder}/{name:24s} tris={tris:5d} size={os.path.getsize(path)}")


def lane_dist(x, z):
    lane = [(300, 800), (760, 800), (1180, 800), (1500, 800), (1900, 800), (2320, 800), (2700, 800)]
    best = 1e9
    for i in range(len(lane) - 1):
        ax, az = lane[i]; bx, bz = lane[i + 1]
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        px, pz = ax + dx * t, az + dz * t
        best = min(best, math.hypot(x - px, z - pz))
    return best


def river_center(z):
    return 1500.0 + (z - 800.0) * 0.16 + math.sin(z * 0.012) * 34.0


def terrain_color(x, z):
    d = lane_dist(x, z)
    r = abs(x - river_center(z))
    if r < 150:
        c = WATER if r < 110 else WATER_EDGE
    elif d < 118:
        c = SOIL
    elif d < 150:
        c = SOIL_EDGE
    else:
        n = math.sin(x * 0.004 + z * 0.007) * 0.5 + 0.5
        n2 = math.sin(x * 0.017 - z * 0.011) * 0.5 + 0.5
        k = (n * 0.7 + n2 * 0.3)
        c = tuple(GRASS[i] * (1 - k) + MEADOW[i] * k for i in range(4))
    return c


def ground():
    reset()
    step = 40.0
    nx, nz = int(MAP_W / step), int(MAP_H / step)
    verts, faces = [], []
    for iz in range(nz + 1):
        for ix in range(nx + 1):
            x, z = ix * step, iz * step
            r = abs(x - river_center(z))
            verts.append((x, z, -0.8 if r < 150 else 0.0))
    for iz in range(nz):
        for ix in range(nx):
            a = iz * (nx + 1) + ix
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))

    def cf(center):
        c = list(terrain_color(center.x, center.y))
        v = 0.025 * math.sin(center.x * 0.09 + center.y * 0.07)
        return (clamp(c[0] + v), clamp(c[1] + v), clamp(c[2] + v), 1.0)
    obj = mesh_obj("ground", verts, faces, cf)
    export("ground", [obj], "Map")

    # Water ribbon, slightly above the riverbed.
    verts, faces = [], []
    seg = 40
    for i in range(seg + 1):
        z = i / seg * MAP_H
        cx = river_center(z)
        verts.append((cx - 110, z, -0.2))
        verts.append((cx + 110, z, -0.2))
    for i in range(seg):
        a = i * 2
        faces.append((a, a + 1, a + 3, a + 2))
    water = mesh_obj("water", verts, faces, lambda _: WATER)
    export("water", [water], "Map")


def make_tower(team, tier):
    reset()
    cap = BLUE if team == "blue" else RED
    glow = BLUE_LIGHT if team == "blue" else RED_LIGHT
    stone = (0.86, 0.80, 0.70, 1) if tier == 0 else (0.92, 0.86, 0.75, 1)
    objs = []
    base = [
        make("cyl", "step0", (0, 6, 0), radius=59, depth=12, color=(0.70, 0.64, 0.54, 1), verts=14),
        make("cyl", "step1", (0, 16, 0), radius=48, depth=8, color=(0.82, 0.76, 0.66, 1), verts=14),
        make("cyl", "body", (0, 50, 0), radius=30, depth=32, color=stone, verts=14),
        make("cyl", "band0", (0, 34, 0), radius=33, depth=3, color=BARK, verts=14),
        make("cyl", "band1", (0, 66, 0), radius=32, depth=3, color=BARK, verts=14),
        make("cube", "door", (0, 28, -30.5), scale=(18, 26, 3), color=BARK_DARK),
        make("sphere", "win_l", (-13, 52, -30), radius=5, scale=(1, 1.2, 0.5), color=glow, seg=8, rings=4),
        make("sphere", "win_r", (13, 52, -30), radius=5, scale=(1, 1.2, 0.5), color=glow, seg=8, rings=4),
    ]
    body = join(base, "Body")
    reorigin(body)
    objs.append(body)

    cap_scale = 160.0 * (1.06 if tier == 1 else 1.0)
    cap_parts = [
        make("sphere", "cap", (0, 100, 0), scale=(cap_scale, 92, cap_scale), radius=0.5, color=cap, seg=16, rings=8),
        make("cyl", "cap_under", (0, 82, 0), radius=cap_scale * 0.82, depth=5, color=tuple(x * 0.75 for x in cap), verts=16),
    ]
    for i in range(7):
        a = i / 7 * math.pi * 2 + 0.3
        rr = 34 + (i % 3) * 13
        sy = 100 + 92 * math.sqrt(max(0.06, 1 - (rr / 80) ** 2)) - 5
        cap_parts.append(make("sphere", f"spot{i}", (math.cos(a) * rr, sy, math.sin(a) * rr),
            scale=(16, 7, 16), radius=0.5, color=CREAM, seg=8, rings=4))
    if tier == 1:
        cap_parts.append(make("cyl", "rim", (0, 99, 0), radius=cap_scale * 0.86, depth=4, color=GOLD, verts=16))
    top = join(cap_parts, "Top_Cap")
    reorigin(top, (0, 100, 0))
    objs.append(top)

    pole = make("cyl", "Top_Pole", (0, 200, 0), radius=1.5, depth=16, color=BARK, verts=6)
    objs.append(pole)
    flag = make("cube", "Top_Flag", (10, 208, 0), rot=(0, 0, math.radians(-8)), scale=(22, 13, 2), color=cap)
    objs.append(flag)
    root = bpy.data.objects.new("Tower", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    export(f"tower_{team}_{'inner' if tier == 1 else 'outer'}", objs, "Structures", root)


def make_crystal(team):
    reset()
    stone = (0.62, 0.57, 0.48, 1)
    glow = BLUE if team == "blue" else RED
    bright = glow
    objs = []
    steps = [
        make("cyl", "step0", (0, 6, 0), radius=110, depth=12, color=(0.48, 0.44, 0.37, 1), verts=18),
        make("cyl", "step1", (0, 14, 0), radius=94, depth=8, color=stone, verts=18),
        make("cyl", "step2", (0, 23, 0), radius=74, depth=10, color=stone, verts=18),
        make("cyl", "step3", (0, 31, 0), radius=62, depth=4, color=(0.54, 0.49, 0.41, 1), verts=18),
    ]
    for i in range(4):
        a = i * math.pi * 0.5 + math.pi * 0.25
        px, pz = math.cos(a) * 90, math.sin(a) * 90
        steps.append(make("cyl", f"pillar{i}", (px, 52, pz), radius=7, depth=34, color=(0.58, 0.53, 0.44, 1), verts=10))
        steps.append(make("sphere", f"orb{i}", (px, 90, pz), radius=7, color=glow, seg=10, rings=5))
    for i in range(2):
        a = i * math.pi + math.pi * 0.5
        px, pz = math.cos(a) * 110, math.sin(a) * 110
        steps.append(make("cyl", f"fpole{i}", (px, 70, pz), radius=2, depth=70, color=BARK, verts=6))
        flag = make("cube", f"Flag{i}", (px + 14, 124, pz), scale=(30, 22, 2), color=glow)
        objs.append(flag)
    base = join(steps, "Base")
    reorigin(base)
    objs.insert(0, base)

    verts = [(0, 85, 0), (0, -85, 0), (39, 0, 0), (0, 0, 39), (-39, 0, 0), (0, 0, -39)]
    verts = [(v[0] * 0.78, v[1] * 0.82, v[2] * 0.78) for v in verts]
    faces = [(0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 5, 4), (0, 2, 5), (1, 2, 3), (1, 3, 4), (1, 4, 5), (1, 5, 2)]
    crystal = mesh_obj("Crystal", verts, faces, lambda _: bright)
    crystal.location = (0, 112, 0)
    objs.append(crystal)
    for i in range(4):
        a = i * math.pi * 0.5
        sh = mesh_obj(f"Shard{i}", [(0, 17, 0), (0, -17, 0), (9, 0, 0), (-9, 0, 0)], [(0, 2, 1), (0, 1, 3), (1, 2, 3), (0, 3, 2)],
                      lambda _: BLUE_LIGHT if team == "blue" else RED_LIGHT)
        sh.location = (math.cos(a) * 105, math.sin(a * 2) * 18, math.sin(a) * 105)
        sh.parent = crystal
        objs.append(sh)
    root = bpy.data.objects.new("CrystalBase", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    export(f"crystal_{team}", objs, "Structures", root)


def make_minion(team):
    reset()
    body_c = BLUE if team == "blue" else RED
    belly_c = BLUE_LIGHT if team == "blue" else RED_LIGHT
    parts = [
        make("sphere", "body", (0, 26, 0), scale=(38, 40, 34), radius=0.5, color=body_c, seg=10, rings=6),
        make("sphere", "belly", (6, 22, 0), scale=(24, 26, 24), radius=0.5, color=belly_c, seg=8, rings=5),
        make("cyl", "stem", (0, 52, 0), radius=3, depth=8, color=MOSS, verts=6),
        make("cone", "leaf", (0, 60, 0), rot=(math.radians(90), 0, 0), radius=8, depth=18, color=MOSS, verts=5),
        make("sphere", "eye_l", (12, 30, -10), radius=6, scale=(1, 1.3, 1), color=CREAM, seg=8, rings=4),
        make("sphere", "eye_r", (12, 30, 10), radius=6, scale=(1, 1.3, 1), color=CREAM, seg=8, rings=4),
        make("sphere", "pupil_l", (15, 30, -10), radius=3, scale=(1, 1.2, 1), color=INK, seg=6, rings=3),
        make("sphere", "pupil_r", (15, 30, 10), radius=3, scale=(1, 1.2, 1), color=INK, seg=6, rings=3),
    ]
    for s in (-1, 1):
        parts.append(make("sphere", f"foot{s}", (6, 8, s * 12), scale=(12, 7, 9), radius=0.5, color=body_c, seg=8, rings=4))
    m = join(parts, f"minion_{team}")
    reorigin(m)
    export(f"minion_{team}", [m], "Minions")


def make_home():
    reset()
    # Mossy clearing disc.
    verts = [(0, 0, 0)]
    faces = []
    for r, z in ((700, 6), (1200, 0), (1500, -4)):
        for i in range(24):
            a = i / 24 * math.pi * 2
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
    for i in range(24):
        faces.append((0, 1 + i, 1 + (i + 1) % 24))
    for ring in range(2):
        base = 1 + ring * 24
        nxt = base + 24
        for i in range(24):
            a = base + i
            b = base + (i + 1) % 24
            faces.append((a, nxt + i, nxt + (i + 1) % 24, b))
    def cf(center):
        r = math.hypot(center.x, center.y)
        k = min(1.0, r / 1500.0)
        base = tuple(MEADOW[i] * (1 - k) + GRASS[i] * k for i in range(4))
        v = 0.018 * math.sin(center.x * 0.05 + center.y * 0.04)
        return (clamp(base[0] + v), clamp(base[1] + v), clamp(base[2] + v), 1.0)
    disc = mesh_obj("showcase_ground", verts, faces, cf)
    export("showcase_ground", [disc], "Props")

    mound = make("sphere", "moss_mound", (0, 0, 0), scale=(140, 42, 120), radius=0.5,
                 color=MOSS, seg=14, rings=7)
    # Flatten the underside to sit on the ground.
    for v in mound.data.vertices:
        v.co.z = max(v.co.z, -2)
    export("moss_mound", [mound], "Props")


def main():
    ground()
    make_home()
    for team in ("blue", "red"):
        make_tower(team, 0)
        make_tower(team, 1)
        make_crystal(team)
        make_minion(team)
    print("[art] RESULT=PASS out=" + OUT)


main()
