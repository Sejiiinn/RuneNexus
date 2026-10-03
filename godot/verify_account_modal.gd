extends SceneTree
## Actual lobby widgets with isolated service state; no network or player save.
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
class Services extends RefCounted:
	signal released
	var busy := false
	var updates := {"blocked":false}
	var account := {"account_id_hint":"fixture-account"}
	var profile := {"nickname":null,"tag":"0012"}
	var online_ready := true
	var issue := ""
	var online := true
	var enabled := true
	var calls: Array = []
	var response := {"ok":true}
	func connected() -> bool: return online
	func configured() -> bool: return enabled
	func needs_profile() -> bool: return online and profile.get("nickname") == null
	func request(method: String, path: String, values: Dictionary) -> Dictionary:
		calls.append({"method":method,"path":path,"values":values.duplicate(true)})
		await released
		return response.duplicate(true)
	func retry() -> Dictionary:
		calls.append({"action":"retry"}); await released; return response.duplicate(true)
	func logout() -> Dictionary:
		calls.append({"action":"logout"}); await released; return response.duplicate(true)
	func login() -> Dictionary:
		calls.append({"action":"login"}); await released; return response.duplicate(true)
var captures := OS.get_environment("ACCOUNT_MODAL_CAPTURE_DIR")
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(10): await process_frame
func texts(node: Node) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): result += "\n" + texts(child)
	return result
func button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == caption: return child
		var found := button(child,caption)
		if found != null: return found
	return null
func capture(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(label+".png"))
func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var app := Fixture.FakeApp.new(); var service := Services.new(); app.services = service
	app.catalog.load_catalog(); app.run_domain.growth.load_catalog()
	var lobby := Lobby.new(); lobby.app = app; root.add_child(lobby); await settle()
	lobby.open_page("설정")
	for width in [440,320]:
		root.size = Vector2i(width,900); root.content_scale_size = root.size; await settle()
		if width == 440: button(lobby.body,"계정 및 저장").pressed.emit()
		else: lobby._service("계정 및 저장")
		await settle()
		assert(texts(lobby.modal_frame).contains("계정 및 저장") and not texts(lobby.modal_frame).contains("계정 로그인 · 온라인 저장"),"Settings alias preserves approved modal title")
		var ui = lobby._services
		var modal_id: int = lobby.modal.get_instance_id()
		assert(texts(lobby.modal_body).contains("닉네임 설정"))
		assert(texts(lobby.modal_body).contains("설정 후 변경할 수 없습니다."))
		var input: LineEdit = lobby.modal_body.find_child("NicknameInput",true,false)
		assert(input.placeholder_text == "닉네임 입력" and input.max_length == 16)
		var confirm := button(lobby.modal_body,"닉네임 확정")
		assert(absf(input.get_global_rect().get_center().y-confirm.get_global_rect().get_center().y)<1,"Nickname input and confirmation share a row")
		assert(input.get_global_rect().end.x < confirm.global_position.x,"Nickname controls do not overlap")
		assert(lobby.modal_frame.get_global_rect().encloses(input.get_global_rect()) and lobby.modal_frame.get_global_rect().encloses(confirm.get_global_rect()),"Nickname controls fit the modal")
		if width == 440: await capture("account-nickname-%d" % width)
		input.text = "RuneNexus_123456"; input.text_changed.emit(input.text)
		var actions: HBoxContainer = lobby.modal_body.find_child("AccountManagementActions",true,false)
		var retry := button(actions,"동기화 다시 시도"); var logout := button(actions,"로그아웃")
		assert(absf(retry.size.y-logout.size.y)<1 and absf(retry.global_position.y-logout.global_position.y)<1)
		assert(absf(retry.size.x/(retry.size.x+logout.size.x)-0.64)<0.005,"Management width preserves 64:36")
		assert(lobby.modal_frame.get_global_rect().encloses(retry.get_global_rect()) and lobby.modal_frame.get_global_rect().encloses(logout.get_global_rect()))
		assert(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(lobby.modal_frame.get_global_rect()))
		if width == 320: await capture("account-nickname-%d" % width)
		lobby.close_modal(); assert(lobby.modal.get_instance_id()==modal_id,"Mandatory nickname gate remains")
		ui.nickname_draft = "bad!"; ui._nickname(); await settle()
		assert(service.calls.is_empty() and texts(lobby.modal_body).contains("사용 가능한 닉네임 형식"))
		ui.nickname_draft = "RuneNexus_123456"; ui._nickname(); await settle()
		assert(service.calls.back() == {"method":"PUT","path":"v1/account/nickname","values":{"nickname":"RuneNexus_123456"}})
		assert(button(lobby.modal_body,"닉네임 확정").disabled and button(lobby.modal_body,"동기화 다시 시도").disabled)
		assert((lobby.modal_body.find_child("NicknameInput",true,false) as LineEdit).text == "RuneNexus_123456")
		assert(texts(lobby.modal_body).contains("처리 중…"))
		service.response = {"ok":false,"code":"NICKNAME_ALREADY_SET"}; service.released.emit(); await settle()
		assert(not button(lobby.modal_body,"닉네임 확정").disabled and texts(lobby.modal_body).contains("이미 닉네임이 설정"))
		assert(lobby.modal.get_instance_id()==modal_id,"Pending/error renders retain modal lifetime")
		service.calls.clear()
	service.profile = {"nickname":"긴닉네임여덟글자","tag":"0012"}
	lobby._service("계정 및 저장"); await settle()
	assert(button(lobby.modal_body,"닉네임 확정")==null and texts(lobby.modal_body).contains("긴닉네임여덟글자#0012"))
	service.busy = true; lobby._services._render(); await settle()
	assert(button(lobby.modal_body,"동기화 다시 시도").disabled and button(lobby.modal_body,"로그아웃").disabled)
	service.busy = false; service.issue = "SAVE_SYNC_REQUIRED"; lobby._services._render(); await settle()
	assert(texts(lobby.modal_body).contains("온라인 저장 상태를 확인") and texts(lobby.modal_body).contains("진행 상황 동기화 후"))
	await capture("account-established-error-320")
	button(lobby.modal_body,"동기화 다시 시도").pressed.emit(); await settle()
	assert(service.calls.back()=={"action":"retry"})
	lobby.close_modal(); service.released.emit(); await settle(); assert(lobby.modal==null,"Late completion cannot reopen dismissed account modal")
	service.online = false; service.issue = ""; lobby._service("계정 및 저장"); await settle()
	assert(texts(lobby.modal_body).contains("계정 저장 · 오프라인") and button(lobby.modal_body,"Google 계정 연결")!=null)
	assert(button(lobby.modal_body,"동기화 다시 시도")!=null and button(lobby.modal_body,"로그아웃")!=null)
	await capture("account-offline-320")
	button(lobby.modal_body,"로그아웃").pressed.emit(); await settle(); assert(service.calls.back()=={"action":"logout"}); service.released.emit(); await settle()
	service.account.account_id_hint = ""; service.enabled = false; lobby._service("계정 및 저장"); await settle()
	assert(texts(lobby.modal_body).contains("게스트") and button(lobby.modal_body,"Google 계정 연결").disabled)
	assert(button(lobby.modal_body,"로그아웃")==null and texts(lobby.modal_body).contains("이 실행 환경에서는"))
	await capture("account-guest-unconfigured-320")
	print("PASS account modal: layout 440/320, nickname constraints, mandatory gate, pending/error, established, offline/guest, late request lifetime")
	lobby.free(); quit()
