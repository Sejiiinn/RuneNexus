extends RefCounted
## Stage-map state and stage data shared by the map, the stage card and app navigation.
const Progression = preload("res://content/stage_progression.gd")
const Quests = preload("res://app/quest_progress.gd")
const RewardArt = preload("res://ui/stage_reward_art.gd")
const CHAPTERS := ["초원 초입", "균열 장막", "공명 용광로"]

var lobby
var chapter := 0
var selected := 0
var active_stage_seen := 0

func setup(owner) -> void:
	lobby = owner

func _state() -> Dictionary:
	return lobby.app.run_domain.state

func _stage_number() -> int:
	return int(_state().get("stage", 0)) + 1

func unlocked(stage: int) -> bool:
	return Progression.stage_unlocked(lobby.progression(), stage) and stage <= lobby.app.catalog.stage_count()

func active(stage: int) -> bool:
	return lobby.has_active_run() and stage == _stage_number()

func cleared(stage: int) -> bool:
	return stage in lobby.progression().get("clearedStageNumbers", [])

func rune_reward(stage: int) -> int:
	# Pure preview of the existing settlement calculation; returned state is discarded.
	var preview: Dictionary = Quests.new().finish(lobby.progression(), {"stageNumber":stage, "completedRounds":lobby.app.catalog.wave_count(stage - 1), "success":true, "grantEconomyRewardsLocally":false})
	return int(preview.lastRunRuneReward)

func best_rounds(stage: int) -> int:
	return int(lobby.progression().get("bestRoundsByStage", {}).get(str(stage), 0))

func reset_navigation() -> void:
	chapter = 0
	selected = 0
	active_stage_seen = 0

## Opens on the active run's chapter, otherwise the newest unlocked one, and
## follows a newly started run there. Keeps the player's own selection otherwise.
func ensure_selection() -> void:
	if lobby.has_active_run() and _stage_number() != active_stage_seen:
		active_stage_seen = _stage_number()
		chapter = Progression.chapter_for(active_stage_seen)
		selected = active_stage_seen
	if chapter == 0:
		var current := 1
		for id in Progression.ordered_ids():
			if unlocked(id): current = id
		chapter = Progression.chapter_for(current)
	if selected == 0 or Progression.chapter_for(selected) != chapter:
		selected = default_selection(chapter)

## The active run, else the first unlocked stage not yet cleared, else the last unlocked one.
func default_selection(value: int) -> int:
	var ids: Array = Progression.ids_for_chapter(value)
	if ids.is_empty(): return 0
	if lobby.has_active_run() and _stage_number() in ids: return _stage_number()
	var last_open: int = ids[0]
	for id in ids:
		if not unlocked(id): break
		last_open = id
		if not cleared(id): return id
	return last_open

func select_chapter(value: int) -> void:
	chapter = clampi(value, 1, CHAPTERS.size())
	selected = default_selection(chapter)

func _continue() -> void:
	lobby.close_modal()
	if not await lobby.app.resume_run(): lobby.show_failure()

func start(stage: int) -> void:
	if active(stage):
		_continue()
		return
	if not unlocked(stage): return
	lobby.close_modal()
	lobby.request_stage_start(stage - 1)

func unlock_items(stage: int) -> Array:
	var items: Array = Progression.unlock_items(stage)
	if stage == 11: items.push_front(["모듈 티켓 %d장" % int(lobby.app.catalog.stage_summary(stage - 1).get("firstClearTurretModuleTicketReward", 0)), "stage_rewards/reward_module_ticket.png", "티켓"])
	return items

## Turret unlocks carry a font glyph id; show the same turret art the HUD uses.
static func unlock_icon(item: Array) -> String:
	return RewardArt.for_reward(str(item[1]))

## Where a first-clear unlock shows up, in a few words.
static func unlock_destination(item: Array) -> String:
	return {"강화":"강화 탭에 추가", "연구":"연구 탭에 추가", "젬":"보상 젬에 추가", "포탑":"포탑 해금", "코어":"코어 스킬 추가", "구조물":"구조물 해금", "티켓":"모듈 티켓 지급"}.get(str(item[2]), str(item[2]))

## Prerequisite stage shown on a locked stage's action.
static func previous_stage(stage: int) -> int:
	var ordinal := Progression.ordinal_for(stage)
	return Progression.ordered_ids()[maxi(0, ordinal - 2)] if ordinal > 1 else stage

func reward_highlighted(stage: int) -> bool:
	if stage == 3 and lobby.progression().has("availableTurretTypes"):
		return "sniper" in lobby.progression().availableTurretTypes
	var found := false
	for kind in Progression.REQUIREMENTS:
		for key in Progression.REQUIREMENTS[kind]:
			if Progression.requirement(kind,key) != stage: continue
			found = true
			if not Progression.has_unlock(lobby.progression(),kind,key): return false
	return found or cleared(stage)
