from pathlib import Path
import json,struct,hashlib,subprocess
R=Path.cwd();O=Path(__file__).resolve().parent
paths=[R/'assets/images/stage1_3d/environment/chapter3_props.glb',O.parent/'chapter3-props-optimized.glb']
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def hit(tris,o,d):
 best=None
 for a,b,c in tris:
  e1,e2=sub(b,a),sub(c,a);h=cross(d,e2);det=dot(e1,h)
  if abs(det)<1e-10:continue
  s=sub(o,a);u=dot(s,h)/det
  if u<0 or u>1:continue
  q=cross(s,e1);v=dot(d,q)/det
  if v<0 or u+v>1:continue
  t=dot(e2,q)/det
  if t>1e-7 and(best is None or t<best):best=t
 return best
reports=[]
for variant_index,path in enumerate(paths):
 raw=subprocess.check_output(['git','show','0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047:assets/images/stage1_3d/environment/chapter3_props.glb'],cwd=R) if variant_index==0 else path.read_bytes()
 if variant_index==0:assert hashlib.sha256(raw).hexdigest()=='c4eb491ef578b6e91219b75b3a854ad4bb3b4b3e565cd0d866d55a5daacd7952'
 n=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+n]);buf=raw[28+n:]
 def accessor(i):
  a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];typ={5126:'f',5125:'I',5123:'H'}[a['componentType']];c={'SCALAR':1,'VEC3':3}[a['type']];size=struct.calcsize('<'+typ*c);off=v.get('byteOffset',0)+a.get('byteOffset',0)
  return [struct.unpack_from('<'+typ*c,buf,off+k*v.get('byteStride',size)) for k in range(a['count'])]
 r={'path':('git:0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047:'+str(path.relative_to(R))) if variant_index==0 else str(path.relative_to(R)),'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'material_count':len(j['materials']),'props':{}}
 for node in j['nodes']:
  if 'mesh' not in node:continue
  tris=[];verts=[]
  for p in j['meshes'][node['mesh']]['primitives']:
   vs=accessor(p['attributes']['POSITION']);ix=accessor(p['indices']);verts+=vs;tris += [tuple(vs[ix[k+t][0]] for t in range(3)) for k in range(0,len(ix),3)]
  kind=node['name'];lo=[min(v[k] for v in verts) for k in range(3)];hi=[max(v[k] for v in verts) for k in range(3)]
  assert lo[2]>=-.001 and lo[2]<=.006 and lo[1]>=-.505
  q={'triangles':len(tris),'bounds_min':lo,'bounds_max':hi,'identity_transform':not any(x in node for x in ['matrix','translation','rotation','scale'])}
  if kind=='elbow_pipe':q['bore_depth']=hit(tris,(0,.5,.215),(0,-1,0));assert q['bore_depth']>.6
  if kind=='side_conduit':q['through_bore_hit']=hit(tris,(-.6,-.25,.135),(1,0,0));assert q['through_bore_hit'] is None
  if kind=='exhaust_vent':
   q['bore_depth']=hit(tris,(0,.5,.143),(0,-1,0));assert q['bore_depth']>.9
   q['slot_front_z']=[.4-hit(tris,(x,-.264,.4),(0,0,-1)) for x in [-.051,0,.051]]
   assert all(.22<z<.235 for z in q['slot_front_z'])
   assert abs(lo[1]+.5)<.006 and hi[1]<=.31
  r['props'][kind]=q
 reports.append(r)
a,b=reports
r={'variants':reports,'historical_baseline_verified':a['sha256']=='c4eb491ef578b6e91219b75b3a854ad4bb3b4b3e565cd0d866d55a5daacd7952','bounds_max_error':max(abs(x-y) for k in a['props'] for field in ['bounds_min','bounds_max'] for x,y in zip(a['props'][k][field],b['props'][k][field]))}
r['stage11_triangles']=[sum(v['props'][k]['triangles']*count for k,count in [('elbow_pipe',2),('side_conduit',2),('exhaust_vent',1)]) for v in reports]
r['stage11_reduction_percent']=100*(1-r['stage11_triangles'][1]/r['stage11_triangles'][0]);r['size_reduction_percent']=100*(1-b['bytes']/a['bytes'])
(O/'asset-comparison.json').write_text(json.dumps(r,indent=2)+'\n');print({k:v for k,v in r.items() if k!='variants'})
