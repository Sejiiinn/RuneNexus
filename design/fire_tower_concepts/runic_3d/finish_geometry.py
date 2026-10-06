"""Finish selected concept geometry without exporting or replacing game assets.
Uses explicit recessed armour panels rather than repeated overlapping booleans.
Execute apply_geometry_finish(scene) through Blender MCP on the saved design.
"""
import bpy, math, bmesh
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt
from pathlib import Path
from collections import Counter
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d')


def inside(p, poly):
    x,y=p; result=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:result=not result
    return result


def panel(name, outline, holes, mapping, normal, thickness, mat, coll, parent, bevel=.002, guides=()):
    verts=[];edges=[]
    for poly in [outline]+holes:
        start=len(verts);verts.extend(Vector(p) for p in poly)
        edges.extend((start+i,start+(i+1)%len(poly)) for i in range(len(poly)))
    for seg in guides:
        j=len(verts);verts.extend(Vector(p) for p in seg);edges.append((j,j+1))
    vv,ee,ff,_,_,_=delaunay_2d_cdt(verts,edges,[],0,1e-7,False)
    faces=[]
    for f in ff:
        c=sum((vv[i] for i in f),Vector((0,0)))/len(f)
        if inside(c,outline) and not any(inside(c,h) for h in holes):faces.append(tuple(f))
    used=sorted({i for f in faces for i in f});remap={i:j for j,i in enumerate(used)}
    uv=[vv[i] for i in used];faces=[tuple(remap[i] for i in f) for f in faces]
    top=[Vector(mapping(*p)) for p in uv];normals=[Vector(normal(*p)).normalized() for p in uv]
    n=len(top);vv3=[tuple(p) for p in top]+[tuple(p-no*thickness) for p,no in zip(top,normals)]
    # Correct orientation before extruding, even for mirrored side panels.
    if faces:
        a,b,c=(top[i] for i in faces[0][:3])
        if (b-a).cross(c-a).dot(normals[faces[0][0]])<0:faces=[tuple(reversed(f)) for f in faces]
    count=Counter(tuple(sorted((f[i],f[(i+1)%len(f)]))) for f in faces for i in range(len(f)))
    fs=faces+[tuple(i+n for i in reversed(f)) for f in faces]
    for f in faces:
        for a,b in zip(f,f[1:]+f[:1]):
            if count[tuple(sorted((a,b)))]==1:fs.append((b,a,a+n,b+n))
    me=bpy.data.meshes.new(name);me.from_pydata(vv3,[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new(name,me);coll.objects.link(o);o.parent=parent;me.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Finished bevel','BEVEL');mod.width=bevel;mod.segments=3;mod.use_clamp_overlap=True
        mod=o.modifiers.new('Weighted broad faces','WEIGHTED_NORMAL');mod.keep_sharp=True
    return o


def rectangle(x0,x1,y0,y1):return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]

def chamfer_rect(w,l,c=.006,cy=0):
    return [(-w/2+c,cy-l/2),(w/2-c,cy-l/2),(w/2,cy-l/2+c),(w/2,cy+l/2-c),(w/2-c,cy+l/2),(-w/2+c,cy+l/2),(-w/2,cy+l/2-c),(-w/2,cy-l/2+c)]

def stroke(a,b,width):
    a,b=Vector(a),Vector(b);d=(b-a).normalized();n=Vector((-d.y,d.x))*width/2
    a-=d*.002;b+=d*.002
    return [tuple(a+n),tuple(a-n),tuple(b-n),tuple(b+n)]


def apply_geometry_finish(scene):
    ns={};exec(compile((ROOT/'build_model.py').read_text(),'build_model.py','exec'),ns)
    gun=scene.objects['turret_barrel'];head=scene.objects['turret_head'];root=scene.objects['turret_root']
    dc=bpy.data.collections['03 Runic Gun Assembly'];hc=bpy.data.collections['02 Rotating Carriage'];bc=bpy.data.collections['01 Fixed Base']
    iron=bpy.data.materials['Iron | forged charcoal'];bronze=bpy.data.materials['Bronze | worn warm alloy'];dark=bpy.data.materials['Recess | dark gunmetal'];ember=bpy.data.materials['Runes | molten orange'];steel=bpy.data.materials['Steel | polished bevel detail']
    # Preserve the chosen muzzle and forward neck, replace the faulty receiver inlays.
    keep=('Tapered forward octagonal barrel','Muzzle','Forward barrel bronze retaining band','turret_barrel','muzzle','upper_flame_port')
    for o in list(dc.objects):
        if not any(o.name.startswith(p) for p in keep):bpy.data.objects.remove(o,do_unlink=True)
    gun.rotation_euler.x=math.radians(9)
    for o in dc.objects:
        if o.name.startswith('Muzzle eight-sided'):
            for m in o.modifiers:
                if m.type=='BEVEL':m.width=.011;m.segments=4
    # Narrower top land and wider shoulders, with a softer faceted rear cap.
    sections=[(-.37,.126,.112),(-.21,.177,.146),(.19,.186,.146),(.335,.178,.143),(.40,.148,.128),(.446,.10,.092)]
    def wh(y):
        for (a,w,h),(b,ww,hh) in zip(sections,sections[1:]):
            if a-1e-6<=y<=b+1e-6:
                t=(y-a)/(b-a);return w+(ww-w)*t,h+(hh-h)*t
        return sections[0][1:] if y<sections[0][0] else sections[-1][1:]
    top_ratio=.55
    # Interior is hidden below the recess floors, maintaining actual opening depth.
    ns['loft']('Receiver interior structural core',[(y,w*.91,min(h-.033,.091)) for y,w,h in sections],dark,dc,gun,.004)
    outer=[(-w*top_ratio,y) for y,w,h in sections]+[(w*top_ratio,y) for y,w,h in reversed(sections)]
    loop=[(0,-.245),(-.058,-.177),(-.053,.107),(-.026,.164),(.025,.164),(.054,.119),(.054,-.174),(0,-.245)]
    cuts=[stroke(a,b,.031) for a,b in zip(loop,loop[1:])]
    side_ys=[-.190,-.122]
    for sign in [-1,1]:
        for yy in side_ys:
            start=(sign*.052,yy+.04);end=(sign*(wh(yy)[0]*top_ratio+.006),yy)
            cuts.append(stroke(start,end,.029))
    port=chamfer_rect(.109,.126,.005,.276)
    mapping=lambda x,y:(x,y,wh(y)[1])
    norm=lambda x,y:(0,0,1)
    guides=[((-wh(y)[0]*top_ratio,y),(wh(y)[0]*top_ratio,y)) for y,_,_ in sections[1:-1]]
    panel('Finished top armour with continuous rune recess',outer,cuts+[port],mapping,norm,.020,iron,dc,gun,.003,guides)
    # Fill the same constrained rune union below its walls; no raised wiring or seams.
    allv=[];alle=[]
    for poly in [outer]+cuts:
        j=len(allv);allv.extend(Vector(p) for p in poly);alle.extend((j+i,j+(i+1)%len(poly)) for i in range(len(poly)))
    vv,_,ff,*_=delaunay_2d_cdt(allv,alle,[],0,1e-7,False)
    triangles=[]
    for f in ff:
        c=sum((vv[i] for i in f),Vector((0,0)))/len(f)
        if inside(c,outer) and any(inside(c,h) for h in cuts):triangles.append(tuple(f))
    # Joined single planar floor, not one overlapping piece per stroke.
    me=bpy.data.meshes.new('Rune continuous luminous floor');me.from_pydata([(p.x,p.y,wh(p.y)[1]-.009) for p in vv],[],triangles);me.update()
    o=bpy.data.objects.new('Rune continuous luminous floor',me);dc.objects.link(o);o.parent=gun;me.materials.append(ember)
    # Each side shoulder and wall has a matching channel gap at the same Y positions.
    uv_outline=rectangle(0,1,sections[0][0],sections[-1][0])
    guides_uv=[((0,y),(1,y)) for y,_,_ in sections[1:-1]]
    for sign in [-1,1]:
        shoulder_map=lambda u,y,si=sign:(si*wh(y)[0]*(top_ratio+(1-top_ratio)*u),y,wh(y)[1]*(1-.45*u))
        shoulder_no=lambda u,y,si=sign:(si*.71,0,.70)
        slots=[rectangle(-.001,1.001,yy-.016,yy+.016) for yy in side_ys]
        panel(('Right' if sign>0 else 'Left')+' shoulder armour',uv_outline,slots,shoulder_map,shoulder_no,.017,iron,dc,gun,.003,guides_uv)
        wall_map=lambda u,y,si=sign:(si*wh(y)[0],y,wh(y)[1]*(.55-1.1*u))
        wall_no=lambda u,y,si=sign:(si,0,0)
        wallslots=[rectangle(-.001,.77,yy-.016,yy+.016) for yy in side_ys]
        panel(('Right' if sign>0 else 'Left')+' side armour',uv_outline,wallslots,wall_map,wall_no,.018,iron,dc,gun,.003,guides_uv)
        for idx,yy in enumerate(side_ys):
            # Two contiguous three-surface inlays, recessed just inside the armour.
            cross=[(wh(yy)[0]*top_ratio,wh(yy)[1]),(wh(yy)[0],wh(yy)[1]*.55),(wh(yy)[0],wh(yy)[1]*(.55-1.1*.77))]
            vs=[]
            for x,z in cross:
                for y in [yy-.012,yy+.012]:vs.append((sign*(x-.003),y,z-.003))
            ob=ns['mesh']('Continuous shoulder orange inlay',vs,[(0,2,3,1),(2,4,5,3)],ember,dc,gun,0)
        # Lower chamfer skin closes the visible receiver shell.
        lower_map=lambda u,y,si=sign:(si*wh(y)[0]*(1-(1-top_ratio)*u),y,wh(y)[1]*(-.55-.45*u))
        panel('Lower angled receiver armour',uv_outline,[],lower_map,lambda u,y,si=sign:(si*.71,0,-.7),.016,iron,dc,gun,.004,guides_uv)
    bottom_outline=outer
    panel('Lower receiver armour',bottom_outline,[],lambda x,y:(x,y,-wh(y)[1]),lambda x,y:(0,0,-1),.016,iron,dc,gun,.004,guides)
    # Short rear cap follows the actual eight-sided section.
    for y,w,h in [sections[-1]]:
        poly=[(-w*top_ratio,h),(w*top_ratio,h),(w,h*.55),(w,-h*.55),(w*top_ratio,-h),(-w*top_ratio,-h),(-w,-h*.55),(-w,h*.55)]
        panel('Chamfered rear cap',poly,[],lambda x,z:(x,y,z),lambda x,z:(0,1,0),.020,iron,dc,gun,.009)
    # One-piece thin chamfered exhaust collar, visually seated into the rear top.
    port_outer=chamfer_rect(.139,.155,.008,.276)
    panel('One-piece inset exhaust bezel',port_outer,[port],lambda x,y:(x,y,wh(y)[1]+.006),norm,.018,bronze,dc,gun,.003)
    panel('Exhaust socket lining',chamfer_rect(.119,.136,.006,.276),[chamfer_rect(.101,.118,.005,.276)],lambda x,y:(x,y,.14),norm,.055,dark,dc,gun,.002)
    ns['cube']('Exhaust ignition depth',(0,.276,.098),(.096,.111,.006),ember,dc,gun,.001)
    scene.objects['upper_flame_port'].location=(0,.276,.142)
    # Full fitted octagonal rear retaining collar, including side and underside.
    verts=[]
    for y,offset in [(.370,.016),(.417,.016),(.370,.001),(.417,.001)]:
        w,h=wh(y);w+=offset;h+=offset
        ring=[(-w*top_ratio,h),(w*top_ratio,h),(w,h*.55),(w,-h*.55),(w*top_ratio,-h),(-w*top_ratio,-h),(-w,-h*.55),(-w,h*.55)]
        verts.extend((x,y,z) for x,z in ring)
    faces=[]
    for i in range(8):
        j=(i+1)%8
        faces.extend([(i,j,j+8,i+8),(i+16,i+24,j+24,j+16),(i,i+16,j+16,j),(i+8,j+8,j+24,i+24)])
    ns['mesh']('Rear full octagonal bronze retaining collar',verts,faces,bronze,dc,gun,.004)
    # Rebuild full-height support engravings as explicit inset geometry.
    prefixes=('Left sculpted','Right sculpted','Left finished rune support','Right finished rune support','Deep dark support engraving','Inset bronze rune diamond','Foot bolt recessed','Single bronze foot fastener','Trunnion','Axle','Support foot','Black recessed','Inset bronze')
    for o in list(hc.objects):
        if any(o.name.startswith(p) for p in prefixes):bpy.data.objects.remove(o,do_unlink=True)
    # Reduce the clutter of two unrelated adjacent pedestal rivets beside each foot.
    for o in list(hc.objects):
        if o.name.startswith('Pedestal rivet') and o.name not in ['Pedestal rivet 00','Pedestal rivet 04']:
            bpy.data.objects.remove(o,do_unlink=True)
    support=[(-.198,.224),(.105,.224),(.154,.372),(.185,.65),(.163,.725),(.102,.76),(.03,.747),(-.009,.632),(-.07,.540),(-.154,.503)]
    diamond=[(-.084,.513),(-.023,.583),(.038,.513),(-.023,.443)]
    chev1=[(-.106,.463),(-.023,.403),(.060,.463),(.060,.439),(-.023,.377),(-.106,.439)]
    chev2=[(-.115,.403),(-.023,.348),(.069,.403),(.069,.379),(-.023,.321),(-.115,.379)]
    # Centre the motif within the broad support face and preserve edge clearance.
    diamond=[(.008+(y+.023)*.87,.500+(z-.513)*.87) for y,z in diamond]
    chev1=[(.008+(y+.023)*.85,z) for y,z in chev1]
    chev2=[(.008+(y+.023)*.85,z) for y,z in chev2]
    bolt_y=.008;bolt_z=.270
    circ=[(bolt_y+.035*math.cos(2*math.pi*i/40),bolt_z+.035*math.sin(2*math.pi*i/40)) for i in range(40)]
    for sign in [-1,1]:
        x=sign*.279
        o=panel(('Right' if sign>0 else 'Left')+' finished rune support',support,[diamond,chev1,chev2,circ],lambda y,z,xx=x:(xx,y,z),lambda y,z,si=sign:(si,0,0),.057,bronze,hc,head,.0028)
        for poly in [diamond,chev1,chev2]:
            panel('Deep dark support engraving',poly,[],lambda y,z,xx=x-sign*.003:(xx,y,z),lambda y,z,si=sign:(si,0,0),.003,dark,hc,head,.001)
        center=[(-.055,.513),(-.023,.550),(.009,.513),(-.023,.476)]
        center=[(.008+(y+.023)*.87,.500+(z-.513)*.87) for y,z in center]
        panel('Inset bronze rune diamond',center,[],lambda y,z,xx=x-sign*.0015:(xx,y,z),lambda y,z,si=sign:(si,0,0),.004,bronze,hc,head,.002)
        ns['cyl']('Foot bolt recessed dark socket',.034,.006,(x-sign*.004,bolt_y,bolt_z),dark,hc,head,48,'X',.003)
        ns['cyl']('Single bronze foot fastener',.025,.016,(x-sign*.001,bolt_y,bolt_z),bronze,hc,head,32,'X',.005)
        ns['cyl']('Trunnion finished iron ring',.104,.065,(sign*.267,.105,.672),dark,hc,head,48,'X',.008)
        ns['cyl']('Trunnion faceted steel step',.078,.031,(sign*.303,.105,.672),steel,hc,head,16,'X',.004)
        ns['cyl']('Trunnion bronze centre',.049,.023,(sign*.325,.105,.672),bronze,hc,head,32,'X',.005)
        ns['cyl']('Axle recessed socket',.014,.003,(sign*.338,.105,.672),dark,hc,head,24,'X',.001)
    # Wider, thicker trapezoidal feet instead of thin uniform wrap straps.
    for o in list(bc.objects):
        if o.name.startswith(('Foundation bronze clamp','Finished trapezoid base clamp')):bpy.data.objects.remove(o,do_unlink=True)
    pts=[(.315,.163),(.35,.182),(.427,.171),(.459,.042),(.449,.010),(.405,.010),(.377,.129),(.315,.129)]
    for i in range(4):
        vs=[]
        for sign in [-1,1]:
            for y,z in pts:
                half=.100-(z/.18)*.018
                vs.append((sign*half,y,z))
        n=len(pts);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
        o=ns['mesh']('Finished trapezoid base clamp %02d'%i,vs,faces,bronze,bc,root,.013)
        o.rotation_euler.z=math.radians(225)+i*math.pi/2
    bpy.context.view_layer.update()
    return {'receiver':'explicit panelled recesses','supports':'large diamond and twin chevron recesses; one round bolt each','clamps':'four thick trapezoidal feet','game_export':False}
