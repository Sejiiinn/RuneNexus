"""Export tracked full-geometry native sources without regeneration or baking.

Background Blender only. All outputs/reports are local checks, never game assets
or original sources. Available after a fresh checkout when ignored before.glbs
are absent; pass --suffix regenerated to retain an existing A/B baseline.
"""
import ast, argparse, hashlib, json, sys
from pathlib import Path
import bpy
OUT=Path(__file__).resolve().parents[1];ROOT=OUT.parents[2]
SOURCES={'chapter2_tiles':'design/chapter2_3d/tiles/chapter2-tiles.blend','chapter2_tiles_optimized':'design/chapter2_3d/optimization/chapter2-tiles-optimized.blend','chapter2_tiles_expansion':'design/stage_expansion_runtime/chapter2-expansion-tile-variants.blend'}
def module(path):
    nodes=[]
    for node in ast.parse(path.read_text()).body:
        if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='parser' for t in node.targets):break
        if isinstance(node,ast.If) and isinstance(node.test,ast.Compare) and isinstance(node.test.left,ast.Name) and node.test.left.id=='__name__':continue
        nodes.append(node)
    ns={'__file__':str(path),'__name__':'source_export_library'};exec(compile(ast.Module(body=nodes,type_ignores=[]),str(path),'exec'),ns);return ns

def main():
    assert bpy.app.background
    parser=argparse.ArgumentParser();parser.add_argument('--suffix',default='before');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    target=OUT/'checks';target.mkdir(parents=True,exist_ok=True);records=[]
    for asset,relative in SOURCES.items():
        source=ROOT/relative;sha=hashlib.sha256(source.read_bytes()).hexdigest();output=target/f'{asset}-{args.suffix}.glb';assert not output.exists(),f'Preserve existing baseline: {output}'
        bpy.ops.wm.open_mainfile(filepath=str(source))
        script=ROOT/('design/chapter2_3d/tiles/build_tiles.py' if asset=='chapter2_tiles' else 'design/chapter2_3d/optimization/build_tile_variants.py')
        ns=module(script);ns['TARGET']=output;ns['HERE']=target
        if asset=='chapter2_tiles':ns['export_tiles']()
        else:
            # Expansion contains only three additional masks; export saved
            # hierarchy directly, without regenerating from map definitions.
            root=bpy.data.objects['chapter2_tiles_optimized'];bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
            for ob in root.children_recursive:ob.select_set(True)
            bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
        assert hashlib.sha256(source.read_bytes()).hexdigest()==sha
        records.append(dict(asset=asset,source=relative,source_sha256=sha,output=str(output.relative_to(ROOT)),output_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),rebaked=False,regenerated=False))
    (target/f'baseline-{args.suffix}.json').write_text(json.dumps(dict(blender=bpy.app.version_string,records=records),indent=2)+'\n');print('FULL_GEOMETRY_BASELINES_READY',flush=True)
if __name__=='__main__':main()
