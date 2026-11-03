# Blender 4.5 headless art pipeline for TapArena.
# Run: blender -b -P tools/blender_lowpoly.py
# Optional: LOWPOLY_ONLY=tiger LOWPOLY_SKIP_RENDER=1
#
# It authors low-poly hero parts in world space, exports bone-local part JSON for
# Unity (X=forward, Y=up, Z=side), and renders 2D splash/bust/head art + app icon.
import bpy
import bmesh
import math
import os
import json
import random
import sys
from mathutils import Vector, Matrix, Euler

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
JSON_DIR = os.path.join(ROOT, "unity", "Assets", "Resources", "LowPoly")
SPLASH_DIR = os.path.join(ROOT, "unity", "Assets", "Resources", "Splash")
PORTRAIT_DIR = os.path.join(ROOT, "unity", "Assets", "Resources", "Portraits")
ART_DIR = os.path.join(ROOT, "unity", "ArtSource", "LowPoly")
ICON_DIR = os.path.join(ROOT, "unity", "Assets", "Art")
for d in (JSON_DIR, SPLASH_DIR, PORTRAIT_DIR, ART_DIR, ICON_DIR):
    os.makedirs(d, exist_ok=True)

R = math.radians


def _s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def col(h):
    h = h.lstrip("#")
    return tuple(_s2l(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def shade(c, f):
    return tuple(max(0.0, min(1.0, c[i] * f)) for i in range(3))


HEROES = {
    "tiger": dict(h=76, fur="#F2A94F", dark="#C9752F", cream="#FFF3E2", accent="#2E8B6F",
                  species="tiger", eye="#2A1710", accessory="scarf"),
    "fox": dict(h=74, fur="#E9A24C", dark="#B5713A", cream="#FFF6EC", accent="#7B54C7",
                species="fox", eye="#2A1710", accessory="robe"),
    "rabbit": dict(h=70, fur="#FFF7F3", dark="#F3D3E0", cream="#FFFFFF", accent="#EE8FB8",
                   species="rabbit", eye="#3A2028", accessory="dress"),
    "bear": dict(h=88, fur="#B98155", dark="#8A5A36", cream="#FBE9D2", accent="#4E9A63",
                 species="bear", eye="#2A1710", accessory="cape"),
    "otter": dict(h=72, fur="#7F9FC4", dark="#5A7290", cream="#F3F7FF", accent="#4FA88F",
                  species="otter", eye="#182636", accessory="vest"),
    "hedgehog": dict(h=68, fur="#D9B98F", dark="#9C7B55", cream="#FFF1DC", accent="#E0604F",
                     species="hedgehog", eye="#2A1A0C", accessory="harness"),
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 24
    sc.render.image_settings.file_format = "PNG"
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0
    sc.view_settings.gamma = 1.0
    sc.render.use_freestyle = True
    vl = bpy.context.view_layer
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    try:
        while len(fs.linesets):
            fs.linesets.remove(fs.linesets[0])
    except Exception:
        pass
    ls = fs.linesets.new("ink")
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_edge_mark = False
    ls.linestyle.color = (0.055, 0.035, 0.045)
    ls.linestyle.thickness = 1.6
    fs.crease_angle = R(138)
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.025, 0.055, 0.055, 1)
    bg.inputs["Strength"].default_value = 0.38
    return sc


def add_obj(name, mesh, mat, coll):
    ob = bpy.data.objects.new(name, mesh)
    coll.objects.link(ob)
    if mat is not None:
        ob.data.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = False
    return ob


def mat_flat(c, strength=1.0):
    m = bpy.data.materials.new("flat")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*c, 1)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def mat_toon(c, emissive=False, strength=1.0):
    m = bpy.data.materials.new("toon")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    if emissive:
        em.inputs["Color"].default_value = (*c, 1)
        em.inputs["Strength"].default_value = strength
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        return m
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.interpolation = "CONSTANT"
    e0 = cr.elements[0]
    e0.position = 0.0
    e0.color = (*shade(c, 0.52), 1)
    e1 = cr.elements.new(0.30)
    e1.color = (*shade(c, 0.82), 1)
    e2 = cr.elements.new(0.62)
    e2.color = (*shade(c, 1.10), 1)
    nt.links.new(diff.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def mat_bg(c, strength=1.0):
    return mat_flat(c, strength)


def mat_gradient(c0, c1):
    m = bpy.data.materials.new("grad")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tex = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = (*c0, 1)
    cr.elements[1].position = 1.0
    cr.elements[1].color = (*c1, 1)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    nt.links.new(tex.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def make_ico(subdiv=1, radius=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    return bm


def make_cube(size=1.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=size)
    return bm


def make_cone(r1, r2, depth, segments=6):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=segments,
                          radius1=r1, radius2=r2, depth=depth)
    return bm


def bm_xform(bm, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    m = Matrix.Translation(Vector(loc))
    if any(abs(a) > 1e-8 for a in rot):
        m = m @ Euler(rot, "XYZ").to_matrix().to_4x4()
    m = m @ Matrix.Diagonal(Vector((scale[0], scale[1], scale[2], 1.0)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def finalize_bm(bm):
    try:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    except Exception:
        pass
    return bm


def lathe_bm(profiles, sides=8, center=(0, 0), close_bottom=True, close_top=True):
    """profiles: [(z, radius_x, radius_y), ...] in local world coords."""
    bm = bmesh.new()
    rings = []
    for (z, rx, ry) in profiles:
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ring.append(bm.verts.new((center[0] + math.cos(a) * rx,
                                      center[1] + math.sin(a) * ry, z)))
        rings.append(ring)
    bm.verts.ensure_lookup_table()
    for j in range(len(rings) - 1):
        for i in range(sides):
            a = rings[j][i]
            b = rings[j][(i + 1) % sides]
            c = rings[j + 1][(i + 1) % sides]
            d = rings[j + 1][i]
            bm.faces.new((a, b, c, d))
    if close_bottom:
        bm.faces.new(tuple(reversed(rings[0])))
    if close_top:
        bm.faces.new(tuple(rings[-1]))
    return finalize_bm(bm)


def torus_bm(major, minor, seg_major=12, seg_minor=5, center=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    verts = []
    for i in range(seg_major):
        phi = 2 * math.pi * i / seg_major
        cx, cy = math.cos(phi) * major, math.sin(phi) * major
        ring = []
        for j in range(seg_minor):
            th = 2 * math.pi * j / seg_minor
            rr = major + math.cos(th) * minor
            ring.append(bm.verts.new((math.cos(phi) * rr, math.sin(phi) * rr,
                                      math.sin(th) * minor)))
        verts.append(ring)
    bm.verts.ensure_lookup_table()
    for i in range(seg_major):
        for j in range(seg_minor):
            a = verts[i][j]
            b = verts[(i + 1) % seg_major][j]
            c = verts[(i + 1) % seg_major][(j + 1) % seg_minor]
            d = verts[i][(j + 1) % seg_minor]
            bm.faces.new((a, b, c, d))
    bm_xform(bm, center, (1, 1, 1), rot)
    return finalize_bm(bm)


def segment_bm(a, b, r0, r1, sides=6, flat=1.0):
    a = Vector(a)
    b = Vector(b)
    axis = (b - a)
    if axis.length < 1e-6:
        axis = Vector((0, 0, 1))
    axis.normalize()
    n1 = axis.orthogonal().normalized()
    n2 = axis.cross(n1).normalized()
    bm = bmesh.new()
    rings = []
    for t, rr in ((0.0, r0), (1.0, r1)):
        c = a.lerp(b, t)
        ring = []
        for i in range(sides):
            ang = 2 * math.pi * i / sides
            off = (n1 * math.cos(ang) + n2 * math.sin(ang)) * rr
            ring.append(bm.verts.new(c + off))
        rings.append(ring)
    bm.verts.ensure_lookup_table()
    for i in range(sides):
        bm.faces.new((rings[0][i], rings[0][(i + 1) % sides],
                      rings[1][(i + 1) % sides], rings[1][i]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[1]))
    return finalize_bm(bm)


def octa_bm(size=1.0, center=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    bm = bmesh.new()
    v = [bm.verts.new((size * scale[0], 0, 0)), bm.verts.new((-size * scale[0], 0, 0)),
         bm.verts.new((0, size * scale[1], 0)), bm.verts.new((0, -size * scale[1], 0)),
         bm.verts.new((0, 0, size * scale[2])), bm.verts.new((0, 0, -size * scale[2]))]
    bm.verts.ensure_lookup_table()
    for a, b in ((0, 2), (0, 3), (1, 2), (1, 3)):
        for c in (4, 5):
            bm.faces.new((v[a], v[b], v[c]))
    bm_xform(bm, center, (1, 1, 1), rot)
    return finalize_bm(bm)


# ---------------------------------------------------------------- hero builder


PARENT = {
    "hips": None, "chest": "hips", "neck": "chest", "head": "neck",
    "earL": "head", "earR": "head", "eyes": "head",
    "shL": "chest", "elL": "shL", "wrL": "elL",
    "shR": "chest", "elR": "shR", "wrR": "elR",
    "weapon": "wrR",
    "thL": "hips", "knL": "thL", "anL": "knL",
    "thR": "hips", "knR": "thR", "anR": "knR",
    "tail1": "hips", "tail2": "tail1",
}

BONE_ORDER = ["hips", "chest", "neck", "head", "earL", "earR", "eyes",
              "shL", "elL", "wrL", "shR", "elR", "wrR", "weapon",
              "thL", "knL", "anL", "thR", "knR", "anR", "tail1", "tail2"]


def pivots(h):
    p = {
        "hips": Vector((0, 0, .40 * h)),
        "chest": Vector((0, 0, .66 * h)),
        "neck": Vector((0, 0, .78 * h)),
        "head": Vector((0, 0, .78 * h)),
        "earL": Vector((-.14 * h, 0, 1.14 * h)),
        "earR": Vector((.14 * h, 0, 1.14 * h)),
        "eyes": Vector((0, 0, .93 * h)),
        "shL": Vector((-.245 * h, .02 * h, .665 * h)),
        "elL": Vector((-.255 * h, .02 * h, .525 * h)),
        "wrL": Vector((-.285 * h, .02 * h, .395 * h)),
        "shR": Vector((.245 * h, .02 * h, .665 * h)),
        "elR": Vector((.265 * h, .02 * h, .525 * h)),
        "wrR": Vector((.295 * h, .02 * h, .395 * h)),
        "weapon": Vector((.305 * h, .02 * h, .515 * h)),
        "thL": Vector((-.12 * h, 0, .40 * h)),
        "knL": Vector((-.128 * h, 0, .22 * h)),
        "anL": Vector((-.142 * h, 0, .065 * h)),
        "thR": Vector((.12 * h, 0, .40 * h)),
        "knR": Vector((.128 * h, 0, .22 * h)),
        "anR": Vector((.142 * h, 0, .065 * h)),
        "tail1": Vector((0, -.17 * h, .43 * h)),
        "tail2": Vector((0, -.28 * h, .445 * h)),
    }
    return p


class Hero:
    def __init__(self, hid, spec, coll):
        self.id = hid
        self.spec = spec
        self.h = spec["h"]
        self.headR = .29 * self.h
        self.coll = coll
        self.p = pivots(self.h)
        self.empties = {}
        self.parts = []          # dicts: bone,color,emissive,verts(U),faces
        self.objs = []
        self.mat_cache = {}
        self.make_empties()
        self.build()

    # ---- materials / parts ----
    def mat(self, hx, emissive=False, strength=1.0):
        key = (hx, emissive, strength)
        if key in self.mat_cache:
            return self.mat_cache[key]
        m = mat_toon(col(hx), emissive, strength)
        self.mat_cache[key] = m
        return m

    def add(self, bm, bone, hx, name, emissive=False, strength=1.0):
        bm = finalize_bm(bm)
        piv = self.p[bone]
        bmesh.ops.translate(bm, vec=-piv, verts=bm.verts)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.validate()
        me.update()
        m = self.mat(hx, emissive, strength)
        ob = add_obj(name, me, m, self.coll)
        ob.parent = self.empties[bone]
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.location = (0, 0, 0)
        self.objs.append(ob)
        # JSON coords: Blender local (x,y,z) -> Unity (y,z,x)
        verts_u = []
        for v in me.vertices:
            verts_u.extend((round(v.co.y, 4), round(v.co.z, 4), round(v.co.x, 4)))
        faces = []
        for poly in me.polygons:
            ii = list(poly.vertices)
            for k in range(1, len(ii) - 1):
                faces.extend((ii[0], ii[k], ii[k + 1]))
        self.parts.append(dict(bone=bone, color=hx, emissive=emissive,
                               strength=strength, verts=verts_u, faces=faces))
        return ob

    def ico(self, bone, hx, loc, scale, subdiv=1, rot=(0, 0, 0), name="ico",
            emissive=False, strength=1.0):
        bm = make_ico(subdiv, 1.0)
        bm_xform(bm, loc, scale, rot)
        return self.add(bm, bone, hx, name, emissive, strength)

    def box(self, bone, hx, loc, scale, rot=(0, 0, 0), name="box",
            emissive=False, strength=1.0):
        bm = make_cube(1.0)
        bm_xform(bm, loc, scale, rot)
        return self.add(bm, bone, hx, name, emissive, strength)

    def cone(self, bone, hx, loc, r1, r2, depth, segments=6, rot=(0, 0, 0),
             name="cone", emissive=False, strength=1.0):
        bm = make_cone(r1, r2, depth, segments)
        bm_xform(bm, loc, (1, 1, 1), rot)
        return self.add(bm, bone, hx, name, emissive, strength)

    def cyl(self, bone, hx, loc, r, depth, segments=8, rot=(0, 0, 0),
            name="cyl", emissive=False, strength=1.0):
        return self.cone(bone, hx, loc, r, r, depth, segments, rot, name, emissive, strength)

    def disc(self, bone, hx, loc, rx, rz, depth, segments=8, name="disc"):
        bm = make_cone(1.0, 1.0, depth, segments)
        bm_xform(bm, loc, (rx, rz, 1.0), (R(90), 0, 0))
        return self.add(bm, bone, hx, name)

    def lathe(self, bone, hx, profiles, sides=8, name="lathe", rot=None, loc=(0, 0, 0)):
        bm = lathe_bm(profiles, sides)
        if rot is not None:
            bm_xform(bm, loc, (1, 1, 1), rot)
        elif loc != (0, 0, 0):
            bm_xform(bm, loc, (1, 1, 1), (0, 0, 0))
        return self.add(bm, bone, hx, name)

    def torus(self, bone, hx, center, major, minor, seg_major=10, seg_minor=4, rot=(0, 0, 0), name="torus"):
        bm = torus_bm(major, minor, seg_major, seg_minor, center, rot)
        return self.add(bm, bone, hx, name)

    def seg(self, bone, hx, a, b, r0, r1, sides=6, name="seg"):
        bm = segment_bm(a, b, r0, r1, sides)
        return self.add(bm, bone, hx, name)

    # ---- skeleton ----
    def make_empties(self):
        for name in BONE_ORDER:
            e = bpy.data.objects.new(name, None)
            self.coll.objects.link(e)
            parent = PARENT[name]
            if parent:
                e.parent = self.empties[parent]
                e.location = self.p[name] - self.p[parent]
            else:
                e.location = self.p[name]
            if name == "earL":
                e.rotation_euler = (0, R(-10), 0)
            elif name == "earR":
                e.rotation_euler = (0, R(10), 0)
            self.empties[name] = e

    # ---- geometry ----
    def build(self):
        sp = self.spec
        h = self.h
        fur, dark, cream, accent = sp["fur"], sp["dark"], sp["cream"], sp["accent"]
        species = sp["species"]
        headR = self.headR
        eye = sp["eye"]
        # torsos
        if species == "bear":
            hipr = .27
            chestr = .25
        elif species == "fox" or species == "rabbit":
            hipr = .23
            chestr = .225
        else:
            hipr = .24
            chestr = .23
        self.lathe("hips", fur, [(.255 * h, hipr * h * .88, .73 * hipr * h),
                                 (.36 * h, hipr * h, .80 * hipr * h),
                                 (.50 * h, hipr * h * .95, .78 * hipr * h),
                                 (.62 * h, hipr * h * .70, .58 * hipr * h)], 8, "pelvis")
        self.lathe("chest", fur, [(.59 * h, chestr * h * .82, .68 * chestr * h),
                                  (.68 * h, chestr * h, .76 * chestr * h),
                                  (.77 * h, chestr * h * .62, .58 * chestr * h),
                                  (.80 * h, chestr * h * .26, .28 * chestr * h)], 8, "chest")
        # belly patch
        self.ico("hips", cream, (0, .165 * h, .46 * h), (.105 * h, .018 * h, .17 * h), 1, name="belly")
        # belt and buckle
        self.torus("hips", dark, (0, 0, .425 * h), .225 * h, .018 * h, 10, 4, name="belt")
        self.box("hips", "#F0C24E", (0, .225 * h, .425 * h), (.045 * h, .018 * h, .028 * h), name="buckle")
        # head
        self.ico("head", fur, (0, 0, .93 * h), (headR, headR * .95, headR * .96), 2, name="head")
        # muzzle / nose / mouth / cheeks
        muz_y = .205 * h if species != "fox" else .235 * h
        self.ico("head", cream, (0, muz_y, .855 * h), (headR * .29, headR * .27, headR * .205), 2, name="muzzle")
        self.ico("head", eye, (0, muz_y + headR * .215, .89 * h),
                 (headR * .075, headR * .060, headR * .055), 1, name="nose")
        self.box("head", eye, (0, muz_y + headR * .24, .833 * h), (.026 * h, .008 * h, .006 * h), name="mouth")
        for side in (-1, 1):
            self.ico("head", "#F08A9A", (side * .19 * h, .225 * h, .87 * h),
                     (.028 * h, .010 * h, .020 * h), 1, name="blush")
        # eyes: flat low-poly discs sitting proud of the faceted face.
        ex = .105 * h
        ey = .268 * h
        ez = .95 * h
        for side in (-1, 1):
            self.disc("eyes", eye, (side * ex, ey, ez), .052 * h, .066 * h, .012 * h, 8, name="eye")
            self.ico("eyes", "#FFFFFF", (side * ex + .015 * h, ey + .016 * h, ez + .032 * h),
                     (.012 * h, .006 * h, .014 * h), 1, name="glint")
        # ears
        if species == "rabbit":
            for side, bone in ((-1, "earL"), (1, "earR")):
                self.seg(bone, fur, (side * .14 * h, 0, 1.14 * h),
                         (side * .18 * h, 0, 1.52 * h), .072 * h, .043 * h, 6, "longear")
                self.ico(bone, fur, (side * .18 * h, 0, 1.535 * h),
                         (.043 * h, .032 * h, .05 * h), 1, name="eartip")
                self.seg(bone, "#F2A7C0", (side * .14 * h, .045 * h, 1.16 * h),
                         (side * .18 * h, .045 * h, 1.49 * h), .035 * h, .018 * h, 5, "innerear")
        elif species == "fox":
            for side, bone in ((-1, "earL"), (1, "earR")):
                self.cone(bone, fur, (side * .14 * h, 0, 1.24 * h), .085 * h, .012 * h, .22 * h, 4, name="pointear")
                self.cone(bone, "#F2A7A0", (side * .14 * h, .035 * h, 1.23 * h), .042 * h, .006 * h, .16 * h, 4, name="innerear")
        else:
            escale = 1.25 if species == "bear" else (.82 if species in ("otter", "hedgehog") else 1.0)
            for side, bone in ((-1, "earL"), (1, "earR")):
                self.ico(bone, fur, (side * .14 * h, 0, 1.18 * h),
                         (.075 * h * escale, .045 * h, .085 * h * escale), 1, name="roundear")
                self.ico(bone, cream, (side * .14 * h, .035 * h, 1.18 * h),
                         (.040 * h * escale, .018 * h, .050 * h * escale), 1, name="innerear")
        if species == "tiger":
            # 额头/太阳穴的低多边形虎纹，别让阿虎只剩一身橙色
            for side in (-1, 1):
                self.box("head", dark, (side * .075 * h, .232 * h, 1.045 * h),
                         (.016 * h, .010 * h, .048 * h), (0, side * R(12), 0), name="tigerstripe")
                self.box("head", dark, (side * .205 * h, .145 * h, .985 * h),
                         (.012 * h, .010 * h, .052 * h), (0, side * R(25), 0), name="tigerstripe")
                self.box("head", dark, (side * .225 * h, .105 * h, .905 * h),
                         (.010 * h, .009 * h, .040 * h), (0, side * R(30), 0), name="tigerstripe")
        # arms
        for side, sh, el, wr in ((-1, "shL", "elL", "wrL"), (1, "shR", "elR", "wrR")):
            self.ico(sh, fur, self.p[sh], (.086 * h,) * 3, 1, name="shoulder")
            self.seg(sh, fur, self.p[sh], self.p[el], .075 * h, .064 * h, 6, "upperarm")
            self.ico(el, fur, self.p[el], (.059 * h,) * 3, 1, name="elbow")
            self.seg(el, fur, self.p[el], self.p[wr], .066 * h, .056 * h, 6, "lowerarm")
            self.ico(wr, cream, self.p[wr] + Vector((0, .008 * h, -.025 * h)),
                     (.076 * h, .061 * h, .066 * h), 1, name="hand")
            self.cyl(wr, accent, self.p[wr] + Vector((0, 0, .02 * h)), .066 * h, .040 * h, 6, name="cuff")
        # legs
        for side, th, kn, an in ((-1, "thL", "knL", "anL"), (1, "thR", "knR", "anR")):
            self.ico(th, fur, self.p[th], (.086 * h,) * 3, 1, name="hipjoint")
            self.seg(th, fur, self.p[th], self.p[kn], .084 * h, .072 * h, 6, "thigh")
            self.ico(kn, fur, self.p[kn], (.059 * h,) * 3, 1, name="knee")
            self.seg(kn, fur, self.p[kn], self.p[an], .072 * h, .059 * h, 6, "shin")
            self.ico(an, cream, self.p[an] + Vector((0, .035 * h, -.025 * h)),
                     (.092 * h, .106 * h, .058 * h), 1, name="boot")
            self.box(an, dark, self.p[an] + Vector((0, .035 * h, -.060 * h)),
                     (.086 * h, .106 * h, .020 * h), name="sole")
        # tail
        self.build_tail(species, fur, cream, dark)
        # outfits / silhouettes
        self.build_outfit(species, fur, cream, dark, accent)
        # head decoration
        self.build_decor(species, fur, dark, cream, accent)
        # weapon / props
        self.build_weapon(species)

    def build_tail(self, species, fur, cream, dark):
        h = self.h
        if species == "rabbit":
            self.ico("tail1", cream, (0, -.01 * h, 0), (.085 * h, .075 * h, .085 * h), 1, name="puff")
            return
        if species == "hedgehog":
            self.ico("tail1", fur, (0, -.02 * h, 0), (.055 * h, .045 * h, .055 * h), 1, name="tail")
            return
        if species == "otter":
            self.seg("tail1", fur, (0, -.17 * h, .43 * h), (0, -.33 * h, .40 * h),
                     .065 * h, .035 * h, 6, "paddle")
            self.ico("tail2", dark, (0, -.06 * h, .005 * h), (.055 * h, .035 * h, .025 * h), 1, name="tailtip")
            return
        big = species == "fox"
        self.seg("tail1", fur, (0, -.17 * h, .43 * h), (0, -.29 * h, .46 * h),
                 (.09 if big else .06) * h, (.075 if big else .05) * h, 6, "tailbase")
        self.ico("tail2", cream if species in ("fox", "tiger") else fur,
                 (0, -.10 * h, .035 * h), ((.075 if big else .05) * h,
                                           (.075 if big else .05) * h,
                                           (.075 if big else .05) * h), 1, name="tailtip")

    def build_outfit(self, species, fur, cream, dark, accent):
        h = self.h
        if species == "tiger":
            self.torus("chest", accent, (0, 0, .665 * h), .175 * h, .032 * h, 10, 4, name="scarf")
            self.box("chest", accent, (0, .16 * h, .595 * h), (.038 * h, .016 * h, .070 * h),
                     (0, R(8), 0), name="scarfend")
            for side in (-1, 1):
                self.box("chest", dark, (side * .135 * h, .125 * h, .66 * h),
                         (.030 * h, .012 * h, .09 * h), (0, side * R(10), 0), name="harness")
        elif species == "fox":
            self.lathe("hips", accent, [(.42 * h, .235 * h, .18 * h),
                                        (.30 * h, .265 * h, .205 * h),
                                        (.205 * h, .295 * h, .23 * h)], 8, "robe")
            self.torus("hips", "#F0C24E", (0, 0, .425 * h), .235 * h, .015 * h, 10, 4, name="goldbelt")
            self.ico("chest", cream, (0, .16 * h, .72 * h), (.095 * h, .025 * h, .075 * h), 1, name="chestfluff")
            self.box("hips", "#6A442E", (-.15 * h, -.02 * h, .48 * h),
                     (.10 * h, .06 * h, .09 * h), (0, R(8), 0), name="satchel")
        elif species == "rabbit":
            self.lathe("hips", accent, [(.42 * h, .235 * h, .18 * h),
                                        (.29 * h, .275 * h, .21 * h),
                                        (.20 * h, .305 * h, .235 * h)], 8, "skirt")
            self.lathe("hips", cream, [(.44 * h, .24 * h, .185 * h),
                                       (.20 * h, .315 * h, .24 * h)], 8, "underskirt")
            for side in (-1, 1):
                self.ico("chest", "#F49AB8", (side * .06 * h, .165 * h, .735 * h),
                         (.045 * h, .025 * h, .04 * h), 1, name="pearl")
            self.box("chest", "#F0C24E", (0, .18 * h, .735 * h), (.035 * h, .02 * h, .03 * h), name="pearlc")
        elif species == "bear":
            self.ico("chest", accent, (0, -.16 * h, .64 * h), (.20 * h, .028 * h, .17 * h), 1, name="cape")
            self.torus("hips", dark, (0, 0, .425 * h), .235 * h, .014 * h, 10, 4, name="rope")
            # leaf shield on left wrist
            self.cyl("wrL", accent, self.p["wrL"] + Vector((-.035 * h, .06 * h, 0)),
                     .165 * h, .020 * h, 6, (R(90), 0, 0), name="shield")
            self.box("wrL", dark, self.p["wrL"] + Vector((-.035 * h, .075 * h, 0)),
                     (.018 * h, .018 * h, .14 * h), name="shieldv")
            self.box("wrL", dark, self.p["wrL"] + Vector((-.035 * h, .075 * h, 0)),
                     (.018 * h, .14 * h, .018 * h), name="shieldh")
        elif species == "otter":
            self.torus("chest", accent, (0, 0, .72 * h), .185 * h, .035 * h, 10, 4, name="vest")
            self.ico("chest", "#F0C24E", (0, .18 * h, .70 * h), (.045 * h, .025 * h, .045 * h), 1, name="shell")
        elif species == "hedgehog":
            self.torus("chest", accent, (0, 0, .70 * h), .185 * h, .022 * h, 10, 4, name="harness")
            self.box("chest", "#F0C24E", (0, .18 * h, .70 * h), (.032 * h, .02 * h, .032 * h), name="buckle")
            self.box("hips", "#6A442E", (-.14 * h, -.12 * h, .47 * h),
                     (.09 * h, .06 * h, .08 * h), (0, R(6), 0), name="pouch")
            # back quills
            for row in range(3):
                for i in range(-2, 3):
                    self.cone("chest", dark, (i * .065 * h, -.21 * h, (.58 + row * .07) * h),
                              .045 * h, .004 * h, .16 * h, 4, (R(-52), 0, R(i * 8)), name="quill")

    def build_decor(self, species, fur, dark, cream, accent):
        h = self.h
        if species == "tiger":
            for i, x in enumerate((-.045 * h, 0, .05 * h)):
                self.cone("head", fur if i != 1 else dark,
                          (x, 0, 1.22 * h), .035 * h, .003 * h, .11 * h, 4,
                          (R(-18 + i * 12), 0, R(-16 + i * 16)), name="tuft")
        elif species == "fox":
            # wizard hat
            self.cyl("head", "#6B4FB0", (0, 0, 1.195 * h), .285 * h, .022 * h, 8, name="hatbrim")
            self.cone("head", "#6B4FB0", (0, 0, 1.38 * h), .22 * h, .012 * h, .36 * h, 6, name="hat")
            self.cyl("head", "#F0C24E", (0, 0, 1.225 * h), .195 * h, .018 * h, 8, name="hatband")
            self.octa("head", "#FFE08A", (0, 0, 1.29 * h), .06 * h, (1, .35, 1), name="hatstar", emissive=True, strength=1.2)
        elif species == "rabbit":
            # flower crown
            for i in range(5):
                x = (-.18 + i * .09) * h
                z = 1.195 * h + math.cos((i - 2) * .55) * .015 * h
                self.ico("head", "#F0C24E", (x, .10 * h, z), (.028 * h, .018 * h, .028 * h), 1, name="flowerc")
                for k in range(4):
                    a = k * math.pi / 2
                    self.ico("head", "#F49AB8", (x + math.cos(a) * .028 * h, .105 * h,
                                                  z + math.sin(a) * .028 * h),
                             (.020 * h, .015 * h, .020 * h), 1, name="petal")
        elif species == "bear":
            self.cone("head", "#4E9A63", (0, .02 * h, 1.22 * h), .055 * h, .008 * h, .16 * h, 4,
                      (R(-12), 0, R(-18)), name="sprout")
            self.ico("head", "#6FBF73", (0, .06 * h, 1.255 * h), (.06 * h, .03 * h, .025 * h), 1,
                     (0, 0, R(-22)), name="leaf")
        elif species == "otter":
            self.ico("head", "#BDEBFF", (0, .02 * h, 1.33 * h), (.070 * h,) * 3, 1,
                     name="bubble", emissive=True, strength=.55)
            self.cone("head", fur, (0, 0, 1.235 * h), .030 * h, .002 * h, .09 * h, 4,
                      (R(-10), 0, 0), name="tuft")
        elif species == "hedgehog":
            for i in (-1, 0, 1):
                self.cone("head", dark, (i * .07 * h, 0, 1.255 * h), .045 * h, .004 * h, .16 * h, 4,
                          (R(-8), 0, R(i * 14)), name="crest")
            for side in (-1, 1):
                for i in range(2):
                    self.cone("head", dark, (side * (.21 + i * .04) * h, -.03 * h,
                                             (1.08 - i * .045) * h),
                              .045 * h, .004 * h, .16 * h, 4,
                              (0, side * R(60 + i * 8), R(12)), name="sidequill")

    def octa(self, bone, hx, loc, size, scale=(1, 1, 1), rot=(0, 0, 0), name="octa",
             emissive=False, strength=1.0):
        bm = octa_bm(size, loc, scale, rot)
        return self.add(bm, bone, hx, name, emissive, strength)

    def build_weapon(self, species):
        h = self.h
        if species in ("fox", "rabbit"):
            # staff/wand attached to the weapon pivot (above the right hand)
            self.cyl("weapon", "#7A5238", (0, 0, .06 * h), .022 * h, .34 * h, 6, name="staff")
            self.cyl("weapon", "#F0C24E", (0, 0, .20 * h), .042 * h, .015 * h, 8, name="staffband")
            if species == "fox":
                self.octa("weapon", "#FFE08A", (0, 0, .27 * h), .075 * h, (1, .4, 1),
                          name="staffstar", emissive=True, strength=1.3)
            else:
                self.octa("weapon", "#FFDF8A", (0, 0, .245 * h), .065 * h, (1, 1, .45),
                          name="wandstar", emissive=True, strength=1.3)

    # ---- json / pose / render ----
    def export_json(self):
        groups = {}
        for p in self.parts:
            key = (p["bone"], p["color"], p["emissive"], p["strength"])
            g = groups.setdefault(key, dict(bone=p["bone"], color=p["color"],
                                            emissive=p["emissive"], strength=p["strength"],
                                            verts=[], faces=[]))
            base = len(g["verts"]) // 3
            g["verts"].extend(p["verts"])
            g["faces"].extend([i + base for i in p["faces"]])
        data = dict(id=self.id, height=self.h, headR=self.headR,
                    parts=list(groups.values()))
        with open(os.path.join(JSON_DIR, self.id + ".json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        print("JSON", self.id, "parts", len(data["parts"]),
              "tris", sum(len(p["faces"]) for p in data["parts"]) // 3)

    def pose(self):
        R_ = R
        e = self.empties
        e["hips"].rotation_euler = (0, 0, R_(-7))
        e["chest"].rotation_euler = (R_(2), 0, R_(12))
        e["neck"].rotation_euler = (0, 0, R_(-2))
        e["head"].rotation_euler = (R_(-4), 0, R_(10))
        e["shR"].rotation_euler = (R_(8), R_(-100), 0)
        e["elR"].rotation_euler = (0, R_(-22), 0)
        e["shL"].rotation_euler = (R_(-4), R_(18), 0)
        e["elL"].rotation_euler = (0, R_(20), 0)
        e["thL"].rotation_euler = (R_(18), 0, 0)
        e["knL"].rotation_euler = (R_(-24), 0, 0)
        e["thR"].rotation_euler = (R_(-10), 0, 0)
        e["knR"].rotation_euler = (R_(-4), 0, 0)
        e["tail1"].rotation_euler = (0, 0, R_(10))
        e["tail2"].rotation_euler = (0, 0, R_(16))
        e["earL"].rotation_euler = (0, R_(-18), R_(3))
        e["earR"].rotation_euler = (0, R_(18), R_(-3))

    def hide_non_head(self):
        keep = {"head", "earL", "earR", "eyes"}
        for ob in self.objs:
            if ob.parent and ob.parent.name not in keep:
                ob.hide_render = True


# ---------------------------------------------------------------- background / render


def make_bg(coll, accent, seed):
    rnd = random.Random(seed)
    c0 = (0.015, 0.040, 0.055)
    c1 = (0.05, 0.12, 0.15)
    # backdrop plane
    bmesh_bg = bmesh.new()
    vs = [bmesh_bg.verts.new((-500, -260, -50)), bmesh_bg.verts.new((500, -260, -50)),
          bmesh_bg.verts.new((500, -260, 320)), bmesh_bg.verts.new((-500, -260, 320))]
    bmesh_bg.faces.new((vs[0], vs[1], vs[2], vs[3]))
    me = bpy.data.meshes.new("backdrop")
    bmesh_bg.to_mesh(me)
    bmesh_bg.free()
    ob = add_obj("backdrop", me, mat_gradient(c0, c1), coll)
    # ground stage
    gbm = make_cone(70, 74, 8, 10)
    bm_xform(gbm, (0, 0, -4), (1, 1, 1), (0, 0, 0))
    gm = bpy.data.meshes.new("stage")
    gbm.to_mesh(gm); gbm.free()
    add_obj("stage", gm, mat_toon(col("#263A34")), coll)
    # halo disc (behind the hero, facing camera)
    hbm = make_cone(78, 78, 2, 12)
    bm_xform(hbm, (0, -160, 72), (1, 1, 1), (R(90), 0, 0))
    hm = bpy.data.meshes.new("halo")
    hbm.to_mesh(hm); hbm.free()
    add_obj("halo", hm, mat_flat(mix(col(accent), (0.01, 0.02, 0.02), 0.55), 0.8), coll)
    # floating low-poly shards
    for i in range(9):
        ang = rnd.uniform(0, math.pi * 2)
        rad = rnd.uniform(95, 165)
        x = math.cos(ang) * rad
        z = rnd.uniform(25, 145)
        y = -rnd.uniform(80, 190)
        s = rnd.uniform(5, 13)
        c = accent if i % 3 else "#FFD98A"
        bm = make_ico(0, 1)
        bm_xform(bm, (x, y, z), (s, s * rnd.uniform(.5, 1.2), s * rnd.uniform(.7, 1.4)),
                 (rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3)))
        me = bpy.data.meshes.new("shard")
        bm.to_mesh(me); bm.free()
        add_obj("shard", me, mat_flat(col(c), 1.2), coll)
    # a few leaf triangles on the ground
    for i in range(5):
        x = rnd.uniform(-70, 70); y = rnd.uniform(-25, 35)
        bm = make_cone(8, 0, 2, 3)
        bm_xform(bm, (x, y, 1.5), (1, 1, 1), (R(90), 0, rnd.uniform(0, 3)))
        me = bpy.data.meshes.new("leaf")
        bm.to_mesh(me); bm.free()
        add_obj("leaf", me, mat_flat(mix(col(accent), (0.1, 0.25, 0.12), .5), .8), coll)


def make_light(coll, name, kind, loc, target, energy, color, size=100):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == "AREA":
        data.size = size
    ob = bpy.data.objects.new(name, data)
    coll.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return ob


def make_camera(coll, loc, target, lens, rx, ry):
    data = bpy.data.cameras.new("cam")
    data.lens = lens
    data.sensor_fit = "VERTICAL"
    ob = bpy.data.objects.new("cam", data)
    coll.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc = bpy.context.scene
    sc.camera = ob
    sc.render.resolution_x = rx
    sc.render.resolution_y = ry
    return ob


def setup_lights(coll):
    make_light(coll, "key", "SUN", (180, 240, 300), (0, 0, 60), 3.2,
               (1.0, 0.94, 0.82))
    make_light(coll, "rim", "SUN", (-80, -260, 220), (0, 0, 80), 2.0,
               (0.55, 0.8, 1.0))
    make_light(coll, "fill", "AREA", (0, 200, 90), (0, 0, 60), 180,
               (1.0, 0.9, 0.8), 180)


def render_hero(spec, hid, coll):
    hero = Hero(hid, spec, coll)
    hero.export_json()
    hero.pose()
    setup_lights(coll)
    make_bg(coll, spec["accent"], sum(ord(c) for c in hid))
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    # splash
    make_camera(coll, (215, 360, 140), (0, 0, 56), 72, 768, 1152)
    sc.render.film_transparent = False
    sc.render.image_settings.color_mode = "RGB"
    sc.render.filepath = os.path.join(SPLASH_DIR, hid + "_splash.png")
    bpy.ops.render.render(write_still=True)
    print("SPLASH", sc.render.filepath)
    # bust
    make_camera(coll, (125, 250, 108), (0, 0, 82), 78, 512, 512)
    sc.render.filepath = os.path.join(SPLASH_DIR, hid + "_bust.png")
    bpy.ops.render.render(write_still=True)
    print("BUST", sc.render.filepath)
    # transparent head for HUD
    for ob in list(bpy.data.objects):
        if ob.type == "MESH" and ob.parent is None:
            ob.hide_render = True
    hero.hide_non_head()
    make_camera(coll, (75, 205, 100), (0, 0, 84), 75, 256, 256)
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.filepath = os.path.join(PORTRAIT_DIR, hid + "_head.png")
    bpy.ops.render.render(write_still=True)
    print("HEAD", sc.render.filepath)
    return hero


def render_icon():
    spec = HEROES["tiger"]
    reset_scene()
    coll = bpy.data.collections.new("icon")
    bpy.context.scene.collection.children.link(coll)
    hero = Hero("tiger_icon", spec, coll)
    hero.hide_non_head()
    # dark green square backdrop
    bm = bmesh.new()
    vs = [bm.verts.new((-300, -160, -100)), bm.verts.new((300, -160, -100)),
          bm.verts.new((300, -160, 300)), bm.verts.new((-300, -160, 300))]
    bm.faces.new((vs[0], vs[1], vs[2], vs[3]))
    me = bpy.data.meshes.new("iconbg"); bm.to_mesh(me); bm.free()
    add_obj("iconbg", me, mat_gradient((0.02, 0.08, 0.08), (0.06, 0.18, 0.16)), coll)
    # gold ring around head, facing camera
    rbm = torus_bm(31, 2.1, 18, 4, (0, -25, 70), (R(90), 0, 0))
    rm = bpy.data.meshes.new("iconring"); rbm.to_mesh(rm); rbm.free()
    add_obj("iconring", rm, mat_flat(col("#FFD98A"), 1.2), coll)
    # small leaves
    for i in range(6):
        a = -math.pi * .8 + i * math.pi * .3
        x, z = math.cos(a) * 47, 70 + math.sin(a) * 47
        bm = make_cone(7, 0, 14, 3)
        bm_xform(bm, (x, -12, z), (1, 1, 1), (R(90), 0, a))
        me = bpy.data.meshes.new("iconleaf"); bm.to_mesh(me); bm.free()
        add_obj("iconleaf", me, mat_flat(col("#4E9A63"), 1.0), coll)
    setup_lights(coll)
    make_camera(coll, (0, 210, 74), (0, 0, 70), 88, 1024, 1024)
    sc = bpy.context.scene
    sc.render.film_transparent = False
    sc.render.image_settings.color_mode = "RGB"
    sc.render.filepath = os.path.join(ICON_DIR, "AppIcon.png")
    bpy.ops.render.render(write_still=True)
    print("ICON", sc.render.filepath)


def main():
    only = os.environ.get("LOWPOLY_ONLY", "").strip()
    skip_render = os.environ.get("LOWPOLY_SKIP_RENDER", "") == "1"
    ids = [only] if only else list(HEROES.keys())
    if not skip_render:
        for hid in ids:
            reset_scene()
            coll = bpy.data.collections.new(hid)
            bpy.context.scene.collection.children.link(coll)
            render_hero(HEROES[hid], hid, coll)
        render_icon()
    else:
        for hid in ids:
            reset_scene()
            coll = bpy.data.collections.new(hid)
            bpy.context.scene.collection.children.link(coll)
            Hero(hid, HEROES[hid], coll).export_json()
    print("LOWPOLY DONE", ids)


if __name__ == "__main__":
    main()
