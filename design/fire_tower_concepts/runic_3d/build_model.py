"""Rune flame turret — independent Blender design source. No game export.
Run sections through Blender MCP. Coordinates: Z up, -Y forward.
"""
import bpy, math, random
from mathutils import Vector
from pathlib import Path
OUT = Path('/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d')
REF = OUT.parent / '2026-09-14/14-runic-mechanism.png'

def collection(name):
    c=bpy.data.collections.new(name); scene.collection.children.link(c); return c

def empty(name, coll, parent=None):
    o=bpy.data.objects.new(name,None); coll.objects.link(o); o.parent=parent; return o

def mesh(name, verts, faces, mat, coll, parent=None, bevel=0):
    m=bpy.data.meshes.new(name); m.from_pydata(verts,[],faces); m.update()
    o=bpy.data.objects.new(name,m); coll.objects.link(o); o.parent=parent
    if mat: m.materials.append(mat)
    if bevel:
        b=o.modifiers.new('Machined edge bevel','BEVEL'); b.width=bevel; b.segments=3
        b=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL'); b.keep_sharp=True; b.weight=40
    return o

def move_coll(o,c):
    for old in list(o.users_collection): old.objects.unlink(o)
    c.objects.link(o)

def cyl(name, radius, depth, loc, mat, coll, parent=None, verts=64, axis='Z', bevel=.006):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=(0,0,0))
    o=bpy.context.object; o.name=name; move_coll(o,coll); o.parent=parent; o.location=loc
    if axis=='X': o.rotation_euler[1]=math.pi/2
    if axis=='Y': o.rotation_euler[0]=math.pi/2
    if mat:o.data.materials.append(mat)
    if bevel:
        b=o.modifiers.new('Machined bevel','BEVEL');b.width=bevel;b.segments=3
        b=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');b.keep_sharp=True
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return o

def cube(name, loc, dims, mat, coll, parent=None, bevel=.008):
    x,y,z=[v/2 for v in dims]
    vs=[(a*x,b*y,c*z) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    fs=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    o=mesh(name,vs,fs,mat,coll,parent,bevel);o.location=loc;return o

def ring(name, ro, ri, depth, loc, mat, coll, parent=None, n=64, axis='Z', bevel=.003, phase=0):
    vs=[]
    for z,r in [(-depth/2,ro),(depth/2,ro),(-depth/2,ri),(depth/2,ri)]:
        for i in range(n):
            a=2*math.pi*i/n+phase; p=(r*math.cos(a),r*math.sin(a),z)
            if axis=='Y':p=(p[0],-p[2],p[1])
            if axis=='X':p=(p[2],p[0],p[1])
            vs.append(p)
    fs=[]
    for i in range(n):
        j=(i+1)%n
        fs.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(n+i,n+j,3*n+j,3*n+i),(j,i,2*n+i,2*n+j)])
    o=mesh(name,vs,fs,mat,coll,parent,bevel);o.location=loc;return o

def profile_x(name, points, thickness, x, mat, coll, parent=None, bevel=.005):
    points=list(points)
    if sum(points[i][0]*points[(i+1)%len(points)][1]-points[(i+1)%len(points)][0]*points[i][1] for i in range(len(points)))<0:points.reverse()
    n=len(points);vs=[(xx,y,z) for xx in [x-thickness/2,x+thickness/2] for y,z in points]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs +=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,mat,coll,parent,bevel)

def loft(name,sections, mat, coll,parent=None,bevel=.009):
    vs=[]
    for y,w,h in sections:
        vs.extend([(x,y,z) for x,z in [(-w*.65,h),(w*.65,h),(w,h*.55),(w,-h*.55),(w*.65,-h),(-w*.65,-h),(-w,-h*.55),(-w,h*.55)]])
    fs=[tuple(reversed(range(8))),tuple(range(len(vs)-8,len(vs)))]
    for k in range(len(sections)-1):
        for j in range(8):fs.append((k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j))
    return mesh(name,vs,fs,mat,coll,parent,bevel)

def bool_diff(o,c):
    import bmesh
    def volume(data):
        bm=bmesh.new();bm.from_mesh(data)
        v=abs(bm.calc_volume(signed=True));bm.free();return v
    backup=o.data.copy();before=volume(o.data)
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active=o
    for solver in ['EXACT','FLOAT']:
        m=o.modifiers.new('Recess cut','BOOLEAN');m.operation='DIFFERENCE';m.object=c;m.solver=solver
        bpy.ops.object.modifier_move_up(modifier=m.name)
        bpy.ops.object.modifier_move_up(modifier=m.name)
        bpy.ops.object.modifier_apply(modifier=m.name)
        after=volume(o.data)
        if o.data.polygons and after>before*.84 and after<before*1.025:
            bpy.data.meshes.remove(backup);bpy.data.objects.remove(c,do_unlink=True);return True
        bad=o.data;o.data=backup.copy();bpy.data.meshes.remove(bad)
    print('Skipped invalid recess',c.name,round(before,5),round(after,5))
    bpy.data.meshes.remove(backup);bpy.data.objects.remove(c,do_unlink=True);return False

def path_ribbon(name, pts, width, height, mat, coll, parent=None):
    # Flat ruled strip with true thickness, mitered corners on XY plane.
    vs=[]
    for i,p in enumerate(pts):
        a=Vector(pts[max(0,i-1)]); b=Vector(pts[min(len(pts)-1,i+1)])
        d=(b-a).normalized(); n=Vector((-d.y,d.x,0)).normalized()*width/2
        for dz in [-height/2,height/2]:
            vs += [tuple(Vector(p)-n+Vector((0,0,dz))),tuple(Vector(p)+n+Vector((0,0,dz)))]
    fs=[(0,2,3,1)]
    for i in range(len(pts)-1):
        k=i*4; q=k+4;fs +=[(k,k+1,q+1,q),(k+2,q+2,q+3,k+3),(k,q,q+2,k+2),(k+1,k+3,q+3,q+1)]
    k=(len(pts)-1)*4;fs.append((k,k+1,k+3,k+2))
    return mesh(name,vs,fs,mat,coll,parent,0)

def metal(name, col, metallic, rough):
    m=bpy.data.materials.new(name);m.use_nodes=True;ns=m.node_tree.nodes;lk=m.node_tree.links
    p=ns.get('Principled BSDF');p.inputs['Metallic'].default_value=metallic
    tex=ns.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=35;tex.inputs['Detail'].default_value=3;tex.inputs['Roughness'].default_value=.7
    ramp=ns.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[1].position=.85
    ramp.color_ramp.elements[0].color=tuple(c*.7 for c in col)+(1,)
    ramp.color_ramp.elements[1].color=tuple(c*1.22 for c in col)+(1,)
    lk.new(tex.outputs['Fac'],ramp.inputs[0]);lk.new(ramp.outputs[0],p.inputs['Base Color'])
    rm=ns.new('ShaderNodeMapRange');rm.inputs['To Min'].default_value=rough-.08;rm.inputs['To Max'].default_value=rough+.09
    lk.new(tex.outputs['Fac'],rm.inputs[0]);lk.new(rm.outputs[0],p.inputs['Roughness'])
    fine=ns.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=240;fine.inputs['Detail'].default_value=2
    bump=ns.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.001
    lk.new(fine.outputs['Fac'],bump.inputs['Height'])
    cracks=ns.new('ShaderNodeTexVoronoi');cracks.feature='DISTANCE_TO_EDGE';cracks.inputs['Scale'].default_value=68
    cr=ns.new('ShaderNodeValToRGB');cr.color_ramp.elements[0].position=.008;cr.color_ramp.elements[1].position=.025
    lk.new(cracks.outputs['Distance'],cr.inputs[0]);bu=ns.new('ShaderNodeBump');bu.inputs['Strength'].default_value=.22;bu.inputs['Distance'].default_value=.0008
    lk.new(cr.outputs[0],bu.inputs['Height']);lk.new(bump.outputs[0],bu.inputs['Normal']);lk.new(bu.outputs[0],p.inputs['Normal'])
    return m

def emissive(name,col,strength):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*col,1);p.inputs['Emission Color'].default_value=(*col,1);p.inputs['Emission Strength'].default_value=strength;p.inputs['Roughness'].default_value=.4;return m

def setup():
    global scene,base_col,head_col,detail_col,fx_col,studio_col,root,head,gun,iron,bronze,dark,edge,ember
    scene=bpy.data.scenes.new('Rune Flame Turret — Design');bpy.context.window.scene=scene
    base_col=collection('01 Fixed Base');head_col=collection('02 Rotating Carriage');detail_col=collection('03 Runic Gun Assembly');fx_col=collection('04 Flame Study');studio_col=collection('90 Studio')
    root=empty('turret_root',base_col);head=empty('turret_head',head_col,root)
    gun=empty('turret_barrel',detail_col,head);gun.location=(0,0,.655);gun.rotation_euler.x=math.radians(13)
    iron=metal('Iron | forged charcoal',(.052,.062,.078),.72,.54)
    bronze=metal('Bronze | worn warm alloy',(.43,.235,.086),.72,.43)
    dark=metal('Recess | dark gunmetal',(.012,.017,.021),.5,.61)
    edge=metal('Steel | polished bevel detail',(.11,.13,.15),.8,.36)
    ember=emissive('Runes | molten orange',(1,.045,.001),2.3)
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    print('Created independent design scene; existing scenes untouched')

def build_base():
    cyl('Foundation lower armor',.43,.125,(0,0,.073),iron,base_col,root,64,bevel=.012)
    cyl('Foundation rim',.415,.035,(0,0,.142),dark,base_col,root,64,bevel=.007)
    cyl('Sloped turntable',.345,.105,(0,0,.193),iron,head_col,head,64,bevel=.018)
    ring('Turntable bronze seam',.332,.320,.013,(0,0,.231),bronze,head_col,head)
    cyl('Rotating pedestal',.274,.13,(0,0,.29),iron,head_col,head,48,bevel=.012)
    ring('Pedestal lower collar',.287,.264,.032,(0,0,.24),dark,head_col,head)
    ring('Pedestal upper bronze inlay',.273,.255,.018,(0,0,.35),bronze,head_col,head)
    cyl('Head spindle',.185,.12,(0,0,.399),dark,head_col,head,48)
    ring('Spindle warm metal collar',.192,.175,.013,(0,0,.426),bronze,head_col,head)
    for i in range(4):
        # Four broad bent armor clamps around the fixed outer ring.
        a=math.radians(15)+i*math.pi/2
        pts=[(.312,.16),(.345,.175),(.427,.165),(.449,.03),(.424,.012),(.393,.035),(.377,.125),(.315,.126)]
        o=profile_x('Foundation bronze clamp %02d'%i,pts,.14,0,bronze,base_col,root,.009);o.rotation_euler.z=a
    for i in range(8):
        a=i*math.pi/4
        o=cyl('Pedestal rivet %02d'%i,.023,.018,(.279*math.sin(a),-.279*math.cos(a),.286),bronze,head_col,head,24,axis='Y',bevel=.003);o.rotation_euler.z=a
    # Front arc segmented seams: small actual dark insets rather than drawn lines.
    for i in range(16):
        a=i*2*math.pi/16
        o=cube('Foundation radial seam %02d'%i,(.425*math.sin(a),-.425*math.cos(a),.08),(.0025,.002,.078),dark,base_col,root,.0003);o.rotation_euler.z=a
    print('Base built')

def build_gun():
    global body
    body=loft('Elongated eight-sided runic receiver',[(-.37,.126,.112),(-.20,.176,.146),(.20,.182,.146),(.37,.17,.146),(.445,.11,.095)],iron,detail_col,gun,.009)
    # Forward barrel is angular and continuous with the receiver.
    loft('Tapered forward octagonal barrel',[(-.61,.082,.081),(-.39,.105,.104),(-.34,.114,.108)],iron,detail_col,gun,.006)
    ring('Muzzle eight-sided bronze jacket',.145,.085,.105,(0,-.621,0),bronze,detail_col,gun,8,'Y',.008,math.pi/8)
    ring('Muzzle inner black sleeve',.087,.070,.11,(0,-.601,0),dark,detail_col,gun,48,'Y',.002)
    ring('Muzzle ignition ring',.072,.063,.009,(0,-.647,0),ember,detail_col,gun,48,'Y',.001)
    cyl('Muzzle dark throat',.065,.009,(0,-.54,0),dark,detail_col,gun,48,'Y',.001)
    ring('Forward barrel bronze retaining band',.132,.114,.037,(0,-.392,0),bronze,detail_col,gun,8,'Y',.005,math.pi/8)
    ring('Rear receiver bronze cap band',.171,.153,.032,(0,.372,0),bronze,detail_col,gun,8,'Y',.004,math.pi/8)
    # Carve a true top exhaust socket; lip is almost flush with the armor.
    cut=cube('Port cutter',(0,.285,.142),(.13,.138,.13),None,detail_col,gun,0);bool_diff(body,cut)
    cube('Exhaust socket bottom',(0,.285,.105),(.12,.13,.015),dark,detail_col,gun,.004)
    # Rectangular collar built as four beveled rails, not a separate brazier.
    for x in [-.071,.071]:cube('Exhaust collar side',(x,.285,.151),(.014,.156,.017),bronze,detail_col,gun,.003)
    for y in [.214,.356]:cube('Exhaust collar end',(0,y,.151),(.13,.014,.017),bronze,detail_col,gun,.003)
    cube('Exhaust ignition bed',(0,.285,.113),(.106,.114,.007),ember,detail_col,gun,.002)
    # Recessed long rune loop. A single internal emissive floor avoids seams.
    pts=[(0,-.218,.146),(-.054,-.159,.146),(-.045,.089,.146),(-.025,.158,.146),(.025,.158,.146),(.046,.11,.146),(.045,-.16,.146),(0,-.218,.146)]
    for a,b in zip(pts,pts[1:]):
        av,bv=Vector(a),Vector(b);dv=bv-av
        c=cube('Rune recess cutter',tuple((av+bv)/2),(dv.xy.length+.013,.039,.041),None,detail_col,gun,0)
        c.rotation_euler.z=math.atan2(dv.y,dv.x);bool_diff(body,c)
    cube('Internal orange rune floor',(0,-.025,.128),(.152,.408,.006),ember,detail_col,gun,.001)
    # Two grooves wrap down each shoulder, following all three actual faces.
    for sign in [-1,1]:
        for yy in [-.16,-.095]:
            points=[Vector((sign*.044,yy,.146)),Vector((sign*.1144,yy,.146)),Vector((sign*.176,yy,.0803)),Vector((sign*.176,yy,-.025))]
            for idx,(a,b) in enumerate(zip(points,points[1:])):
                d=(b-a).normalized(); n=d.cross(Vector((0,1,0)))
                if sign<0:n=-n
                def strip(name,width,depth,offset,mat):
                    mid=(a+b)/2+n*offset
                    # Local x follows groove, local y lies across it.
                    from mathutils import Matrix
                    v=Vector((0,sign,0))
                    rot=Matrix((d,v,n)).transposed().to_4x4()
                    o=cube(name,tuple(mid),((b-a).length+.012,width,depth),mat,detail_col,gun,0)
                    o.rotation_euler=rot.to_euler();return o
                c=strip('Shoulder recess cutter',.031,.038,-.009,None)
                if not bool_diff(body,c):continue
                strip('Recessed orange shoulder inlay',.024,.005,-.007,ember)
    # Separate assembly origin markers retained for editing only.
    o=empty('muzzle',detail_col,gun);o.location=(0,-.675,0)
    o=empty('upper_flame_port',detail_col,gun);o.location=(0,.285,.16)
    print('Gun and inlaid runes built')

def build_supports():
    pts=[(-.215,.205),(.09,.205),(.14,.36),(.182,.65),(.155,.724),(.095,.76),(.018,.736),(-.012,.626),(-.093,.517),(-.162,.485)]
    for sign in [-1,1]:
        x=sign*.244
        o=profile_x(('Right' if sign==1 else 'Left')+' sculpted bronze support',pts,.049,x,bronze,head_col,head,.01)
        cyl('Trunnion dark outer ring',.104,.075,(sign*.238,.105,.672),dark,head_col,head,48,'X',.007)
        cyl('Trunnion faceted steel hub',.078,.034,(sign*.287,.105,.672),edge,head_col,head,16,'X',.004)
        cyl('Trunnion bronze axle cap',.050,.021,(sign*.31,.105,.672),bronze,head_col,head,48,'X',.004)
        cyl('Axle central inset',.016,.002,(sign*.322,.105,.672),dark,head_col,head,24,'X',.001)
        cyl('Support foot bolt',.032,.017,(sign*.28,-.09,.266),bronze,head_col,head,32,'X',.004)
        # Deep diamond-and-chevron recesses cut into the bronze plate.
        xx=sign*.269
        motifs=[ [(-.066,.495),(-.025,.547),(.016,.495),(-.025,.443)],
                 [(-.084,.436),(-.025,.385),(.034,.436),(.034,.413),(-.025,.361),(-.084,.413)],
                 [(-.09,.377),(-.025,.322),(.04,.377),(.04,.354),(-.025,.30),(-.09,.354)] ]
        for idx,poly in enumerate(motifs):
            poly=[(yy,zz+.055) for yy,zz in poly]
            c=profile_x('Rune relief cutter',poly,.022,xx,None,head_col,head,0);bool_diff(o,c)
            profile_x('Black recessed support rune',poly,.002,xx-sign*.012,dark,head_col,head,.001)
        profile_x('Inset bronze diamond',[(-.047,.550),(-.025,.576),(-.003,.550),(-.025,.524)],.003,xx-sign*.01,bronze,head_col,head,.002)
    print('Sculpted supports with carved rune relief built')

def studio():
    scene.render.engine='CYCLES';scene.cycles.samples=80;scene.cycles.use_denoising=True
    scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Muted studio atmosphere');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.18,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
    ground=metal('Studio | desaturated forest',(.015,.032,.026),0,.92)
    cube('Studio floor',(0,0,-.013),(200,200,.02),ground,studio_col,None,0)
    def light(name,pos,power,size,col):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=col
        o=bpy.data.objects.new(name,data);studio_col.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.4))-o.location).to_track_quat('-Z','Y').to_euler();return o
    light('Large warm key',(-2,-3,4),250,3,(1,.88,.74))
    light('Soft neutral fill',(3,-1,2.5),150,2.8,(.72,.83,1))
    light('Bronze rim',(.2,3,3),240,2,(1,.69,.40))
    data=bpy.data.cameras.new('Camera reference 3-4');cam=bpy.data.objects.new('Camera reference 3-4',data);studio_col.objects.link(cam)
    cam.location=(3.2,-3,2.6);target=Vector((0,-.035,.50));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=1.62;data.lens=50;scene.camera=cam
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=-.55
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'runic-flame-turret-hero.png')
    # Reference is packed and available in Blender's image editor without affecting render.
    img=bpy.data.images.load(str(REF),check_existing=True);img.name='REFERENCE — selected concept 14';img.pack()
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
    note=bpy.data.texts.new('START HERE — 화염 룬 포탑')
    note.write('선택 시안 14의 Blender 디자인 원본. 게임 이관 없음.\n01 Fixed Base / 02 Rotating Carriage / 03 Runic Gun Assembly / 04 Flame Study 별도 편집 가능.\n좌표 Z 위, -Y 전방. 단위 1, 받침 지름 .86.\nREFERENCE 이미지가 파일에 패킹되어 있습니다. 화염은 별도 편집 가능한 형태 연구용 메시입니다.\n')
    print('Studio configured')
