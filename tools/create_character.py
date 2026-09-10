"""Create TinyScape's original skinned adventurer and two cyclic animations.

Run with Blender 5.2 in background mode:
  blender --background --python tools/create_character.py
The GLB is an engine-ready, Y-up asset facing +Z. Blender source faces -Y.
"""

import bpy
import json
import math
import struct
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "source"
MODELS = ROOT / "assets" / "models"
SHOTS = ROOT / "screenshots"
for directory in (SOURCE, MODELS, SHOTS):
    directory.mkdir(parents=True, exist_ok=True)
(SOURCE / ".gdignore").write_text("", encoding="utf-8")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)


def mat(name, color, roughness=0.85, metallic=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return material


M = {
    "skin": mat("Warm terracotta skin", (.62, .34, .20)),
    "skin_light": mat("Nose and ears", (.70, .40, .24)),
    "tunic": mat("Petrol teal linen", (.045, .285, .25)),
    "trim": mat("Woven teal edging", (.085, .38, .31)),
    "scarf": mat("Saffron wool", (.79, .48, .105)),
    "scarf_light": mat("Saffron folded edge", (.94, .65, .18)),
    "trousers": mat("Charcoal blue trousers", (.075, .105, .12)),
    "leather": mat("Chestnut leather", (.255, .115, .058)),
    "leather_light": mat("Leather stitched edges", (.365, .195, .09)),
    "sole": mat("Boot soles", (.072, .056, .04)),
    "brass": mat("Warm brass", (.68, .45, .17), .42, .45),
    "hair": mat("Walnut hair", (.10, .043, .025)),
    "hair_light": mat("Hair sunlit facets", (.19, .079, .033)),
    "eye": mat("Eyes ivory", (.92, .88, .74)),
    "dark": mat("Eyes and brows", (.025, .028, .022)),
    "mouth": mat("Quiet smile", (.22, .072, .045)),
    "pack": mat("Canvas rucksack", (.38, .35, .19)),
}
pieces = []


def finish(obj, name, material, bone):
    obj.name = name
    obj.data.materials.append(M[material])
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    pieces.append(obj)
    return obj


def mesh(name, vertices, faces, material, bone):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, material, bone)


def ellipsoid(name, center, scale, material, bone, segments=12, rings=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material, bone)


def bevel_box(name, center, scale, material, bone, bevel=.015, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    if rotation:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Hand-cut corners", "BEVEL")
    mod.width = bevel
    mod.segments = 1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, material, bone)


def loft(name, rings, material, bone, sides=12):
    """Rings: (center_x, center_y, height, x_radius, y_radius)."""
    vertices = []
    for cx, cy, z, rx, ry in rings:
        for i in range(sides):
            angle = 2 * math.pi * i / sides
            vertices.append((cx + rx * math.cos(angle), cy + ry * math.sin(angle), z))
    faces = [tuple(reversed(range(sides)))]
    for j in range(len(rings) - 1):
        for i in range(sides):
            a, b = j * sides + i, j * sides + (i + 1) % sides
            c, d = b + sides, a + sides
            # Alternating diagonals give the cloth quiet, broad angular facets.
            if 0 < j < len(rings) - 2:
                faces.extend([(a, b, d), (b, c, d)])
            else:
                faces.append((a, b, c, d))
    faces.append(tuple(range((len(rings) - 1) * sides, len(rings) * sides)))
    return mesh(name, vertices, faces, material, bone)


def segment(name, start, end, r1, r2, material, bone, sides=8):
    a, b = Vector(start), Vector(end)
    direction = (b - a).normalized()
    tangent = direction.cross(Vector((0, 1, 0))).normalized()
    bitangent = direction.cross(tangent)
    vertices = []
    for center, radius in [(a, r1), (b, r2)]:
        for i in range(sides):
            ang = 2 * math.pi * i / sides
            vertices.append(center + radius * (tangent * math.cos(ang) + bitangent * math.sin(ang)))
    faces = [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    faces += [(i, (i + 1) % sides, (i + 1) % sides + sides, i + sides) for i in range(sides)]
    return mesh(name, vertices, faces, material, bone)


# Long, tapered limbs and a shaped waist keep the silhouette away from a block toy.
loft("Tunic shaped body", [(0, 0, 1.065, .185, .125), (0, 0, 1.17, .20, .127),
                         (0, 0, 1.32, .244, .145), (0, 0, 1.395, .252, .12),
                         (0, 0, 1.455, .10, .085)], "tunic", "Spine")
loft("Split tunic skirt", [(0, 0, .905, .245, .148), (0, 0, .96, .226, .147),
                         (0, 0, 1.085, .185, .127)], "tunic", "Hips")
loft("Tunic hem binding", [(0, 0, .9, .246, .15), (0, 0, .928, .239, .150)], "trim", "Hips")
loft("Waist belt", [(0, 0, 1.052, .195, .14), (0, 0, 1.094, .19, .14)], "leather", "Hips")
bevel_box("Belt buckle", (0, -.143, 1.074), (.072, .027, .052), "brass", "Hips", .006)
bevel_box("Buckle inset", (0, -.160, 1.074), (.042, .009, .027), "leather", "Hips", .003)
bevel_box("Right hip leather pouch", (.215, -.034, 1.015), (.13, .14, .16), "leather", "Hips", .024)
bevel_box("Pouch flap", (.22, -.103, 1.058), (.139, .027, .084), "leather_light", "Hips", .016)
ellipsoid("Pouch stud", (.22, -.12, 1.035), (.010, .006, .010), "brass", "Hips", 8, 4)

for side, sign in [("L", 1), ("R", -1)]:
    x = sign * .115
    segment(f"{side} trouser thigh", (x, 0, .943), (x, 0, .53), .098, .070, "trousers", f"Thigh.{side}")
    ellipsoid(f"{side} trouser knee", (x, 0, .545), (.070, .073, .072), "trousers", f"Shin.{side}", 10, 5)
    segment(f"{side} lower trousers", (x, 0, .55), (x, 0, .23), .069, .049, "trousers", f"Shin.{side}")
    loft(f"{side} boot shaft", [(x, 0, .115, .068, .072), (x, .006, .245, .063, .065),
                              (x, .007, .32, .073, .074)], "leather", f"Shin.{side}", 8)
    loft(f"{side} folded boot cuff", [(x, .007, .293, .079, .079), (x, .007, .331, .077, .077)],
         "leather_light", f"Shin.{side}", 8)
    bevel_box(f"{side} boot sole", (x, -.049, .029), (.15, .278, .058), "sole", f"Foot.{side}", .024)
    bevel_box(f"{side} boot foot", (x, -.047, .082), (.142, .258, .112), "leather", f"Foot.{side}", .04)
    bevel_box(f"{side} toe cap", (x, -.141, .079), (.144, .076, .07), "leather_light", f"Foot.{side}", .018)
    for lace in range(3):
        bevel_box(f"{side} boot lace {lace}", (x, -.068 + lace * .034, .142), (.073, .012, .008),
                  "leather_light", f"Foot.{side}", .002)
    shoulder = (sign * .234, 0, 1.362)
    elbow = (sign * .331, 0, 1.139)
    wrist = (sign * .368, -.025, .981)
    ellipsoid(f"{side} tailored shoulder", shoulder, (.109, .114, .075), "tunic", f"UpperArm.{side}", 10, 5)
    segment(f"{side} short tunic sleeve", shoulder, (sign * .31, 0, 1.18), .113, .083,
            "tunic", f"UpperArm.{side}")
    segment(f"{side} sleeve binding", (sign * .303, 0, 1.195), (sign * .315, 0, 1.165), .086, .084,
            "trim", f"UpperArm.{side}")
    ellipsoid(f"{side} elbow", elbow, (.066, .065, .067), "skin", f"Forearm.{side}", 10, 5)
    segment(f"{side} forearm", elbow, wrist, .062, .043, "skin", f"Forearm.{side}")
    segment(f"{side} wrist binding", (sign * .358, -.017, 1.03), (sign * .368, -.025, .985),
            .052, .049, "leather", f"Forearm.{side}")
    ellipsoid(f"{side} hand", (sign * .377, -.034, .932), (.047, .04, .066), "skin", f"Hand.{side}", 10, 6)
    ellipsoid(f"{side} thumb", (sign * .338, -.047, .951), (.026, .025, .042), "skin_light", f"Hand.{side}", 8, 5)

# A small practical rucksack, with straps following the chest, reads from all views.
bevel_box("Canvas rucksack", (0, .19, 1.253), (.32, .20, .36), "pack", "Spine", .045)
bevel_box("Rucksack leather lid", (0, .202, 1.411), (.33, .222, .083), "leather", "Spine", .024)
bevel_box("Rucksack rear pocket", (0, .295, 1.19), (.217, .067, .133), "leather_light", "Spine", .024)
for sign in (-1, 1):
    segment("Chest shoulder strap", (sign * .155, -.104, 1.414), (sign * .122, -.123, 1.11),
            .025, .024, "leather", "Spine", 4)
    segment("Rear shoulder strap", (sign * .155, -.09, 1.414), (sign * .155, .197, 1.407),
            .025, .025, "leather", "Spine", 4)
    bevel_box("Rucksack buckle", (sign * .09, .324, 1.296), (.029, .015, .042), "brass", "Spine", .003)

segment("Neck", (0, 0, 1.418), (0, 0, 1.588), .074, .077, "skin", "Neck", 10)
loft("Folded scarf collar", [(0, -.004, 1.443, .123, .105), (0, -.008, 1.477, .131, .11),
                            (0, -.004, 1.515, .098, .095)], "scarf", "Neck", 10)
loft("Scarf upper rolled edge", [(0, -.004, 1.499, .106, .099), (0, -.004, 1.519, .099, .094)],
     "scarf_light", "Neck", 10)
ellipsoid("Scarf knot", (-.086, -.097, 1.464), (.050, .036, .050), "scarf_light", "Neck", 8, 5)
mesh("Angled scarf tail", [(-.103, -.126, 1.47), (-.034, -.139, 1.43), (-.069, -.161, 1.232),
                          (-.105, -.165, 1.268), (-.144, -.152, 1.245), (-.146, -.135, 1.394),
                          (-.09, -.158, 1.358)],
     [(0, 1, 6), (1, 2, 6), (2, 3, 6), (3, 4, 6), (4, 5, 6), (5, 0, 6)], "scarf", "Spine")

# Head, face, ears and swept angular locks: all follow the head bone.
loft("Faceted face", [(0, -.014, 1.544, .083, .082), (0, -.009, 1.574, .129, .124),
                     (0, .004, 1.643, .178, .154), (0, .009, 1.744, .188, .164),
                     (0, .017, 1.819, .163, .150), (0, .015, 1.86, .095, .10)], "skin", "Head", 12)
for sign in (-1, 1):
    ellipsoid("Ear", (sign * .185, .008, 1.702), (.043, .042, .067), "skin_light", "Head", 8, 6)
    ellipsoid("Ear inset", (sign * .213, -.014, 1.702), (.009, .022, .032), "skin", "Head", 8, 4)
    x = sign * .073
    # Front faces are slightly pitched to follow the cheek planes.
    mesh("Almond eye", [(x - .029, -.156, 1.719), (x - .018, -.164, 1.738),
                        (x + .020, -.163, 1.740), (x + .029, -.154, 1.723),
                        (x + .014, -.164, 1.710), (x - .016, -.166, 1.709)],
         [(0, 5, 4, 3, 2, 1)], "eye", "Head")
    ellipsoid("Dark hazel iris", (x, -.168, 1.725), (.013, .007, .018), "dark", "Head", 10, 5)
    ellipsoid("Eye glint", (x - .004, -.175, 1.732), (.004, .002, .005), "eye", "Head", 6, 4)
    mesh("Expressive brow", [(x - .035, -.153, 1.768), (x + .029, -.153, 1.774),
                             (x + .030, -.157, 1.761), (x - .030, -.159, 1.756)],
         [(0, 1, 2, 3)], "hair", "Head")
mesh("Sculpted nose", [(-.021, -.151, 1.718), (.021, -.151, 1.718), (.022, -.159, 1.664),
                       (-.022, -.159, 1.664), (0, -.201, 1.673)],
     [(0, 4, 1), (1, 4, 2), (2, 4, 3), (3, 4, 0), (0, 1, 2, 3)], "skin_light", "Head")
mesh("Small smile", [(-.034, -.145, 1.626), (0, -.154, 1.62), (.035, -.145, 1.628),
                     (.023, -.15, 1.617), (0, -.156, 1.612), (-.026, -.15, 1.616)],
     [(0, 5, 4, 1), (1, 4, 3, 2)], "mouth", "Head")

hair_vertices = []
N = 12
for layer in range(4):
    for i in range(N):
        angle = 2 * math.pi * i / N
        if layer == 0:
            z = 1.757 + .032 * max(0, -math.sin(angle))
            rx, ry = .200, .177
        elif layer == 1:
            z, rx, ry = 1.85 + .012 * math.cos(angle), .207, .178
        elif layer == 2:
            z, rx, ry = 1.914 + .014 * math.cos(angle), .142, .137
        else:
            z, rx, ry = 1.938, .037, .046
        hair_vertices.append((rx * math.cos(angle) + .011 * layer, .02 + ry * math.sin(angle), z))
hair_faces = []
for layer in range(3):
    for i in range(N):
        hair_faces.append((layer*N+i, layer*N+(i+1)%N, (layer+1)*N+(i+1)%N, (layer+1)*N+i))
hair_faces.append(tuple(range(3*N, 4*N)))
hair = mesh("Swept polygon hair cap", hair_vertices, hair_faces, "hair", "Head")
hair.data.materials.append(M["hair_light"])
for polygon in hair.data.polygons:
    polygon.material_index = 1 if polygon.index in (18, 19, 20, 28, 31, 32, 33) else 0
mesh("Swooping fringe", [(-.163, -.094, 1.849), (-.111, -.153, 1.861), (.023, -.187, 1.876),
                        (.136, -.119, 1.859), (.143, -.139, 1.79), (.074, -.175, 1.807),
                        (-.025, -.186, 1.785), (-.101, -.162, 1.782), (-.134, -.126, 1.73),
                        (-.17, -.105, 1.785)],
     [(0, 1, 7, 8, 9), (1, 2, 6, 7), (2, 3, 5, 6), (3, 4, 5)], "hair_light", "Head")
for sign in (-1, 1):
    mesh("Tapered side lock", [(sign*.179, -.068, 1.82), (sign*.201, -.035, 1.808),
                              (sign*.19, -.041, 1.689), (sign*.168, -.076, 1.721)],
         [(0, 1, 2, 3)], "hair", "Head")

# Bones have an explicit, predictable local X rotation axis for sagittal motion.
arm_data = bpy.data.armatures.new("Adventurer skeleton")
rig = bpy.data.objects.new("Adventurer", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")


def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = arm_data.edit_bones[parent]
    b.align_roll(Vector((0, 1, 0)))
    return b


bone("Root", (0, 0, 0), (0, 0, .20))
bone("Hips", (0, 0, .93), (0, 0, 1.07), "Root")
bone("Spine", (0, 0, 1.07), (0, 0, 1.39), "Hips")
bone("Neck", (0, 0, 1.39), (0, 0, 1.54), "Spine")
bone("Head", (0, 0, 1.54), (0, 0, 1.85), "Neck")
for side, sign in [("L", 1), ("R", -1)]:
    bone(f"Thigh.{side}", (sign*.115, 0, .93), (sign*.115, 0, .55), "Hips")
    bone(f"Shin.{side}", (sign*.115, 0, .55), (sign*.115, 0, .17), f"Thigh.{side}")
    bone(f"Foot.{side}", (sign*.115, 0, .17), (sign*.115, -.15, .07), f"Shin.{side}")
    bone(f"UpperArm.{side}", (sign*.234, 0, 1.362), (sign*.331, 0, 1.139), "Spine")
    bone(f"Forearm.{side}", (sign*.331, 0, 1.139), (sign*.368, -.025, .981), f"UpperArm.{side}")
    bone(f"Hand.{side}", (sign*.368, -.025, .981), (sign*.377, -.034, .908), f"Forearm.{side}")
bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.object.select_all(action="DESELECT")
for obj in pieces:
    obj.select_set(True)
bpy.context.view_layer.objects.active = pieces[0]
bpy.ops.object.join()
character = bpy.context.object
character.name = "AdventurerMesh"
character.parent = rig
modifier = character.modifiers.new("Skeletal deformation", "ARMATURE")
modifier.object = rig
modifier.use_vertex_groups = True
for material in character.data.materials:
    material.use_backface_culling = False

scene = bpy.context.scene
scene.render.fps = 30
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"


def reset_pose():
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def world_location(pb, xyz):
    pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector(xyz)


def key_pose(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert("location", frame=frame, group=pb.name)
        pb.keyframe_insert("rotation_euler", frame=frame, group=pb.name)
        pb.keyframe_insert("scale", frame=frame, group=pb.name)


def action_curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


def make_action(name, length, pose):
    reset_pose()
    action = bpy.data.actions.new(name)
    rig.animation_data.action = action
    for frame in range(1, length + 2):
        pose((frame - 1) / length)
        key_pose(frame)
    for curve in action_curves(action):
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"
        curve.modifiers.new("CYCLES")
    action.use_fake_user = True
    rig.animation_data.action = None
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.name = name
    strip.action_frame_start = 1
    strip.action_frame_end = length + 1
    track.mute = True
    return action


def idle(t):
    reset_pose()
    s = math.sin(2 * math.pi * t)
    c = math.cos(2 * math.pi * t)
    # Broad enough to read at game distance, soft enough to feel calm.
    world_location(rig.pose.bones["Root"], (0.006*s, 0, .003*(1-c)))
    rig.pose.bones["Spine"].scale = (1 + .014*s, 1 + .010*s, 1 + .014*s)
    rig.pose.bones["Spine"].rotation_euler[1] = .018*s
    rig.pose.bones["Head"].rotation_euler[1] = -.024*s
    rig.pose.bones["Head"].rotation_euler[0] = .012*c
    for side, sign in [("L", 1), ("R", -1)]:
        rig.pose.bones[f"UpperArm.{side}"].rotation_euler[0] = .026*s*sign
        rig.pose.bones[f"Forearm.{side}"].rotation_euler[0] = .045 + .022*c


def walk(t):
    reset_pose()
    phase = 2 * math.pi * t
    hip_z = .895 + .011*math.cos(2*phase)
    world_location(rig.pose.bones["Root"], (0, 0, hip_z - .93))
    rig.pose.bones["Spine"].rotation_euler[0] = -.038
    rig.pose.bones["Spine"].rotation_euler[1] = .046*math.sin(phase)
    rig.pose.bones["Head"].rotation_euler[0] = .018
    rig.pose.bones["Head"].rotation_euler[1] = -.025*math.sin(phase)
    for side, offset in [("L", 0), ("R", .5)]:
        p = (t + offset) % 1
        if p < .5:
            y, ankle_z = -.185 + .74*p, .17
        else:
            u = (p-.5)*2
            y, ankle_z = .185*math.cos(math.pi*u), .17+.095*math.sin(math.pi*u)
        down = hip_z - ankle_z
        length = .38
        cosine = max(-1, min(1, (y*y+down*down-2*length*length)/(2*length*length)))
        knee = math.acos(cosine)
        thigh = math.atan2(y, down)-math.atan2(length*math.sin(knee), length+length*math.cos(knee))
        rig.pose.bones[f"Thigh.{side}"].rotation_euler[0] = thigh
        rig.pose.bones[f"Shin.{side}"].rotation_euler[0] = knee
        rig.pose.bones[f"Foot.{side}"].rotation_euler[0] = -(thigh+knee)
        swing = math.cos(2*math.pi*p)
        rig.pose.bones[f"UpperArm.{side}"].rotation_euler[0] = .37*swing
        rig.pose.bones[f"Forearm.{side}"].rotation_euler[0] = .12 + .12*max(0, -swing)
        rig.pose.bones[f"Hand.{side}"].rotation_euler[0] = .045*swing


idle_action = make_action("Idle", 90, idle)
walk_action = make_action("Walk", 30, walk)
rig.animation_data.action = walk_action
planted_foot_error = 0.0
for frame in range(1, 32):
    scene.frame_set(frame)
    for side, offset in [("L", 0), ("R", .5)]:
        phase = ((frame-1)/30 + offset) % 1
        if phase <= .5:
            planted_foot_error = max(planted_foot_error, abs(rig.pose.bones[f"Foot.{side}"].head.z-.17))
assert planted_foot_error < .0001, f"Planted feet drift: {planted_foot_error}"
reset_pose()
rig.animation_data.action = None
scene.frame_start, scene.frame_end = 1, 91
scene.frame_set(1)

# Export only runtime objects; no camera, render stage or lights enter the game.
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
character.select_set(True)
bpy.context.view_layer.objects.active = rig
glb_path = MODELS / "adventurer.glb"
bpy.ops.export_scene.gltf(
    filepath=str(glb_path), export_format="GLB", use_selection=True,
    export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
    export_nla_strips_merged_animation_name="Animation", export_frame_range=False,
    export_force_sampling=True, export_skins=True, export_all_influences=False,
    export_apply=False, export_materials="EXPORT", export_cameras=False,
    export_lights=False, export_extras=True,
)

# A clean source scene also contains a ready-to-render portrait stage.
stage_mat = mat("Preview background", (.075, .108, .087))
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.014))
stage = bpy.context.object
stage.name = "PREVIEW ONLY - ground"
stage.data.materials.append(stage_mat)
bpy.ops.object.camera_add(location=(3.1, -6.5, 2.75))
camera = bpy.context.object
camera.name = "PREVIEW ONLY - portrait camera"
camera.rotation_euler = (Vector((0, 0, .99))-camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.44
scene.camera = camera


def area(name, location, energy, color, size):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy, light.data.color, light.data.shape, light.data.size = energy, color, "DISK", size
    light.rotation_euler = (Vector((0, 0, 1))-light.location).to_track_quat("-Z", "Y").to_euler()


area("PREVIEW ONLY - warm key", (-3, -4, 6), 430, (1, .88, .70), 4)
area("PREVIEW ONLY - sky fill", (3, -2, 3), 230, (.64, .83, 1), 3)
area("PREVIEW ONLY - rim", (0, 3, 4), 500, (1, .79, .49), 3)
scene.world.color = (.22, .22, .22)
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 850, 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"
scene.render.filepath = str(SHOTS / "character.png")
rig.animation_data.action = idle_action
scene.frame_set(15)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
rig.show_in_front = True
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "adventurer.blend"))
bpy.ops.render.render(write_still=True)

# Verify the binary artifact itself, not just the authoring scene.
raw = glb_path.read_bytes()
assert raw[:4] == b"glTF"
chunk_size, chunk_kind = struct.unpack_from("<II", raw, 12)
assert chunk_kind == 0x4E4F534A
doc = json.loads(raw[20:20+chunk_size])
binary_start = 20 + chunk_size + 8
components = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def accessor_values(index):
    accessor = doc["accessors"][index]
    view = doc["bufferViews"][accessor["bufferView"]]
    fmt, size = components[accessor["componentType"]]
    width = widths[accessor["type"]]
    start = binary_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", size*width)
    return [struct.unpack_from("<"+fmt*width, raw, start+i*stride) for i in range(accessor["count"])]


animations = {}
loop_error = 0.0
for animation in doc.get("animations", []):
    times = [doc["accessors"][sampler["input"]] for sampler in animation["samplers"]]
    animations[animation["name"]] = round(max(a["max"][0] for a in times)-min(a["min"][0] for a in times), 5)
    for sampler in animation["samplers"]:
        outputs = accessor_values(sampler["output"])
        loop_error = max(loop_error, max(abs(a-b) for a, b in zip(outputs[0], outputs[-1])))
assert set(animations) == {"Idle", "Walk"}, animations
assert loop_error < 0.00001, f"Cyclic endpoint mismatch: {loop_error}"
assert len(doc.get("skins", [])) == 1, "Asset must contain one actual skeleton"
triangles = 0
weighted_vertices = 0
for entry in doc["meshes"]:
    for primitive in entry["primitives"]:
        assert "JOINTS_0" in primitive["attributes"] and "WEIGHTS_0" in primitive["attributes"]
        for weights in accessor_values(primitive["attributes"]["WEIGHTS_0"]):
            assert all(w >= 0 for w in weights) and abs(sum(weights)-1) < .00001, weights
            weighted_vertices += 1
        triangles += doc["accessors"][primitive["indices"]]["count"] // 3
report = {
    "file": str(glb_path), "animations_seconds": animations,
    "triangles": triangles, "bones": len(doc["skins"][0]["joints"]),
    "materials": len(doc.get("materials", [])), "bytes": len(raw),
    "forward_godot": "+Z", "up_godot": "+Y", "height_rest": 1.938,
    "verified_weighted_vertices": weighted_vertices, "cyclic_endpoint_max_error": loop_error,
    "planted_ankle_max_error_meters": planted_foot_error,
}
(SOURCE / "character-verification.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print("CHARACTER_ASSET_VERIFIED " + json.dumps(report))
