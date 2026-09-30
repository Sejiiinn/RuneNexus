"""01 SWIFT approved swept receiver and curved silver yoke, actual 3D geometry.
Called by build_sniper.py with its existing helpers/materials/contract nodes.
"""
import math
from mathutils import Vector

def catmull(points,steps=5):
    out=[]
    for i in range(len(points)-1):
        a=points[max(0,i-1)];b=points[i];c=points[i+1];d=points[min(len(points)-1,i+2)]
        for j in range(steps):
            t=j/steps
            out.append(tuple(.5*((2*bb)+(-aa+cc)*t+(2*aa-5*bb+4*cc-dd)*t*t+(-aa+3*bb-3*cc+dd)*t*t*t) for aa,bb,cc,dd in zip(a,b,c,d)))
    return out+[tuple(points[-1])]

def build_swift(ctx):
    mesh,cube,cyl,ring,profile_x,loft,flat_inlay,bolt=[ctx[k] for k in ['mesh','cube','cyl','ring','profile_x','loft','flat_inlay','bolt']]
    iron,silver,bronze,dark,rune,carriage,gunparts,head,gun=[ctx[k] for k in ['iron','silver','bronze','dark','rune','carriage','gunparts','head','gun']]
    # Curve band center is lower than the receiver; the arms wrap its underside.
    upper=catmull([(-.271,.244),(-.195,.245),(-.157,.217),(-.118,.169),(-.060,.151),(.018,.158),(.075,.190),(.109,.263),(.169,.282)],5)
    lower=catmull([(.179,.230),(.145,.153),(.106,.103),(.041,.087),(-.042,.087),(-.119,.110),(-.171,.167),(-.220,.195),(-.279,.198)],5)
    yoke=upper+lower
    for s in [-1,1]:
        o=profile_x('SWIFT continuous curved silver yoke',yoke,.042,s*.169,silver,carriage,head,.006)
        for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
        # Behind the external boss, one uninterrupted axle crosses the receiver.
        cyl('SWIFT trunnion dark bearing',.048,.024,(s*.194,.135,.213),dark,carriage,head,32,'X',.004)
        cyl('SWIFT bronze pivot boss',.036,.021,(s*.211,.135,.213),bronze,carriage,head,24,'X',.003)
        cyl('SWIFT recessed pivot hub',.018,.027,(s*.225,.135,.213),dark,carriage,head,24,'X',.002)
        for y,z in [(-.240,.218),(-.150,.165),(.126,.252)]:bolt('SWIFT yoke fastening',(s*.194,y,z),head,carriage,'X',.004)
    cube('SWIFT bearing bridge across both yokes',(0,.009,.081),(.359,.183,.039),dark,carriage,head,.008)
    cube('SWIFT lower receiver saddle',(0,.032,.163),(.286,.246,.072),dark,carriage,head,.023)
    cyl('SWIFT continuous trunnion axle',.034,.405,(0,.135,.213),silver,carriage,head,32,'X',.003)
    # Section y, half-width, bottom, lower side, upper side, roof.
    controls=[(-.302,.069,.263,.275,.313,.340),(-.235,.087,.243,.262,.322,.358),(-.151,.116,.232,.247,.343,.393),(-.061,.144,.202,.221,.370,.435),(.037,.157,.195,.222,.393,.458),(.129,.153,.223,.246,.389,.451),(.211,.132,.262,.278,.367,.414),(.276,.082,.283,.297,.327,.350),(.291,.040,.301,.309,.320,.329)]
    # Match the approved low flowing crown: local shell compression only.
    roof_drop=[0,.003,.010,.019,.025,.023,.017,.010,.004]
    shoulder_drop=[0,.001,.006,.010,.012,.014,.012,.006,.002]
    belly_raise=[0,0,.007,.015,.015,.010,.005,0,0]
    controls=[(y,w,b+db,lo+db,hi-dh,t-dt) for (y,w,b,lo,hi,t),dt,dh,db in zip(controls,roof_drop,shoulder_drop,belly_raise)]
    sections=catmull(controls,4)
    verts=[]
    for y,w,b,lo,hi,t in sections:
        verts.extend([(x,y,z) for x,z in [(-w*.48,t),(w*.48,t),(w*.84,t-.010),(w,hi),(w,lo),(w*.68,b),(-w*.68,b),(-w,lo),(-w,hi),(-w*.84,t-.010)]])
    faces=[tuple(reversed(range(10))),tuple(range(len(verts)-10,len(verts)))]
    for i in range(len(sections)-1):
        for j in range(10):faces.append((i*10+j,i*10+(j+1)%10,(i+1)*10+(j+1)%10,(i+1)*10+j))
    body=mesh('SWIFT swept teardrop receiver shell',verts,faces,iron,gunparts,gun,.003)
    body.data.materials.append(silver)
    for p in body.data.polygons:
        if p.index>=2:
            segment=(p.index-2)//10;face=(p.index-2)%10
            # Thick silver upper shoulders flow into the tapered nose, then a
            # dark rounded back closes the silhouette instead of an octagon cap.
            if face in [1,2,8,9] and sections[segment][0]<.158:p.material_index=1
            p.use_smooth=True
    # A narrow physical silver seam continues around the dark rear shoulder.
    def sample(y):
        for a,b in zip(sections[:-1],sections[1:]):
            if a[0]<=y<=b[0]:
                f=(y-a[0])/(b[0]-a[0]);return tuple(x+(yy-x)*f for x,yy in zip(a,b))
        return sections[0] if y<sections[0][0] else sections[-1]
    for s in [-1,1]:
        strip=[]
        for y in [sections[i][0] for i in range(len(sections)) if sections[i][0]>.126]:
            _,w,b,lo,hi,t=sample(y);strip.append((s*(w+.0009),y,hi-.004))
        flat_inlay('SWIFT rear shoulder silver seam',strip,.005,silver,gun,gunparts,(s,0,0))
        diamond=[(.017,.374),(.046,.322),(.017,.270),(-.012,.322),(.017,.374)]
        paths=[]
        for a,b in zip(diamond[:-1],diamond[1:]):
            for j in range(8):
                f=j/8;y=a[0]*(1-f)+b[0]*f;z=a[1]*(1-f)+b[1]*f;w=sample(y)[1];paths.append((s*(w+.00035),y,z))
        paths.append((s*(sample(diamond[-1][0])[1]+.00035),*diamond[-1]))
        flat_inlay('SWIFT flush diamond recessed outline',paths,.008,dark,gun,gunparts,(s,0,0))
        flat_inlay('SWIFT flush cyan diamond inlay',[(x+s*.0006,y,z) for x,y,z in paths],.0048,rune,gun,gunparts,(s,0,0))
        for y,z in [(-.211,.288),(.184,.341)]:bolt('SWIFT shell flush fastening',(s*(sample(y)[1]+.003),y,z),gun,gunparts,'X',.0035)
    # A low, swept housing grows out of the roof; its circular optic sits behind
    # the outer metal rim, not on a raised cylinder glued on the shell.
    optic=loft('SWIFT integrated swept sight housing',[(-.174,.047,.045),(-.124,.050,.039),(.033,.049,.018),(.078,.039,.010)],silver,gunparts,gun,.006)
    # The housing rises gently toward the rear in world Z; all sections attach.
    for v in optic.data.vertices:
        v.co.z+=.420+(v.co.y+.174)*.08
    ring('SWIFT sight silver recessed bezel',.044,.034,.023,(0,-.184,.420),silver,gunparts,gun,48,'Y',.0018)
    ring('SWIFT sight dark inner well',.034,.025,.024,(0,-.184,.420),dark,gunparts,gun,48,'Y',.001)
    cyl('SWIFT inset cyan aiming lens',.024,.003,(0,-.194,.420),rune,gunparts,gun,48,'Y',.0007)
    ring('SWIFT lens retaining line',.027,.024,.003,(0,-.193,.420),bronze,gunparts,gun,48,'Y',.0005)
    for s in [-1,1]:bolt('SWIFT optical housing fastening',(s*.048,-.140,.422),gun,gunparts,'X',.0035)
    return body
