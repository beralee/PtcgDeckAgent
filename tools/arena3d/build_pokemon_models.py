"""Author the three signature sculptures in Blender; no remote assets or runtime Python.

Run with Blender --background --python tools/arena3d/build_pokemon_models.py.
Meshes are deliberately stylized, with separate articulated parts and named pivots.
The original 2D signature art supplies silhouette/color/gesture direction only.
"""
from pathlib import Path
import math
import json
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/arena3d/pokemon'
OUT.mkdir(parents=True, exist_ok=True)

def material(name, color, metallic=0.0, roughness=.36, emission=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Metallic'].default_value = metallic * .5
    bs.inputs['Roughness'].default_value = max(.48, roughness)
    bs.inputs['Specular IOR Level'].default_value = .22
    bs.inputs['Emission Color'].default_value = (*color, 1)
    bs.inputs['Emission Strength'].default_value = emission
    return m

def joint(name, pos=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = pos
    bpy.context.view_layer.update()
    adopt(o, parent)
    return o

def adopt(o, parent):
    if parent:
        bpy.context.view_layer.update()
        world = o.matrix_world.copy()
        o.parent = parent
        o.matrix_world = world
    return o

def finish(o, name, mat, parent, smooth=True):
    o.name = name
    o.data.materials.append(mat)
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    return adopt(o, parent)

def ellipsoid(name, pos, size, mat, parent, rotation=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=pos)
    o = bpy.context.object
    o.scale = size
    if rotation: o.rotation_euler = rotation
    return finish(o, name, mat, parent)

def mesh(name, vertices, faces, mat, parent, smooth=True, bevel=0):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    finish(o, name, mat, parent, smooth)
    if bevel:
        mod = o.modifiers.new('Soft sculpted edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
        norm = o.modifiers.new('Corner normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=norm.name)
    return o

def hull(name, vertices, mat, parent):
    data=bpy.data.meshes.new(name)
    bm=bmesh.new()
    for point in vertices: bm.verts.new(point)
    bmesh.ops.convex_hull(bm,input=list(bm.verts))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    o=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(o)
    return finish(o,name,mat,parent,False)

def tube(name, pts, radii, mat, parent, steps=5, sides=12):
    # Catmull-Rom centerline, with a parallel-looking frame on each ring.
    points = [Vector(p) for p in pts]
    centers, rr = [], []
    for i in range(len(points)-1):
        p0,p1,p2,p3 = points[max(0,i-1)],points[i],points[i+1],points[min(i+2,len(points)-1)]
        for j in range(steps):
            t=j/steps
            centers.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
            rr.append(radii[i]*(1-t)+radii[i+1]*t)
    centers.append(points[-1]); rr.append(radii[-1])
    verts=[]
    for i,c in enumerate(centers):
        tangent=(centers[min(i+1,len(centers)-1)]-centers[max(i-1,0)]).normalized()
        ref=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))
        u=tangent.cross(ref).normalized(); v=tangent.cross(u).normalized()
        for k in range(sides):
            a=2*math.pi*k/sides
            verts.append(tuple(c+rr[i]*(math.cos(a)*u+math.sin(a)*v)))
    faces=[]
    for i in range(len(centers)-1):
        for k in range(sides):
            a=i*sides+k; b=i*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(range(sides-1,-1,-1)),tuple((len(centers)-1)*sides+k for k in range(sides))])
    return mesh(name,verts,faces,mat,parent)

def prism(name, polygon, depth, mat, parent, bevel=.03):
    # Polygon in XYZ; thickness along Y. Useful for fins, eyelids and wing armor.
    n=len(polygon)
    vs=[(x,y-depth/2,z) for x,y,z in polygon]+[(x,y+depth/2,z) for x,y,z in polygon]
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,mat,parent,False,bevel)

def crystal(name, base, tip, radius, mat, parent):
    b,t=Vector(base),Vector(tip); axis=(t-b).normalized()
    u=axis.cross(Vector((0,1,0))).normalized(); v=axis.cross(u)
    ring=[b+radius*(math.cos(i*math.pi/2)*u+math.sin(i*math.pi/2)*v) for i in range(4)]
    vs=[tuple(p) for p in ring]+[tuple(t),tuple(b-(t-b)*.14)]
    return mesh(name,vs,[(i,(i+1)%4,4) for i in range(4)]+[((i+1)%4,i,5) for i in range(4)],mat,parent,False)

def claw(pos, direction, mat, parent, size=.17):
    p=Vector(pos); d=Vector(direction)
    tube('Ivory claw',[p,p+d*.55,p+d],[size*.4,size*.32,.005],mat,parent,steps=3,sides=8)

def eyes(head, z, y, spacing, ivory, gold, dark, scale=1):
    for s in (-1,1):
        ellipsoid('Eye socket',(s*spacing,y,z),(.22*scale,.08,.13*scale),dark,head)
        ellipsoid('Golden iris',(s*spacing,y-.062,z),(.16*scale,.037,.075*scale),gold,head)
        ellipsoid('Vertical pupil',(s*spacing,y-.095,z),(.025*scale,.015,.059*scale),dark,head)
        ellipsoid('Eye glint',(s*spacing-.025,y-.11,z+.028),(.018,.01,.017),ivory,head)

def dragapult():
    root=joint('Dragapult')
    teal=material('Spectral teal',(.025,.31,.34),.28)
    dark=material('Midnight head',(.022,.065,.105),.35,.29)
    red=material('Coral fins',(.73,.065,.14),.25)
    light=material('Warm chest',(.83,.72,.34),.12)
    gold=material('Luminous eyes',(1,.58,.035),.15,.25,.45)
    cyan=material('Ghost tail edge',(.035,.74,.78),.25,.25,.2)
    ivory=material('Ivory',(.95,.98,.94))
    body=joint('Body',(0,0,1.75),root)
    ellipsoid('Tapered chest',(0,.03,1.75),(.58,.48,.86),teal,body)
    ellipsoid('Chest bib',(0,-.411,1.9),(.4,.075,.67),light,body)
    for z in [1.6,1.84,2.08]:
        prism('Chest chevron',[(-.30,-.499,z+.12),(0,-.53,z-.06),(.30,-.499,z+.12),(0,-.53,z+.02)],.012,red,body,.012)
    tail=joint('Tail',(0,.1,1.35),body)
    tube('Long spectral tail',[(0,.09,1.4),(.12,.23,.83),(.60,.30,.40),(1.3,.25,.46),(1.78,.16,.82),(1.8,.06,1.13)],[.47,.38,.24,.16,.09,.008],teal,tail,8,16)
    tube('Tail luminous crest',[(.38,.03,.47),(.92,.04,.37),(1.49,.02,.6),(1.8,.06,1.13)],[.035,.038,.027,.003],cyan,tail)
    head=joint('Head',(0,0,2.5),body)
    # A single beveled delta-shaped head, not a spherical approximation.
    vs=[(-2,.42,2.91),(-.94,-.28,3.08),(0,-.91,2.75),(.94,-.28,3.08),(2,.42,2.91),(0,.53,3.17),(-1.9,.42,2.69),(-.82,-.27,2.69),(0,-.91,2.59),(.82,-.27,2.69),(1.9,.42,2.69),(0,.5,2.79)]
    fs=[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5),(6,11,7),(7,11,8),(8,11,9),(9,11,10),(10,11,6)]
    fs += [(i,(i+1)%5,(i+1)%5+6,i+6) for i in range(5)]
    hull('Delta head',vs,dark,head)
    for s in [-1,1]:
        prism('Swept coral stabilizer',[(s*.85,.45,3.02),(s*2.5,.7,3.22),(s*1.93,.42,2.78)],.16,red,head,.025)
        prism('Recessed eye',[(s*.18,-.79,2.83),(s*.76,-.39,2.88),(s*.59,-.51,2.73)],.055,gold,head,.012)
        tube('Head edge piping',[(s*.06,-.915,2.61),(s*.84,-.29,2.7),(s*1.90,.42,2.7)],[.026,.028,.012],cyan,head,4,8)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.42,-.03,2.0),body)
        tube('Small forearm',[(s*.44,-.02,2.04),(s*.76,-.22,1.77),(s*.63,-.51,1.64)],[.16,.115,.1],teal,arm)
        for i in range(3): claw((s*(.55+i*.08),-.55,1.65),(s*.02,-.15,-.12),red,arm,.11)
        child=joint('Dreepy_L' if s<0 else 'Dreepy_R',(s*1.33,.34,3.15),head)
        ellipsoid('Dreepy body',(s*1.33,.30,3.29),(.16,.17,.29),teal,child)
        prism('Dreepy arrowhead',[(s*1.33-.4,.27,3.55),(s*1.33,.02,3.41),(s*1.33+.4,.27,3.55),(s*1.33,.37,3.73)],.19,red,child)
        for dx in [-.09,.09]: ellipsoid('Dreepy eye',(s*1.33+dx,.106,3.5),(.045,.028,.05),gold,child)
        tube('Dreepy tail',[(s*1.33,.36,3.13),(s*1.42,.5,2.98),(s*1.54,.48,3.04)],[.10,.06,.004],cyan,child)
    return root

def charizard():
    root=joint('Charizard')
    orange=material('Amber hide',(.75,.205,.036),.15,.34)
    gold=material('Warm belly',(.94,.65,.25),.14,.4)
    teal=material('Deep blue wing membranes',(.025,.17,.23),.3,.32)
    edge=material('Wing blue highlights',(.05,.34,.4),.18)
    dark=material('Mouth and pupils',(.028,.012,.02))
    ivory=material('Ivory claws',(.95,.88,.69),.1)
    eye=material('Arctic eyes',(.19,.83,.97),.1,.23,.3)
    amber=material('Faceted amber',(.95,.32,.045),.55,.18)
    ember=material('Molten crystal edges',(1,.68,.12),.4,.2,.45)
    flame=material('Tail fire',(1,.20,.013),.1,.3,1.5)
    core=material('Flame core',(1,.83,.22),.1,.3,2)
    body=joint('Body',(0,0,1.55),root)
    ellipsoid('Powerful torso',(0,0,1.5),(.69,.55,.96),orange,body)
    ellipsoid('Golden belly',(0,-.49,1.38),(.52,.10,.76),gold,body)
    for z in [.93,1.19,1.46,1.73]:
        tube('Belly groove',[(-.38,-.544,z),(0,-.606,z-.055),(.38,-.544,z)],[.014,.015,.014],orange,body,5,6)
    tube('Arched neck',[(0,.05,2.02),(0,.03,2.47),(0,-.14,2.82)],[.4,.31,.29],orange,body,8,16)
    tail=joint('Tail',(0,.3,.91),body)
    tube('Long dragon tail',[(0,.32,.91),(.55,.81,.56),(1.17,.95,.58),(1.6,.83,1.04),(1.78,.72,1.5)],[.29,.26,.19,.12,.075],orange,tail,7,16)
    tip=joint('Flame',(1.78,.72,1.58),tail)
    for i in range(7):
        angle=i*2.4; x=1.78+math.sin(angle)*.12; y=.72+math.cos(angle)*.10
        tube('Fire lick',[(x,y,1.48),(x+math.sin(i)*.15,y,1.78),(x+math.sin(i)*.13,y,2.10+(i%3)*.10)],[.11,.09,.001],flame if i%2 else core,tip,5,8)
    head=joint('Head',(0,-.14,2.68),body)
    ellipsoid('Dragon cranium',(0,-.15,2.94),(.36,.39,.4),orange,head)
    ellipsoid('Long muzzle',(0,-.51,2.81),(.34,.40,.22),orange,head)
    ellipsoid('Open mouth shadow',(0,-.65,2.64),(.265,.265,.09),dark,head)
    jaw=joint('Jaw',(0,-.2,2.69),head)
    ellipsoid('Lower jaw',(0,-.50,2.59),(.28,.33,.075),gold,jaw)
    for s in [-1,1]:
        tube('Swept horn',[(s*.24,.02,3.15),(s*.32,.18,3.45),(s*.37,.31,3.61)],[.13,.09,.004],orange,head)
        prism('Angled eye',[(s*.13,-.5,3.09),(s*.37,-.39,3.15),(s*.31,-.47,2.99)],.025,ivory,head,.012)
        ellipsoid('Blue iris',(s*.26,-.493,3.07),(.038,.023,.05),eye,head)
        ellipsoid('Pupil',(s*.26,-.514,3.07),(.013,.013,.04),dark,head)
        prism('Fierce brow',[(s*.08,-.53,3.13),(s*.40,-.36,3.22),(s*.37,-.40,3.14),(s*.13,-.52,3.09)],.065,orange,head,.016)
        ellipsoid('Nostril',(s*.16,-.86,2.88),(.04,.018,.025),dark,head)
        claw((s*.21,-.68,2.72),(0,0,-.18),ivory,head,.14)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.48,-.02,2.09),body)
        tube('Muscular arm',[(s*.49,0,2.06),(s*.85,-.19,1.80),(s*1.00,-.55,1.96)],[.21,.17,.13],orange,arm,6,14)
        ellipsoid('Palm',(s*1.0,-.57,1.95),(.18,.19,.12),orange,arm)
        for i in range(3): claw((s*(.9+.1*i),-.69,1.94),(s*.03,-.2,-.10),ivory,arm,.16)
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.44,.02,1.0),body)
        ellipsoid('Powerful thigh',(s*.52,.01,.82),(.35,.37,.47),orange,leg)
        tube('Shin',[(s*.59,.02,.77),(s*.61,-.16,.42)],[.24,.20],orange,leg)
        ellipsoid('Foot',(s*.63,-.31,.26),(.3,.39,.19),orange,leg)
        for i in range(3): claw((s*.63+(i-1)*.18,-.59,.28),(0,-.25,-.07),ivory,leg,.17)
        wing=joint('Wing_L' if s<0 else 'Wing_R',(s*.41,.25,2.13),body)
        a=(s*.40,.27,2.1); b=(s*1.10,.36,3.48); c=(s*2.6,.42,2.99)
        d=(s*2.43,.38,1.36); e=(s*1.72,.35,1.82); f=(s*.99,.29,1.45)
        # Scalloped, thickened membranes with explicit radial wing fingers.
        outline=[a,b,c,d,(s*2.10,.32,1.80),e,(s*1.34,.30,1.96),f]
        center=(s*1.42,.18,2.57)
        w=mesh('Sculpted bat wing',outline+[center],[(8,i,(i+1)%len(outline)) for i in range(len(outline))],teal,wing,True)
        mod=w.modifiers.new('Wing thickness','SOLIDIFY');mod.thickness=.045
        bpy.context.view_layer.objects.active=w;bpy.ops.object.modifier_apply(modifier=mod.name)
        tube('Wing leading edge',[a,b,c],[.15,.12,.025],orange,wing,5,12)
        for end in [d,e,f]: tube('Wing finger',[b,((b[0]+end[0])*.5,.21,(b[2]+end[2])*.5),end],[.065,.041,.008],orange,wing,5,8)
        tube('Wing lower edge',[c,d,outline[4],e,outline[6],f,a],[.022]*7,edge,wing,4,6)
        claw(b,(s*.07,-.02,.28),ivory,wing,.17)
        for i in range(4):
            base=(s*(.50+i*.10),-.01,2.10-i*.10)
            crystal('Shoulder crystal',base,(base[0]+s*.23,-.06,base[2]+.41-i*.035),.11,amber if i%2 else ember,body)
    for i in range(5):
        x=(i-2)*.14
        crystal('Crown crystal',(x,.035,3.20),(x*1.45,.16,3.70-abs(i-2)*.12),.11,amber if i%2 else ember,head)
    for z in [1.6,1.9,2.2]: crystal('Back crystal',(0,.48,z),(0,.79,z+.26),.16,amber,body)
    return root

def munkidori():
    root=joint('Munkidori')
    fur=material('Ink violet fur',(.032,.025,.068),.06,.53)
    fur_hi=material('Fur ridges',(.065,.055,.12),.12,.45)
    blue=material('Periwinkle skin',(.26,.34,.59),.08,.4)
    muzzle=material('Cool muzzle',(.42,.52,.70),.04,.43)
    pink=material('Toxic magenta',(.63,.035,.48),.35,.23,.15)
    glow=material('Psychic highlights',(.84,.14,.70),.2,.24,.4)
    gold=material('Sharp yellow eyes',(.98,.68,.07),.15,.25,.4)
    dark=material('Deep expression',(.007,.005,.014))
    ivory=material('Eye glints',(.8,.94,1))
    body=joint('Body',(0,0,1.23),root)
    ellipsoid('Slender torso',(0,.02,1.20),(.46,.30,.65),fur,body)
    ellipsoid('Chest marking',(0,-.285,1.41),(.3,.027,.23),blue,body)
    for s in [-1,1]:
        for z in [.98,1.23,1.50]:
            prism('Swept shoulder fur',[(s*.23,.02,z+.18),(s*.79,.07,z-.12),(s*.33,-.02,z-.09)],.17,fur_hi,body,.025)
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.29,0,.90),body)
        tube('Crouched thigh',[(s*.25,0,.88),(s*.84,-.05,.60),(s*.54,-.32,.3)],[.22,.21,.11],fur,leg,7,14)
        ellipsoid('Blue foot',(s*.55,-.39,.23),(.22,.24,.09),blue,leg)
        for i in range(3): tube('Toe',[(s*.55+(i-1)*.1,-.47,.24),(s*.55+(i-1)*.1,-.69,.19)],[.055,.025],blue,leg,3,8)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.35,0,1.63),body)
        if s<0: pts=[(-.36,0,1.63),(-.96,-.06,2.01),(-.69,-.24,2.68)]; palm=(-.63,-.28,2.76)
        else: pts=[(.36,0,1.6),(.86,-.18,1.21),(.61,-.48,.79)];palm=(.61,-.51,.74)
        tube('Long expressive arm',pts,[.15,.14,.10],fur,arm,7,14)
        ellipsoid('Blue palm',palm,(.145,.09,.15),blue,arm)
        for i in range(4):
            x=palm[0]+(i-1.5)*.077
            dz=.24 if s<0 else -.18
            tube('Articulated finger',[(x,palm[1],palm[2]),(x-.02,palm[1]-.03,palm[2]+dz),(x+.045,palm[1]-.075,palm[2]+dz+.04)],[.041,.035,.019],blue,arm,4,8)
    tail=joint('Tail',(0,.19,.88),body)
    tube('Long hooked tail',[(0,.19,.88),(.75,.48,.75),(1.33,.43,1.24),(1.47,.34,1.99),(1.19,.17,2.23),(.94,.02,2.04),(1.02,-.03,1.88)],[.12,.095,.08,.08,.09,.085,.045],fur,tail,8,12)
    ellipsoid('Tail tip',(1.02,-.03,1.88),(.10,.09,.15),pink,tail)
    head=joint('Head',(0,-.015,1.93),body)
    ellipsoid('Large simian head',(0,-.015,2.08),(.44,.33,.49),fur,head)
    ellipsoid('Blue face',(0,-.277,2.10),(.35,.095,.36),blue,head)
    ellipsoid('Protruding muzzle',(0,-.39,1.97),(.30,.19,.18),muzzle,head)
    ellipsoid('Nose',(0,-.546,2.048),(.09,.037,.056),blue,head)
    eyes(head,2.21,-.367,.17,ivory,gold,dark,.8)
    for s in [-1,1]:
        prism('Heavy angled brow',[(s*.03,-.435,2.31),(s*.33,-.30,2.38),(s*.31,-.384,2.25),(s*.05,-.449,2.25)],.04,fur,head,.017)
        ellipsoid('Ear',(s*.43,.005,2.13),(.14,.11,.19),blue,head)
        # Toxic-chain loops, modeled as actual tubes rather than a painted stripe.
        loop=[(s*.47+.075*math.cos(a),-.095,2.27+.19*math.sin(a)) for a in [i*math.tau/16 for i in range(17)]]
        tube('Side chain link',loop,[.035]*len(loop),pink,head,2,8)
    tube('Wry mouth',[(-.19,-.535,1.93),(0,-.571,1.89),(.20,-.531,1.94)],[.009,.01,.009],dark,head,5,6)
    for i in range(5):
        x=(i-2)*.165
        ellipsoid('Toxic chain bead',(x,-.29+abs(x)*.24,2.48),(.145,.09,.13),pink if i%2 else glow,head,rotation=(0,.3*(i-2),0))
    for i in range(4):
        tube('Swept head tuft',[(-.20+i*.12,.0,2.43),(-.10+i*.13,.08,2.66),(.01+i*.14,.10,2.74)],[.12,.095,.002],fur_hi,head,5,10)
    return root

if __name__ == '__main__':
    # The refined collection owns exports; this module retains reusable geometry helpers.
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    from build_pokemon_collection import build
    build()
