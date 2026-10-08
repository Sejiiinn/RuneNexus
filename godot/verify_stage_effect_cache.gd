extends SceneTree
## Selected-family loading, shared identity, eviction and cancellation contracts.
const Preparation = preload("res://presentation/effect_preparation.gd")
const Resources = preload("res://presentation/stage_resources.gd")
const Projectiles = preload("res://presentation/battlefield_projectiles.gd")
const Units = preload("res://presentation/battlefield_units.gd")
const Burn = preload("res://effects/enemy_burn.gd")
const Frost = preload("res://effects/enemy_frost.gd")
const Fire = preload("res://effects/runic_fire.gd")
const Status = preload("res://effects/guardian_status.gd")
const Lightning = preload("res://effects/lightning_attack.gd")
class Battle extends Node3D:
	var _world_environment := Environment.new()
	var sun := DirectionalLight3D.new()
	var camera := Camera3D.new()
	var world := Node3D.new()
	var _projectile_renderer
	var _stage_manifest := {}
	var _stage_preparation_generation := 0
	var last_frame := {"time": 0.0}
	var field: Dictionary:
		get: return _projectile_renderer.field
	func _ready():
		add_child(world)
		add_child(camera)
		add_child(sun)
		_projectile_renderer = Projectiles.new(world, camera)
var scene: Battle
var failures := []
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	if not value: failures.append(label);push_error(label)
func select(enemies: Array, towers: Array):
	var paths := Preparation.resource_paths(enemies,towers)
	for kind: String in enemies:
		paths.append(Units.ENEMY_MODELS[kind])
		if kind in ["normal", "fast", "tank"]: paths.append("res://assets/enemies/%s_death.glb" % kind)
	for kind: String in towers: paths.append(Units.TURRET_MODELS[kind])
	check(Resources.prepare(paths), "resource paths resolve")
	scene._stage_preparation_generation += 1
	scene._stage_manifest = {"enemy_types":enemies,"tower_types":towers}
	check(scene._projectile_renderer.configure_stage(towers), "projectile families configure")
	Preparation.retain_stage(enemies,towers)
	Resources.retain(paths,"probe")
func prepare() -> bool:
	var preparation := Preparation.new()
	scene.add_child(preparation)
	var result: bool = await preparation.prepare(scene,scene._stage_manifest)
	preparation.free()
	return result
func run():
	check(Resources.snapshot().count == 0, "Effect script loading has no authored resources")
	for path: String in ["res://assets/enemies/boss.glb", "res://assets/effects/enemy_frost/crystals.glb", "res://assets/effects/enemy_burn/flame_atlas.png", "res://effects/lightning_attack_meshes/beam00.res"]:
		check(not ResourceLoader.has_cached(path), "script graph does not eagerly preload " + path)
	scene=Battle.new();root.add_child(scene)
	select(["normal"],["arrow"])
	check(await prepare(), "arrow-only preparation succeeds without cannon")
	check(scene.field.is_empty(), "no cannon field on arrow stage")
	check(scene._projectile_renderer._ballistic_pool.arrow.size()==2, "arrow reserves prepared")
	check(Fire._meshes.is_empty() and Burn._material==null and Frost._coat==null and Lightning._mesh_cache.is_empty(), "ineligible effect families stay cold")
	var arrow = scene._projectile_renderer._ballistic_pool.arrow.back()
	check(await prepare(), "repeat preparation succeeds")
	check(scene._projectile_renderer._ballistic_pool.arrow.back()==arrow, "shared prepared reserve reused")
	select(["normal","armored"],["arrow","cannon","magic","frost","lightning"])
	check(await prepare(), "mixed preparation succeeds")
	check(Burn._multimeshes.keys()==["armored"] and Frost._multimeshes.keys()==["armored"], "rigid status geometry created for required family only")
	var coat = Frost._coat
	var normal_status = Status._materials["EnemyFrost:normal"][0]
	var field_ref = weakref(scene.field.texture)
	select(["normal"],["magic","frost"])
	check(Frost._coat==coat and Status._materials["EnemyFrost:normal"][0]==normal_status, "overlapping status materials retained")
	check(Burn._multimeshes.is_empty() and Frost._multimeshes.is_empty(), "obsolete rigid family geometry evicted")
	check(scene._projectile_renderer.impact_pool.is_empty() and scene._projectile_renderer._ballistic_pool.cannon.is_empty(), "obsolete cannon pools evicted")
	check(field_ref.get_ref()==null, "cannon field GPU resource released after last owner")
	check(await prepare(), "retained family re-prepares")
	select(["fast"],["arrow"])
	check(Status._materials.is_empty() and Frost._body_materials.is_empty() and Frost._skinned_coats.is_empty(), "obsolete enemy source materials unpinned")
	check(Fire._meshes.is_empty() and Burn._material==null and Frost._coat==null, "ineligible shared status/weapon caches evicted")
	check(await prepare(), "new family prepares after eviction")
	select(["normal"],["magic"])
	var outcomes=[]
	cancelled_prepare(outcomes)
	scene._stage_preparation_generation += 1
	scene._stage_manifest = {"enemy_types":["fast"],"tower_types":["arrow"]}
	await process_frame
	await process_frame
	check(outcomes==[false], "generation switch cancels rehearsal")
	check(scene._projectile_renderer._fire_projectile_pool.is_empty(), "cancelled rehearsal cannot adopt stale pools")
	scene._projectile_renderer.clear()
	scene.free()
	Preparation.retain_stage([],[])
	Resources.clear()
	print("STAGE_EFFECT_CACHE failures=", failures)
	quit(0 if failures.is_empty() else 1)
func cancelled_prepare(outcomes: Array): outcomes.append(await prepare())
