"""Authored A/C table scenes. Run with Blender --background --python this_file.

Sources: verified Poly Haven CC0 scans from fetch_product_assets.ps1.
No screenshot/background planes. All silhouettes, trim, props and leaves are geometry.
"""
import bpy, math, json, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'art/arena3d/product-v3/sources'
OUT = ROOT / 'assets/arena3d/product-v5'
ART = ROOT / 'art/arena3d/product-v5'
EVIDENCE = ROOT / 'evidence/arena3d/product-v5-20260919'
random.seed(19)

def material(name, color, rough=.45, metal=0, scan=None, normal=.3):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    if scan:
        for file, socket, noncolor in [('Diffuse.jpg','Base Color',False),('Rough.jpg','Roughness',True),('nor_gl.jpg','Normal',True)]:
            p = SRC / scan / file
            if not p.exists(): continue
            tex = m.node_tree.nodes.new('ShaderNodeTexImage')
            tex.image = bpy.data.images.load(str(p), check_existing=True)
            if noncolor: tex.image.colorspace_settings.name = 'Non-Color'
            if file == 'nor_gl.jpg':
                n = m.node_tree.nodes.new('ShaderNodeNormalMap')
                n.inputs['Strength'].default_value = normal
                m.node_tree.links.new(tex.outputs['Color'], n.inputs['Color'])
                m.node_tree.links.new(n.outputs['Normal'], bs.inputs[socket])
            else: m.node_tree.links.new(tex.outputs['Color'], bs.inputs[socket])
    return m

def assign(obj, mat):
    obj.data.materials.append(mat)
    return obj

def uv_planar(obj, tile=2, rotate=False):
    uv = obj.data.uv_layers.new(name='Surface UV') if not obj.data.uv_layers else obj.data.uv_layers.active
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            v = obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv = ((v.y if rotate else v.x)/tile, (v.x if rotate else v.y)/tile)

def finish(obj, mat, bevel=0):
    assign(obj, mat)
    if bevel:
        mod=obj.modifiers.new('Manufactured edge radius','BEVEL'); mod.width=bevel; mod.segments=3
        mod=obj.modifiers.new('Corner normals','WEIGHTED_NORMAL')
    return obj

def box(name, pos, dims, mat, bevel=.035, tile=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj=bpy.context.object; obj.name=name; obj.dimensions=dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    uv_planar(obj,tile)
    return finish(obj,mat,bevel)

def outline(w,h,r,steps=20):
    pts=[]
    for cx,cy,start in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),(-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)]:
        for i in range(steps+1):
            a=math.radians(start+i*90/steps)
            pts.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return pts

def slab(name,w,h,r,z,depth,mat,tile=3):
    pts=outline(w,h,r); n=len(pts)
    verts=[(x,y,zz) for zz in [z-depth,z] for x,y in pts]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    uv_planar(obj,tile);return finish(obj,mat,.025)

def band(name,w,h,r,width,z,depth,mat,tile=3):
    outer=outline(w,h,r);inner=outline(w-width*2,h-width*2,max(.04,r-width));n=len(outer)
    verts=[(x,y,zz) for zz in [z-depth,z] for path in [outer,inner] for x,y in path]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,j+2*n,i+2*n),(i+2*n,j+2*n,j+3*n,i+3*n),(i+n,i+3*n,j+3*n,j+n),(i,j,i+n,j+n)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    uv_planar(obj,tile);return finish(obj,mat,min(.02,width*.2))

def cylinder(name,pos,r,depth,mat,vertices=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=pos)
    obj=bpy.context.object;obj.name=name;uv_planar(obj)
    return finish(obj,mat,.02)

def torus(name,pos,r,tube,mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,location=pos,major_radius=r,minor_radius=tube)
    obj=bpy.context.object;obj.name=name;assign(obj,mat)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def insignia(x,y,z,r,mat):
    torus('Inlaid tournament emblem',(x,y,z),r,.018,mat)
    box('Emblem divider',(x,y,z),(r*2,.04,.016),mat,.008)
    cylinder('Emblem center',(x,y,z+.01),r*.26,.026,mat,48)

def deckbox(x,y,body,trim):
    box('Leather deck case',(x,y,.59),(1.1,1.5,.7),body,.12)
    box('Deck case lid',(x,y,.97),(1.13,1.54,.12),body,.065)
    box('Case metal clasp',(x,y-.75,.72),(.28,.055,.29),trim,.026)
    torus('Case stitched medallion',(x,y,1.04),.28,.012,trim)
    insignia(x,y,1.04,.19,trim)

def ball(x,y,white,red,dark,metal):
    # Equatorial split is real geometry, not a flat painted circle.
    for upper,mat in [(True,red),(False,white)]:
        verts=[];faces=[];R=.65
        for lat in range(17):
            phi=(lat/16)*math.pi/2 + (0 if upper else math.pi/2)
            for seg in range(64):
                a=seg*math.tau/64;verts.append((x+R*math.sin(phi)*math.cos(a),y+R*math.sin(phi)*math.sin(a),.81+R*math.cos(phi)))
        for row in range(16):
            for seg in range(64):
                a=row*64+seg;b=row*64+(seg+1)%64;faces.append((a,b,b+64,a+64))
        mesh=bpy.data.meshes.new('Ceramic hemisphere');mesh.from_pydata(verts,[],faces);mesh.update()
        obj=bpy.data.objects.new('Ceramic ball upper' if upper else 'Ceramic ball lower',mesh);bpy.context.collection.objects.link(obj);assign(obj,mat)
        for p in mesh.polygons:p.use_smooth=True
    torus('Ball equator',(x,y,.81),.65,.034,dark)
    # Button angled toward the camera (top view).
    cylinder('Ball top medallion',(x,y,1.455),.17,.025,metal)
    cylinder('Ball top inset',(x,y,1.48),.12,.02,white)

def make(theme):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    assert theme == 'grove'
    cloth=material('Jade woven playing felt',(.046,.105,.070),.88,scan='fabric_pattern_07',normal=.22)
    wood=material('Oiled black walnut',(.2,.09,.035),scan='black_walnut_veneer_02',normal=.22)
    metal=material('Satin antique brass',(.43,.24,.085),.27,.78)
    fine=material('Pale brass inlay',(.64,.43,.19),.19,.85)
    dark=material('Graphite powder coat',(.018,.023,.022),.49,.24)
    white=material('Ivory ceramic',(.85,.84,.75),.25)
    leather=material('Forest leather',(.028,.08,.047),.8,scan='fabric_pattern_07',normal=.13)
    # Recessed playing surface: layered curved profiles catch different highlights.
    slab('Continuous table foundation',23.5,14.1,1.2,-.05,.7,wood)
    slab('Walnut surround',23.2,13.8,1.15,.10,.18,wood,tile=7)
    band('Outer moulding',22.5,13.1,1.05,.16,.23,.15,metal)
    band('Primary raised frame',22.12,12.74,.94,.25,.29,.18,wood,tile=5)
    band('Inner color inlay',21.58,12.20,.73,.105,.255,.10,metal)
    band('Fine rolled inner lip',21.33,11.95,.64,.032,.242,.07,fine)
    slab('Recessed woven playfield',21.24,11.86,.61,.21,.13,cloth,tile=2.4)
    band('Felt stitched perimeter',20.95,11.57,.51,.012,.218,.006,metal)
    # Decorative fittings live outside the playable card columns.
    for side in [-1,1]:
        for yy in [-5.6,5.6]:
            cylinder('Corner escutcheon',(side*10.55,yy,.36),.35,.12,metal)
            torus('Engraved escutcheon rim',(side*10.55,yy,.43),.27,.014,fine)
            insignia(side*10.55,yy,.44,.17,fine)
    ball(-10.55,5.50,white,leather,dark,metal)
    # Hairline embossing never competes with card faces.
    for xx in [-6.9,6.9]:
        for yy in [-4.2,4.2]:
            box('Playfield registration',(xx,yy,.218),(.17,.012,.003),metal,.002)
    bpy.ops.import_scene.gltf(filepath=str(SRC/'fern_02/fern_02.gltf'))
    originals=[o for o in bpy.context.selected_objects if o.type=='MESH']
    for obj in originals:
        bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    # Scanned plants at the outer rim; varied rotation/scale breaks repetition.
    for index,(x,y,s) in enumerate([(-11.25,-4.3,2.8),(-11.3,1.8,2.4),(-10.9,5.8,2.2),(11.15,-5.1,2.4),(11.3,3.0,2.9),(9.3,6.45,2.4),(-7.7,-6.65,2.0),(10.0,-6.4,1.7)]):
        for original in originals:
            obj=original.copy();obj.data=original.data;obj.name=f'Fern border {index:02d}';bpy.context.collection.objects.link(obj)
            obj.location=(x,y,.30);obj.scale=(s,s,s);obj.rotation_euler[2]=random.uniform(0,math.tau)
        cylinder('Planting bowl',(x,y,.06),.57,.48,wood)
        torus('Bowl brass rim',(x,y,.32),.54,.026,metal)
    for o in originals:bpy.data.objects.remove(o,do_unlink=True)
    world=bpy.data.worlds.new(theme+' studio') if bpy.context.scene.world is None else bpy.context.scene.world
    bpy.context.scene.world=world;world.use_nodes=True
    nodes=world.node_tree.nodes;nodes.clear();tex=nodes.new('ShaderNodeTexEnvironment');tex.image=bpy.data.images.load(str(SRC/'studio_small_09.hdr'),check_existing=True)
    bg=nodes.new('ShaderNodeBackground');bg.inputs['Strength'].default_value=.45;out=nodes.new('ShaderNodeOutputWorld')
    world.node_tree.links.new(tex.outputs['Color'],bg.inputs['Color']);world.node_tree.links.new(bg.outputs['Background'],out.inputs['Surface'])
    for pos,energy,color,size in [((-5,1,12),2000,(1,.89,.72),8),((7,-3,9),900,(.80,.88,1),7)]:
        bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=energy;l.data.color=color;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((0,0,0))-l.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(0,-1.4,22));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=24.5
    scene=bpy.context.scene;scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX'
    # Join only meshes with shared material to bound runtime draw calls.
    groups={}
    for obj in list(scene.objects):
        if obj.type=='MESH' and len(obj.data.materials)==1:groups.setdefault(obj.data.materials[0].name,[]).append(obj)
    for objects in groups.values():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        for o in objects:
            bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/f'{theme}_table.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{theme}_table.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False,export_yup=True)
    scene.render.filepath=str(EVIDENCE/f'blender-{theme}.png')
    # Runtime screenshots validate the final game lighting.
    return {'theme':theme,'objects':len([o for o in scene.objects if o.type=='MESH']),'triangles':sum(len(p.vertices)-2 for o in scene.objects if o.type=='MESH' for p in o.data.polygons),'source':f'art/arena3d/product-v5/{theme}_table.blend'}

for p in [OUT,ART,EVIDENCE]:p.mkdir(parents=True,exist_ok=True)
report=[make(t) for t in ['grove']]
(EVIDENCE/'asset-build.json').write_text(json.dumps(report,indent=2),encoding='utf8')
