"""Author CutLog's bag camera pose; preserve the existing GLB mesh and materials.

Run with Blender --background --python-exit-code 1 --python tools/create_log_icon.py
after regenerating woodcutting props. No game code or runtime textures are produced.
"""
import json
import math
import struct
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / 'assets/models/woodcutting/CutLog.glb'
SOURCE = ROOT / 'assets/source/woodcutting'
PREVIEW = ROOT / 'screenshots/woodcutting/cut-log-icon.png'

raw = MODEL.read_bytes()
json_size = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20 + json_size])
binary_chunk = raw[20 + json_size:]
assert not doc.get('textures') and not doc.get('skins')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(MODEL))
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
centre = Vector([(min(p[i] for p in points) + max(p[i] for p in points)) / 2
                 for i in range(3)])
root = next(o for o in scene.objects if o.parent is None)
for obj in list(scene.objects):
    if obj.name == 'IconAnchor':
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.object.camera_add()
camera = bpy.context.object
camera.name = 'PREVIEW ONLY - icon camera'
camera.data.type = 'PERSP'
camera.data.sensor_fit = 'VERTICAL'
camera.data.angle = math.radians(30)
scene.camera = camera
scene.render.resolution_x = scene.render.resolution_y = 128
scene.render.resolution_percentage = 100
# Log runs along X. This view keeps the cut face and length visible together.
direction = Vector((1.25, -1.65, 1.15)).normalized()
camera.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
near, far = .8, 8.0
for _ in range(48):
    distance = (near + far) / 2
    camera.location = centre + direction * distance
    bpy.context.view_layer.update()
    projected = [world_to_camera_view(scene, camera, p) for p in points]
    if all(.075 <= p.x <= .925 and .075 <= p.y <= .925 and p.z > 0
           for p in projected):
        far = distance
    else:
        near = distance
camera.location = centre + direction * far
bpy.context.view_layer.update()
anchor = bpy.data.objects.new('IconAnchor', None)
scene.collection.objects.link(anchor)
anchor.parent = root
anchor.matrix_world = camera.matrix_world.copy()
anchor.empty_display_type = 'ARROWS'
anchor.empty_display_size = .15
anchor['purpose'] = 'Camera pose: local -Z looks at item, +Y is camera up; vertical FOV 30 degrees'

# Add only a node to the original GLB: the binary geometry and materials stay exact.
conversion = Matrix.Rotation(math.radians(-90), 4, 'X')
transform = conversion @ anchor.matrix_local @ conversion.inverted()
node = dict(name='IconAnchor', matrix=[transform[row][col]
            for col in range(4) for row in range(4)],
            extras={'icon_vertical_fov_degrees': 30, 'icon_frame_fraction': .85})
existing = next((i for i, n in enumerate(doc['nodes']) if n.get('name') == 'IconAnchor'), None)
if existing is None:
    index = len(doc['nodes'])
    doc['nodes'].append(node)
    parent_index = next(i for i, n in enumerate(doc['nodes']) if n.get('name') == root.name)
    doc['nodes'][parent_index].setdefault('children', []).append(index)
else:
    doc['nodes'][existing] = node
encoded = json.dumps(doc, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
output = struct.pack('<4sII', b'glTF', 2, 20 + len(encoded) + len(binary_chunk))
output += struct.pack('<II', len(encoded), 0x4E4F534A) + encoded + binary_chunk
MODEL.write_bytes(output)
assert output[20 + len(encoded):] == binary_chunk

# Reimport the delivered model and verify the converted camera pose before rendering.
expected = camera.matrix_world.copy()
for obj in list(meshes) + [anchor, root]:
    if obj.name in bpy.data.objects:
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(MODEL))
delivered_anchor = bpy.data.objects['IconAnchor']
bpy.context.view_layer.update()
assert max(abs(delivered_anchor.matrix_world[r][c] - expected[r][c])
           for r in range(4) for c in range(4)) < 1e-5
camera.matrix_world = delivered_anchor.matrix_world.copy()
triangles = 0
for obj in scene.objects:
    if obj.type == 'MESH':
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
assert triangles == 60

scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.world = bpy.data.worlds.new('Warm ambient')
scene.world.use_nodes = True
background = scene.world.node_tree.nodes['Background']
background.inputs['Color'].default_value = (1, .94, .83, 1)
background.inputs['Strength'].default_value = .40
bpy.ops.object.light_add(type='SUN')
sun = bpy.context.object
sun.name = 'PREVIEW ONLY - warm upper-left key'
sun.rotation_euler = Vector((3, 4, -8)).to_track_quat('-Z', 'Y').to_euler()
sun.data.energy = .85
sun.data.color = (1, .94, .83)
sun.data.angle = math.radians(12)
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.render.filepath = str(PREVIEW)
PREVIEW.parent.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'cut_log_icon.blend'))
bpy.ops.render.render(write_still=True)
preview_image = bpy.data.images.load(str(PREVIEW), check_existing=False)
pixels = list(preview_image.pixels)
occupied = [(i % 128, i // 128) for i in range(128 * 128)
            if pixels[i * 4 + 3] > .05]
pixel_bounds = [min(p[0] for p in occupied), min(p[1] for p in occupied),
                max(p[0] for p in occupied), max(p[1] for p in occupied)]
assert all(0 < v < 127 for v in pixel_bounds), pixel_bounds
assert 100 <= pixel_bounds[2] - pixel_bounds[0] + 1 <= 110, pixel_bounds
assert pixels[3] == 0
report = {'triangles': triangles, 'geometry_and_material_buffers_unchanged': True,
          'anchor_roundtrip_verified': True, 'render_size': [128, 128],
          'vertical_fov_degrees': 30, 'transparent_background': True,
          'geometry_modified': False, 'alpha_bounds_pixels': pixel_bounds,
          'engine_bag_render_verified': False}
(SOURCE / 'log-icon-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
