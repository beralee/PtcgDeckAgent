"""Author reusable 3D arena hardware. Blender source and GLB are both retained."""
import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/arena3d/product-v5'
OUT=ROOT/'assets/arena3d/product-v5'
ART.mkdir(parents=True,exist_ok=True)
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
def mat(name,color,metal,rough,glow=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if glow:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
    return m
shell=mat('Gunmetal machined housing',(.045,.075,.11),.82,.28)
rim=mat('Brushed alloy bevel',(.21,.29,.34),.9,.24)
rubber=mat('Recessed dark socket',(.015,.026,.033),.1,.76)
light=mat('Status light channel',(.08,.7,1),.2,.3,2)
def box(name,loc,size,material,bevel):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    b=o.modifiers.new('Machined bevel','BEVEL');b.width=bevel;b.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o
box('Reward cradle base',(0,0,.10),(1.48,2.02,.20),shell,.09)
box('Recessed reward bed',(0,0,.22),(1.30,1.84,.06),rubber,.06)
for x in [-.70,.70]:
    box('Raised alloy rail',(x,0,.24),(.065,1.90,.17),rim,.026)
    box('Light guide',(x,0,.335),(.028,1.52,.018),light,.008)
for y in [-.97,.97]:box('End cap',(0,y,.21),(1.37,.06,.17),rim,.025)
for x in [-.62,.62]:
    for y in [-.86,.86]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.047,depth=.015,location=(x,y,.285))
        bpy.context.object.name='Recessed fastener';bpy.context.object.data.materials.append(rim)
groups={}
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH':groups.setdefault(obj.data.materials[0].name,[]).append(obj)
for objects in groups.values():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True);bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'reward_cradle.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'reward_cradle.glb'),export_format='GLB',export_apply=True)
print('ARENA_TACTICAL_MODULES_AUTHORED')
