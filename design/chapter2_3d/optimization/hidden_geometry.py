"""Shared conservative hidden-face deletion; retained faces and UVs stay intact."""
import bmesh

def prune_hidden_faces(original, copy, local):
    # Interior grout is opaque from Z=-.45 to -.085, with bevelled perimeter.
    # Only remove faces whose EVERY vertex is comfortably inside that solid,
    # or entirely below geology's -.39 surface. Never alter a retained face.
    doomed=[]
    removed_faces=0
    for face in copy.data.polygons:
        points=[local@copy.data.vertices[v].co for v in face.vertices]
        buried=all(abs(p.x)<.47 and abs(p.y)<.47 and -.44<p.z<-.09 for p in points)
        below=all(abs(p.x)<.48 and abs(p.y)<.48 and p.z<-.405 for p in points)
        if (buried and not original.name.startswith('inner_foundation')) or below:
            doomed.append(face.index);removed_faces+=len(face.vertices)-2
    if doomed:
        bm=bmesh.new();bm.from_mesh(copy.data);bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=[bm.faces[i] for i in doomed],context='FACES')
        bm.to_mesh(copy.data);bm.free();copy.data.update()
    return removed_faces
