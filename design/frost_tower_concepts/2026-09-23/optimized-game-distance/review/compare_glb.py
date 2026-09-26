from pathlib import Path
import json,struct,hashlib,subprocess,sys
R=Path.cwd();O=Path(__file__).resolve().parent
baseline=subprocess.check_output(['git','show','1bb0c1365481d05183c6c4110310a35add423a25:assets/images/stage1_3d/turrets/frost.glb'],cwd=R)
assert hashlib.sha256(baseline).hexdigest()=='e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544'
reports=[]
for label,raw in [('original',baseline),('optimized',Path(sys.argv[1]).read_bytes())]:
 n=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+n]);buf=raw[28+n:]
 r={'variant':label,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'meshes':len(j['meshes']),'surfaces':sum(len(m['primitives']) for m in j['meshes']),'nodes':j['nodes'],'materials':[m.get('name','') for m in j['materials']],'triangles':0,'material_triangles':{},'textures':[]}
 for m in j['meshes']:
  for p in m['primitives']:
   t=j['accessors'][p['indices']]['count']//3;r['triangles']+=t;k=j['materials'][p['material']]['name'];r['material_triangles'][k]=r['material_triangles'].get(k,0)+t
 for im in j['images']:
  v=j['bufferViews'][im['bufferView']];b=buf[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']];r['textures'].append({'name':im.get('name'),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'png_dimensions':list(struct.unpack('>II',b[16:24])) if b.startswith(b'\x89PNG') else None})
 r['charge_material_names_present']=all(any(s in k for k in r['materials']) for s in ['cold aluminum fins','cold circulating core'])
 assert r['charge_material_names_present']
 reports.append(r)
a,b=reports
out={'variants':reports,'triangle_reduction_percent':100*(1-b['triangles']/a['triangles']),'file_reduction_percent':100*(1-b['bytes']/a['bytes']),'texture_payloads_equal':sorted(x['sha256'] for x in a['textures'])==sorted(x['sha256'] for x in b['textures'])}
(O/'asset-comparison.json').write_text(json.dumps(out,indent=2)+'\n');print({k:v for k,v in out.items() if k!='variants'})
