"""Low-poly costume props for the six Polyfork animals.

Every piece is a vertex-coloured mesh bound rigidly to one bone, then joined
into the body SkinnedMesh by polyfork_to_fbx.py. Sizes are expressed as a
fraction of the animal's body height so a 0.36 m cat and a 1.67 m lion both
read correctly after the game normalises them to their design height.
"""
import bpy
import math

PURPLE = (0.42, 0.27, 0.70, 1.0)
PURPLE_DARK = (0.26, 0.16, 0.45, 1.0)
GOLD = (1.0, 0.78, 0.30, 1.0)
WOOD = (0.52, 0.34, 0.20, 1.0)
WOOD_DARK = (0.34, 0.22, 0.13, 1.0)
MOSS = (0.30, 0.51, 0.28, 1.0)
MOSS_LIGHT = (0.42, 0.64, 0.34, 1.0)
PINK = (0.94, 0.56, 0.72, 1.0)
CREAM = (0.96, 0.92, 0.82, 1.0)
CYAN = (0.40, 0.88, 0.95, 1.0)
LEATHER = (0.48, 0.30, 0.18, 1.0)
ORANGE = (0.94, 0.48, 0.18, 1.0)
FEATHER = (0.46, 0.72, 0.66, 1.0)


def bone(arm, name):
    b = arm.data.bones.get(name)
    if b is not None:
        return b
    for cand in arm.data.bones:
        if cand.name.lower().endswith(name.lower()):
            return cand
    return None


def paint(obj, color):
    mesh = obj.data
    attr = mesh.color_attributes.get("Color")
    if attr is None:
        attr = mesh.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    attr.data.foreach_set("color", list(color) * len(attr.data))


def make(kind, name, loc, rot=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0), color=WOOD, **kw):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("verts", 8),
            radius=kw.get("radius", 0.5), depth=kw.get("depth", 1.0), location=loc, rotation=rot)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("verts", 6),
            radius1=kw.get("radius", 0.5), depth=kw.get("depth", 1.0), location=loc, rotation=rot)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=kw.get("subdiv", 1),
            radius=kw.get("radius", 0.5), location=loc, rotation=rot)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=kw.get("radius", 0.5),
            minor_radius=kw.get("minor", 0.1), major_segments=kw.get("major", 10),
            minor_segments=kw.get("minor_seg", 4), location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    paint(obj, color)
    return obj


def bind(obj, arm, bone_name):
    b = bone(arm, bone_name)
    if b is None:
        print(f"[costume] bone missing {bone_name}, fallback Hips")
        b = bone(arm, "Hips")
    if b is None:
        return None
    vg = obj.vertex_groups.new(name=b.name)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


def hpos(arm, name):
    b = bone(arm, name)
    return b.head_local.copy() if b else None


def build(asset, arm, body_height):
    """Return a list of accessory objects for the given Polyfork asset id."""
    h = body_height
    objs = []

    def add(obj, bname):
        bind(obj, arm, bname)
        objs.append(obj)
        return obj

    head = hpos(arm, "Head") or hpos(arm, "Neck") or hpos(arm, "Hips")
    chest = hpos(arm, "Chest") or hpos(arm, "Spine") or head
    hips = hpos(arm, "Hips") or chest
    spine = hpos(arm, "Spine") or chest

    if asset == "lion-base":
        # Wooden shield on the left flank + leaf mantle.
        add(make("cyl", "lion_shield", (chest.x + 0.30 * h, chest.y + 0.04 * h, chest.z - 0.04 * h),
                 rot=(0, math.radians(90), 0), radius=0.17 * h, depth=0.035 * h,
                 color=WOOD, verts=10), "Chest")
        add(make("sphere", "lion_shield_boss", (chest.x + 0.32 * h, chest.y + 0.04 * h, chest.z - 0.04 * h),
                 radius=0.05 * h, color=GOLD, subdiv=1), "Chest")
        add(make("torus", "lion_mantle", (chest.x, chest.y + 0.05 * h, chest.z + 0.03 * h),
                 radius=0.24 * h, minor=0.035 * h, color=MOSS, major=10), "Chest")
        add(make("cone", "lion_cape_tip", (chest.x, chest.y + 0.20 * h, chest.z - 0.28 * h),
                 rot=(math.radians(180), 0, 0), scale=(1.0, 0.18, 1.0),
                 radius=0.18 * h, depth=0.34 * h, color=MOSS_LIGHT, verts=5), "Chest")
    elif asset == "red-fox-5c3bc0":
        # Wizard hat + brim + floating star.
        add(make("cone", "fox_hat", (head.x, head.y, head.z + 0.22 * h),
                 radius=0.19 * h, depth=0.30 * h, color=PURPLE, verts=7), "Head")
        add(make("cyl", "fox_hat_brim", (head.x, head.y, head.z + 0.06 * h),
                 radius=0.25 * h, depth=0.025 * h, color=PURPLE_DARK, verts=10), "Head")
        add(make("cube", "fox_hat_band", (head.x, head.y, head.z + 0.10 * h),
                 scale=(0.30 * h, 0.035 * h, 0.05 * h), color=GOLD), "Head")
        add(make("sphere", "fox_star", (head.x, head.y - 0.20 * h, head.z + 0.34 * h),
                 radius=0.055 * h, color=GOLD, subdiv=1), "Head")
    elif asset == "forest-rabbit-ea2da0":
        # Flower crown + satchel with a carrot.
        add(make("torus", "rabbit_crown", (head.x, head.y, head.z + 0.10 * h),
                 radius=0.20 * h, minor=0.025 * h, color=PINK, major=10), "Head")
        for i in range(3):
            a = i * 2.1
            add(make("sphere", f"rabbit_flower{i}",
                     (head.x + math.cos(a) * 0.20 * h, head.y + math.sin(a) * 0.20 * h, head.z + 0.13 * h),
                     radius=0.045 * h, color=CREAM, subdiv=1), "Head")
        add(make("cube", "rabbit_satchel", (hips.x + 0.22 * h, hips.y - 0.02 * h, hips.z - 0.02 * h),
                 scale=(0.16 * h, 0.14 * h, 0.12 * h), color=WOOD), "Hips")
        add(make("cone", "rabbit_carrot", (hips.x + 0.26 * h, hips.y - 0.02 * h, hips.z + 0.10 * h),
                 radius=0.045 * h, depth=0.14 * h, color=ORANGE, verts=6), "Hips")
    elif asset == "black-bear-adbdc7":
        # Rounded moss back plate + wooden shoulder pads.
        add(make("sphere", "bear_back", (spine.x, spine.y + 0.20 * h, spine.z),
                 scale=(0.55 * h, 0.16 * h, 0.46 * h), radius=0.5,
                 color=MOSS, seg=12, rings=6), "Spine")
        add(make("sphere", "bear_moss", (spine.x, spine.y + 0.28 * h, spine.z + 0.10 * h),
                 scale=(0.18 * h, 0.08 * h, 0.16 * h), radius=0.5,
                 color=MOSS_LIGHT, seg=10, rings=5), "Spine")
        for sx in (-1, 1):
            add(make("sphere", f"bear_pad{sx}", (chest.x + sx * 0.26 * h, chest.y - 0.06 * h, chest.z + 0.06 * h),
                     scale=(0.18 * h, 0.09 * h, 0.22 * h), radius=0.5,
                     color=WOOD_DARK, seg=10, rings=5), "Chest")
    elif asset == "frog-base":
        # Floating bubble + reed cape.
        add(make("sphere", "frog_bubble", (head.x + 0.24 * h, head.y - 0.10 * h, head.z + 0.20 * h),
                 radius=0.16 * h, color=CYAN, subdiv=2), "Head")
        for i in (-1, 0, 1):
            add(make("cone", f"frog_reed{i}", (chest.x + i * 0.16 * h, chest.y + 0.18 * h, chest.z + 0.16 * h),
                     rot=(math.radians(18), 0, math.radians(i * 12)),
                     radius=0.05 * h, depth=0.42 * h, color=MOSS, verts=5), "Chest")
    elif asset == "cat-base":
        # Quiver with arrows + front-leg wraps + chest strap.
        add(make("cyl", "cat_quiver", (spine.x, spine.y + 0.24 * h, spine.z + 0.02 * h),
                 rot=(math.radians(20), 0, math.radians(-24)), radius=0.09 * h, depth=0.38 * h,
                 color=LEATHER, verts=8), "Spine")
        for i in range(3):
            add(make("cyl", f"cat_arrow{i}",
                     (spine.x + (i - 1) * 0.05 * h, spine.y + 0.30 * h, spine.z + 0.20 * h),
                     rot=(math.radians(20), 0, math.radians(-24)), radius=0.012 * h, depth=0.30 * h,
                     color=WOOD_DARK, verts=4), "Spine")
            add(make("cone", f"cat_feather{i}",
                     (spine.x + (i - 1) * 0.05 * h, spine.y + 0.40 * h, spine.z + 0.28 * h),
                     radius=0.035 * h, depth=0.10 * h, color=FEATHER, verts=4), "Spine")
        for bname in ("LeftFrontLeg", "RightFrontLeg"):
            lp = hpos(arm, bname)
            if lp is None: continue
            add(make("cyl", "cat_wrap" + bname, (lp.x, lp.y, lp.z + 0.03 * h),
                     radius=0.055 * h, depth=0.10 * h, color=LEATHER, verts=6), bname)
        add(make("cube", "cat_strap", (chest.x, chest.y, chest.z + 0.03 * h),
                 rot=(0, 0, math.radians(28)), scale=(0.36 * h, 0.025 * h, 0.04 * h),
                 color=LEATHER), "Chest")
    return objs
