"""Author the approved woodcutting A1/A3/A4 assets; Blender-only, no game code.

Run from any directory with Blender --background --python tools/create_woodcutting_props.py.
Regenerates its own sources, exports, verification report and two preview renders.
"""
import bpy
import bmesh
import json
import math
import struct
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/woodcutting'
MODELS = ROOT / 'assets/models/woodcutting'
SHOTS = ROOT / 'screenshots/woodcutting'
for folder in (SOURCE, MODELS, SHOTS):
    folder.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, rgb, srgb=False):
    if srgb:
        rgb = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Roughness'].default_value = .78
    return mat


def palette(name, value):
    return material(name, [int(value[i:i+2], 16) / 255 for i in (0, 2, 4)], True)


walnut = palette('Walnut #573f2e', '573f2e')
walnut_dark = palette('Walnut dark #3a3026', '3a3026')
meadow = palette('Canopy light #8d9c55', '8d9c55')
meadow_shade = palette('Reed #91965b', '91965b')
canopy = palette('Canopy #758747', '758747')
sage = palette('Sage void #8eaa9c', '8eaa9c')
# Exact linear values from tools/create_woodcutting_assets.py, not new colours.
honey = material('Axe - honey oak', (.46, .245, .075))
honey_light = material('Axe - oak facets', (.55, .32, .11))
assets = {}


def asset(name):
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    root['units'] = 'metres; ground-centred origin; glTF +Y up, +Z forward'
    assets[name] = root
    return root


def mesh(name, vertices, faces, mats, indices, root):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.parent = root
    for mat in mats:
        data.materials.append(mat)
    for poly, index in zip(data.polygons, indices):
        poly.material_index = index
        poly.use_smooth = False
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(edge.is_manifold for edge in bm.edges), name
    bm.to_mesh(data)
    bm.free()
    return obj


def rings(name, levels, sides, mats, root, face_indices=None):
    # level = (centre x, centre y, height, radius x, radius y)
    verts = [(x + rx * math.cos(i * math.tau / sides),
              y + ry * math.sin(i * math.tau / sides), z)
             for x, y, z, rx, ry in levels for i in range(sides)]
    faces = [tuple(reversed(range(sides)))]
    indices = [0]
    for j in range(len(levels) - 1):
        for i in range(sides):
            faces.append((j*sides+i, j*sides+(i+1)%sides,
                          (j+1)*sides+(i+1)%sides, (j+1)*sides+i))
            indices.append(face_indices(j, i) if face_indices else 0)
    faces.append(tuple(range((len(levels)-1)*sides, len(levels)*sides)))
    indices.append(len(mats)-1)
    return mesh(name, verts, faces, mats, indices, root)


def beam(name, a, b, radius, root, mat=honey, sides=4):
    a, b = Vector(a), Vector(b)
    length = (b-a).length
    obj = rings(name, [(0, 0, 0, radius*.86, radius*.86),
                       (0, 0, .025, radius, radius),
                       (0, 0, length-.025, radius*.94, radius*.94),
                       (0, 0, length, radius*.80, radius*.80)], sides, [mat], root)
    rotation = (b-a).to_track_quat('Z', 'Y')
    for vertex in obj.data.vertices:
        vertex.co = a + rotation @ vertex.co
    return obj


def make_log(root, name, position=(0, 0, .17), length=1.25, radius=.17, roll=0):
    # Recessed honey end grain within a broad eight-sided bark rim; no textures.
    levels = [(0, 0, -length/2, radius*.81, radius*.81),
              (0, 0, -length/2+.025, radius, radius),
              (0, 0, length/2-.025, radius*.96, radius*.96),
              (0, 0, length/2, radius*.78, radius*.78)]
    obj = rings(name, levels, 8, [honey_light, walnut, walnut_dark, honey], root,
                lambda j, i: (1 if i % 3 else 2) if j == 1 else 0)
    # Both cut faces use the established lighter honey material.
    obj.data.polygons[-1].material_index = 0
    for vertex in obj.data.vertices:
        x, y, z = vertex.co
        vertex.co = (z + position[0],
                     x*math.cos(roll)-y*math.sin(roll)+position[1],
                     x*math.sin(roll)+y*math.cos(roll)+position[2])
    return obj


willow = asset('WillowTree')
willow['requirement'] = 'A1: shorter trunk, broad drooping canopy; third silhouette'
willow['trunk_base_radius_m'] = .32
rings('Willow_Trunk', [(0, 0, 0, .32, .32), (.02, 0, .30, .3076, .3076),
                      (.10, .02, 1.70, .25, .25), (.15, .04, 2.35, .16, .16)],
      8, [walnut, walnut_dark], willow, lambda j, i: 1 if i in (3, 4) else 0)
for i in range(4):
    angle = i * math.tau / 4 + .2
    beam('Willow_Bough_%02d' % i, (.08, .02, 1.4),
         (math.cos(angle)*1.15, math.sin(angle)*1.1, 2.9), .16, willow, walnut, 6)
# A low umbrella joins hanging lobes; there is no oak's stacked ball crown.
rings('Willow_Umbrella', [(0, 0, 2.45, .7, .65), (0, 0, 2.85, 1.78, 1.54),
                         (-.10, .05, 3.42, 1.2, 1.02), (-.18, .06, 3.65, .35, .30)],
      10, [canopy, meadow_shade, meadow], willow,
      lambda j, i: 0 if j == 0 else (1 if i % 4 == 0 else 2))
for i in range(7):
    angle = i * math.tau / 7 + .12
    cx, cy = math.cos(angle), math.sin(angle)
    drop = [1.05, 1.32, 1.16, 1.00, 1.25, 1.14, 1.38][i]
    rings('Willow_Drape_%02d' % i,
          [(cx*1.78, cy*1.65, drop, .16, .17),
           (cx*1.93, cy*1.72, drop+.30, .39, .38),
           (cx*1.73, cy*1.57, 2.48, .66, .60),
           (cx*1.27, cy*1.16, 3.02, .68, .62),
           (cx*.91, cy*.81, 3.25, .24, .23)],
          7, [canopy, meadow_shade, meadow], willow,
          lambda j, side: 0 if j == 0 else (1 if side % 3 == 0 else 2))

log = asset('CutLog')
log['requirement'] = 'A3: ground log and future icon source; length 1.25 m'
make_log(log, 'CutLog_Mesh')


def rack(name, loaded):
    root = asset(name)
    root['requirement'] = 'A4: handmade Village register; interchangeable ground origin'
    for i, x in enumerate((-.47, .47)):
        beam('Bearer_%d' % i, (x, -.89, .12), (x+.025, .89, .12), .12, root)
        for j, y in enumerate((-.82, .82)):
            height = [[1.05, .94], [.98, 1.10]][i][j]
            beam('Stake_%d_%d' % (i, j), (x, y, .015),
                 (x + (-.035 if i == 0 else .02), y*1.04, height), .105, root,
                 honey if i == j else honey_light)
    for j, y in enumerate((-.83, .83)):
        beam('SideRail_%d' % j, (-.56, y, .46), (.58, y+.015, .50), .075, root)
    if loaded:
        index = 0
        for row, count in enumerate((4, 3, 2)):
            for col in range(count):
                make_log(root, 'Stack_Log_%02d' % index,
                         ((index % 3 - 1)*.04, (col-(count-1)/2)*.34, .41+row*.294),
                         length=1.25+(index%3)*.045, radius=.17, roll=0)
                index += 1
    return root


rack('LogPileEmpty', False)
rack('LogPileStacked', True)

# Authoring validation and per-asset GLB exports, all transforms baked into meshes.
report = {'requirements': ['A1', 'A3', 'A4'], 'assets': {},
          'textures': False, 'uvs': 'Unneeded for flat-colour materials',
          'engine_validation': 'Not performed; asset-only delivery'}
for name, root in assets.items():
    objects = [root, *root.children_recursive]
    triangles = 0
    points = []
    for obj in objects[1:]:
        assert tuple(obj.scale) == (1, 1, 1)
        assert obj.location.length == 0
        assert all(math.isfinite(v) for vertex in obj.data.vertices for v in vertex.co)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        assert all(edge.is_manifold for edge in bm.edges), obj.name
        assert bm.calc_volume(signed=True) > 0, obj.name
        assert all(face.calc_area() > 1e-9 for face in bm.faces), obj.name
        bm.free()
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        points.extend(vertex.co.copy() for vertex in obj.data.vertices)
    bounds = [[min(p[i] for p in points), max(p[i] for p in points)] for i in range(3)]
    assert bounds[2][0] >= -1e-5, (name, bounds)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = MODELS / (name + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_yup=True, export_animations=False, export_extras=True,
                              export_cameras=False, export_lights=False)
    raw = path.read_bytes()
    assert raw[:4] == b'glTF' and struct.unpack_from('<I', raw, 8)[0] == len(raw)
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+size])
    assert not doc.get('textures') and not doc.get('images')
    assert not doc.get('animations') and not doc.get('skins')
    assert all(node.get('scale', [1, 1, 1]) == [1, 1, 1] for node in doc['nodes'])
    exported_triangles = sum(doc['accessors'][p['indices']]['count']//3
                             for m in doc['meshes'] for p in m['primitives'])
    assert exported_triangles == triangles
    report['assets'][name] = dict(triangles=triangles, bounds_blender_xyz_m=bounds,
                                  mesh_components=len(objects)-1,
                                  closed_components=True, outward_normals=True,
                                  finite_vertices=True, unit_scales=True,
                                  glb_triangles_verified=True)

# Shared editable source keeps assets at their export origins in named collections.
for name, root in assets.items():
    collection = bpy.data.collections.new(name)
    scene.collection.children.link(collection)
    for obj in [root, *root.children_recursive]:
        scene.collection.objects.unlink(obj)
        collection.objects.link(obj)

scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('Warm studio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.78, .82, .73, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .8
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
stage = bpy.data.collections.new('PREVIEW ONLY')
scene.collection.children.link(stage)


def stage_object(obj):
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    stage.objects.link(obj)
    return obj


bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.018))
floor = stage_object(bpy.context.object)
floor.name = 'PREVIEW ONLY - sage ground'
floor.data.materials.append(sage)
bpy.ops.object.light_add(type='AREA', location=(-3, -4, 8))
light = stage_object(bpy.context.object)
light.name = 'PREVIEW ONLY - warm key'
light.data.energy = 650
light.data.shape = 'DISK'
light.data.size = 5
light.data.color = (1, .92, .80)
bpy.ops.object.camera_add(location=(7, -10, 7))
camera = stage_object(bpy.context.object)
camera.name = 'PREVIEW ONLY - camera'
camera.data.type = 'ORTHO'
scene.camera = camera


def frame(target, scale, width, height):
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = scale
    scene.render.resolution_x, scene.render.resolution_y = width, height


def show(names):
    for name in assets:
        bpy.data.collections[name].hide_render = name not in names
        bpy.context.view_layer.layer_collection.children[name].hide_viewport = name not in names


show(['WillowTree'])
frame((0, 0, 1.8), 6.1, 800, 800)
bpy.ops.object.select_all(action='DESELECT')
willow.select_set(True)
bpy.context.view_layer.objects.active = willow
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'woodcutting_props.blend'))
scene.render.filepath = str(SHOTS / 'willow-tree.png')
bpy.ops.render.render(write_still=True)

# Arrange instances for the prop sheet, leaving source/export origins untouched.
show(['CutLog', 'LogPileEmpty', 'LogPileStacked'])
assets['LogPileEmpty'].location = (-1.35, .7, 0)
assets['LogPileStacked'].location = (1.15, .7, 0)
assets['CutLog'].location = (0, -1.25, 0)
camera.location = (6, -9, 6)
frame((0, .05, .45), 6.4, 1000, 700)
scene.render.filepath = str(SHOTS / 'log-pile-states.png')
bpy.ops.render.render(write_still=True)
(SOURCE / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('WOODCUTTING_PROPS_VERIFIED ' + json.dumps(report))
