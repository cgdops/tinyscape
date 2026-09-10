"""Blender authoring only: Mabb, a reusable villager construction, and tree stumps.

Run Blender --background --python-exit-code 1 --python tools/create_villager_handoff.py.
Reuses the established character mesh/rig helpers without running its asset generator.
Only overwrites this script's outputs. Flat colours need no UVs or image textures.
"""
import ast
import bpy
import bmesh
import json
import math
import struct
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/villagers'
MODELS = ROOT / 'assets/models/villagers'
SHOTS = ROOT / 'screenshots/villagers'
for path in (SOURCE, MODELS, SHOTS):
    path.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
pieces = []

# Pure helper definitions only; never executes the adventurer authoring/export code.
helper_names = {'mat', 'finish', 'mesh', 'ellipsoid', 'bevel_box', 'loft', 'segment',
                'bone', 'reset_pose', 'key_pose', 'action_curves', 'make_action'}
tree = ast.parse((ROOT / 'tools/create_character.py').read_text())
defs = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in helper_names]
assert len(defs) == len(helper_names)
exec(compile(ast.Module(body=defs, type_ignores=[]), 'character_helpers', 'exec'))

PALETTE = {
    'skin': 'b3805e', 'skin_light': 'c79a76', 'hair': '8f8b7e', 'hair_light': 'a8a396',
    'tunic': '607840', 'linen': 'e1cfaa', 'leather': '8a5f44', 'worn': '3a3026',
    'trousers': '284636', 'sole': '4c4338', 'brass': 'd4b16d',
    'eye': 'f6f1df', 'dark': '2c2f29', 'mouth': '814c3c',
    'wood': '573f2e', 'wood_light': '907044', 'sage': '8eaa9c', 'iron': '414c46',
}


def linear(hex_value):
    rgb = [int(hex_value[i:i+2], 16)/255 for i in (0, 2, 4)]
    return [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]


M = {key: mat(key + ' #' + value, linear(value)) for key, value in PALETTE.items()}
# This base deliberately exposes the two distinguishing silhouette controls.
BASE = {'shoulder_radius': .295, 'hip_radius': .215, 'stance': .145}


def villager_body():
    """Reusable base; replace apron/hair and palette to derive another villager."""
    loft('Work tunic', [(0, 0, .86, .225, .145), (0, 0, 1.00, BASE['hip_radius'], .145),
                       (0, 0, 1.22, BASE['shoulder_radius'], .163),
                       (0, 0, 1.29, .29, .14), (0, 0, 1.34, .10, .085)], 'tunic', 'Spine', 8)
    loft('Short tunic hem', [(0, 0, .77, .24, .16), (0, 0, .89, .225, .145)], 'tunic', 'Hips', 8)
    loft('Work belt', [(0, 0, .885, .232, .164), (0, 0, .927, .225, .16)], 'worn', 'Hips', 8)
    bevel_box('Single brass buckle', (.17, -.195, .927), (.057, .024, .044), 'brass', 'Hips', .005)
    for side, sign in [('L', 1), ('R', -1)]:
        x = sign * BASE['stance']
        segment(side+' trouser thigh', (x, 0, .82), (x, 0, .46), .113, .085, 'trousers', 'Thigh.'+side)
        ellipsoid(side+' knee', (x, 0, .455), (.087, .089, .08), 'trousers', 'Shin.'+side, 8, 4)
        segment(side+' trouser calf', (x, 0, .47), (x, 0, .19), .086, .066, 'trousers', 'Shin.'+side)
        loft(side+' boot shaft', [(x, 0, .10, .082, .09), (x, 0, .28, .085, .085)], 'trousers', 'Shin.'+side, 8)
        bevel_box(side+' planted sole', (x, -.047, .025), (.18, .29, .05), 'sole', 'Foot.'+side, .016)
        bevel_box(side+' boot', (x, -.043, .082), (.176, .28, .12), 'trousers', 'Foot.'+side, .028)
        shoulder, elbow, wrist = (sign*.285, 0, 1.24), (sign*.375, -.025, 1.055), (sign*.39, -.09, .895)
        ellipsoid(side+' shoulder', shoulder, (.12, .127, .095), 'tunic', 'UpperArm.'+side, 8, 4)
        segment(side+' linen sleeve', shoulder, elbow, .101, .076, 'linen', 'UpperArm.'+side)
        ellipsoid(side+' elbow cloth', elbow, (.077, .077, .075), 'linen', 'Forearm.'+side, 8, 4)
        segment(side+' forearm sleeve', elbow, wrist, .078, .055, 'linen', 'Forearm.'+side)
        segment(side+' glove cuff', (sign*.388, -.078, .93), wrist, .067, .065, 'worn', 'Forearm.'+side)
        ellipsoid(side+' work glove', (sign*.391, -.105, .86), (.058, .055, .073), 'leather', 'Hand.'+side, 8, 5)
        ellipsoid(side+' glove thumb', (sign*.348, -.13, .882), (.027, .03, .044), 'leather', 'Hand.'+side, 8, 4)
    segment('Neck', (0, 0, 1.30), (0, 0, 1.43), .076, .078, 'skin', 'Neck', 8)


villager_body()
# A wide short apron, asymmetrical repair and contrasting worn edges are Mabb's identifiers.
bevel_box('Broad leather apron', (0, -.157, .805), (.425, .047, .36), 'leather', 'Hips', .018)
bevel_box('Apron worn lower edge', (0, -.185, .635), (.414, .012, .025), 'worn', 'Hips', .004)
bevel_box('Apron bib', (0, -.166, 1.06), (.25, .035, .27), 'leather', 'Spine', .012)
for sign in (-1, 1):
    segment('Apron neck strap', (sign*.093, -.152, 1.17), (sign*.083, -.075, 1.32), .016, .016, 'worn', 'Spine', 4)
bevel_box('Mismatched apron repair', (-.105, -.186, .76), (.112, .015, .092), 'worn', 'Hips', .006, (0, .08, .08))
for index in range(3):
    bevel_box('Repair stitch', (-.14+index*.035, -.197, .802), (.012, .005, .014), 'linen', 'Hips', .001)

# Sixteen-sided sculpted jaw, cheeks and brow against the eight-sided torso.
face = loft('Weathered face', [(0, -.009, 1.365, .074, .078),
    (0, -.016, 1.393, .116, .109), (0, -.009, 1.435, .147, .123),
    (0, .002, 1.485, .174, .148), (0, .008, 1.543, .17, .15),
    (0, .014, 1.61, .16, .143), (0, .015, 1.657, .099, .10)], 'skin', 'Head', 16)
face.data.materials.append(M['skin_light'])
for polygon in face.data.polygons:
    if polygon.center.x < -.08 and 1.43 < polygon.center.z < 1.50:
        polygon.material_index = 1
for sign in (-1, 1):
    x = sign*.065
    ellipsoid('Ear', (sign*.172, .004, 1.50), (.035, .033, .052), 'skin_light', 'Head', 8, 5)
    bevel_box('Narrow eye', (x, -.137, 1.535), (.05, .014, .024), 'eye', 'Head', .004)
    ellipsoid('Iris', (x, -.148, 1.534), (.010, .005, .012), 'dark', 'Head', 8, 4)
    bevel_box('Level brow', (x, -.14, 1.56), (.059, .016, .016), 'dark', 'Head', .004, (0, sign*.055, 0))
    segment('Cheek crease', (sign*.09, -.129, 1.484), (sign*.108, -.119, 1.464), .003, .002, 'skin', 'Head', 4)
mesh('Strong nose', [(-.023, -.144, 1.543), (.023, -.144, 1.543),
    (.03, -.151, 1.479), (-.03, -.151, 1.479), (0, -.186, 1.49)],
    [(0,4,1),(1,4,2),(2,4,3),(3,4,0),(0,1,2,3)], 'skin_light', 'Head')
bevel_box('Quiet mouth', (0, -.137, 1.436), (.063, .012, .009), 'mouth', 'Head', .003)
hair = loft('Short swept-back ash hair', [(0, .037, 1.579, .175, .142),
    (0, .023, 1.631, .173, .151), (0, .026, 1.679, .123, .119),
    (0, .03, 1.70, .045, .052)], 'hair', 'Head', 12)
hair.data.materials.append(M['hair_light'])
for p in hair.data.polygons:
    p.material_index = int(p.index in (3,4,14,15,16,25,26))
ellipsoid('Tied-back short knot', (0, .166, 1.574), (.073, .056, .057), 'hair', 'Head', 10, 5)
bevel_box('Plain hair tie', (0, .191, 1.57), (.077, .014, .018), 'worn', 'Head', .004)

arm_data = bpy.data.armatures.new('Villager skeleton')
rig = bpy.data.objects.new('MabbTruet', arm_data)
scene.collection.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
bone('Root', (0,0,0), (0,0,.15))
bone('Hips', (0,0,.81), (0,0,.94), 'Root')
bone('Spine', (0,0,.94), (0,0,1.27), 'Hips')
bone('Neck', (0,0,1.27), (0,0,1.365), 'Spine')
# Head local +Z is character forward (-Y Blender => +Z glTF).
head = bone('Head', (0,0,1.365), (0,0,1.64), 'Neck')
head.align_roll(Vector((0,-1,0)))
for side, sign in [('L',1),('R',-1)]:
    x = sign*BASE['stance']
    bone('Thigh.'+side, (x,0,.81), (x,0,.46), 'Hips')
    bone('Shin.'+side, (x,0,.46), (x,0,.15), 'Thigh.'+side)
    bone('Foot.'+side, (x,0,.15), (x,-.15,.07), 'Shin.'+side)
    bone('UpperArm.'+side, (sign*.285,0,1.24), (sign*.375,-.025,1.055), 'Spine')
    bone('Forearm.'+side, (sign*.375,-.025,1.055), (sign*.39,-.09,.895), 'UpperArm.'+side)
    bone('Hand.'+side, (sign*.39,-.09,.895), (sign*.391,-.105,.82), 'Forearm.'+side)
bpy.ops.object.mode_set(mode='OBJECT')

# Retain named mesh pieces in source for inexpensive costume/base variations.
for obj in pieces:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), obj.name
    assert bm.calc_volume(signed=True) > 0, obj.name
    assert all(f.calc_area() > 1e-10 for f in bm.faces), obj.name
    bm.to_mesh(obj.data)
    bm.free()
    obj.parent = rig
    obj.modifiers.new('Rigid faceted skin', 'ARMATURE').object = rig
    for v in obj.data.vertices:
        assert len(v.groups) == 1 and abs(v.groups[0].weight-1) < 1e-6
        assert all(math.isfinite(c) for c in v.co)
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'


def idle(t):
    reset_pose()
    s = math.sin(math.tau*t)
    rig.pose.bones['Spine'].rotation_euler[1] = .022*s
    rig.pose.bones['Spine'].rotation_euler[0] = .025
    rig.pose.bones['Head'].rotation_euler[1] = .07*math.sin(math.tau*t)**3
    for side, sign in [('L',1),('R',-1)]:
        rig.pose.bones['Forearm.'+side].rotation_euler[0] = .10 + .018*s*sign


def talk(t):
    reset_pose()
    rig.pose.bones['Head'].rotation_euler[1] = math.radians(3)*math.sin(math.tau*t)
    rig.pose.bones['Head'].rotation_euler[0] = math.radians(3)*math.sin(math.tau*t+.4)
    for side in ('L','R'):
        rig.pose.bones['Forearm.'+side].rotation_euler[0] = .10


idle_action = make_action('Idle', 120, idle)
talk_action = make_action('Talk', 50, talk)
foot_error = 0
for action, end in [(idle_action,121),(talk_action,51)]:
    rig.animation_data.action = action
    for f in range(1,end+1):
        scene.frame_set(f)
        for side in ('L','R'):
            foot_error = max(foot_error, (rig.pose.bones['Foot.'+side].head - arm_data.bones['Foot.'+side].head_local).length)
assert foot_error < 1e-6
rig.animation_data.action = None
reset_pose()
scene.frame_set(1)


def export(path, objects, animated=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_yup=True, export_animations=animated, export_animation_mode='NLA_TRACKS',
        export_frame_range=False, export_force_sampling=True, export_skins=animated,
        export_cameras=False, export_lights=False, export_extras=True)


export(MODELS/'MabbTruet.glb', [rig,*pieces], True)


def check_glb(path, animated=False):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF' and struct.unpack_from('<I',raw,8)[0] == len(raw)
    size = struct.unpack_from('<I',raw,12)[0]
    doc = json.loads(raw[20:20+size])
    binary = 28+size
    def values(idx):
        a = doc['accessors'][idx]; v = doc['bufferViews'][a['bufferView']]
        fmt, unit = {5126:('f',4),5125:('I',4),5123:('H',2),5121:('B',1)}[a['componentType']]
        width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        start = binary+v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*width,raw,start+i*v.get('byteStride',unit*width)) for i in range(a['count'])]
    assert not doc.get('textures') and not doc.get('images')
    assert all(max(abs(v-1) for v in n.get('scale',[1,1,1])) < 1e-6 for n in doc['nodes'])
    triangles=0
    for m in doc['meshes']:
        for p in m['primitives']:
            triangles += doc['accessors'][p['indices']]['count']//3
            assert all(math.isfinite(c) for v in values(p['attributes']['POSITION']) for c in v)
            for n in values(p['attributes']['NORMAL']):
                assert abs(sum(c*c for c in n)-1) < 1e-4
            if animated:
                assert 'JOINTS_0' in p['attributes']
                assert all(abs(sum(w)-1)<1e-5 and min(w)>=0 for w in values(p['attributes']['WEIGHTS_0']))
    clips={}; error=0
    for a in doc.get('animations',[]):
        clips[a['name']] = max(values(s['input'])[-1][0] for s in a['samplers'])-min(values(s['input'])[0][0] for s in a['samplers'])
        for s in a['samplers']:
            v=values(s['output']); error=max(error,max(abs(x-y) for x,y in zip(v[0],v[-1])))
    if animated:
        assert set(clips)=={'Idle','Talk'} and error<1e-5
        assert len(doc['skins'])==1
        assert any(n.get('name')=='Head' for n in doc['nodes'])
        parents={child:i for i,n in enumerate(doc['nodes']) for child in n.get('children',[])}
        def global_matrix(i):
            n=doc['nodes'][i]; q=n.get('rotation',[0,0,0,1])
            local=Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),
                Quaternion((q[3],q[0],q[1],q[2])),Vector(n.get('scale',[1,1,1])))
            return global_matrix(parents[i])@local if i in parents else local
        head_index=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='Head')
        head_world=global_matrix(head_index)
        assert (head_world.to_3x3()@Vector((0,0,1))-Vector((0,0,1))).length<1e-5
        assert (head_world.translation-Vector((0,1.365,0))).length<1e-5
    return dict(triangles=triangles,clips_seconds=clips,loop_endpoint_error=error,
                unit_scales=True,finite_vertices=True,normalized_normals=True,textures=False)


report={'MabbTruet':check_glb(MODELS/'MabbTruet.glb',True), 'palette_srgb':PALETTE,
        'foot_drift_m':foot_error, 'rest_height_m':max(v.co.z for o in pieces for v in o.data.vertices),
        'base_shoulder_to_hip_ratio':BASE['shoulder_radius']/BASE['hip_radius'],
        'head_forward_blender':list(arm_data.bones['Head'].matrix_local.col[2][:3]),
        'engine_playback':'Not tested; Blender and binary GLB validation only'}
assert abs(report['rest_height_m']-1.70)<1e-5

# Warm single-key preview stage. Source is saved with stage but export excludes it.
scene.world=bpy.data.worlds.new('Warm ambient')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(1,.94,.84,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012))
floor=bpy.context.object; floor.name='PREVIEW ONLY ground'; floor.data.materials.append(M['sage'])
bpy.ops.object.light_add(type='AREA',location=(-3,-4,6))
light=bpy.context.object; light.name='PREVIEW ONLY warm key'; light.data.energy=450
light.data.color=(1,.92,.80); light.data.size=4
light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.5,-6,2.5))
camera=bpy.context.object; camera.name='PREVIEW ONLY camera'; camera.data.type='ORTHO'; scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG'; scene.render.resolution_percentage=100


def render(name, target, scale, width, height):
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=scale
    scene.render.resolution_x=width; scene.render.resolution_y=height
    scene.render.filepath=str(SHOTS/name)
    bpy.ops.render.render(write_still=True)


rig.animation_data.action=idle_action; scene.frame_start=1; scene.frame_end=121; scene.frame_set(1)
camera.rotation_euler=(Vector((0,0,.87))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=2.1
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'MabbTruet.blend'))
render('mabb.png',(0,0,.87),2.1,600,700)
floor.hide_render=True; scene.render.film_transparent=True
camera.location=(.65,-4,1.70)
render('chathead.png',(0,-.005,1.535),.43,256,256)
rig.animation_data.action=talk_action; scene.frame_set(14)
render('chathead-talk.png',(0,-.005,1.535),.43,256,256)
floor.hide_render=False; scene.render.film_transparent=False

# A2: all three share approved trunk albedo and eight radial sides.
for obj in [rig,*pieces]:
    obj.hide_render=True; obj.hide_set(True)
pieces=[]
stumps=[]
for name,radius,height in [('WillowStump',.32,.30),('OakStump',.28,.32),('PineStump',.23,.28)]:
    obj=loft(name,[(0,0,0,radius,radius),(0,0,height-.018,radius*.95,radius*.95),
                   (0,0,height,radius*.86,radius*.86)],'wood','Root',8)
    obj.data.materials.append(M['wood_light'])
    obj.data.polygons[-1].material_index=1
    bm=bmesh.new(); bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0
    bm.free()
    path=ROOT/'assets/models/woodcutting'/(name+'.glb')
    export(path,[obj])
    report[name]=check_glb(path)
    report[name].update(radius_m=radius,height_m=height)
    stumps.append(obj)
# Save isolated stump source, then arrange only the preview.
for obj in [rig,*rig.children]:
    bpy.data.objects.remove(obj,do_unlink=True)
camera.location=(2.5,-4,3.4)
camera.rotation_euler=(Vector((0,0,.15))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=1.1
for obj in stumps:
    collection=bpy.data.collections.new(obj.name)
    scene.collection.children.link(collection)
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    collection.hide_render=obj!=stumps[0]
    bpy.context.view_layer.layer_collection.children[collection.name].hide_viewport=obj!=stumps[0]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/source/woodcutting/stumps.blend'))
for i,obj in enumerate(stumps):
    obj.users_collection[0].hide_render=False
    bpy.context.view_layer.layer_collection.children[obj.users_collection[0].name].hide_viewport=False
    obj.location.x=(i-1)*.88
render('stumps.png',(0,0,.12),2.9,800,400)

# Mabb's nearby felling axe: larger, plain iron, no additional brass fitting.
for obj in stumps:
    bpy.data.objects.remove(obj,do_unlink=True)
pieces=[]
segment('Felling axe haft',(0,0,0),(0,0,1.03),.034,.046,'wood_light','Root',8)
outline=[(.10,.87),(.10,1.035),(-.12,1.035),(-.31,1.105),(-.34,.79),(-.12,.85)]
vertices=[(x,y,z) for x in (-.043,.043) for y,z in outline]
faces=[tuple(reversed(range(6))),tuple(range(6,12))]
faces += [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
blade=mesh('Plain heavy iron head',vertices,faces,'iron','Root')
bpy.context.view_layer.objects.active=blade
mod=blade.modifiers.new('Light cutting bevel','BEVEL'); mod.width=.009; mod.segments=1
bpy.ops.object.modifier_apply(modifier=mod.name)
for obj in pieces:
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0
    bm.to_mesh(obj.data); bm.free()
export(MODELS/'MabbFellingAxe.glb',pieces)
report['MabbFellingAxe']=check_glb(MODELS/'MabbFellingAxe.glb')
camera.location=(2,-4,2)
camera.rotation_euler=(Vector((0,0,.55))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=1.5
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'MabbFellingAxe.blend'))
render('felling-axe.png',(0,-.07,.55),1.5,400,500)

# Inspect the existing exported Head guarantee without editing approved player assets.
for name in ('adventurer','adventurer_woodcutting'):
    raw=(ROOT/'assets/models'/(name+'.glb')).read_bytes()
    size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size])
    matches=[n for n in doc['nodes'] if n.get('name')=='Head']
    report[name+'_Head_nodes']=matches
    assert len(matches)==1
(SOURCE/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('VILLAGER_HANDOFF_VERIFIED '+json.dumps(report))
