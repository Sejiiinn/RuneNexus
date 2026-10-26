extends SceneTree
## Isolated claim lifecycle regression: no live account or external API.
const Quest = preload("res://app/quest_progress.gd")
class Lobby extends "res://ui/lobby.gd":
	func _ready(): pass
class Credentials extends RefCounted:
	var credentials := {"accountId":"00000000-0000-4000-8000-000000000001"}
class Service extends Node:
	signal completed(result: Dictionary)
	var epoch := 1
	var account = Credentials.new()
	var requests: Array = []
	var busy := false
	var economy := {"busy":false}
	var issue := ""
	func connected() -> bool: return true
	func perform(action: String, target: Dictionary) -> Dictionary:
		requests.append({"action":action,"target":target.duplicate(true)})
		busy = true; economy.busy = true
		var result: Dictionary = await completed
		busy = false; economy.busy = false
		return result
class App extends RefCounted:
	var progression_inputs: Dictionary = {}
	var services
var failures: Array = []
var checks := 0
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func texts(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += texts(child)
	return result
func buttons(node: Node) -> Array:
	var result: Array = [node] if node is Button else []
	for child in node.get_children(): result.append_array(buttons(child))
	return result
func panels(node: Node) -> Array:
	var result: Array = [node.get_instance_id()] if node is PanelContainer else []
	for child in node.get_children(): result.append_array(panels(child))
	return result
func frames(count: int = 3):
	for i in range(count): await process_frame
func run():
	var app = App.new()
	app.progression_inputs = Quest.new().refresh({},1800450000000)
	app.progression_inputs.dailyQuestProgress = Quest.DAILY.duplicate()
	var service = Service.new(); root.add_child(service); app.services=service
	var host = Lobby.new(); host.app=app; host.theme=preload("res://ui/battle_theme.gd").create()
	root.add_child(host); host.size=Vector2(440,440); host.collection.setup(host)
	host.open_quests(); await frames(8)
	var parent: VBoxContainer = host.modal_body
	await verify_attendance_ui(app,host,parent)
	app.progression_inputs = Quest.new().refresh({},1800450000000)
	app.progression_inputs.dailyQuestProgress = Quest.DAILY.duplicate()
	host.collection.set_period("daily",parent); await frames()
	var initial := panels(parent)
	host.modal_scroll.scroll_vertical=50; await frames()
	var scroll: int = host.modal_scroll.scroll_vertical
	host.collection.quests(parent); await frames()
	check(panels(parent)==initial,"same period reuses quest rows")
	check(host.modal_scroll.scroll_vertical==scroll,"in-place quest refresh preserves scroll")
	var claim = buttons(parent).filter(func(button): return button.text=="수령")[0]
	claim.pressed.emit(); await frames()
	check(service.requests.size()==1,"first claim sends one command")
	check(buttons(parent).filter(func(button): return button.text=="수령" and not button.disabled).is_empty(),"pending disables all claim controls")
	claim.pressed.emit(); await frames()
	check(service.requests.size()==1,"rapid repeated press cannot send another command")
	service.completed.emit({"ok":false,"code":"NETWORK_ERROR"}); await frames()
	check(not buttons(parent).filter(func(button): return button.text=="수령" and not button.disabled).is_empty(),"failure enables retry")
	check(panels(parent)==initial,"pending and failure keep original rows")
	check("수령하지 못했습니다" in texts(parent),"failed claim displays existing retry guidance")
	claim=buttons(parent).filter(func(button): return button.text=="수령" and not button.disabled)[0]
	claim.pressed.emit(); await frames()
	check(service.requests.size()==2,"retry sends next command")
	var target: Dictionary = service.requests.back().target
	if target.rewardType=="all_complete": app.progression_inputs.dailyQuestAllCompleteClaimed=true
	elif target.rewardType=="attendance": app.progression_inputs.dailyAttendanceRewardClaimed=true
	else: app.progression_inputs.claimedDailyQuestRewards.append(target.questType)
	service.completed.emit({"ok":true}); await frames()
	check(buttons(parent).any(func(button):return button.text=="수령 완료" and button.disabled),"successful claim updates claimed row")
	check(panels(parent)==initial,"success preserves row identities")
	check(host.modal_scroll.scroll_vertical==scroll,"claim completion preserves scroll")
	host.collection.set_period("weekly",parent); await frames()
	check("웨이브 150회 클리어" in texts(parent),"weekly tab refreshes correct goals")
	host.collection.set_period("daily",parent); await frames()
	claim=buttons(parent).filter(func(button):return button.text=="수령" and not button.disabled)[0]
	claim.pressed.emit(); await frames()
	host.collection.set_period("weekly",parent); await frames()
	service.completed.emit({"ok":true}); await frames()
	check(host.collection.period=="weekly" and "웨이브 150회 클리어" in texts(parent),"pending daily response keeps selected weekly tab")
	check(not "보상을 수령했습니다" in texts(parent),"daily completion cannot announce success on weekly tab")
	host.collection.set_period("daily",parent); await frames()
	claim=buttons(parent).filter(func(button):return button.text=="수령" and not button.disabled)[0]
	claim.pressed.emit(); await frames()
	host.close_modal(true); host.open_quests(); await frames()
	parent=host.modal_body
	check(buttons(parent).filter(func(button):return button.text=="수령" and not button.disabled).is_empty(),"reopened same binding retains pending disable")
	service.completed.emit({"ok":false,"code":"NETWORK_ERROR"}); await frames()
	check(not buttons(parent).filter(func(button):return button.text=="수령" and not button.disabled).is_empty(),"reopened same binding unlocks after previous completion")
	check(not "수령하지 못했습니다" in texts(parent),"closed dialog completion does not overwrite reopened dialog notice")
	claim=buttons(parent).filter(func(button):return button.text=="수령" and not button.disabled)[0]
	claim.pressed.emit(); await frames()
	var old_service=service
	host.close_modal(true)
	service=Service.new(); service.epoch=2; service.account.credentials.accountId="00000000-0000-4000-8000-000000000002"; root.add_child(service)
	app.services=service
	app.progression_inputs=Quest.new().refresh({},1800450000000)
	host.open_quests(); await frames()
	var new_parent=host.modal_body
	var new_claim=buttons(new_parent).filter(func(button):return button.text=="수령" and not button.disabled)[0]
	new_claim.pressed.emit(); await frames()
	check(service.requests.size()==1,"new binding claim starts before old account response")
	old_service.completed.emit({"ok":true}); await frames()
	check(buttons(new_parent).filter(func(button):return button.text=="수령" and not button.disabled).is_empty(),"late old response retains new binding pending controls")
	new_claim.pressed.emit(); await frames()
	check(service.requests.size()==1,"old completion cannot clear new request guard")
	check(not "보상을 수령했습니다" in texts(new_parent),"late old-account response cannot announce success in new modal")
	check(not app.progression_inputs.dailyAttendanceRewardClaimed,"late old-account response leaves new claim flags")
	service.completed.emit({"ok":false,"code":"NETWORK_ERROR"}); await frames()
	check(not buttons(new_parent).filter(func(button):return button.text=="수령" and not button.disabled).is_empty(),"new account modal has no stuck pending guard")
	print("QUEST_CLAIM_UI checks=",checks," failures=",failures)
	host.close_modal(true); host.free(); old_service.free(); service.free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func verify_attendance_ui(app, host, parent: VBoxContainer):
	var base: Dictionary = Quest.new().refresh({},1800450000000)
	var home = preload("res://ui/lobby_home.gd").new()
	home.lobby = host
	var first_day := int(base.weeklyQuestWeekKey) * 7 - 3
	base.weeklyAttendanceDayKeys = [first_day,first_day+1,first_day+2,first_day+3,first_day+4]
	base.weeklyAttendanceRewardClaimed = true
	base.weeklyQuestProgress = {"killEnemies":500,"clearWaves":65,"killBosses":7,"buyRunUpgrades":23}
	base.claimedWeeklyQuestRewards = ["killEnemies"]
	app.progression_inputs = base.duplicate(true)
	host.collection.set_period("weekly",parent); await frames()
	var view: Dictionary = parent.get_meta("quest_view")
	check(view.rows.all_complete.count.text=="2 / 4 완료" and view.rows.all_complete.button.disabled,"reported screenshot counts attendance and kills as two")
	app.progression_inputs.weeklyQuestProgress.clearWaves = 150
	app.progression_inputs.weeklyQuestProgress.killBosses = 15
	host.collection.quests(parent); await frames()
	check(view.rows.all_complete.count.text=="4 / 4 완료" and not view.rows.all_complete.button.disabled,"weekly attendance plus three enables summary in place")
	app.progression_inputs.weeklyQuestProgress.buyRunUpgrades = 25
	host.collection.quests(parent); await frames()
	check(view.rows.all_complete.count.text=="4 / 4 완료" and not view.rows.all_complete.button.disabled,"all five display capped four and remain claimable")
	app.progression_inputs = base.duplicate(true)
	app.progression_inputs.dailyQuestProgress = {"clearWaves":30,"killBosses":3,"killEnemies":100}
	host.collection.set_period("daily",parent); await frames()
	view = parent.get_meta("quest_view")
	check(view.rows.all_complete.count.text=="4 / 4 완료" and not view.rows.all_complete.button.disabled,"unclaimed daily attendance plus three enables summary")
	app.progression_inputs.dailyAttendanceRewardClaimed = true
	app.progression_inputs.claimedDailyQuestRewards = ["clearWaves","killBosses","killEnemies"]
	host.collection.quests(parent); await frames()
	check(view.rows.all_complete.count.text=="4 / 4 완료" and not view.rows.all_complete.button.disabled,"claimed daily attendance remains included")
	check(host._quest_ready(),"lobby reward-ready icon includes attendance plus three claimed goals")
	check(home._claimable(),"home reward dot includes daily attendance plus three claimed goals")
	app.progression_inputs.dailyQuestAllCompleteClaimed = true
	check(not host._quest_ready(),"claimed summary leaves no reward-ready icon")
	check(not home._claimable(),"claimed daily summary leaves no home reward dot")
	app.progression_inputs.weeklyQuestProgress = {"clearWaves":150,"killBosses":15,"killEnemies":500}
	app.progression_inputs.claimedWeeklyQuestRewards = ["clearWaves","killBosses","killEnemies"]
	check(home._claimable(),"home reward dot includes weekly attendance plus three claimed goals")
	app.progression_inputs.weeklyQuestAllCompleteClaimed = true
	check(not home._claimable(),"claimed weekly summary leaves no home reward dot")
	home.free()
	app.progression_inputs.dailyQuestAllCompleteClaimed = false
	app.progression_inputs.dailyQuestProgress.killBosses = 2
	host.collection.quests(parent); await frames()
	check(view.rows.all_complete.count.text=="3 / 4 완료" and view.rows.all_complete.button.disabled,"daily attendance plus two waits")
