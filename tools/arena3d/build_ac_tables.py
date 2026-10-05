"""Rebuild the two authored tables with Blender; no reference-image projection."""
import bpy, math, pathlib, random, json
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'evidence/arena3d/ac-v2'
OUT.mkdir(parents=True, exist_ok=True)

def mat(name, rgb, metal=0, rough=.6):
    m = bpy.data.materials.new(name); m.diffuse_color = (*rgb, 1); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Metallic'].default_value = metal; p.inputs['Roughness'].default_value = rough
    return m

def textured(name, rgb, wood=False):
    m = mat(name, rgb, 0, .86 if not wood else .42)
    # Portable packed color texture: no baked illumination or reference shadows.
    n=512; image=bpy.data.images.new(name+' weave', width=n, height=n)
    rng=random.Random(831); pixels=[]
    for y in range(n):
        for x in range(n):
            grain=(math.sin(y*.19+math.sin(x*.015)*3)*.12+math.sin(y*.8)*.025) if wood else ((x%3-y%3)*.018)
            f=1+grain+rng.uniform(-.06,.06)
            pixels.extend([max(0,min(1,c*f)) for c in rgb]+[1])
    image.pixels.foreach_set(pixels); image.pack()
    nodes=m.node_tree.nodes; tex=nodes.new('ShaderNodeTexImage'); tex.image=image
    m.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    return m

def box(name, at, size, material, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o=bpy.context.object; o.name=name; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    if bevel:
        b=o.modifiers.new('Soft machined edge','BEVEL'); b.width=bevel; b.segments=4
        o.modifiers.new('Face normals','WEIGHTED_NORMAL')
    return o

def cylinder(name, at, radius, depth, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth, location=at)
    o=bpy.context.object; o.name=name; o.data.materials.append(material)
    b=o.modifiers.new('Coin rim','BEVEL'); b.width=.035; b.segments=3
    o.modifiers.new('Face normals','WEIGHTED_NORMAL'); return o

def leaf(at, angle, length, material):
    # Opaque curved leaf, avoiding alpha layers over the playing surface.
    verts=[(0,0,0),(.13*length,.23*length,.03),(.22*length,.5*length,.06),(.14*length,.76*length,.05),(0,length,.01),(-.14*length,.76*length,.05),(-.22*length,.5*length,.06),(-.13*length,.23*length,.03),(0,.48*length,.12)]
    mesh=bpy.data.meshes.new('Leaf blade'); mesh.from_pydata(verts,[],[(i,(i+1)%8,8) for i in range(8)])
    mesh.materials.append(material); o=bpy.data.objects.new('Peripheral leaf',mesh)
    bpy.context.collection.objects.link(o); o.location=at; o.rotation_euler.z=angle
    return o

reports=[]
for theme in ['grove']:
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    assert theme == 'grove'
    frame=textured('Walnut end grain',(.22,.095,.038),True)
    trim=mat('Copper',(.51,.29,.105),.72,.28)
    felt=textured('Deep spruce woven mat',(.035,.105,.067))
    base=mat('Table underside',(.035,.027,.022),.1,.65)
    box('Solid table', (0,0,-.5),(21,12.6,.75),base,.42)
    box('Outer frame',(0,0,-.09),(20.8,12.4,.32),frame,.38)
    box('Inset accent trim',(0,0,.07),(20.08,11.7,.14),trim,.32)
    box('Playing cloth',(0,0,.15),(19.87,11.49,.11),felt,.3)
    # Rails and corner medallions live outside the central card footprint.
    for x in [-10.08,10.08]:
        for y in [-5.85,5.85]:
            cylinder('Corner medallion',(x,y,.13),.27,.06,trim)
            cylinder('Medallion inset',(x,y,.17),.19,.022,frame)
    for side in [-1,1]:
        box('Card deck case',(side*8.6,side*4.1,.43),(1.05,1.5,.45),base,.09)
        box('Case accent',(side*8.6,side*4.1,.67),(.96,1.41,.035),trim,.06)
        cylinder('Metal play coin',(side*8.7,side*2.8,.25),.32,.065,frame)
    greens=[mat('Leaf '+str(i),c,0,.82) for i,c in enumerate([(.025,.065,.018),(.055,.105,.025),(.018,.042,.024)])]
    rng=random.Random(912)
    for side in [-1,1]:
        for j in range(9):
            y=-5.6+j*1.37+rng.uniform(-.25,.25)
            # Plant blades point along/outside the edge, never into the cards.
            for k in range(5):
                leaf((side*(10.22+rng.uniform(-.1,.2)),y,.23+rng.random()*.15),side*(-1.15+k*.5)+rng.uniform(-.2,.2),.4+rng.random()*.7,greens[(j+k)%3])
    bpy.ops.object.camera_add(location=(0,-.6,20))
    camera=bpy.context.object; camera.name='Game composition camera'
    camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'; camera.data.ortho_scale=22
    scene=bpy.context.scene; scene.camera=camera
    bpy.ops.object.light_add(type='AREA',location=(-5,-2,12)); bpy.context.object.data.energy=1800; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=10
    scene.world.color=(.3,.3,.3); scene.render.engine='CYCLES'; scene.cycles.samples=16
    scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    source=ROOT/f'art/arena3d/{theme}_table_v2.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    output=ROOT/f'assets/arena3d/themes/{theme}/table.glb'; output.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
    scene.render.filepath=str(OUT/f'blender-{theme}.png'); bpy.ops.render.render(write_still=True)
    deps=bpy.context.evaluated_depsgraph_get(); triangles=0; meshes=0
    for o in scene.objects:
        if o.type=='MESH':
            ev=o.evaluated_get(deps); me=ev.to_mesh(); me.calc_loop_triangles(); triangles+=len(me.loop_triangles); meshes+=1; ev.to_mesh_clear()
    reports.append(dict(theme=theme,source=str(source),asset=str(output),bytes=output.stat().st_size,meshes=meshes,triangles=triangles,texture_size=512))
(OUT/'asset-report.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
print('AC_TABLE_EXPORT_PASS')
