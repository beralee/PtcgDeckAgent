"""Blender offline LOD bake. Retains every desktop part, joint and character.

blender --background --python tools/arena3d/build_portable_assets.py
No runtime Python. Originals remain untouched. Palette meshes are batched per
articulated joint with baked vertex lighting; table material groups retain UVs.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import subprocess
import shutil
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/arena3d'
OUT = SOURCE / 'portable'
OUT.mkdir(parents=True, exist_ok=True)
manifest = {'schema_version': 1, 'assets': [], 'texture_limit': 768}


def unlit_glb(path):
    data = path.read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + size])
    for mat in doc.get('materials', []):
        mat.setdefault('extensions', {})['KHR_materials_unlit'] = {}
    doc['extensionsUsed'] = sorted(set(doc.get('extensionsUsed', []) + ['KHR_materials_unlit']))
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    rest = data[20 + size:]
    path.write_bytes(struct.pack('<4sII', b'glTF', 2, 20 + len(encoded) + len(rest)) + struct.pack('<I4s', len(encoded), b'JSON') + encoded + rest)


def bake(source, target, actor=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    source_parts = sorted(o.name for o in meshes)
    joints = sorted(o.name for o in bpy.context.scene.objects if o.type == 'EMPTY')
    before = sum(len(o.data.polygons) for o in meshes)
    light = Vector((-.4, -.3, .85)).normalized()
    palette = bpy.data.materials.new('Portable baked palette')
    palette.use_nodes = True
    color_node = palette.node_tree.nodes.new('ShaderNodeVertexColor')
    color_node.layer_name = 'PortableColor'
    palette.node_tree.links.new(color_node.outputs['Color'], palette.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        if len(obj.data.polygons) > 96:
            modifier = obj.modifiers.new('Portable silhouette LOD', 'DECIMATE')
            modifier.ratio = max(0.24 if actor else 0.28, 96 / len(obj.data.polygons))
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        colors = obj.data.color_attributes.new(name='PortableColor', type='FLOAT_COLOR', domain='CORNER')
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        for face in obj.data.polygons:
            material = obj.data.materials[face.material_index]
            bsdf = material.node_tree.nodes.get('Principled BSDF') if material.use_nodes else None
            base = tuple(bsdf.inputs['Base Color'].default_value) if bsdf else tuple(material.diffuse_color)
            for index in face.loop_indices:
                normal = normal_matrix @ obj.data.vertices[obj.data.loops[index].vertex_index].normal
                shade = .54 + .46 * max(0, normal.normalized().dot(light))
                colors.data[index].color = (*[base[c] * shade if actor else shade for c in range(3)], 1)
        if actor:
            obj.data.materials.clear()
            obj.data.materials.append(palette)
            for face in obj.data.polygons: face.material_index = 0
    if actor:
        groups = {}
        for obj in meshes: groups.setdefault(obj.parent, []).append(obj)
        for parent, objects in groups.items():
            bpy.ops.object.select_all(action='DESELECT')
            for obj in objects: obj.select_set(True)
            bpy.context.view_layer.objects.active = objects[0]
            bpy.ops.object.join()
            objects[0].name = (parent.name if parent else 'Body') + '_PortableMesh'
    else:
        for material in bpy.data.materials:
            if not material.use_nodes: continue
            bsdf = material.node_tree.nodes.get('Principled BSDF')
            if not bsdf: continue
            # Keep authored diffuse textures and their UVs; drop normal/roughness
            # sampling and dynamic specular. All prop silhouettes are still here.
            for socket in ['Normal', 'Roughness', 'Metallic']:
                for link in list(bsdf.inputs[socket].links): material.node_tree.links.remove(link)
            bsdf.inputs['Metallic'].default_value = 0
            bsdf.inputs['Roughness'].default_value = 1
        for image in bpy.data.images:
            width, height = image.size
            if max(width, height) > 768:
                ratio = 768 / max(width, height)
                image.scale(max(1, round(width * ratio)), max(1, round(height * ratio)))
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', export_yup=True,
        export_animations=False, export_cameras=False, export_lights=False, export_image_format='AUTO')
    unlit_glb(target)
    final_meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    manifest['assets'].append({'path': target.relative_to(ROOT).as_posix(),
        'source': source.relative_to(ROOT).as_posix(), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'source_parts': source_parts,
        'joints': joints, 'source_faces': before, 'portable_faces': sum(len(o.data.polygons) for o in final_meshes),
        'source_meshes': len(meshes), 'portable_meshes': len(final_meshes)})
    print('PORTABLE_ASSET', target.name, before, manifest['assets'][-1]['portable_faces'], flush=True)


bake(SOURCE / 'product-v6/grove_table.glb', OUT / 'grove_table.glb')
bake(SOURCE / 'product-v5/reward_cradle.glb', OUT / 'reward_cradle.glb')
for source in sorted((SOURCE / 'pokemon').glob('*.glb')):
    bake(source, OUT / 'pokemon' / source.name, actor=True)
# Character sheets retain all six poses, at 384px per pose for the portable UI;
# the original desktop artwork and audio are retained separately.
for source in sorted((SOURCE / 'supporters').rglob('*.png')):
    image = bpy.data.images.load(str(source), check_existing=False)
    width, height = image.size
    ratio = min(1, 1152 / width, 768 / height)
    image.scale(round(width * ratio / 3) * 3, round(height * ratio / 2) * 2)
    target = OUT / source.relative_to(SOURCE)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(target)
    image.file_format = 'PNG'
    image.save()
    descriptor = target.with_suffix(target.suffix + '.import')
    if descriptor.exists():
        settings = descriptor.read_text(encoding='utf-8').replace('compress/mode=0', 'compress/mode=1').replace('compress/lossy_quality=0.7', 'compress/lossy_quality=0.82')
        descriptor.write_text(settings, encoding='utf-8')
    manifest['assets'].append({'path':target.relative_to(ROOT).as_posix(),'source':source.relative_to(ROOT).as_posix(),
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
        'size':list(image.size),'poses':6})
    bpy.data.images.remove(image)
for directory in ['pokemon/audio', 'supporters/audio']:
    for source in sorted((SOURCE / directory).glob('*.wav')):
        target = (OUT / source.relative_to(SOURCE)).with_suffix('.ogg')
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([shutil.which('ffmpeg'), '-loglevel', 'error', '-y', '-i', str(source), '-c:a', 'libvorbis', '-q:a', '4', str(target)], check=True)
        manifest['assets'].append({'path':target.relative_to(ROOT).as_posix(),'source':source.relative_to(ROOT).as_posix(),
            'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
(OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
