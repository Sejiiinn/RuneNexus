"""Check rebaked atlas interiors, overlap and tangent-normal pixels.

Run with the existing xatlas environment (numpy/Pillow). Constant untextured
materials deliberately share a UV point and are excluded.
"""
from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image
OUT=Path(__file__).resolve().parents[1];SIZE=2048
hits=np.zeros((SIZE,SIZE),np.uint16);lens=np.zeros_like(hits,bool)
for mi in (0,2):
    data=np.load(OUT/'checks'/f'mesh{mi}-uv.npz');geom=np.load(OUT/'checks'/f'mesh{mi}-geometry.npz')
    triangles=data['loop_uv'].reshape(-1,3,2)
    assignment=np.load(OUT/'checks'/f'mesh{mi}-assignment.npz')['material_index']
    mask=np.isin(assignment,[0,1,4,5,8,12])
    assert np.isfinite(triangles).all() and triangles.min()>=0 and triangles.max()<=1
    for ti in np.flatnonzero(mask):
        q=triangles[ti]*SIZE-.5;lo=np.maximum(np.ceil(q.min(0)).astype(int),0);hi=np.minimum(np.floor(q.max(0)).astype(int),SIZE-1)
        if np.any(hi<lo):continue
        yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];r=np.stack((xx-q[0,0],yy-q[0,1]),axis=-1);a=q[1]-q[0];b=q[2]-q[0];den=a[0]*b[1]-a[1]*b[0]
        assert abs(den)>1e-10
        v=(r[...,0]*b[1]-r[...,1]*b[0])/den;w=(a[0]*r[...,1]-a[1]*r[...,0])/den
        # A complete 1-pixel footprint must lie inside this triangle. Chart-edge
        # interpolation is deliberately excluded from normal-vector checks.
        area2=abs(den);heights=area2/np.array([np.linalg.norm(q[2]-q[1]),np.linalg.norm(b),np.linalg.norm(a)])
        inside=(v>1./heights[1])&(w>1./heights[2])&((1-v-w)>1./heights[0])
        hits[lo[1]:hi[1]+1,lo[0]:hi[0]+1]+=inside
        if mi==2 and geom['low_groups'][ti]==297:lens[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=inside
strict=hits>0
# PNG row0 is UV v=1; raster above has v=0 row0.
normal=np.asarray(Image.open(OUT/'textures/frost-normal.png').convert('RGB'),np.float32)[::-1]/255
basecolor=np.asarray(Image.open(OUT/'textures/frost-basecolor.png').convert('RGB'))[::-1]
basecolor_miss=(basecolor.max(-1)==0)&strict
vectors=normal*2-1;length=np.linalg.norm(vectors,axis=-1)
miss=(normal.max(-1)<.02)&strict
# Baked/filter-averaged normal vectors need not be unit length: the normal
# shader normalizes them. Keep shortened vectors as a diagnostic, reject
# degenerate vectors, impossible lengths and reversed tangent hemispheres.
bad=((length<.25)|(length>1.2))&strict
short=(length<.8)&strict
negative=(vectors[...,2]<-.02)&strict
report={'glb_sha256':hashlib.sha256((OUT/'frost-rebaked-10k.glb').read_bytes()).hexdigest(),'textured_strict_interior_pixels':int(strict.sum()),'strict_overlap_pixels':int((hits>1).sum()),'basecolor_black_miss_pixels':int(basecolor_miss.sum()),'normal_miss_pixels':int(miss.sum()),'normal_invalid_length_pixels':int(bad.sum()),'normal_shortened_vector_pixels':int(short.sum()),'normal_negative_z_pixels':int(negative.sum()),'normal_length_min_max':list(map(float,(length[strict].min(),length[strict].max()))),'normal_length_note':'Filter-averaged source/bake vectors may be shortened; normal shader normalizes nondegenerate vectors. Counts remain diagnostic.','lens_strict_pixels':int(lens.sum()),'constant_uv_overlap':'intentional; original untextured/charge materials do not sample UV','maps':{}}
for name in ('basecolor','normal','orm','emission'):
    p=OUT/'textures'/f'frost-{name}.png';im=Image.open(p)
    report['maps'][name]={'size':list(im.size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
report['status']='PASS' if not report['strict_overlap_pixels'] and not report['basecolor_black_miss_pixels'] and not report['normal_miss_pixels'] and not report['normal_invalid_length_pixels'] and not report['normal_negative_z_pixels'] else 'FAIL'
(OUT/'map-validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));assert report['status']=='PASS'
