"""Create a common non-overlapping atlas without changing geometry."""
import numpy as np,xatlas,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]
atlas=xatlas.Atlas();inputs=[]
geometry=json.loads((OUT/'geometry-manifest.json').read_text())
textured_materials={0,1,4,5,8,12}
common_scale=4.
for mi in range(3):
    data=np.load(OUT/'checks'/f'mesh{mi}-geometry.npz');v=data['positions'];f=data['low_faces']
    groupmask=np.array([bool(set(part['materials'])&textured_materials) for part in geometry['records'][mi]['parts']])
    textured=groupmask[data['low_groups']]
    if not textured.any():
        np.savez_compressed(OUT/'checks'/f'mesh{mi}-uv.npz',loop_uv=np.full((f.size,2),.5,np.float32),textured_faces=textured)
        continue
    selected=f[textured]
    q=v[selected].astype(np.float64);areas=np.linalg.norm(np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]),axis=1)*.5
    assert areas.min()>0
    scale=common_scale
    chart_positions=v.copy()
    if mi==2:
        # More samples for the visible cracked lens, within the same 2k atlas.
        lens_parts=[i for i,p in enumerate(geometry['records'][mi]['parts']) if 12 in p['materials']]
        lens_vertices=np.unique(f[np.isin(data['low_groups'],lens_parts)])
        chart_positions[lens_vertices]*=2.
    atlas.add_mesh(np.ascontiguousarray(chart_positions*scale,np.float32),np.ascontiguousarray(selected,np.uint32));inputs.append((mi,v,f,selected,textured,scale))
chart=xatlas.ChartOptions();chart.normal_deviation_weight=2;chart.normal_seam_weight=0;chart.max_cost=2;chart.max_iterations=2
pack=xatlas.PackOptions();pack.resolution=2048;pack.texels_per_unit=120.;pack.padding=8;pack.bilinear=True;pack.create_image=True
atlas.generate(chart_options=chart,pack_options=pack)
assert atlas.atlas_count==1
records=[]
for ai,(mi,v,f,selected,textured,scale) in enumerate(inputs):
    refs,indices,uv=atlas[ai];assert np.array_equal(refs[indices],selected);assert np.isfinite(uv).all() and uv.min()>=0 and uv.max()<=1
    loopuv=np.full((len(f),3,2),.5,np.float32);loopuv[textured]=uv[indices];loopuv=loopuv.reshape(-1,2)
    np.savez_compressed(OUT/'checks'/f'mesh{mi}-uv.npz',loop_uv=loopuv,textured_faces=textured)
    records.append({'mesh':mi,'triangles':len(f),'textured_triangles':int(textured.sum()),'chart_count':atlas.get_mesh_chart_count(ai),'input_scale':scale,'uv_min':uv.min(0).tolist(),'uv_max':uv.max(0).tolist(),'geometry_correspondence_exact':True})
report={'method':'xatlas 0.0.11','atlas_count':atlas.atlas_count,'width':atlas.width,'height':atlas.height,'padding':8,'lens_texel_density_multiplier':2,'constant_material_uv_overlap':'intentional at .5/.5; no textures, excluded from atlas/bake coverage checks','utilization':atlas.utilization,'records':records}
(OUT/'uv-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
