extends SceneTree
## Isolated achievement claim feedback: no live account or external API.
const Cumulative = preload("res://content/cumulative_achievements.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
class Lobby extends "res://ui/lobby.gd":
	var keys: Array = []
	func _ready(): pass
	func challenge_claim_keys() -> Array: return keys
class Service extends Node:
	signal completed(result: Dictionary)
	var epoch := 1
	var requests: Array = []
	func connected() -> bool: return true
	func perform(action: String, target: Dictionary) -> Dictionary:
		requests.append({"action":action,"target":target.duplicate(true)})
		return await completed
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
func frames(count: int = 3):
	for i in range(count): await process_frame
func plate(host, plate_name := "CumulativeClaim_attendance") -> Button:
	return host.modal_body.find_child(plate_name, true, false)
func run():
	var app = App.new()
	app.progression_inputs = {Cumulative.COUNTERS_FIELD:{"attendance":30}, "freeDiamonds":100}
	var service = Service.new(); root.add_child(service); app.services = service
	var host = Lobby.new(); host.app = app; host.theme = preload("res://ui/battle_theme.gd").create()
	root.add_child(host); host.size = Vector2(440, 760); host.challenges.setup(host)
	host.challenges.chapter = 1
	host.challenges.tab = "cumulative"
	host.open_challenges(); await frames(8)
	plate(host).pressed.emit(); await frames()
	check(service.requests.size() == 1 and service.requests[0].action == "claim_achievement" and service.requests[0].target.tier == 1, "claim sends the next tier once")
	var overlay: Control = host.modal.get_node_or_null("ClaimOverlay")
	check(overlay != null and overlay.visible and overlay.mouse_filter == Control.MOUSE_FILTER_STOP and host.modal.get_child(-1) == overlay, "pending claim blocks the dialog with the server spinner")
	check("보상을 수령하는 중" in texts(overlay), "pending claim shows the quest claim caption")
	check(plate(host).disabled, "pending claim disables the plate")
	plate(host).pressed.emit(); await frames()
	check(service.requests.size() == 1, "repeated press cannot send another command")
	for i in range(3): host.challenges.refresh()
	await frames()
	check(host.modal.get_child(-1) == overlay and host.modal.get_children().filter(func(child): return child.name == "ClaimOverlay").size() == 1, "refresh keeps one spinner on top")
	service.completed.emit({"ok":false, "code":"NETWORK_ERROR"}); await frames()
	check(not overlay._active, "failed claim releases the spinner")
	check(host.modal.get_node_or_null("ClaimGain") == null, "failed claim shows no gained diamonds")
	check("보상을 받지 못했습니다" in texts(host.modal_body), "failed claim keeps the retry notice")
	host.challenges.notice = ""
	host.challenges.refresh(); await frames(4)
	var before: Rect2 = plate(host).get_global_rect()
	plate(host).pressed.emit(); await frames()
	host.keys.append(Cumulative.reward_key("attendance", 1))
	app.progression_inputs.freeDiamonds = 400
	service.completed.emit({"ok":true}); await frames(4)
	check(not overlay._active, "successful claim releases the spinner")
	var gain: Control = host.modal.get_node_or_null("ClaimGain")
	check(gain != null and "+300" in texts(gain), "success rises the gained diamonds")
	check(gain != null and absf(gain.get_global_rect().get_center().x - before.get_center().x) < 2 and absf(gain.get_global_rect().get_center().y - before.get_center().y) < 30, "gained diamonds rise from the claimed plate")
	await create_timer(1.6).timeout
	check(not is_instance_valid(gain), "gained diamond pop removes itself")
	plate(host).pressed.emit(); await frames()
	host.close_modal(true); host.open_challenges(); await frames(6)
	var reopened: Control = host.modal.get_node_or_null("ClaimOverlay")
	check(reopened != null and reopened._active, "reopened dialog restores the pending spinner")
	host.keys.append(Cumulative.reward_key("attendance", 2))
	app.progression_inputs.freeDiamonds = 900
	service.completed.emit({"ok":true}); await frames(4)
	check(not reopened._active, "reopened dialog releases the spinner")
	var again: Control = host.modal.get_node_or_null("ClaimGain")
	check(again != null and "+500" in texts(again), "reopened dialog still shows the gained diamonds")
	await create_timer(1.6).timeout
	# Stage tab: diamonds and tickets take the same path.
	app.progression_inputs["challengeStageNumbers"] = [1, 2]
	app.progression_inputs["turretModules"] = {"tickets":0}
	host.challenges.tab = "stage"
	host.challenges.refresh(); await frames(4)
	service.requests.clear()
	plate(host, "Challenge_1_normal").pressed.emit(); await frames()
	check(service.requests.size() == 1 and service.requests[0].action == "claim_challenge" and service.requests[0].target == {"stageNumber":1, "difficulty":"normal"}, "stage claim keeps its request")
	var stage_overlay: Control = host.modal.get_node_or_null("ClaimOverlay")
	check(stage_overlay != null and stage_overlay._active, "stage claim shows the server spinner")
	plate(host, "Challenge_1_normal").pressed.emit(); await frames()
	check(service.requests.size() == 1, "repeated stage press cannot send another command")
	host.keys.append(StageChallenges.reward_key(1, "normal"))
	app.progression_inputs.freeDiamonds = 1000
	service.completed.emit({"ok":true}); await frames(4)
	var stage_gain: Control = host.modal.get_node_or_null("ClaimGain")
	check(not stage_overlay._active and stage_gain != null and "+100" in texts(stage_gain), "stage claim rises the gained diamonds")
	await create_timer(1.6).timeout
	plate(host, "Challenge_2_normal").pressed.emit(); await frames()
	host.keys.append(StageChallenges.reward_key(2, "normal"))
	app.progression_inputs.turretModules.tickets = 4
	service.completed.emit({"ok":true}); await frames(4)
	var ticket_gain: Control = host.modal.get_node_or_null("ClaimGain")
	check(ticket_gain != null and "+4" in texts(ticket_gain), "stage claim rises the gained tickets")
	await create_timer(1.6).timeout
	app.progression_inputs[Cumulative.COUNTERS_FIELD].attendance = 200
	host.challenges.tab = "cumulative"
	host.challenges.refresh(); await frames(4)
	# A new account on the same service drops the old claim's feedback.
	service.requests.clear()
	plate(host).pressed.emit(); await frames()
	check(service.requests.size() == 1, "old account claim is pending")
	service.epoch += 1
	host.close_modal(true); await frames(); host.open_challenges(); await frames()
	var rebound: Control = host.modal.get_node_or_null("ClaimOverlay")
	check(rebound == null or not rebound._active, "new account does not restore the old spinner")
	check(not plate(host).disabled, "new account can claim during the old request")
	service.completed.emit({"ok":false, "code":"STALE_BINDING"}); await frames()
	check(host.challenges.notice.is_empty(), "late old-account failure leaves no notice")
	# A replaced service releases the open dialog and accepts a new claim.
	service.requests.clear()
	plate(host).pressed.emit(); await frames()
	var stale: Control = host.modal.get_node_or_null("ClaimOverlay")
	var replacement = Service.new(); root.add_child(replacement); app.services = replacement
	host.challenges.refresh(); await frames()
	check(not stale._active, "replaced service releases the old spinner")
	plate(host).pressed.emit(); await frames()
	check(replacement.requests.size() == 1, "replaced service accepts a new claim")
	service.completed.emit({"ok":false, "code":"NETWORK_ERROR"}); await frames()
	check(host.challenges.pending != "" and host.challenges.notice.is_empty(), "late old-service response keeps the new claim pending")
	replacement.completed.emit({"ok":false, "code":"NETWORK_ERROR"}); await frames()
	check(not stale._active and "보상을 받지 못했습니다" in texts(host.modal_body), "new claim failure still reports")
	host.close_modal(true); host.free(); service.free(); replacement.free()
	print("ACHIEVEMENT_CLAIM_UI checks=", checks, " failures=", failures)
	await frames()
	quit(0 if failures.is_empty() else 1)
