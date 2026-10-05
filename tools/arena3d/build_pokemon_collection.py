"""Original authored, articulated character collection, based on visual references.

Blender --background --python tools/arena3d/build_pokemon_collection.py -- [species...]
No extracted game meshes, external model dependencies, or player-runtime Python.
Organic surfaces are section-lofted or remeshed; armor, feathers and crystals have
explicit contours. All named pivots are preserved for deterministic Godot animation.
"""
from pathlib import Path
import sys, math, json, random
sys.path.insert(0, str(Path(__file__).parent))
import bpy
from mathutils import Vector
import build_pokemon_models as B
from build_pokemon_models import joint, adopt, mesh, hull, tube, prism, crystal, claw, ellipsoid
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/arena3d/pokemon'

def mat(name, color, metal=0, rough=.48, glow=0):
    m=B.material(name,color)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Metallic'].default_value=metal
    p.inputs['Roughness'].default_value=rough
    p.inputs['Specular IOR Level'].default_value=.32
    p.inputs['Emission Strength'].default_value=glow
    return m

def sub(o, level=1):
    m=o.modifiers.new('Sculpted continuity','SUBSURF');m.levels=level
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.modifier_apply(modifier=m.name)
    return o

def loft(name, sections, material, parent, sides=20, subdiv=1):
    # Rings of (x,y,z,half-width,half-depth). Unlike spheres this controls the silhouette.
    vertices=[]
    for x,y,z,rx,ry in sections:
        for j in range(sides):
            a=j*math.tau/sides
            vertices.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
    faces=[tuple(range(sides-1,-1,-1))]
    for i in range(len(sections)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple((len(sections)-1)*sides+j for j in range(sides)))
    o=mesh(name,vertices,faces,material,parent)
    return sub(o,subdiv) if subdiv else o

def leaf(name, start, end, width, material, parent, curve=.12, thick=.055):
    """Curved lenticular surface with a ridge; real silhouette from every angle."""
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    side=axis.cross(Vector((0,1,0))).normalized()
    if side.length<.1:side=Vector((1,0,0))
    front=side.cross(axis).normalized()
    vs=[];steps=9;sides=10
    for i in range(steps):
        t=i/(steps-1); w=max(.003,math.sin(math.pi*t)**.8)*width
        center=a.lerp(b,t)+front*math.sin(t*math.pi)*curve
        for j in range(sides):
            u=j*math.tau/sides
            vs.append(tuple(center+side*math.cos(u)*w+front*math.sin(u)*thick*math.sin(t*math.pi)))
    fs=[tuple(range(sides-1,-1,-1))]
    for i in range(steps-1):
        for j in range(sides):
            k=i*sides+j;n=i*sides+(j+1)%sides;fs.append((k,n,n+sides,k+sides))
    fs.append(tuple((steps-1)*sides+j for j in range(sides)))
    return sub(mesh(name,vs,fs,material,parent),1)

def line(name, pts, material, parent, radius=.012):
    return tube(name,pts,[radius]*len(pts),material,parent,4,6)

def ring(name, pos, radius, thickness, material, parent, tilt=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=40,minor_segments=8,location=pos,major_radius=radius,minor_radius=thickness,rotation=tilt)
    return B.finish(bpy.context.object,name,material,parent)

def crystal(name, base, tip, radius, material, parent):
    # Cut-gem shoulders and pavilion, rather than a four-sided cone.
    b,t=Vector(base),Vector(tip);axis=(t-b).normalized()
    u=axis.cross(Vector((0,1,0))).normalized()
    if u.length<.1:u=Vector((1,0,0))
    v=axis.cross(u);vertices=[]
    for offset,r in [(-.12,.10),(0,1),(.43,.78),(.78,.37),(1,.015)]:
        c=b+(t-b)*offset
        for k in range(6):vertices.append(tuple(c+(u*math.cos(k*math.tau/6)+v*math.sin(k*math.tau/6))*radius*r))
    faces=[tuple(range(5,-1,-1))]
    for row in range(4):
        for k in range(6):faces.append((row*6+k,row*6+(k+1)%6,(row+1)*6+(k+1)%6,(row+1)*6+k))
    return mesh(name,vertices,faces,material,parent,False)

def feather(name,start,end,width,red,white,green,parent):
    o=leaf(name,start,end,width,red,parent,.09,.035)
    o.data.materials.append(white);o.data.materials.append(green)
    a,b=Vector(start),Vector(end);axis=b-a
    for p in o.data.polygons:
        center=sum((o.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
        t=(center-a).dot(axis)/axis.length_squared
        p.material_index=2 if t>.88 else (1 if t>.68 else 0)
    return o

def eye(parent,pos,size,white,iris,dark,angry=False):
    x,y,z=pos;w,h=size
    ellipsoid('Eye rim',(x,y+.006,z),(w*1.12,.054,h*1.14),dark,parent)
    ellipsoid('Eye white',(x,y-.025,z),(w,.036,h),white,parent)
    ellipsoid('Iris',(x,y-.059,z),(w*.50,.019,h*.82),iris,parent)
    ellipsoid('Pupil',(x,y-.073,z),(w*.23,.012,h*.71),dark,parent)
    ellipsoid('Catchlight',(x-w*.20,y-.087,z+h*.28),(w*.17,.008,h*.18),white,parent)
    if angry:
        s=1 if x>0 else -1
        line('Expression brow',[(x-s*w,y-.07,z+h*.35),(x+s*w*.6,y-.045,z+h*.92)],dark,parent,.027)

def claws(parent,center,material,spread=.13,length=.20,count=3):
    x,y,z=center
    for i in range(count):claw((x+(i-(count-1)/2)*spread,y,z),(0,-length,-length*.25),material,parent,length*.72)

def sculpt_join(parent,material,voxel=.055):
    # Fuse touching organic volumes per articulated part; leave other materials intact.
    items=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent and o.data.materials and o.data.materials[0]==material]
    if len(items)<2:return
    bpy.ops.object.select_all(action='DESELECT')
    for o in items:o.select_set(True)
    bpy.context.view_layer.objects.active=items[0]
    bpy.ops.object.join();o=bpy.context.object
    o.name=parent.name+' continuous sculpt'
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    r=o.modifiers.new('Continuous organic surface','REMESH');r.mode='VOXEL';r.voxel_size=voxel
    bpy.ops.object.modifier_apply(modifier=r.name)
    r=o.modifiers.new('Surface relaxation','SMOOTH');r.factor=1.1;r.iterations=5
    bpy.ops.object.modifier_apply(modifier=r.name)
    r=o.modifiers.new('Desktop topology budget','DECIMATE');r.ratio=.55
    bpy.ops.object.modifier_apply(modifier=r.name)
    for p in o.data.polygons:p.use_smooth=True

def star(name, center, radius, material, parent, points=5):
    x,y,z=center;vs=[]
    for i in range(points*2):
        a=math.pi/2+i*math.pi/points;r=radius if i%2==0 else radius*.46
        vs.append((x+math.cos(a)*r,y,z+math.sin(a)*r))
    vs += [(x,y-radius*.28,z),(x,y+radius*.17,z)]
    n=points*2
    return mesh(name,vs,[(i,(i+1)%n,n) for i in range(n)]+[((i+1)%n,i,n+1) for i in range(n)],material,parent,False)

def ceruledge():
    root=joint('Ceruledge');body=joint('Body',(0,0,1.8),root)
    ink=mat('Armor recess',(.024,.026,.065),.25,.36)
    purple=mat('Indigo ceramic armor',(.30,.23,.49),.32,.29)
    light=mat('Lilac edge bevel',(.40,.32,.64),.28,.28)
    ghost=mat('Pale blue ghost flame',(.37,.56,1),.20,.27,.42)
    white=mat('Blade white core',(.76,.76,1),.2,.23,.28)
    pink=mat('Violet flame tip',(.62,.16,.60),.25,.25,.22)
    loft('Slim armored torso',[(0,0,1.38,.22,.18),(0,0,1.58,.3,.23),(0,0,1.95,.40,.24),(0,0,2.19,.52,.25),(0,0,2.31,.25,.16)],ink,body)
    for s in (-1,1):
        prism('Pectoral armor',[(s*.05,-.24,2.28),(s*.47,-.20,2.20),(s*.34,-.31,2.04),(s*.06,-.32,2.07)],.11,purple,body,.035)
        prism('Waist segmented plate',[(s*.04,-.27,1.94),(s*.30,-.25,1.88),(s*.49,-.18,1.34),(s*.20,-.32,1.54)],.10,purple,body,.025)
        line('Waist armor light rim',[(s*.08,-.34,1.89),(s*.25,-.32,1.78),(s*.44,-.22,1.40)],light,body,.018)
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.23,0,1.49),body)
        tube('Dark leg articulation',[(s*.23,0,1.5),(s*.47,.06,.89),(s*.55,-.05,.34)],[.16,.145,.1],ink,leg)
        loft('Thigh armor',[(s*.26,0,1.52,.18,.22),(s*.47,-.03,1.32,.29,.24),(s*.49,-.03,1.03,.22,.22),(s*.49,0,.85,.08,.14)],purple,leg,8)
        prism('Knee crest',[(s*.31,-.20,1.12),(s*.56,-.27,1.26),(s*.57,-.22,.85)],.10,light,leg,.02)
        loft('Pointed greave',[(s*.55,-.18,.11,.1,.22),(s*.54,-.02,.23,.17,.18),(s*.55,0,.64,.11,.14),(s*.52,.02,.88,.16,.16)],purple,leg,8)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.47,0,2.13),body)
        tube('Shoulder elbow wrist',[(s*.46,0,2.14),(s*.70,-.05,1.84),(s*.95,-.12,1.64)],[.15,.16,.12],ink,arm)
        prism('Shoulder pauldron',[(s*.41,-.01,2.32),(s*.71,.01,2.27),(s*.88,-.01,2.06),(s*.63,-.14,1.99),(s*.45,-.15,2.12)],.29,purple,arm,.045)
        prism('Vambrace',[(s*.68,-.07,1.98),(s*.90,-.12,1.86),(s*1.13,-.17,1.56),(s*.77,-.22,1.64)],.22,purple,arm,.02)
        blade=joint('Blade_L' if s<0 else 'Blade_R',(s*.91,-.15,1.65),arm)
        poly=[(s*.84,-.17,1.72),(s*1.06,-.17,1.76),(s*1.24,-.17,1.31),(s*1.69,-.17,.56),(s*1.15,-.17,.88),(s*.99,-.17,1.31)]
        prism('Flame blade silhouette',poly,.085,ghost,blade,.024)
        prism('Flame blade luminous bevel',[(s*.99,-.22,1.67),(s*1.12,-.22,1.53),(s*1.60,-.22,.67),(s*1.23,-.22,1.02)],.022,white,blade,.01)
        prism('Amethyst blade tip',[(s*1.26,-.225,1.08),(s*1.60,-.225,.67),(s*1.32,-.225,.83)],.022,pink,blade,.01)
        for k in range(3):tube('Blade licking fire',[(s*(.99+k*.075),-.10,1.74-k*.10),(s*(1.18+k*.075),-.10,1.86-k*.13),(s*(1.08+k*.08),-.10,2.02-k*.13)],[.07,.05,.002],ghost,blade,5,8)
    head=joint('Head',(0,0,2.36),body)
    loft('Helmet silhouette',[(0,0,2.31,.15,.14),(0,-.02,2.47,.28,.23),(0,.01,2.74,.36,.28),(0,.05,2.96,.22,.20),(0,.06,3.02,.04,.08)],purple,head,10)
    prism('Black face opening',[(-.18,-.265,2.82),(.18,-.265,2.82),(.14,-.29,2.51),(0,-.30,2.40),(-.14,-.29,2.51)],.028,ink,head,.02)
    prism('Gothic central visor',[(-.055,-.25,2.97),(0,-.33,2.89),(.055,-.25,2.97),(.10,-.315,2.64),(0,-.35,2.45),(-.10,-.315,2.64)],.035,purple,head,.013)
    prism('Visor forehead diamond',[(0,-.325,2.88),(.043,-.33,2.80),(0,-.35,2.71),(-.043,-.33,2.80)],.012,light,head,.005)
    for s in (-1,1):
        ellipsoid('Pale spirit eye',(s*.162,-.312,2.66),(.069,.026,.086),white,head)
        ellipsoid('Violet spirit iris',(s*.153,-.337,2.66),(.028,.012,.070),pink,head)
        tube('White flame eyebrow',[(s*.12,-.334,2.70),(s*.105,-.323,2.76),(s*.14,-.30,2.82),(s*.127,-.28,2.86)],[.025,.019,.023,.001],white,head,4,6)
        prism('Helmet swept horns',[(s*.24,.02,2.57),(s*.67,.17,2.83),(s*.33,-.05,2.74)],.09,white,head,.012)
        line('Helmet seam',[(s*.07,-.245,2.96),(s*.20,-.28,2.80),(s*.23,-.29,2.71)],light,head,.02)
    flame=joint('Flame',(0,.05,2.99),head)
    for i in range(4):
        x=(i-1.5)*.1
        tube('Head spirit flame',[(x,.08,2.96),(x-.12,.12,3.19),(x+.14,.12,3.36),(x+.04,.12,3.64-i*.10)],[.17,.14,.08,.001],ghost if i%2 else white,flame,7,12)
    return root

def garchomp():
    root=joint('Garchomp');body=joint('Body',(0,0,1.6),root)
    blue=mat('Shark blue hide',(.29,.34,.49),.06,.46);edge=mat('Dorsal blue',(.30,.38,.56),.10,.42)
    red=mat('Chest vermilion',(.76,.18,.10));gold=mat('Crest gold',(.96,.65,.07));white=mat('Ivory teeth',(.96,.94,.79))
    ink=mat('Mouth',(.018,.023,.035));iris=mat('Predator yellow',(.94,.70,.14),0,.35)
    loft('Athletic shark torso',[(0,.13,1.02,.30,.30),(0,.08,1.30,.52,.36),(0,.04,1.64,.33,.28),(0,.06,1.98,.53,.37),(0,.12,2.22,.43,.32),(0,.10,2.43,.24,.26)],blue,body,24,2)
    loft('Red throat and breast',[(0,-.292,1.58,.20,.024),(0,-.33,1.78,.31,.05),(0,-.345,2.05,.37,.06),(0,-.22,2.38,.18,.12),(0,-.26,2.65,.19,.10)],red,body,18)
    prism('Gold abdomen shield',[(-.25,-.343,1.6),(.25,-.343,1.6),(.23,-.37,1.34),(0,-.40,1.18),(-.23,-.37,1.34)],.032,gold,body,.035)
    tail=joint('Tail',(0,.25,1.14),body)
    tube('Muscular curved tail',[(0,.24,1.15),(.35,.68,.94),(.85,1.13,.83),(1.32,1.33,1.0),(1.60,1.40,1.26)],[.28,.25,.19,.12,.025],blue,tail,9,20)
    prism('Shark tail fin',[(1.24,1.35,.92),(1.60,1.41,1.27),(1.79,1.42,1.65),(1.79,1.42,.79)],.10,edge,tail,.025)
    prism('Great dorsal fin',[(0,.29,2.22),(0,1.14,2.17),(0,.47,1.55)],.16,edge,body,.03)
    for s in (-1,1):
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.38,.02,1.23),body)
        tube('Crouched powerful leg',[(s*.36,.03,1.3),(s*.72,-.14,.90),(s*.81,.03,.56),(s*.82,-.08,.22)],[.29,.32,.20,.16],blue,leg,8,18)
        ellipsoid('Wide foot',(s*.82,-.23,.20),(.24,.33,.15),blue,leg)
        claws(leg,(s*.82,-.49,.19),white,.16,.25)
        for k in range(2): crystal('Thigh spike',(s*.55,-.32,1.01+k*.17),(s*.60,-.54,1.14+k*.17),.10,white,leg)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.46,.04,2.04),body)
        tube('Swept forearm',[(s*.46,.04,2.07),(s*.82,-.07,1.86),(s*1.30,-.20,1.95)],[.22,.19,.14],blue,arm,8,16)
        prism('Scythe arm fin',[(s*.80,-.015,1.94),(s*1.32,-.17,1.97),(s*1.13,.12,.90),(s*.75,.10,1.62)],.11,edge,arm,.025)
        claw((s*1.32,-.20,1.96),(s*.29,-.10,-.42),white,arm,.30)
        for k in range(2):crystal('Elbow ivory spur',(s*(.70+k*.16),-.10,1.98),(s*(.72+k*.16),-.11,2.19),.08,white,arm)
        sculpt_join(leg,blue,.045)
    head=joint('Head',(0,.04,2.47),body)
    skull=hull('Sculpted shark skull',[(-.31,.27,2.54),(.31,.27,2.54),(-.34,-.12,2.75),(.34,-.12,2.75),(-.23,.20,2.99),(.23,.20,2.99),(0,-.41,2.96),(-.23,-.64,2.72),(.23,-.64,2.72),(0,-.79,2.60),(-.23,-.67,2.54),(.23,-.67,2.54)],blue,head)
    bevel=skull.modifiers.new('Soft shark planes','BEVEL');bevel.width=.055;bevel.segments=3
    bpy.context.view_layer.objects.active=skull;bpy.ops.object.modifier_apply(modifier=bevel.name)
    normals=skull.modifiers.new('Sculpted shark normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=normals.name)
    for s in (-1,1):
        tube('Hammerhead sensory lobe',[(s*.26,.02,2.75),(s*.57,.03,2.79),(s*.75,.14,2.95)],[.18,.18,.055],blue,head,7,16)
        line('Hammerhead gill seam',[(s*.61,-.15,2.74),(s*.72,-.12,2.80),(s*.78,-.02,2.90)],ink,head,.009)
        prism('Angled eye white',[(s*.06,-.645,2.78),(s*.29,-.45,2.83),(s*.22,-.55,2.69)],.03,white,head,.02)
        ellipsoid('Yellow eye',(s*.18,-.603,2.75),(.045,.022,.047),iris,head)
        ellipsoid('Slit pupil',(s*.18,-.623,2.75),(.014,.012,.037),ink,head)
    prism('Gold forehead chevron',[(-.20,-.53,2.92),(0,-.59,2.86),(.20,-.53,2.92),(.10,-.63,2.74),(0,-.63,2.80),(-.10,-.63,2.74)],.035,gold,head,.015)
    prism('Open mouth interior',[(-.24,-.645,2.56),(.24,-.645,2.56),(.19,-.66,2.38),(0,-.68,2.34),(-.19,-.66,2.38)],.045,ink,head,.015)
    jaw=joint('Jaw',(0,-.10,2.46),head)
    ellipsoid('Lower mandible',(0,-.46,2.37),(.24,.24,.045),red,jaw)
    for s in (-1,1):
        for k in range(3):
            x=s*(.055+k*.076)
            prism('Upper triangular shark tooth',[(x-.026,-.704,2.555),(x+.026,-.704,2.555),(x,-.709,2.48)],.012,white,head,.002)
            prism('Lower triangular shark tooth',[(x-.020,-.704,2.385),(x+.020,-.704,2.385),(x,-.709,2.445)],.012,white,jaw,.002)
    return root

def budew():
    root=joint('Budew');body=joint('Body',(0,0,.8),root)
    green=mat('Living green',(.31,.59,.15),0,.55);light=mat('Bud pale green',(.64,.81,.29),0,.54)
    darkgreen=mat('Leaf collar',(.15,.37,.13),0,.6);yellow=mat('Soft lemon face',(.89,.85,.30),0,.57)
    ink=mat('Seed black eyes',(.019,.028,.016),0,.4);white=mat('Eye dew',(.98,1,.85))
    loft('Pear shaped seedling',[(0,0,.20,.29,.23),(0,0,.36,.53,.40),(0,0,.75,.63,.43),(0,0,1.16,.47,.35),(0,0,1.40,.23,.21)],green,body,28,2)
    head=joint('Head',(0,-.08,.96),body)
    ellipsoid('Heart shaped yellow face',(0,-.365,.94),(.42,.13,.40),yellow,head)
    for s in (-1,1):
        eye(head,(s*.22,-.494,.98),(.027,.078),ink,ink,ink)
        ellipsoid('Tiny eye glint',(s*.218,-.530,1.016),(.008,.005,.013),white,head)
        line('Happy mouth',[(s*.18,-.481,.81),(s*.09,-.511,.755),(0,-.515,.72)],ink,head,.009)
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.27,0,.23),body)
        leaf('Seed foot',(s*.21,0,.27),(s*.37,-.32,.09),.15,yellow,leg,.04,.08)
        for i in range(2):leaf('Leaf collar lobe',(s*.08,-.435,.69),(s*(.20+i*.20),-.405,.42+i*.11),.18,darkgreen,body,.07,.07)
        petal=joint('Petal_L' if s<0 else 'Petal_R',(s*.11,.015,1.28),body)
        tube('Crossed bud stem',[(s*.27,.025,.89),(s*.33,.02,1.30),(-s*.22,.025,1.79),(-s*.10,.03,2.06)],[.23,.20,.16,.13],green,petal,9,16)
        leaf('Unfolding bud cup',(-s*.20,.03,1.71),(s*.06,.03,2.22),.23,light,petal,.07,.18)
        line('Bud seam',[(-s*.28,-.14,1.91),(-s*.19,-.155,2.13),(s*.02,-.04,2.21)],darkgreen,petal,.008)
    return root

def pikachu_tera():
    root=joint('PikachuStellar');body=joint('Body',(0,0,1.03),root)
    yellow=mat('Crystalline golden coat',(.95,.65,.06),.25,.24)
    gold=mat('Amber shade',(.67,.32,.025),.32,.25);ink=mat('Obsidian ear tips',(.025,.02,.027),.18,.29)
    red=mat('Ruby electric cheeks',(.85,.055,.027),.24,.22,.13);white=mat('Pearl eye glints',(.98,.98,.9),.15,.18)
    palette=[mat('Stellar prism '+str(i),c,.38,.20,.08) for i,c in enumerate([(.80,.93,1),(.33,.87,.90),(.54,.46,.94),(.98,.57,.67),(.99,.84,.20),(.40,.92,.50)])]
    loft('Pikachu pear torso',[(0,0,.29,.27,.23),(0,.02,.49,.53,.38),(0,.01,.95,.48,.37),(0,0,1.35,.30,.26),(0,0,1.47,.22,.21)],yellow,body,24,1)
    for s in (-1,1):
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.32,0,.35),body)
        ellipsoid('Oval hind paw',(s*.38,-.17,.22),(.20,.34,.15),yellow,leg)
        for i in range(2):line('Toe crease',[(s*.38+(i-.5)*.09,-.44,.25),(s*.38+(i-.5)*.09,-.38,.31)],gold,leg,.007)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.34,-.03,1.24),body)
        tube('Small forepaw',[(s*.32,-.02,1.25),(s*.53,-.18,1.10),(s*.44,-.40,1.12)],[.16,.14,.10],yellow,arm,7,16)
        for i in range(3):leaf('Little finger',(s*.44+(i-1)*.05,-.38,1.12),(s*.43+(i-1)*.06,-.50,1.13),.025,yellow,arm,.01,.035)
    tail=joint('Tail',(.17,.28,.70),body)
    prism('Lightning tail brown root',[(.15,.28,.66),(.42,.31,.73),(.40,.33,1.02),(.68,.34,.94),(.62,.34,.63),(.29,.31,.58)],.12,gold,tail,.02)
    prism('Lightning tail gold',[(.38,.34,.95),(.55,.38,1.16),(.99,.4,1.08),(.89,.43,1.43),(1.41,.46,1.70),(1.61,.46,1.17),(1.12,.43,.99),(1.16,.42,.74),(.63,.38,.91)],.12,yellow,tail,.02)
    head=joint('Head',(0,-.02,1.47),body)
    loft('Continuous cheek silhouette',[(0,-.04,1.25,.24,.21),(0,-.04,1.38,.46,.33),(0,-.02,1.60,.59,.41),(0,0,1.90,.50,.37),(0,.02,2.08,.28,.25),(0,.02,2.12,.08,.08)],yellow,head,28,2)
    for s in (-1,1):
        eye(head,(s*.245,-.369,1.76),(.105,.139),ink,ink,ink)
        ellipsoid('White eye glint',(s*.228,-.421,1.811),(.036,.015,.042),white,head)
        ellipsoid('Electric cheek ruby',(s*.45,-.282,1.53),(.13,.077,.125),red,head)
        ear=joint('Ear_L' if s<0 else 'Ear_R',(s*.32,.04,1.98),head)
        tip=(s*.77,.02,2.98 if s<0 else 2.84)
        leaf('Long expressive ear',(s*.27,.03,1.92),tip,.155,yellow,ear,.04,.10)
        start=Vector((s*.27,.03,1.92)).lerp(Vector(tip),.72)
        leaf('Black ear tip',start,tip,.104,ink,ear,.04,.076)
    ellipsoid('Button nose',(0,-.419,1.60),(.049,.023,.027),ink,head)
    line('Pikachu smile',[(-.16,-.385,1.46),(-.07,-.414,1.41),(0,-.421,1.44),(.07,-.414,1.41),(.16,-.385,1.46)],ink,head,.012)
    crown=joint('Crown',(0,.03,2.14),head)
    ring('Stellar crown silver rim',(0,.03,2.30),.46,.032,palette[0],crown)
    for i in range(12):
        a=i*math.tau/12;x=math.cos(a)*.47;y=.03+math.sin(a)*.40
        crystal('Crown rainbow diamond',(x,y,2.30),(x,y,2.62),.11,palette[i%6],crown)
    star('Central stellar jewel',(0,.03,2.96),.44,palette[0],crown,6)
    for s in (-1,1):star('Orbiting crown star',(s*.66,.05,2.71),.26,palette[4 if s<0 else 3],crown)
    crystal('Crown tall prism',(0,.035,2.53),(0,.035,3.42),.22,palette[1],crown)
    # Sparse prismatic facets preserve the yellow identity instead of a white glare blob.
    rng=random.Random(25)
    for target in [body,head]:
        for o in [q for q in target.children if q.type=='MESH' and q.data.materials[0]==yellow]:
            reduce=o.modifiers.new('Broad crystalline facets','DECIMATE');reduce.ratio=.36
            bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=reduce.name)
            triangulate=o.modifiers.new('Triangular crystal cuts','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=triangulate.name)
            for m in palette:o.data.materials.append(m)
            for p in o.data.polygons:
                if rng.random()<.08:p.material_index=1+rng.randrange(len(palette))
                p.use_smooth=False
    return root

def archaludon():
    root=joint('Archaludon');body=joint('Body',(0,.08,1.35),root)
    steel=mat('Brushed silver ceramic',(.64,.70,.80),.50,.30)
    pale=mat('Armor bevel silver',(.87,.90,.94),.45,.27)
    navy=mat('Bridge navy structure',(.035,.08,.20),.4,.29)
    coral=mat('Copper conductive rails',(.72,.29,.25),.45,.26)
    gold=mat('Gold terminals',(.92,.70,.30),.55,.24)
    black=mat('Recess seams',(.025,.035,.065),.3,.35)
    loft('Angular bridge breast',[(0,.12,.67,.38,.30),(0,.12,.91,.55,.39),(0,.15,1.47,.55,.45),(0,.26,2.04,.40,.42),(0,.42,2.71,.27,.31),(0,.45,3.14,.19,.21)],steel,body,4,0)
    # A real X truss down the frontal arch, separated from armor with narrow recesses.
    for s in (-1,1):
        tube('Navy side girder',[(s*.34,-.20,.74),(s*.47,-.24,1.25),(s*.36,-.18,2.04),(s*.19,.11,3.13)],[.09,.10,.09,.065],navy,body,3,4)
        tube('Copper lower rail',[(s*.13,-.25,.76),(s*.25,-.31,1.15),(s*.24,-.29,1.66)],[.035,.035,.035],coral,body,4,4)
        for z,w,y in [(1.85,.32,-.18),(2.19,.28,-.09),(2.50,.24,.025)]:
            prism('Cross brace',[(s*w,y,z+.25),(-s*w*.76,y-.05,z),( -s*w*.69,y-.065,z-.02),(s*w*.88,y-.035,z+.16)],.07,navy,body,.012)
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.43,.18,.82),body)
        loft('Front armor pylon',[(s*.55,-.06,.08,.22,.29),(s*.55,.05,.27,.21,.27),(s*.50,.16,.86,.20,.23)],pale,leg,4,0)
        prism('Foot dark notch',[(s*.52,-.35,.07),(s*.61,-.35,.07),(s*.57,-.35,.24)],.03,navy,leg,.01)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.43,.20,1.79),body)
        tube('Shoulder bridge beam',[(s*.39,.18,1.91),(s*.86,.05,1.92)],[.20,.22],steel,arm,2,4)
        loft('Long rising tower forearm',[(s*.85,-.15,1.17,.27,.31),(s*.88,-.12,1.40,.28,.29),(s*.96,.02,2.29,.16,.18),(s*1.06,.16,3.22,.03,.06)],pale,arm,4,0)
        crystal('Gold tower terminal',(s*1.035,.14,3.06),(s*1.07,.165,3.34),.07,gold,arm)
        prism('Forearm dark underside',[(s*.60,-.46,1.21),(s*1.11,-.44,1.26),(s*1.05,-.45,1.05),(s*.67,-.46,1.04)],.10,navy,arm,.015)
        line('Armor panel seam',[(s*.82,-.37,1.43),(s*.90,-.16,2.10),(s*.99,.08,2.86)],black,arm,.008)
    tail=joint('Tail',(0,.37,.73),body)
    loft('Back bridge arch',[(0,.74,.53,.38,.30),(0,.86,.83,.39,.38),(0,.97,1.20,.26,.38),(0,1.08,1.84,.08,.12)],steel,tail,4,0)
    for s in (-1,1):
        prism('Rear buttress',[(s*.20,.60,.78),(s*.76,1.08,.14),(s*.62,1.37,.10),(s*.23,.90,1.06)],.25,pale,tail,.025)
        line('Rear armor seam',[(s*.09,.96,1.26),(s*.28,1.30,.86)],navy,tail,.017)
    head=joint('Head',(0,.35,2.85),body)
    hull('Bridge dragon head',[(-.23,.15,2.81),(.23,.15,2.81),(-.18,.47,3.20),(.18,.47,3.20),(0,-.09,2.95),(0,.43,3.25)],navy,head)
    for s in (-1,1):
        prism('Yellow recessed eye',[(s*.04,-.011,2.98),(s*.19,.125,3.09),(s*.17,.12,2.98)],.025,gold,head,.006)
        tube('Tall head antenna',[(s*.14,.40,3.10),(s*.22,.46,3.72)],[.045,.012],navy,head,2,4)
        tube('Copper antenna tip',[(s*.205,.45,3.58),(s*.24,.47,3.84)],[.035,.006],coral,head,2,4)
    return root

def grimmsnarl():
    root=joint('Grimmsnarl');body=joint('Body',(0,0,1.35),root)
    fur=mat('Deep violet hair',(.24,.17,.34),.03,.55);ridge=mat('Hair ridge violet',(.31,.24,.42),.02,.48)
    green=mat('Goblin green skin',(.28,.62,.32),0,.55);pink=mat('Inner ear',(.70,.14,.27));ivory=mat('Fangs',(.92,.94,.76));ink=mat('Mouth',(.023,.014,.038));red=mat('Angry iris',(.80,.055,.08))
    loft('Hair covered massive torso',[(0,.03,.99,.31,.30),(0,.03,1.28,.40,.33),(0,.04,1.59,.38,.33),(0,.07,1.95,.62,.41),(0,.08,2.17,.78,.36),(0,.08,2.32,.40,.23)],fur,body,28,2)
    leaf('Bare green abdomen',(0,-.36,1.03),(0,-.36,1.85),.15,green,body,.045,.05)
    for s in (-1,1):
        for k in range(5):
            tube('Pectoral woven hair',[(s*.05,-.37,2.12-k*.036),(s*.31,-.43,2.04-k*.043),(s*.60,-.26,2.17-k*.037)],[.055,.064,.022],ridge if k%2 else fur,body,7,10)
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.30,.04,1.09),body)
        tube('Wide crouched leg',[(s*.28,.03,1.14),(s*.68,.08,.70),(s*.66,-.08,.29)],[.31,.32,.19],fur,leg,8,20)
        ellipsoid('Green foot',(s*.67,-.24,.18),(.27,.36,.15),green,leg)
        claws(leg,(s*.67,-.52,.18),green,.16,.20)
        for k in range(4):leaf('Thigh pointed hair',(s*(.33+k*.1),-.16,1.02),(s*(.65+k*.07),-.15,.43+k*.02),.12,ridge if k%2 else fur,leg,.09,.07)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.58,.01,2.08),body)
        tube('Hair bound muscular arm',[(s*.58,0,2.08),(s*.99,-.09,1.90),(s*1.29,-.28,1.68),(s*1.46,-.39,1.86)],[.29,.33,.25,.21],fur,arm,9,20)
        ellipsoid('Huge palm',(s*1.48,-.40,1.81),(.33,.20,.26),fur,arm)
        for k in range(4):
            x=s*(1.25+k*.15)
            tube('Curling knuckle fingers',[(x,-.47,1.80),(x+s*.09,-.69,1.72),(x+s*.03,-.75,1.55)],[.085,.077,.036],fur,arm,5,12)
        tube('Hooked thumb',[(s*1.22,-.42,1.89),(s*1.13,-.65,1.99),(s*1.15,-.76,1.83)],[.11,.09,.035],fur,arm,5,12)
        leaf('Green hand marking',(s*1.39,-.593,1.85),(s*1.51,-.593,1.92),.045,green,arm,.01,.015)
        hair=joint('Hair_L' if s<0 else 'Hair_R',(s*.60,.04,2.11),arm)
        for k in range(4):
            leaf('Shoulder flowing hair',(s*(.49+k*.1),.07,2.05),(s*(.80+k*.23),.18,2.45+k*.06),.17,ridge if k%2 else fur,hair,.17,.10)
        for k in range(5):line('Arm hair striation',[(s*(.75+k*.045),-.22,2.09),(s*(1.03+k*.047),-.28,1.87),(s*(1.32+k*.04),-.46,1.93)],ridge,arm,.011)
        sculpt_join(arm,fur,.045)
    head=joint('Head',(0,.00,2.29),body)
    loft('Long goblin face',[(0,-.02,2.22,.11,.10),(0,-.07,2.39,.23,.19),(0,-.02,2.65,.28,.24),(0,.03,2.88,.22,.19),(0,.04,2.94,.10,.10)],green,head,20,2)
    for s in (-1,1):
        leaf('Tall goblin ear',(s*.18,.01,2.70),(s*.50,.02,3.32),.16,green,head,.02,.08)
        leaf('Inner ear red',(s*.23,-.062,2.78),(s*.45,-.04,3.22),.08,pink,head,.012,.012)
        eye(head,(s*.13,-.237,2.68),(.085,.06),ivory,red,ink,True)
        leaf('Long face hair',(s*.24,-.13,2.87),(s*.36,-.34,2.12),.16,fur,head,.1,.12)
        claw((s*.14,-.28,2.48),(0,-.03,-.17),ivory,head,.14)
    ellipsoid('Snarling open mouth',(0,-.221,2.42),(.13,.055,.13),ink,head)
    leaf('Forehead hair crest',(0,.025,2.97),(0,-.275,2.61),.22,fur,head,.08,.13)
    return root

def zoroark():
    root=joint('Zoroark');body=joint('Body',(0,0,1.38),root)
    fur=mat('Charcoal grey fur',(.12,.11,.17),0,.62);black=mat('Mane black tips',(.045,.036,.07),0,.57)
    red=mat('Crimson mane',(.52,.055,.14),0,.55);ridged=mat('Mane lit ridges',(.70,.13,.23),0,.54)
    teal=mat('Turquoise tie and eyes',(.07,.62,.58),.15,.3);white=mat('Eye white',(.96,.97,.86));ink=mat('Face ink',(.014,.01,.022));clawred=mat('Crimson claws',(.74,.12,.16),.02,.4)
    loft('Lean fox body',[(0,.17,.96,.25,.28),(0,.14,1.15,.40,.32),(0,.04,1.48,.25,.27),(0,-.04,1.84,.42,.35),(0,-.08,2.08,.33,.29)],fur,body,24,2)
    for s in (-1,1):
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.26,.13,1.12),body)
        tube('Digitigrade leg',[(s*.28,.14,1.12),(s*.63,-.04,.77),(s*.53,.23,.42),(s*.59,-.10,.18)],[.26,.29,.12,.14],fur,leg,8,16)
        ellipsoid('Fox paw',(s*.61,-.23,.14),(.25,.27,.13),fur,leg)
        claws(leg,(s*.61,-.45,.17),clawred,.16,.24)
        arm=joint('Arm_L' if s<0 else 'Arm_R',(s*.32,-.04,1.93),body)
        tube('Long fox forearm',[(s*.34,-.04,1.93),(s*.68,-.08,1.60),(s*.91,-.48,1.62)],[.17,.145,.13],fur,arm,8,16)
        ellipsoid('Claw hand',(s*.94,-.51,1.60),(.18,.23,.12),fur,arm)
        claws(arm,(s*.95,-.71,1.62),clawred,.13,.26)
        for k in range(3):leaf('Forearm long fur',(s*(.56+k*.055),-.04,1.69),(s*(.70+k*.13),.06,2.02+k*.11),.11,black,arm,.08,.07)
        for k in range(3):leaf('Ankle fur',(s*.50,.02,.48),(s*(.58+k*.1),.04,.65+k*.08),.10,fur,leg,.07,.06)
        sculpt_join(leg,fur,.043)
    head=joint('Head',(0,-.08,2.08),body)
    ellipsoid('Fox cranium',(0,-.06,2.32),(.30,.32,.32),fur,head)
    hull('Pointed fox muzzle',[(-.23,-.16,2.40),(.23,-.16,2.40),(-.16,-.54,2.20),(.16,-.54,2.20),(0,-.88,2.15),(0,-.68,2.32),(0,-.20,2.52)],fur,head)
    for s in (-1,1):
        leaf('Pointed black ear',(s*.20,.02,2.42),(s*.37,.15,2.98),.17,black,head,.03,.08)
        leaf('Red inner ear',(s*.21,-.04,2.54),(s*.34,.09,2.88),.09,red,head,.018,.02)
        prism('Narrow white eye',[(s*.05,-.51,2.42),(s*.24,-.265,2.52),(s*.17,-.34,2.35)],.028,white,head,.015)
        ellipsoid('Blue fox iris',(s*.147,-.42,2.43),(.031,.014,.049),teal,head)
        line('Red brow marking',[(s*.05,-.52,2.46),(s*.22,-.28,2.56)],clawred,head,.023)
        line('Fox smile',[(s*.04,-.77,2.17),(s*.22,-.35,2.22)],ink,head,.009)
    ellipsoid('Black nose',(0,-.84,2.20),(.05,.04,.033),ink,head)
    mane=joint('Mane',(0,.14,2.38),body)
    # Overlapping curved locks define the huge ponytail, not a smooth red sphere.
    for i in range(18):
        a=i*math.tau/18
        start=(math.sin(a)*.17,.17,2.50+math.cos(a)*.08)
        end=(math.sin(a)*(.73 if i%2 else .85),.83+math.cos(a)*.16,2.29+math.cos(a)*.64)
        mid=Vector(start).lerp(Vector(end),.42);mid.z+=.33
        tube('Flowing mane lock',[start,mid,end],[.19,.26,.008],red if i%3 else ridged,mane,8,12)
        leaf('Black mane tip',Vector(start).lerp(Vector(end),.71),end,.10,black,mane,.02,.06)
    tail=joint('ManeTip',(.13,.82,2.03),mane)
    tube('Ponytail flowing root',[(.1,.72,2.03),(.45,1.03,1.72),(.86,1.07,1.52),(1.08,1.02,1.83)],[.28,.27,.22,.008],red,tail,9,16)
    ring('Turquoise mane clasp',(.45,1.02,1.76),.23,.07,teal,tail,(0,.6,0))
    for i in range(5):leaf('Ponytail split end',(.68,1.0,1.63),(1.0+i*.07,1.08,1.48+i*.13),.13,red if i%2 else black,tail,.10,.08)
    return root

def ho_oh():
    root=joint('HoOh');body=joint('Body',(0,.06,1.65),root)
    red=mat('Scarlet plumage',(.87,.15,.045),0,.48);redlight=mat('Feather orange edge',(.98,.29,.08),0,.45)
    white=mat('Ivory underfeathers',(.84,.89,.75),0,.64);green=mat('Emerald flight feathers',(.22,.43,.12),.03,.51)
    gold=mat('Golden crest and tail',(.97,.59,.06),.12,.40);yellow=mat('Light feather tips',(.98,.90,.49),.06,.42)
    feet=mat('Slate talons',(.16,.18,.29),0,.52);ink=mat('Eye black',(.018,.024,.026));iris=mat('Ruby eyes',(.74,.09,.06))
    loft('Avian breast',[(0,.13,.82,.23,.27),(0,.05,1.08,.54,.44),(0,.02,1.50,.59,.43),(0,.02,1.88,.42,.36),(0,-.02,2.03,.27,.25)],red,body,26,2)
    loft('Ivory chest',[(0,-.27,.90,.26,.11),(0,-.34,1.14,.49,.12),(0,-.36,1.42,.50,.10),(0,-.32,1.63,.35,.10)],white,body,22,1)
    tube('Long graceful neck',[(0,-.02,1.87),(0,-.20,2.21),(0,-.35,2.61)],[.28,.23,.19],red,body,10,20)
    head=joint('Head',(0,-.34,2.51),body)
    ellipsoid('Ho Oh head',(0,-.33,2.72),(.23,.26,.24),red,head)
    hull('Long upper golden beak',[(-.12,-.47,2.80),(.12,-.47,2.80),(-.08,-.57,2.70),(.08,-.57,2.70),(0,-1.01,2.91),(0,-.71,2.93)],gold,head)
    jaw=joint('Jaw',(0,-.43,2.70),head)
    tube('Curving lower beak',[(0,-.44,2.69),(0,-.73,2.56),(0,-.94,2.73)],[.10,.073,.008],gold,jaw,7,12)
    for s in (-1,1):eye(head,(s*.135,-.51,2.80),(.083,.074),white,iris,ink,True)
    for k in range(5):
        x=(k-2)*.105
        leaf('Crest fan feather',(x*.4,-.28,2.88),(x,-.12,3.24+(.11 if k==2 else 0)),.09,gold,head,.08,.045)
    ring('Emerald collar',(0,-.26,2.37),.21,.025,green,body)
    for s in (-1,1):
        leg=joint('Leg_L' if s<0 else 'Leg_R',(s*.24,.04,1.0),body)
        tube('Bird lower leg',[(s*.24,.03,1.05),(s*.28,-.11,.64),(s*.30,-.16,.44)],[.17,.12,.095],feet,leg,7,12)
        for k in range(3):
            x=s*.30+(k-1)*.13
            tube('Gripping bird toe',[(s*.30,-.14,.46),(x,-.37,.39),(x,-.46,.21)],[.07,.06,.018],feet,leg,5,10)
            claw((x,-.46,.24),(0,-.07,-.12),ink,leg,.09)
        wing=joint('Wing_L' if s<0 else 'Wing_R',(s*.35,.08,1.83),body)
        tube('Wing skeletal contour',[(s*.34,.08,1.86),(s*1.10,.04,2.06),(s*1.91,.09,2.57)],[.17,.13,.045],red,wing,8,16)
        tip=joint('WingTip_L' if s<0 else 'WingTip_R',(s*1.34,.08,2.27),wing)
        for k in range(12):
            t=k/11
            start=(s*(.50+t*1.32),.08,1.94+t*.59)
            end=(s*(.70+t*2.1),.12,.96+t*2.42)
            par=wing if k<6 else tip
            feather('Banded primary flight feather',start,end,.18,redlight if k%3==0 else red,white,green,par)
            line('Feather rachis',[start,Vector(start).lerp(Vector(end),.65)],red,par,.011)
        for k in range(6):leaf('Shoulder covert',(s*(.43+k*.12),-.055,1.95+k*.06),(s*(.71+k*.13),-.02,1.56+k*.08),.12,redlight,wing,.045,.04)
    tail=joint('Tail',(0,.29,1.03),body)
    for k in range(9):
        t=(k-4)/4
        start=(t*.15,.25,1.09);end=(t*1.0,1.13,.18+abs(t)*.29)
        feather('Golden fan tail feather',start,end,.20,gold,gold,yellow,tail)
        line('Tail feather shaft',[start,Vector(start).lerp(Vector(end),.95)],redlight,tail,.007)
    return root

def raging_bolt():
    root=joint('RagingBolt');body=joint('Body',(0,.25,1.13),root)
    yellow=mat('Ancient golden hide',(.92,.65,.06),0,.50);black=mat('Jagged thunder stripes',(.055,.055,.07),0,.49)
    white=mat('Pale neck and claws',(.90,.91,.87),0,.57);red=mat('Vermilion accents',(.85,.14,.055),0,.48)
    cloud=mat('Storm lavender cloud',(.37,.29,.52),0,.67);rim=mat('Cloud lavender rim',(.49,.40,.63),0,.62)
    cyan=mat('Cyan lightning whiskers',(.17,.68,.77),.10,.36,.08);eye_mat=mat('Red eye',(.89,.1,.055))
    ellipsoid('Long quadruped body',(0,.33,1.14),(.48,.85,.43),yellow,body)
    for s in (-1,1):
        for front in (True,False):
            y=-.18 if front else .83
            leg=joint(('Leg_' if front else 'HindLeg_')+('L' if s<0 else 'R'),(s*.31,y,1.06),body)
            tube('Strong column leg',[(s*.31,y,1.12),(s*.49,y-.035,.74),(s*.48,y-.12,.22)],[.24,.23,.17],yellow,leg,9,18)
            ellipsoid('Ivory broad paw',(s*.49,y-.23,.16),(.23,.29,.14),white,leg)
            ring('Red ankle band',(s*.48,y-.10,.28),.18,.033,red,leg)
            for k in range(2):line('Paw toe split',[(s*.49+(k-.5)*.13,y-.48,.17),(s*.49+(k-.5)*.13,y-.37,.26)],black,leg,.008)
            for k in range(2):
                prism('Jagged leg stripe',[(s*.31,y-.255,.74+k*.17),(s*.62,y-.255,.65+k*.17),(s*.62,y-.255,.76+k*.17),(s*.48,y-.27,.72+k*.17),(s*.39,y-.265,.85+k*.17)],.026,black,leg,.006)
            leaf('Red ankle flare',(s*.48,y,.22),(s*.67,y,.54),.09,red,leg,.035,.055)
    neck=joint('Neck',(0,-.15,1.30),body)
    tube('Long rising thunder neck',[(0,-.17,1.25),(0,-.34,1.78),(0,-.24,2.46),(0,-.15,3.29)],[.34,.26,.205,.18],yellow,neck,11,22)
    tube('White throat ribbon',[(0,-.40,1.34),(0,-.58,1.77),(0,-.432,2.39),(0,-.325,3.24)],[.18,.16,.11,.08],white,neck,11,16)
    for s in (-1,1):
        line('Red throat border',[(s*.15,-.39,1.40),(s*.15,-.50,1.83),(s*.095,-.41,2.43),(s*.07,-.325,3.17)],red,neck,.028)
        for k in range(6):
            z=1.95+k*.19;y=-.555+(z-1.95)*.20
            prism('Lightning neck chevron',[(s*.075,y,z+.17),(s*.22,y+.025,z+.22),(s*.19,y,z+.035),(s*.09,y-.01,z-.02)],.025,black,neck,.004)
    head=joint('Head',(0,-.15,3.19),neck)
    ellipsoid('Feline thunder head',(0,-.25,3.42),(.26,.33,.23),black,head)
    for s in (-1,1):
        prism('Red thunder eye',[(s*.03,-.601,3.48),(s*.22,-.533,3.60),(s*.17,-.57,3.44)],.024,eye_mat,head,.006)
        line('White brow',[(s*.04,-.594,3.55),(s*.21,-.535,3.64)],white,head,.014)
        for k in range(3):leaf('White spiked crest',(s*.12,.01,3.49),(s*(.12+k*.11),.09,3.91-k*.10),.08,white,head,.04,.045)
        prism('Cyan zigzag whisker',[(s*.12,-.52,3.35),(s*.35,-.56,3.59),(s*.34,-.56,3.32),(s*.58,-.55,3.45),(s*.29,-.58,3.17)],.035,cyan,head,.012)
    clouds=joint('Cloud',(0,-.11,3.20),neck)
    for k in range(12):
        a=k*math.tau/12;x=math.cos(a)*.65;y=-.08+math.sin(a)*.50;z=3.22+.04*math.sin(a*3)
        ellipsoid('Sculpted storm cloud curl',(x,y,z),(.29,.25,.16),rim if k%3==0 else cloud,clouds)
        if k in (2,4,7,9):
            pts=[(x+.14*math.cos(t),y-.17,z+.095*math.sin(t)) for t in [j*math.pi*1.5/12 for j in range(13)]]
            line('Cloud whorl relief',pts,cloud,clouds,.012)
    # Merge cloud lobes so overlaps read as a single billowing collar.
    sculpt_join(clouds,cloud,.035)
    # Front crest curls frame the face, with a readable lower opening.
    for s in (-1,1):
        tube('Rolling front storm curl',[(s*.70,-.34,3.21),(s*.49,-.63,3.18),(s*.30,-.68,3.25),(s*.30,-.64,3.36)],[.15,.15,.10,.006],rim,clouds,7,14)
    tail=joint('Tail',(0,1.04,1.15),body)
    points=[(0,1.0,1.17),(.18,1.38,1.69),(.43,1.46,1.35),(.59,1.59,1.83),(.91,1.73,1.41)]
    tube('Angular lightning tail',points,[.04]*len(points),cyan,tail,1,6)
    star('Cyan tail thunder star',(.91,1.73,1.41),.23,cyan,tail,6)
    for k in range(3):
        y=.12+k*.3
        prism('Back thunder stripe',[(-.39,y,1.40),(-.20,y-.05,1.60),(0,y,1.56),(.20,y-.05,1.60),(.39,y,1.40),(.24,y+.065,1.53),(0,y+.08,1.47),(-.24,y+.065,1.53)],.018,black,body,.01)
    return root

def terapagos():
    root=joint('TerapagosStellar');body=joint('Body',(0,0,1.65),root)
    blue=mat('Terapagos indigo',(.045,.06,.24),.13,.37);cyan=mat('Terapagos teal light',(.12,.72,.76),.22,.27,.08)
    white=mat('Crystal pearl',(.78,.92,.96),.35,.21);pink=mat('Eye pink',(.94,.33,.57),.08,.34);black=mat('Eye midnight',(.005,.016,.06))
    colors=[(.28,.79,.87),(.56,.41,.91),(.96,.37,.54),(.94,.73,.19),(.41,.81,.30),(.41,.57,.94)]
    gems=[mat('Prismatic shell '+str(i),c,.38,.22,.05) for i,c in enumerate(colors)]
    shell=joint('Shell',(0,.13,1.58),body)
    # The broad floating dome and outlined hexagonal energy tiles are the Stellar silhouette.
    loft('Stellar floating indigo dome',[(0,.18,.57,.68,.55),(0,.18,.69,1.16,.91),(0,.18,1.02,1.45,1.12),(0,.18,1.34,1.33,1.02),(0,.18,1.61,.94,.75),(0,.18,1.76,.35,.28)],blue,shell,24,0)
    dome_sections=[(.69,1.16),(1.02,1.45),(1.34,1.33),(1.61,.94)]
    def dome_radius(z):
        for (za,ra),(zb,rb) in zip(dome_sections,dome_sections[1:]):
            if za<=z<=zb:return ra+(rb-ra)*(z-za)/(zb-za)+.012
        return 1.17
    for row in range(3):
        z=.85+row*.24;r=dome_radius(z)
        for k in range(12):
            a=k*math.tau/12+(row%2)*math.pi/12
            cx=math.cos(a)*r;cy=.18+math.sin(a)*r*.79
            pts=[]
            for j in range(7):
                q=j*math.tau/6;angle=a+.135*math.cos(q);zz=z+.13*math.sin(q);rad=dome_radius(zz)
                pts.append((math.cos(angle)*rad,.18+math.sin(angle)*rad*.78,zz))
            tube('Dome hexagonal lattice',pts,[.010]*len(pts),cyan,shell,1,6)
    ring('Lower prismatic rim',(0,.18,.76),1.21,.025,cyan,shell)
    ellipsoid('Small turtle body',(0,-.07,1.94),(.59,.48,.23),blue,body)
    for s in (-1,1):
        for front in (True,False):
            y=-.30 if front else .34
            leg=joint(('Arm_' if front else 'Leg_')+('L' if s<0 else 'R'),(s*.39,y,1.97),body)
            leaf('Turtle swimming flipper',(s*.31,y,1.95),(s*.81,y-.19,1.58),.20,blue,leg,.1,.11)
            ring('Flipper luminous cuff',(s*.64,y-.14,1.67),.13,.04,cyan,leg)
        crystal('Dome floating foot',(s*.64,.03,.75),(s*.80,.02,.13),.25,gems[1],shell)
    head=joint('Head',(0,-.36,2.04),body)
    tube('Turtle neck',[(0,-.23,1.97),(0,-.56,2.17),(0,-.62,2.42)],[.18,.20,.22],blue,head,7,16)
    ellipsoid('Turtle round head',(0,-.63,2.48),(.29,.27,.31),blue,head)
    for s in (-1,1):
        eye(head,(s*.155,-.843,2.50),(.095,.15),white,pink,black)
        star('Forehead sparkle',(s*.20,-.768,2.74),.045,cyan,head,4)
    line('Small smile',[(-.09,-.857,2.29),(0,-.89,2.27),(.09,-.857,2.29)],pink,head,.015)
    # Turtle shell above the great dome: hexagonal facets with raised central jewel.
    for k in range(12):
        a=k*math.tau/12
        crystal('Crown shell gem',(math.cos(a)*.46,.18+math.sin(a)*.36,2.14),(math.cos(a)*.45,.18+math.sin(a)*.34,2.46),.21,gems[k%6],body)
    crown=joint('Crown',(0,.18,2.40),body)
    crystal('Central pearl prism',(0,.18,2.26),(0,.18,2.91),.31,white,crown)
    # Miniature crystalline turtle crest, as on the Stellar crown.
    ellipsoid('Crown little turtle shell',(0,.18,3.04),(.24,.19,.13),white,crown)
    ellipsoid('Crown little turtle head',(0,-.025,3.14),(.09,.10,.10),cyan,crown)
    star('Stellar crest',(0,.18,3.39),.20,blue,crown,6)
    orbit=joint('Orbit',(0,.15,1.65),body)
    for k in range(18):
        a=k*math.tau/18
        crystal('Orbit type crystal',(math.cos(a)*1.70,.15+math.sin(a)*1.30,1.62),(math.cos(a)*1.70,.15+math.sin(a)*1.30,1.93),.15,gems[k%6],orbit)
    return root

def refine_original(name):
    root=getattr(B,name)()
    # Fused surface continuity eliminates the spherical overlaps of the first pass.
    for part_name,material_name in {'charizard':[('Body','Amber hide'),('Head','Amber hide'),('Leg_L','Amber hide'),('Leg_R','Amber hide')],
                                   'dragapult':[('Body','Spectral teal')],
                                   'munkidori':[('Head','Ink violet fur'),('Leg_L','Ink violet fur'),('Leg_R','Ink violet fur')]}[name]:
        sculpt_join(bpy.data.objects.get(part_name),bpy.data.materials.get(material_name),.033 if part_name=='Head' else .045)
    for m in bpy.data.materials:
        if m.node_tree:
            p=m.node_tree.nodes.get('Principled BSDF')
            if p:p.inputs['Specular IOR Level'].default_value=.31
    head=bpy.data.objects.get('Head');body=bpy.data.objects.get('Body')
    if name=='dragapult':
        teal=bpy.data.materials['Spectral teal'];red=bpy.data.materials['Coral fins'];gold=bpy.data.materials['Luminous eyes'];dark=bpy.data.materials['Midnight head']
        # The head is a stealth delta with recessed launch ducts and a visible mouth seam.
        for s in (-1,1):
            ring('Recessed Dreepy launch duct',(s*1.33,.20,3.12),.20,.045,dark,head,(math.pi/2,0,0))
            line('Head crown sculpted ridge',[(s*.17,-.54,2.99),(s*.61,-.11,3.14),(s*1.53,.39,3.03)],teal,head,.021)
            line('Delta fin engraved inset',[(s*.98,.43,3.04),(s*2.18,.62,3.18)],dark,head,.016)
            ellipsoid('Dark eye pupil',(s*.39,-.635,2.81),(.025,.018,.055),dark,head)
            passenger=bpy.data.objects.get('Dreepy_L' if s<0 else 'Dreepy_R')
            for dx in (-.09,.09):ellipsoid('Dreepy eye pupil',(s*1.33+dx,.079,3.51),(.016,.010,.032),dark,passenger)
            line('Dreepy smile',[(s*1.33-.055,.092,3.40),(s*1.33,.065,3.385),(s*1.33+.055,.092,3.40)],dark,passenger,.007)
        line('Sly delta mouth',[(-.30,-.62,2.625),(0,-.932,2.58),(.30,-.62,2.625)],dark,head,.012)
        # Multi-section chest is narrow at the abdomen; stronger flowing ghost silhouette.
        old=bpy.data.objects.get('Tapered chest')
        if old:bpy.data.objects.remove(old,do_unlink=True)
        loft('Continuous ghost thorax',[(0,.13,1.10,.25,.27),(0,.08,1.36,.40,.36),(0,.02,1.88,.51,.43),(0,.03,2.18,.49,.36),(0,.04,2.51,.27,.25)],teal,body,26,2)
    elif name=='charizard':
        orange=bpy.data.materials['Amber hide'];dark=bpy.data.materials['Mouth and pupils'];ivory=bpy.data.materials['Ivory claws']
        crystal_mat=mat('Smoky amber crystal',(.42,.18,.07),.48,.21)
        # Correct dark Tera crown cue: a raised central eye and dark curved prongs.
        crown=joint('Crown',(0,.1,3.28),head)
        smoke=mat('Dark Tera crown obsidian',(.025,.019,.045),.53,.19)
        rim=mat('Dark crown cyan edging',(.17,.40,.56),.48,.23)
        for s in (-1,1):
            tube('Dark crown swept horn',[(s*.08,.17,3.31),(s*.37,.20,3.70),(s*.31,.24,3.98)],[.15,.11,.001],smoke,crown,6,6)
            line('Crown edge glint',[(s*.12,.04,3.37),(s*.30,.10,3.69),(s*.31,.24,3.98)],rim,crown,.014)
            for k in range(4):claw((s*.23,-.77+k*.10,2.71),(0,0,-.11),ivory,head,.082)
        eye(crown,(0,-.01,3.57),(.18,.09),ivory,orange,dark,True)
        for s in (-1,1):
            wing=bpy.data.objects.get('Wing_L' if s<0 else 'Wing_R')
            for k in range(6):
                t=k/6
                line('Wing fine tension vein',[(s*1.1,.26,3.45),(s*(1.4+t*.9),.26,2.70-t*.62),(s*(1.7+t*.65),.28,1.86-t*.38)],bpy.data.materials['Deep blue wing membranes'],wing,.003)
            # Shoulder faceting integrated into the hide rather than tall decorative spikes.
            for k in range(5):crystal('Amber shoulder microfacet',(s*(.47+k*.06),-.17,2.05-k*.06),(s*(.54+k*.07),-.20,2.19-k*.06),.073,crystal_mat,body)
        for o in list(bpy.context.scene.objects):
            if o.name.startswith('Crown crystal'):bpy.data.objects.remove(o,do_unlink=True)
    else:
        fur=bpy.data.materials['Ink violet fur'];blue=bpy.data.materials['Periwinkle skin'];pink=bpy.data.materials['Toxic magenta']
        for s in (-1,1):
            for k in range(6):leaf('Cheek swept fur',(s*.30,.04,2.25-k*.06),(s*(.52+k*.025),.09,2.08-k*.045),.08,fur,head,.08,.05)
            for k in range(8):
                x=s*(.22+k*.022)
                line('Combed forehead fur',[(x,-.13,2.50),(x+s*.025,-.17,2.35),(x+s*.04,-.21,2.23)],bpy.data.materials['Fur ridges'],head,.004)
        # Actual linked toxic chain circles with alternating depth, instead of round beads.
        for o in list(bpy.context.scene.objects):
            if o.name.startswith('Toxic chain bead'):bpy.data.objects.remove(o,do_unlink=True)
        for k in range(7):
            x=(k-3)*.105
            ring('Interlocked toxic chain',(x,-.29+abs(x)*.2,2.47),.075,.029,pink,head,(math.pi/2,.45 if k%2 else -.45,0))
        for side in ['L','R']:
            arm=bpy.data.objects.get('Arm_'+side)
            # Small knuckle pads and nail creases bring the gestures into focus.
            for o in list(arm.children):
                if o.type=='MESH' and o.name.startswith('Articulated finger'):
                    for p in o.data.polygons:p.use_smooth=True
    return root

def gardevoir():
    root=joint('Gardevoir');body=joint('Body',(0,0,1.72),root)
    white=mat('Ivory flowing gown',(.93,.95,.91),0,.76)
    shade=mat('Pearl inner folds',(.64,.77,.73),0,.78)
    green=mat('Jade hair and bodice',(.22,.64,.43),0,.68)
    darkgreen=mat('Deep jade hair edge',(.09,.36,.24),0,.68)
    red=mat('Ruby heart fin',(.88,.19,.30),.12,.32,.09)
    iris=mat('Rose eyes',(.79,.18,.30),0,.49)
    ink=mat('Fine facial contours',(.07,.13,.13),0,.74)
    loft('Slender torso',[(0,0,1.35,.19,.14),(0,0,1.55,.18,.14),(0,0,1.86,.27,.19),(0,0,2.12,.31,.20),(0,0,2.23,.15,.12)],white,body,24,2)
    loft('Green shoulder mantle',[(0,.035,1.69,.19,.14),(0,.035,1.92,.27,.19),(0,.035,2.13,.33,.22),(0,.035,2.22,.14,.12)],green,body,24,1)
    # A layered open gown has a bell silhouette, folds and a separate back train.
    skirt=joint('Skirt',(0,0,1.48),body)
    loft('Underskirt',[(0,.10,.07,.80,.53),(0,.11,.24,.78,.51),(0,.09,.62,.56,.39),(0,.05,1.04,.33,.24),(0,0,1.50,.19,.15)],shade,skirt,32,2)
    for s,label in [(-1,'L'),(1,'R')]:
        petal=joint('Skirt_'+label,(s*.17,0,1.43),skirt)
        loft('Sweeping dress panel '+label,[(s*.40,-.12,.08,.48,.50),(s*.38,-.12,.26,.48,.46),(s*.29,-.10,.64,.34,.35),(s*.18,-.05,1.04,.23,.24),(s*.06,0,1.51,.14,.14)],white,petal,24,2)
        for k in range(3):
            x=s*(.26+k*.14)
            tube('Raised silk fold',[(x,-.53,.13),(x*.73,-.41,.60),(x*.42,-.24,1.10),(s*.06,-.13,1.46)],[.025,.024,.018,.005],white,petal,6,8)
        leg=joint('Leg_'+label,(s*.13,0,.80),body)
        tube('Delicate leg',[(s*.13,0,.80),(s*.14,-.01,.42),(s*.15,-.02,.13)],[.085,.065,.052],green,leg,6,12)
        ellipsoid('Foot',(s*.15,-.105,.09),(.082,.16,.07),green,leg)
        arm=joint('Arm_'+label,(s*.31,0,2.07),body)
        tube('Tapered arm',[(s*.28,0,2.11),(s*.44,-.035,1.91),(s*.53,-.12,1.63),(s*.67,-.23,1.42)],[.105,.085,.060,.042],green,arm,8,14)
        hand=joint('Hand_'+label,(s*.65,-.22,1.45),arm)
        ellipsoid('Small palm',(s*.68,-.24,1.43),(.07,.044,.10),green,hand)
        for k in range(3):
            tube('Expressive finger',[(s*(.65+k*.034),-.26,1.43),(s*(.67+k*.043),-.28,1.32),(s*(.68+k*.045),-.27,1.29)],[.019,.014,.009],green,hand,4,8)
    heart=joint('Heart',(0,-.17,1.95),body)
    leaf('Front ruby heart fin',(0,-.16,1.65),(0,-.47,2.13),.17,red,heart,.05,.045)
    leaf('Back ruby heart fin',(0,.13,1.74),(0,.41,2.05),.13,red,heart,.03,.04)
    head=joint('Head',(0,0,2.49),body)
    ellipsoid('Porcelain face',(0,-.035,2.51),(.305,.235,.31),white,head)
    hair=joint('Hair',(0,.01,2.68),head)
    loft('Smooth jade cap',[(0,.045,2.45,.26,.20),(0,.04,2.70,.34,.24),(0,.055,2.83,.24,.17),(0,.055,2.90,.025,.025)],green,hair,32,2)
    for s in [-1,1]:
        leaf('Long side fringe',(s*.22,.02,2.76),(s*.34,-.045,2.23),.14,green,hair,.025,.06)
        leaf('Back swept hair',(s*.14,.10,2.76),(s*.32,.35,2.37),.15,darkgreen,hair,.035,.06)
        eye(head,(s*.12,-.243,2.51),(.079,.113),white,iris,ink)
    leaf('Signature pointed fringe',(0,-.17,2.81),(.04,-.289,2.42),.16,green,hair,.035,.05)
    line('Gentle mouth',[(-.052,-.252,2.34),(0,-.266,2.329),(.047,-.251,2.344)],ink,head,.008)
    return root

BUILDERS={n:(lambda n=n:refine_original(n)) for n in ['dragapult','charizard','munkidori']}
BUILDERS.update({f.__name__:f for f in [ceruledge,terapagos,grimmsnarl,zoroark,archaludon,ho_oh,budew,garchomp,raging_bolt,pikachu_tera,gardevoir]})

def build():
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(BUILDERS)
    previous=json.loads((OUT/'model_manifest.json').read_text()) if (OUT/'model_manifest.json').exists() else {}
    reports={r['species']:r for r in previous.get('models',[])}
    for name in requested:
        if name not in BUILDERS:raise ValueError(name)
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        for m in list(bpy.data.materials):bpy.data.materials.remove(m)
        root=BUILDERS[name]()
        root['authoring_revision']='sculpted-collection-v2'
        # Authoring swatches are sRGB. glTF stores linear factors, otherwise bright
        # greens/yellows bleach and every skin reads like lacquer under studio light.
        for m in bpy.data.materials:
            if not m.use_nodes:continue
            p=m.node_tree.nodes.get('Principled BSDF')
            if not p:continue
            rgba=tuple(p.inputs['Base Color'].default_value)
            if m.name=='Amber hide':rgba=(.92,.54,.25,1)
            if m.name=='Warm belly':rgba=(.88,.77,.51,1)
            linear=tuple(((c+.055)/1.055)**2.4 if c>.04045 else c/12.92 for c in rgba[:3])
            p.inputs['Base Color'].default_value=(*linear,1)
            p.inputs['Emission Color'].default_value=(*linear,1)
            is_gem=any(k in m.name.lower() for k in ['crystal','prism','crown','obsidian','terminal'])
            p.inputs['Specular IOR Level'].default_value=.16 if is_gem else .12
            p.inputs['Roughness'].default_value=max(p.inputs['Roughness'].default_value,.28 if is_gem else .66)
            if not is_gem:p.inputs['Metallic'].default_value=min(p.inputs['Metallic'].default_value,.12)
        bpy.context.view_layer.update()
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
        # Export bevelled normals without accidentally flattening organic surfaces.
        triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
        bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',export_yup=True,export_animations=False,export_extras=True)
        reports[name]={'species':name,'triangles':triangles,'mesh_parts':len(objects),'bytes':(OUT/f'{name}.glb').stat().st_size,'revision':2}
        print('CHARACTER_DONE',json.dumps(reports[name]),flush=True)
        # Free orphaned authored meshes between characters; no accumulating scene history.
        for data in list(bpy.data.meshes):
            if data.users==0:bpy.data.meshes.remove(data)
    (OUT/'model_manifest.json').write_text(json.dumps({'revision':2,'authoring':'Original sculpted Blender surfaces and articulated components; Godot procedural action clips','models':list(reports.values())},indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':build()
