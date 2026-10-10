extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Fixture = preload("res://session/chapter_three_combat_fixture.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const LobbyFixture = preload("res://verify_lobby.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
class Host extends RefCounted:
	var _native_combat
class App extends RefCounted:
	var scene
	var catalog
	var run_domain
func _initialize() -> void:
	var catalog = Catalog.new()
	assert(catalog.load_catalog())
	for spec in [[26,10],[27,20],[28,10],[29,10],[30,30]]:
		var fixture: Dictionary = Fixture.create(catalog,spec[0],spec[1])
		assert(fixture.error.is_empty())
		var state: Dictionary = fixture.domain.state
		state.tileSize = 1.0
		var index: int = catalog.stage_index(spec[0])
		var derived: Dictionary = fixture.domain.service.derived(state)
		var bootstrap: Dictionary = catalog.bootstrap(index,{"tileSize":1.0,"defenseConfig":derived.defenseConfig,"coreConfig":fixture.domain.growth.core_config(state,index,spec[1]-1,catalog)})
		bootstrap.turrets = []
		for command in fixture.domain.service.runtime_commands(state): bootstrap.turrets.append(command.turret)
		var runtime = Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"session":{"clock":"godot","phase":"wave","paused":false}},false)
		state.phase = "wave"
		var rng := RandomNumberGenerator.new()
		rng.seed = Fixture.SEED+spec[0]*100+spec[1]
		var wave: Dictionary = catalog.wave(index,spec[1]-1,100000,{"tileSize":1.0,"spawnValues":catalog.random_spawn_values(index,spec[1]-1,rng)})
		runtime.process_command({"epoch":1,"sequence":1,"running":true,"commands":[{"kind":"waveStart","wave":wave}]},false)
		runtime.process_command({"epoch":1,"sequence":2,"ackEvent":runtime.event_id},false)
		var app := App.new()
		app.catalog = catalog
		app.run_domain = fixture.domain
		app.scene = Host.new()
		app.scene._native_combat = runtime
		var checkpoint = Checkpoint.new("/tmp/ch3-combat-checkpoint-%d" % spec[0])
		var result: Error = checkpoint.persist_state(app,state)
		if result != OK:
			push_error(str(spec)+": "+checkpoint.message)
			quit(1)
			return
		assert(runtime.turrets.size() == state.turrets.size())
		print("CHECKPOINT_CONTRACT ",spec," turrets=",runtime.turrets.size()," tile=",runtime.tile_size," saved=",result)
	var ui_app = LobbyFixture.FakeApp.new()
	assert(ui_app.catalog.load_catalog())
	ui_app.run_domain = Fixture.create(ui_app.catalog,28,10).domain
	ui_app.run_domain.state.phase = "wave"
	var lobby = LobbyFixture.Lobby.new()
	lobby.app = ui_app
	lobby.page = "로비"
	root.add_child(lobby)
	await process_frame
	await process_frame
	var continue_button := lobby.find_child("ContinueRun",true,false) as Button
	assert(continue_button != null,"actual home page exposes ContinueRun for seeded active run")
	continue_button.pressed.emit()
	assert(ui_app.resumes == 1,"actual ContinueRun button invokes resume_run")
	lobby.queue_free()
	await process_frame
	print("PASS chapter three native-coordinate checkpoint and Continue UI contract")
	quit()
