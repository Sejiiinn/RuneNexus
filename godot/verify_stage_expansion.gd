extends SceneTree
const Progress = preload("res://content/stage_progression.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Quest = preload("res://app/quest_progress.gd")
const Codec = preload("res://app/save_codec.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Outbox = preload("res://app/reward_outbox.gd")
const Store = preload("res://app/local_save_store.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
class RejectMigrationStore extends Store:
	func save_save(data: Dictionary) -> Error:
		if data.progression.has("progressionVersion"):
			last_error = ERR_CANT_CREATE
			last_error_message = "Injected migration write failure"
			return last_error
		return super.save_save(data)
class ProgressionApp extends RefCounted:
	var progression_inputs: Dictionary = {}
const Hash = preload("res://services/save_payload_hash.gd")
var failures := 0
var checks := 0
func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures += 1; printerr(label)
func _initialize() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(),"content loads")
	check(catalog.stage_count() == 25,"25 fixed stages")
	check(Progress.ids_for_chapter(1) == [1,2,3,4,5,16,17,18,19,20],"chapter one display order")
	check(Progress.ids_for_chapter(2) == [6,7,8,9,10,21,22,23,24,25],"chapter two display order")
	check(Progress.stage_label(11) == "3-1" and Progress.stage_label(16) == "1-6" and Progress.stage_label(25) == "2-10","labels preserve IDs")
	var fresh: Dictionary = growth.data.defaultProgression.duplicate(true)
	for kind in ["upgrade","research","turret","gem","core","feature"]:
		for key in Progress.REQUIREMENTS[kind]:
			var required := Progress.requirement(kind,key)
			check(Progress.has_unlock(fresh,kind,key) == (required == 0),"fresh gate %s:%s" % [kind,key])
	var rich := fresh.duplicate(true)
	rich.runes = 100000
	check(not growth.execute(rich,{"kind":"upgradePermanent","id":"bossBounty"}).ok,"new account command cannot bypass boss bounty gate")
	check(not growth.execute(rich,{"kind":"startResearch","id":"linkMaintenance","nowMillis":100}).ok,"new account command cannot bypass research gate")
	var rich_old := Progress.migrate_progression({"growthVersion":1,"runes":100000})
	check(growth.execute(rich_old,{"kind":"upgradePermanent","id":"bossBounty"}).ok and growth.execute(rich_old,{"kind":"startResearch","id":"linkMaintenance","nowMillis":100}).ok,"legacy level0 purchase and research rights")
	var old := {"growthVersion":1,"unlockedStageCount":11,"clearedStageNumbers":[1,2,6,8,10],"researchLevels":{},"activeResearches":[],"runes":77,"researchSlotTwoUnlocked":false}
	var migrated := Progress.migrate_progression(old)
	check(migrated.runes == 77 and migrated.clearedStageNumbers == old.clearedStageNumbers,"migration no currency/clear creation")
	for pair in [["upgrade","bossBounty"],["research","linkMaintenance"],["research","gemAttunement"],["turret","lightning"],["gem","armorPiercing"],["feature","researchSlotTwo"],["feature","researchSlotTwoPreview"],["core","riftMark"]]:
		check(Progress.has_unlock(migrated,pair[0],pair[1]),"legacy zero-level right "+str(pair))
	check(not migrated.researchSlotTwoUnlocked,"slot purchase not granted")
	var old_ten := Progress.migrate_progression({"growthVersion":1,"clearedStageNumbers":[10],"researchSlotTwoUnlocked":false})
	check(Progress.has_unlock(old_ten,"feature","researchSlotTwoPreview") and Progress.has_unlock(old_ten,"feature","researchSlotTwo") and not old_ten.researchSlotTwoUnlocked,"legacy ID10 only preview and purchase eligibility")
	check(Progress.stage_unlocked(migrated,11) and not Progress.stage_unlocked(migrated,25),"old stage access, no inserted fake clear")
	check(migrated == Progress.migrate_progression(migrated),"migration idempotent")
	var ancient := Progress.migrate_progression({"growthVersion":0,"runes":100,"criticalChanceUpgradeLevel":5,"emergencySaleUpgradeLevel":2,"researchLevels":{"bossBounty":3},"researchElapsedMillis":{"bossBounty":500},"activeResearches":[{"type":"bossBounty","targetLevel":6},{"type":"gemAttunement","targetLevel":1,"durationMillis":100,"startedAtMillis":50}]})
	check(ancient.researchLevels.criticalChance == 3 and ancient.researchLevels.emergencySale == 2 and ancient.bossBountyUpgradeLevel == 6,"old growth conversion once")
	check(ancient.runes == 100 and ancient.activeResearches.size() == 1 and ancient.activeResearches[0].durationMillis == 100 and not ancient.researchElapsedMillis.has("bossBounty"),"research time and no repayment")
	check(ancient == Progress.migrate_progression(ancient),"old growth idempotence")
	var quest = Quest.new()
	check(quest.finish(fresh,{"stageNumber":16,"completedRounds":40,"success":false}).lastRunRuneReward == 343,"new ID16 uses logical sixth-stage rune amount")
	check(quest.finish(fresh,{"stageNumber":11,"completedRounds":40,"success":false}).lastRunRuneReward == 4109,"existing ID11 uses logical twenty-first-stage rune amount")
	var reward := {"runId":"11111111-1111-4111-8111-111111111111","stageNumber":25,"completedRounds":40,"pendingDiamonds":0,"success":true,"createdAtMillis":123,"firstClearModuleTickets":0}
	check(Outbox.valid_reward(reward),"new fixed ID25 settlement accepted")
	reward.firstClearModuleTickets = 5
	check(not Outbox.valid_reward(reward),"new stage never receives ID11 module tickets")
	reward.stageNumber = 11
	check(Outbox.valid_reward(reward),"old fixed ID11 tickets remain accepted")
	var p := fresh.duplicate(true)
	for id in Progress.ordered_ids():
		check(Progress.stage_unlocked(p,id),"logical next gate "+str(id))
		var before := p.duplicate(true)
		p = quest.finish(p,{"stageNumber":id,"completedRounds":40,"success":true,"firstClearCorePointReward":2,"firstClearTurretModuleTicketReward":5 if id == 11 else 0})
		check(id in p.clearedStageNumbers and id in p.claimedCorePointStageRewards and p.totalCorePoints == Progress.ordinal_for(id)*2,"fixed first clear IDs "+str(id))
		check(p.lastRunTurretModuleTicketReward == (5 if id == 11 else 0),"fixed ID11 reward "+str(id))
		var repeated := quest.finish(p,{"stageNumber":id,"completedRounds":40,"success":true,"firstClearCorePointReward":2,"firstClearTurretModuleTicketReward":5 if id == 11 else 0})
		check(repeated.totalCorePoints == p.totalCorePoints and repeated.lastRunTurretModuleTicketReward == 0,"first clear no duplicate "+str(id))
		for kind in Progress.REQUIREMENTS:
			for key in Progress.REQUIREMENTS[kind]:
				if Progress.requirement(kind,key) == id: check(Progress.has_unlock(p,kind,key) and not Progress.has_unlock(before,kind,key),"clear unlock %s:%s" % [kind,key])
	var acquired := Progress.migrate_progression({"growthVersion":1,"clearedStageNumbers":[],"researchElapsedMillis":{"gemAttunement":100}}, {"turrets":[{"type":"lightning","equippedGemSlots":["armorPiercing"]}],"runCoreCombatSkill":"riftMark"}, {"items":[{"turretType":"sniper"}]})
	check(Progress.has_unlock(acquired,"turret","lightning") and Progress.has_unlock(acquired,"turret","sniper") and Progress.has_unlock(acquired,"gem","armorPiercing") and Progress.has_unlock(acquired,"core","riftMark") and Progress.has_unlock(acquired,"research","gemAttunement"),"old acquired evidence retained")
	var temp_root := OS.get_environment("TMPDIR").path_join("expansion-save")
	var checkpoint = Checkpoint.new(temp_root)
	checkpoint.allow_progression_only = true
	var old_save: Dictionary = Codec.decode({"version":2,"savedAtMillis":123,"progression":{"growthVersion":0,"runes":100,"criticalChanceUpgradeLevel":5,"emergencySaleUpgradeLevel":2,"researchLevels":{"bossBounty":3},"activeResearches":[{"type":"bossBounty","targetLevel":6,"startedAtMillis":50,"durationMillis":100}]},"turretModules":{},"preferences":{"selectedStageNumber":11},"activeRun":null})
	check(checkpoint.store.save_save(old_save) == OK,"store old raw normalized growth0")
	var app = ProgressionApp.new()
	var loaded_result: Error = checkpoint._load_content(app)
	check(loaded_result == OK,"formal app migration before play: "+checkpoint.message)
	if loaded_result != OK:
		quit(1); return
	var persisted: Dictionary = checkpoint.store.load_save()
	check(persisted.progression.progressionVersion == 1 and persisted.progression.growthVersion == 1 and persisted.progression.researchLevels.criticalChance == 3 and persisted.progression.bossBountyUpgradeLevel == 6 and persisted.preferences.selectedStageNumber == 11,"raw0 retained through decode then atomic migration")
	check(checkpoint._load_content(app) == OK and checkpoint.store.load_save() == persisted,"restart idempotence")
	checkpoint.store.clear()
	var failure_checkpoint = Checkpoint.new(temp_root+"-failure")
	failure_checkpoint.allow_progression_only = true
	failure_checkpoint.store = RejectMigrationStore.new(temp_root+"-failure")
	check(failure_checkpoint.store.save_save(old_save) == OK,"failure test preserves original save")
	var untouched_app = ProgressionApp.new()
	check(failure_checkpoint._load_content(untouched_app) == ERR_CANT_CREATE and untouched_app.progression_inputs.is_empty(),"failed migration blocks play without assigning state")
	check(failure_checkpoint.store.load_save() == old_save,"failed migration leaves original raw0 save intact")
	failure_checkpoint.store = Store.new(temp_root+"-failure")
	check(failure_checkpoint._load_content(untouched_app) == OK and untouched_app.progression_inputs.researchLevels.criticalChance == 3,"migration write retry retains entitlement and converts once")
	failure_checkpoint.store.clear()
	var service = Commands.new(catalog,growth)
	var adapter = Adapter.new(catalog,growth)
	for index in range(15,25):
		var source: Dictionary = catalog.stage(index)
		check(source.id == index+1 and source.waves.size() == 40,"append-only index "+str(index))
		for round_index in range(40):
			var wave: Dictionary = catalog.wave(index,round_index)
			check(not wave.is_empty() and wave.spawnQueue.size() == source.waves[round_index].spawnQueue.size(),"real wave %d:%d" % [source.id,round_index+1])
			var runtime = Runtime.new()
			var bootstrap: Dictionary = catalog.bootstrap(index)
			bootstrap.wave = wave
			runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","paused":false},"bootstrap":bootstrap})
			runtime._step(float(catalog.initial_delay())+0.01)
			check(not runtime.enemies.is_empty(),"native spawn %d:%d" % [source.id,round_index+1])
		var state: Dictionary = service.initial_state(p,index)
		state.phase = "wave"
		state.nexusHp = 20.0
		state.economyRunId = "expansion-run-%d" % source.id
		var runtime = Runtime.new()
		var bootstrap: Dictionary = catalog.bootstrap(index,{"defenseConfig":service.derived(state).defenseConfig,"coreConfig":growth.core_config(state,index,0,catalog)})
		bootstrap.wave = catalog.wave(index,0)
		runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","paused":true},"bootstrap":bootstrap})
		runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
		var saved: Dictionary = adapter.capture(state,runtime.snapshot(),123,{"selectedStageNumber":source.id})
		check(not saved.is_empty(),"v2 capture "+adapter.error)
		if saved.is_empty(): continue
		check(Codec.is_normalized_v2(saved) and saved.progression.progressionVersion == 1,"new fields roundtrip")
		var restored: Dictionary = adapter.prepare(saved)
		check(not restored.is_empty() and restored.stage == index and restored.state.economyRunId == state.economyRunId,"v2 new stage resume "+adapter.error)
		var changed := saved.duplicate(true)
		changed.progression.grandfatherUnlocks.append("research:gemAttunement")
		check(Hash.hash_payload(changed) != Hash.hash_payload(saved),"rights included in cloud hash")
	print("STAGE_EXPANSION failures=%d checks=%d nativeWaves=400" % [failures,checks])
	quit(1 if failures else 0)
