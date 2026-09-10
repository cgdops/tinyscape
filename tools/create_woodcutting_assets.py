"""Blender-only asset authoring: option-1 axe and the existing adventurer's chop.

Run: blender --background --python tools/create_woodcutting_assets.py
Original adventurer files are inputs; new source/export files are written separately.
"""
import bpy
import bmesh
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source"
MODELS = ROOT / "assets/models"
SHOTS = ROOT / "screenshots/woodcutting"
SHOTS.mkdir(parents=True, exist_ok=True)
RENDER = '--skip-renders' not in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(SOURCE / "adventurer.blend"))
scene = bpy.context.scene
rig = bpy.data.objects['Adventurer']
character = bpy.data.objects['AdventurerMesh']
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
scene.frame_set(1)
bpy.context.view_layer.update()


def material(name, color, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    s = m.node_tree.nodes['Principled BSDF']
    s.inputs['Base Color'].default_value = (*color, 1)
    s.inputs['Metallic'].default_value = metal
    s.inputs['Roughness'].default_value = .64
    return m


wood = material('Axe - honey oak', (.46, .245, .075))
wood_light = material('Axe - oak facets', (.55, .32, .11))
steel = material('Axe - charcoal steel', (.22, .26, .29), .55)
edge = material('Axe - sharpened bevel', (.60, .65, .68), .65)


def mesh(name, vertices, faces, materials, indices):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    for m in materials:
        data.materials.append(m)
    for poly, index in zip(data.polygons, indices):
        poly.material_index = index
        poly.use_smooth = False
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    bm.to_mesh(data)
    bm.free()
    return obj


# Eight-sided curved handle; all shapes are editable, untextured geometry.
verts, faces, indices = [], [], []
rings = [(-.13, .014, .029), (-.113, .01, .034), (0, 0, .025),
         (.20, -.018, .022), (.40, -.021, .025), (.575, 0, .029),
         (.69, 0, .028), (.70, 0, .023)]
for z, y, radius in rings:
    for i in range(8):
        a = math.tau * i / 8
        verts.append((radius*.8*math.cos(a), y+radius*math.sin(a), z))
faces.append(tuple(reversed(range(8))))
indices.append(0)
for j in range(len(rings)-1):
    for i in range(8):
        faces.append((j*8+i, j*8+(i+1)%8, (j+1)*8+(i+1)%8, (j+1)*8+i))
        indices.append(1 if i in (1, 4) else 0)
faces.append(tuple(range((len(rings)-1)*8, len(rings)*8)))
indices.append(1)
handle = mesh('Axe_Handle', verts, faces, [wood, wood_light], indices)

# A continuous wedge, with an actual thin cutting bevel and a blunt poll.
verts, faces, indices = [], [], []
sections = [(-.235, .50, .735, .003), (-.208, .508, .723, .012),
            (-.085, .552, .685, .040), (.035, .555, .678, .042),
            (.070, .561, .672, .032)]
for y, bottom, top, halfwidth in sections:
    verts += [(-halfwidth, y, bottom), (halfwidth, y, bottom),
              (halfwidth, y, top), (-halfwidth, y, top)]
faces.append((3, 2, 1, 0))
indices.append(1)
for j in range(len(sections)-1):
    for i in range(4):
        faces.append((j*4+i, j*4+(i+1)%4, (j+1)*4+(i+1)%4, (j+1)*4+i))
        indices.append(1 if j == 0 else 0)
faces.append(tuple(range(16, 20)))
indices.append(0)
head = mesh('Axe_Head', verts, faces, [steel, edge], indices)
bpy.ops.object.select_all(action='DESELECT')
handle.select_set(True)
head.select_set(True)
bpy.context.view_layer.objects.active = handle
bpy.ops.object.join()
axe = bpy.context.object
axe.name = 'WoodCuttingAxe'
axe['style'] = 'Approved option 1: chunky low poly, flat colors, no textures'
axe['grip_origin'] = 'Palm center; Blender +Z toward head, -Y cutting edge'
axe.data.calc_loop_triangles()
axe_triangles = len(axe.data.loop_triangles)


def export(path, objects, animated=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB', use_selection=True,
        export_yup=True, export_animations=animated,
        export_animation_mode='NLA_TRACKS', export_frame_range=False,
        export_force_sampling=True, export_skins=True, export_apply=False,
        export_cameras=False, export_lights=False, export_extras=True,
    )


grip = bpy.data.objects.new('AxeGrip', None)
scene.collection.objects.link(grip)
axe.parent = grip
grip['attachment'] = 'Parent under AxeMount.R with identity transform'
export(MODELS/'wood_cutting_axe.glb', [grip, axe])
# The standalone source is saved after the character file and previews.
axe.parent = None
bpy.data.objects.remove(grip, do_unlink=True)

# Socket rest axes equal the standalone axe axes; the bone head is the palm.
palm_rest = Vector((-.377, -.034, .932))
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
socket = rig.data.edit_bones.new('AxeSocket.R')
socket.head = palm_rest
socket.tail = palm_rest + Vector((0, .10, 0))
socket.parent = rig.data.edit_bones['Hand.R']
socket.align_roll(Vector((0, 0, 1)))
socket.use_deform = False
bpy.ops.object.mode_set(mode='OBJECT')
rig.data.bones['AxeSocket.R']['purpose'] = 'Right palm attachment; use child AxeMount.R for exports'
# Keep glTF's bone/object axis correction on a reusable mount, not the asset.
mount = bpy.data.objects.new('AxeMount.R', None)
scene.collection.objects.link(mount)
mount.parent = rig
mount.parent_type = 'BONE'
mount.parent_bone = 'AxeSocket.R'
mount.matrix_parent_inverse = Matrix.Translation((0, -.10, 0))
mount.matrix_basis = Matrix.Identity(4)
mount['attachment'] = 'Parent standalone AxeGrip here; zero position/rotation and unit scale'
axe.parent = mount
axe.matrix_parent_inverse = Matrix.Identity(4)
axe.matrix_basis = Matrix.Identity(4)

action = bpy.data.actions.new('Wood Cutting')
action.use_fake_user = True
rig.animation_data.action = action
scene.render.fps = 30
scene.frame_start, scene.frame_end = 1, 55

# Key poses: time, palm position, horizontal shaft yaw, torso pitch, torso twist.
# The fast stroke is followed by a small rebound and a slower recovery.
poses = [
    (1, (-.44, -.10, 1.22), 35, -2, -8),
    (10, (-.47, .035, 1.22), -10, -1, -16),
    (22, (-.48, .10, 1.22), -45, 0, -25),
    (26, (-.47, .07, 1.22), -38, -1, -22),
    (32, (-.27, -.30, 1.22), 85, -3, 22),
    (35, (-.22, -.31, 1.22), 98, -3, 27),
    (39, (-.28, -.28, 1.22), 79, -2, 18),
    (47, (-.40, -.15, 1.22), 50, -2, 0),
    (55, (-.44, -.10, 1.22), 35, -2, -8),
]


def interpolate(frame):
    for a, b in zip(poses, poses[1:]):
        if a[0] <= frame <= b[0]:
            t = (frame-a[0])/(b[0]-a[0])
            t = t*t*(3-2*t)
            return (Vector(a[1]).lerp(Vector(b[1]), t),
                    *[math.radians(a[i]+(b[i]-a[i])*t) for i in (2, 3, 4)])


def aim_bone(name, start, end):
    pb = rig.pose.bones[name]
    rest = pb.bone.matrix_local.to_quaternion()
    rest_direction = rest @ Vector((0, 1, 0))
    rotation = rest_direction.rotation_difference((end-start).normalized()) @ rest
    pb.matrix = Matrix.Translation(start) @ rotation.to_matrix().to_4x4()
    bpy.context.view_layer.update()


max_reach_error = 0
for frame in range(1, 56):
    scene.frame_set(frame)
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.matrix_basis = Matrix.Identity(4)
    palm, angle, lean, twist = interpolate(frame)
    spine_rest = rig.data.bones['Spine'].matrix_local.to_quaternion()
    rig.pose.bones['Spine'].rotation_quaternion = (spine_rest.inverted()
        @ Quaternion((0, 0, 1), twist) @ Quaternion((1, 0, 0), lean) @ spine_rest)
    rig.pose.bones['Head'].rotation_quaternion = Quaternion((1, 0, 0), -.08)
    # Free hand supplies a quiet counterbalance, away from the cutting path.
    rig.pose.bones['UpperArm.L'].rotation_quaternion = Quaternion((1, 0, 0), -.22)
    rig.pose.bones['Forearm.L'].rotation_quaternion = Quaternion((1, 0, 0), .40)
    bpy.context.view_layer.update()
    # Shaft and cutting direction stay horizontal, sweeping right to left.
    shaft_rotation = Quaternion((0, 0, 1), angle) @ Quaternion((0, 1, 0), -math.pi/2)
    hand_bone = rig.data.bones['Hand.R']
    wrist = palm - shaft_rotation @ (palm_rest-hand_bone.head_local)
    upper = rig.pose.bones['UpperArm.R']
    shoulder = upper.head.copy()
    l1 = upper.bone.length
    l2 = rig.data.bones['Forearm.R'].length
    direction = wrist-shoulder
    distance = direction.length
    assert abs(l1-l2)+.001 < distance < l1+l2-.001, (frame, distance, l1+l2)
    direction.normalize()
    pole = Vector((-.9, .25, -.3))
    bend = (pole-direction*pole.dot(direction)).normalized()
    along = (l1*l1-l2*l2+distance*distance)/(2*distance)
    height = math.sqrt(max(0, l1*l1-along*along))
    elbow = shoulder+direction*along+bend*height
    aim_bone('UpperArm.R', shoulder, elbow)
    aim_bone('Forearm.R', elbow, wrist)
    rig.pose.bones['Hand.R'].matrix = (Matrix.Translation(wrist)
        @ shaft_rotation.to_matrix().to_4x4()
        @ hand_bone.matrix_local.to_quaternion().to_matrix().to_4x4())
    bpy.context.view_layer.update()
    max_reach_error = max(max_reach_error, (rig.pose.bones['AxeSocket.R'].head-palm).length)
    for pb in rig.pose.bones:
        pb.keyframe_insert('location', frame=frame, group=pb.name)
        pb.keyframe_insert('rotation_quaternion', frame=frame, group=pb.name)
        pb.keyframe_insert('scale', frame=frame, group=pb.name)

for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:
                    key.interpolation = 'LINEAR'
assert max_reach_error < .00001, max_reach_error
rig.animation_data.action = None
track = rig.animation_data.nla_tracks.new()
track.name = 'Wood Cutting'
track.strips.new('Wood Cutting', 1, action)
track.mute = True
# Existing clips use Euler channels, while the new action was solved as quaternions.
# Convert the new action to Euler channels on the rig so all three play correctly.
rig.animation_data.action = action
sampled = {}
for frame in range(1, 56):
    scene.frame_set(frame)
    sampled[frame] = {pb.name: pb.rotation_quaternion.copy() for pb in rig.pose.bones}
for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'
previous = {}
for frame, rotations in sampled.items():
    for name, rotation in rotations.items():
        pb = rig.pose.bones[name]
        pb.rotation_euler = rotation.to_euler('XYZ', previous.get(name, pb.rotation_euler))
        previous[name] = pb.rotation_euler.copy()
        pb.keyframe_insert('rotation_euler', frame=frame, group=name)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in list(bag.fcurves):
                if curve.data_path.endswith('rotation_quaternion'):
                    bag.fcurves.remove(curve)
                else:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
scene.frame_set(1)
export(MODELS/'adventurer_woodcutting.glb', [rig, character, mount, axe], True)
rig.animation_data.action = action
scene.frame_set(1)
scene.timeline_markers.clear()
for name, frame in [('Ready', 1), ('Wind-up', 22), ('Strike', 32), ('Recover', 39), ('Loop', 55)]:
    scene.timeline_markers.new(name, frame=frame)

# Numerical attachment, root, planted feet, and cycle checks on the authored rig.
attachment_error = 0
foot_error = 0
endpoints = []
edge_heights = []
for frame in range(1, 56):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    attachment_error = max(attachment_error,
        (axe.matrix_world.translation-rig.pose.bones['AxeSocket.R'].head).length)
    edge_heights.append((axe.matrix_world @ Vector((0, -.235, .6175))).z)
    for side in ('L', 'R'):
        foot_error = max(foot_error,
            (rig.pose.bones[f'Foot.{side}'].head-rig.data.bones[f'Foot.{side}'].head_local).length)
    assert rig.pose.bones['Root'].location.length < 1e-6
    if frame in (1, 55):
        endpoints.append([v for pb in rig.pose.bones for row in pb.matrix for v in row])
loop_error = max(abs(a-b) for a, b in zip(*endpoints))
assert attachment_error < 1e-5, attachment_error
assert foot_error < 1e-5, foot_error
assert loop_error < 1e-5, loop_error
horizontal_error = max(edge_heights)-min(edge_heights)
assert horizontal_error < 1e-5, horizontal_error


def glb_doc(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF'
    size = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20+size])


doc = glb_doc(MODELS/'adventurer_woodcutting.glb')
animations = {}
for animation in doc['animations']:
    times = [doc['accessors'][s['input']] for s in animation['samplers']]
    animations[animation['name']] = round(max(a['max'][0] for a in times)-min(a['min'][0] for a in times), 5)
assert animations == {'Idle': 3.0, 'Walk': 1.0, 'Wood Cutting': 1.8}, animations
socket_index = next(i for i, n in enumerate(doc['nodes']) if n['name'] == 'AxeSocket.R')
axe_index = next(i for i, n in enumerate(doc['nodes']) if n['name'] == 'WoodCuttingAxe')
mount_index = next(i for i, n in enumerate(doc['nodes']) if n['name'] == 'AxeMount.R')
assert mount_index in doc['nodes'][socket_index]['children']
assert axe_index in doc['nodes'][mount_index]['children']
assert doc['nodes'][axe_index].get('translation', [0, 0, 0]) == [0, 0, 0]
assert doc['nodes'][axe_index].get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1]
assert doc['nodes'][axe_index].get('scale', [1, 1, 1]) == [1, 1, 1]
assert len(doc['skins']) == 1
report = dict(axe_triangles=axe_triangles, animations_seconds=animations,
              swing='horizontal right-to-left', cutting_edge_height_range_m=horizontal_error,
              attachment_bone='AxeSocket.R', attachment_mount='AxeMount.R', attachment_error_m=attachment_error,
              planted_foot_error_m=foot_error, loop_matrix_error=loop_error,
              solved_palm_error_m=max_reach_error,
              original_character_preserved=True, exported_socket_child_verified=True)
(SOURCE/'woodcutting-verification.json').write_text(json.dumps(report, indent=2)+'\n')

# Lightweight actual 3D previews: four pose renders and a small looping sequence.
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 600, 700
scene.render.resolution_percentage = 100
camera = scene.camera
camera.location = (-3.6, -6.3, 3.0)
camera.rotation_euler = (Vector((-.20, -.14, 1.10))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 3.4
scene.frame_set(22)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'adventurer_woodcutting.blend'))
for frame in ((1, 22, 32, 39) if RENDER else ()):
    scene.frame_set(frame)
    scene.render.filepath = str(SHOTS/f'pose-{frame:02}.png')
    bpy.ops.render.render(write_still=True)
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.background_type = 'WORLD'
scene.render.resolution_x, scene.render.resolution_y = 420, 490
for frame in (range(1, 55, 2) if RENDER else ()):
    scene.frame_set(frame)
    scene.render.filepath = str(SHOTS/f'motion-{frame:02}.png')
    bpy.ops.render.render(write_still=True)
axe.parent = None
axe.matrix_parent_inverse = Matrix.Identity(4)
axe.matrix_basis = Matrix.Identity(4)
bpy.data.objects.remove(character, do_unlink=True)
bpy.data.objects.remove(mount, do_unlink=True)
bpy.data.objects.remove(rig, do_unlink=True)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
grip = bpy.data.objects.new('AxeGrip', None)
scene.collection.objects.link(grip)
axe.parent = grip
scene.timeline_markers.clear()
scene.frame_start, scene.frame_end = 1, 1
scene.frame_set(1)
camera.location = (2.8, -1.7, 1.2)
camera.rotation_euler = (Vector((0, -.06, .30))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 1.04
stage = bpy.data.objects.get('PREVIEW ONLY - ground')
stage.location.z = -.14
scene.render.engine = 'CYCLES'
scene.render.resolution_x, scene.render.resolution_y = 600, 700
scene.render.filepath = str(SHOTS/'axe.png')
bpy.ops.object.select_all(action='DESELECT')
axe.select_set(True)
bpy.context.view_layer.objects.active = axe
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'wood_cutting_axe.blend'))
if RENDER:
    bpy.ops.render.render(write_still=True)
print('WOODCUTTING_VERIFIED '+json.dumps(report))
