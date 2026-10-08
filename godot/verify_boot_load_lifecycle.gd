extends SceneTree
## Controlled loaders exercise real threaded tokens, without accounts or saves.
const Boot = preload("res://app/boot.gd")
const RETRY_PATH := "res://boot-lifecycle-retry.bootprobe"
const DISPOSE_FAILED_PATH := "res://boot-lifecycle-dispose-failed.bootprobe"

class ControlledLoader extends ResourceFormatLoader:
	var mutex := Mutex.new()
	var release := Semaphore.new()
	var calls := 0
	var remaining_failures := 0
	var hold := false
	func configure(failures: int, held: bool = false) -> void:
		mutex.lock()
		remaining_failures = failures
		hold = held
		mutex.unlock()
	func call_count() -> int:
		mutex.lock()
		var count := calls
		mutex.unlock()
		return count
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["bootprobe"])
	func _handles_type(kind: StringName) -> bool:
		return kind == &"PackedScene"
	func _get_resource_type(_path: String) -> String:
		return "PackedScene"
	func _exists(path: String) -> bool:
		return path.ends_with(".bootprobe")
	func _load(_path: String, _original: String, _sub_threads: bool, _cache_mode: int) -> Variant:
		mutex.lock()
		calls += 1
		var held := hold
		var fail := remaining_failures > 0
		remaining_failures = maxi(0, remaining_failures - 1)
		mutex.unlock()
		if held: release.wait()
		if fail: return ERR_FILE_CORRUPT
		var packed := PackedScene.new()
		var node := Node.new()
		packed.pack(node)
		node.free()
		return packed

class ObservedBoot extends Boot:
	var observed := {"instances":0}
	func _ready() -> void:
		updates = Updates.new()
		updates.blocked = false
		add_child(updates)
	func _instantiate(_packed: PackedScene) -> void:
		observed.instances += 1
		_effects_pending = false

var failures: Array[String] = []
var checks := 0
var loader := ControlledLoader.new()

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func frames(count: int = 3) -> void:
	for frame in count: await process_frame

func wait_until(predicate: Callable, label: String) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(predicate.call(), label)

func make_boot(path: String) -> ObservedBoot:
	var boot := ObservedBoot.new()
	boot.game_scene_path = path
	root.add_child(boot)
	return boot

func no_token(path: String) -> bool:
	return ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE

func run() -> void:
	ResourceLoader.add_resource_format_loader(loader, true)
	await retry_checks()
	await cancellation_checks()
	ResourceLoader.remove_resource_format_loader(loader)
	print("BOOT_LOAD_LIFECYCLE checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func retry_checks() -> void:
	loader.configure(2)
	var boot := make_boot(RETRY_PATH)
	boot.updates.blocked = true
	boot._advance()
	await frames()
	check(loader.call_count() == 0 and not boot._load_started, "update gate never requests the game early")
	boot.updates.blocked = false
	boot._advance()
	boot._advance()
	check(loader.call_count() == 0, "request yields a startup frame before starting")
	await wait_until(func(): return not boot._failure.is_empty(), "first injected failure reaches retry state")
	check(loader.call_count() == 1 and boot.observed.instances == 0 and not boot._loading, "failed load never instantiates")
	check(no_token(RETRY_PATH) and boot._requested_path.is_empty(), "failed request is collected before retry is offered")
	for press in 5: boot._action()
	await wait_until(func(): return not boot._failure.is_empty(), "second injected failure reaches retry state")
	check(loader.call_count() == 2 and no_token(RETRY_PATH), "repeated retry clicks start exactly one fresh request")
	for press in 5: boot._action()
	await wait_until(func(): return boot.observed.instances == 1, "third same-path attempt succeeds after transient failures")
	check(loader.call_count() == 3 and boot._failure.is_empty() and no_token(RETRY_PATH), "success consumes one terminal token")
	check(not boot._effects_pending and boot.game == null and boot.services == null, "loader completion does not prepare stage resources or account services")
	for press in 5: boot._action();boot._advance()
	await frames()
	check(loader.call_count() == 3 and boot.observed.instances == 1, "completed boot ignores repeated retry and advance")
	boot.free()
	check(no_token(RETRY_PATH), "completed boot disposal has no outstanding request")

func cancellation_checks() -> void:
	loader.configure(0)
	var before := loader.call_count()
	var early := make_boot("res://boot-lifecycle-before-request.bootprobe")
	early._advance()
	root.remove_child(early)
	await frames()
	check(loader.call_count() == before and not early._loading, "cancel before deferred request starts no load")
	early.free()
	for fail in [false, true]:
		var path := DISPOSE_FAILED_PATH if fail else "res://boot-lifecycle-dispose-success.bootprobe"
		loader.configure(1 if fail else 0, true)
		before = loader.call_count()
		var boot := make_boot(path)
		var observed: Dictionary = boot.observed
		boot._advance()
		await wait_until(func(): return loader.call_count() == before + 1, "controlled request reaches held loader")
		check(ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS, "held request remains asynchronous")
		boot.free()
		await frames()
		check(observed.instances == 0, "disposing during a held request cannot instantiate")
		loader.release.post()
		await wait_until(func(): return no_token(path), "disposed boot drains its terminal token without blocking")
		check(observed.instances == 0, "disposed boot never instantiates the completed scene")
		loader.configure(0)
		var retry := make_boot(path)
		retry._advance()
		await wait_until(func(): return retry.observed.instances == 1, "new boot retries cancelled same path successfully")
		check(loader.call_count() == before + 2 and no_token(path), "cancelled path gets a fresh request without stale tokens")
		retry.free()
	# A replacement may request the same path before the cancelled work finishes.
	# Both callers own tokens even though Godot shares one underlying load.
	loader.configure(0, true)
	var overlap_path := "res://boot-lifecycle-overlapping-owners.bootprobe"
	before = loader.call_count()
	var cancelled := make_boot(overlap_path)
	var cancelled_observed: Dictionary = cancelled.observed
	cancelled._advance()
	await wait_until(func(): return loader.call_count() == before + 1, "overlapping owner reaches held load")
	cancelled.free()
	var replacement := make_boot(overlap_path)
	replacement._advance()
	await wait_until(func(): return not replacement._requested_path.is_empty(), "replacement owns the shared in-flight request")
	check(loader.call_count() == before + 1, "same-path overlap shares one underlying load")
	loader.release.post()
	await wait_until(func(): return replacement.observed.instances == 1 and no_token(overlap_path), "each overlapping owner consumes only its own token")
	check(cancelled_observed.instances == 0 and replacement.observed.instances == 1, "only surviving boot instantiates shared completion")
	replacement.free()
	# A loaded-but-deferred scene must not attach after cancellation either.
	loader.configure(0)
	var late := make_boot("res://boot-lifecycle-before-instance.bootprobe")
	late.set_process(false)
	late._advance()
	await wait_until(func(): return ResourceLoader.load_threaded_get_status(late.game_scene_path) == ResourceLoader.THREAD_LOAD_LOADED, "request can complete before instantiation")
	late._process(0.0)
	root.remove_child(late)
	await frames()
	check(late.observed.instances == 0 and no_token(late.game_scene_path), "cancel between collection and deferred instantiation discards scene")
	late.free()
