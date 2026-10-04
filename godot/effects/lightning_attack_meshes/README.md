# Lightning A spatial effect resources

These meshes were baked from the approved `lightning-A-attack-editable.blend`
with the added spherical aura. They preserve the curve control points, branch
depth and point-radius taper. Dominant spine widths remain exact; fine branches
compensate for the reduced side count to preserve mean projected width. The
approved stronger discharge/impact profile remains in the reproducible bake. Curves keep capped six-sided dominant spines and four-sided fine branches.
The latter compensate mean projected width to preserve game-camera strength. Core and sheath share a single additive surface.

- `charge00`–`charge03`: four authored charge-current variants, 2,920 triangles each
- `beam00`–`beam03`: discharge branches, 2,352 triangles each
- `beam04`–`beam05`: sparser late discharge branches, 1,344 triangles each
- `feed00`–`feed03`: two electrode currents per feed, 368 triangles each
- `impact`: seven spatial contact forks, 1,064 triangles

All 15 resources together contain 13,848 vertices and 26,312 triangles. Only the
current phase is visible. No mesh is built, duplicated or retessellated per shot.
The 288-triangle charge sphere hull is shared and generated once by Godot's
`SphereMesh`. It encloses the shader's unchanged analytic sphere; the visible
volume is not reduced to a faceted ball.

Coordinate conversion is Blender `(x, y, z)` to Godot `(x, z, -y)`. Release and
feed paths are normalized along their actual source-to-target axes. `UV2.x`
stores the centerline station, allowing the vertex shader to stretch the center
path without stretching tube thickness. Vertex colors contain the core/sheath
color and opacity; `UV.y` distinguishes the hot core.

The presentation layer supplies actual world-space sources, target contacts and
event age. These resources contain no demo target or fixed turret placement.
The module owns no lights, gameplay state, wall clock or particle simulation.

Reproducible authoring utilities and the approved source are under
`design/lightning_tower_concepts/approved_a/`: `extract_lightning_paths.py`,
`lightning_paths.json`, and `bake_lightning.gd`.
Headless module verification: `godot/verify_lightning_attack.gd`. Rendering and
mobile performance must be checked separately in the actual game.
