extends Node
## Lightweight entry: render startup before update/network or heavy game resources.
const Startup = preload("res://ui/startup_screen.gd")
const Updates = preload("res://services/update_service.gd")
const Json = preload("res://app/save_json.gd")
var updates
var services
var screen: Control
var game: Node
var game_scene_path := "res://main.tscn"
var _load_started := false
var _loading := false
var _load_progress := 0.0
var _failure := ""
var _last_view := {}
var _first_frame_ready := false

func _ready() -> void:
	if "--fixture" in OS.get_cmdline_user_args() or "--session" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(game_scene_path)
		return
	add_to_group("rune_app_boot")
	get_tree().root.content_scale_size=Vector2i(440,760)
	var layer=CanvasLayer.new();layer.layer=100;add_child(layer)
	screen=Startup.new();layer.add_child(screen)
	if updates==null: updates=Updates.new()
	add_child(updates)
	var config: Variant=Json.parse(FileAccess.get_file_as_string("res://app_config.json")) if FileAccess.file_exists("res://app_config.json") else {}
	var platform=Engine.get_singleton("RuneNexusPlatform") if Engine.has_singleton("RuneNexusPlatform") else null
	updates.setup(platform,str(config.get("updateManifestUrl","")) if config is Dictionary else "")
	updates.changed.connect(_update_changed)
	_refresh()
	# Two frame boundaries let the canvas submit its first frame before work starts.
	await get_tree().process_frame
	await get_tree().process_frame
	_first_frame_ready=true
	await updates.check()
	_advance()

func attach_services(coordinator) -> void:
	services=coordinator
	services.changed.connect(_refresh)
	_refresh()

func blocks_app_ui() -> bool:
	return updates==null or updates.blocked or services==null or services._startup_pending or not _failure.is_empty()

func _update_changed() -> void:
	_refresh()
	_advance()

func _advance() -> void:
	if updates==null or updates.blocked or _load_started: return
	_load_started=true;_loading=true;_failure=""
	_refresh()
	_start_load.call_deferred()

func _start_load() -> void:
	await get_tree().process_frame
	if ResourceLoader.load_threaded_request(game_scene_path,"PackedScene",true)!=OK:
		fail_preparation("게임 파일을 불러오지 못했습니다. 다시 시도해 주세요.")

func _process(_delta: float) -> void:
	if not _loading: return
	var progress: Array=[]
	var status=ResourceLoader.load_threaded_get_status(game_scene_path,progress)
	if not progress.is_empty():
		_load_progress=float(progress[0]);_refresh()
	if status==ResourceLoader.THREAD_LOAD_LOADED:
		_loading=false
		var packed=ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
		if packed==null: fail_preparation("게임 파일을 불러오지 못했습니다. 다시 시도해 주세요.");return
		_instantiate.call_deferred(packed)
	elif status==ResourceLoader.THREAD_LOAD_FAILED:
		fail_preparation("게임 파일을 불러오지 못했습니다. 다시 시도해 주세요.")

func _instantiate(packed: PackedScene) -> void:
	# Keep the preparation canvas visible while main's GLB instances initialize.
	await get_tree().process_frame
	while updates.blocked: await updates.changed
	game=packed.instantiate()
	if game is Node3D: game.visible=false
	add_child(game)
	_refresh()

func _notification(what: int) -> void:
	# Before main exists, boot owns installer/settings returns. Afterwards the
	# application lifecycle owns them, including its Google-login return guard.
	if what==NOTIFICATION_APPLICATION_RESUMED and _first_frame_ready and services==null and updates!=null and not updates.busy:
		updates.check()

func fail_preparation(reason: String) -> void:
	_loading=false;_failure=reason
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(screen): return
	var active=blocks_app_ui()
	screen.visible=active
	if game is Node3D: game.visible=not active
	if not active: return
	var view=presentation()
	if view!=_last_view:
		_last_view=view.duplicate(true)
		screen.present(view,_action,_continue)

func presentation() -> Dictionary:
	if not _failure.is_empty(): return {"status":"게임 준비","busy":false,"details":true,"error":_failure,"action":"다시 시도"}
	if updates==null or not updates.blocked:
		var load_error=services!=null and services._startup_pending and not services._initializing and services.issue=="LOCAL_SAVE_LOAD_FAILED"
		if load_error: return {"status":"게임 준비","busy":false,"details":true,"error":"저장을 불러오지 못했습니다. 기존 저장은 보존됩니다.","action":"다시 시도"}
		return {"status":"게임 준비 중","busy":true,"details":false,"progress":_load_progress if _loading else -1.0}
	var release: Dictionary=updates.release
	var checking=updates.phase=="checking"
	var required=updates.required()
	var status="업데이트 확인 중" if checking else ("필수 업데이트가 있습니다" if required else ("업데이트 확인" if release.is_empty() else "새 버전이 있습니다"))
	if updates.busy and not checking:
		status="설치 준비 중" if updates.downloaded else ("변경분을 다운로드하고 새 APK를 복원하는 중" if updates.transfer=="patch" else ("변경분을 적용하지 못해 전체 앱을 다운로드하는 중" if updates.transfer=="full_fallback" else "업데이트를 다운로드하고 확인하는 중"))
		if not updates.downloaded:
			match updates.transfer_stage:
				"download": status="변경분 다운로드 중" if updates.transfer=="patch" else ("전체 앱 다시 다운로드 중" if updates.transfer=="full_fallback" else "업데이트 다운로드 중")
				"verify": status="다운로드 파일 확인 중"
				"apply": status="변경분 적용 중"
	var receiving=updates.busy and updates.phase=="download" and updates.transfer_stage=="download" and updates.total_bytes>0
	var patch: Dictionary=updates._patch() if not release.is_empty() else {}
	return {"status":status,"busy":updates.busy or checking,"details":not checking,"required":required,
		"progress":float(updates.received_bytes)/updates.total_bytes if receiving else -1.0,
		"progress_text":"%.1f / %.1f MB" % [float(updates.received_bytes)/(1024*1024),float(updates.total_bytes)/(1024*1024)] if receiving else "",
		"version":"%s · %.1f MB" % [str(release.get("versionName","")),float(release.get("sizeBytes",0))/(1024*1024)] if not release.is_empty() else "",
		"notes":str(release.get("notes","")),"error":updates.error_message,
		"message":updates.message if updates.phase=="install" and not updates.busy else "",
		"transfer":"변경분 다운로드 %.1f MB" % [float(patch.get("sizeBytes",0))/(1024*1024)] if not patch.is_empty() and updates.transfer!="full_fallback" else "",
		"action":"다시 시도" if not updates.error_message.is_empty() or release.is_empty() else ("설치 계속" if updates.downloaded else ("업데이트하기" if required else "업데이트")),
		"can_continue":not release.is_empty() and not required}

func _action() -> void:
	if not _failure.is_empty():
		_failure="";_load_started=false
		if is_instance_valid(game): game.queue_free();game=null
		services=null;_advance()
	elif updates.blocked: await updates.update()
	elif services!=null and services._startup_pending: await services._initialize()
	_refresh()

func _continue() -> void:
	updates.skip()
