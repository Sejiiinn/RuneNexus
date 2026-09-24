extends RefCounted
## Account-bound services keep requests alive when a modal is dismissed.
const T = preload("res://ui/app_theme.gd")
var lobby
var page := ""
var context := {}
var notice := ""
var data := {}
var pending := false
var view_epoch := 0
var nickname_draft := ""

func _services(): return lobby.app.get("services")

func open(title: String, values: Dictionary = {}) -> void:
	page = title
	context = values.duplicate(true)
	notice = ""
	data = {}
	view_epoch += 1
	pending = false
	_render()
	if title in ["우편함", "리더보드"] and _connected(): _fetch()

func _connected() -> bool:
	return _services() != null and _services().connected()

func _button(body: Node, text: String, callback: Callable, role := "primary") -> Button:
	var button := T.button(text,callback,role)
	button.disabled = pending or (_services() != null and _services().busy)
	body.add_child(button)
	return button

func _render() -> void:
	var body: VBoxContainer = lobby.open_modal(page)
	lobby.modal.set_meta("service_view_epoch",view_epoch)
	lobby.modal.set_meta("service_page",page)
	lobby.modal.set_meta("max_width",480 if page == "우편함" else 420)
	body.name = "ServiceBody"
	if page == "업데이트":
		_update(body)
	elif page in ["계정 및 저장", "계정 로그인 · 온라인 저장"]:
		_account(body)
	elif not _connected():
		body.add_child(T.label("계정을 연결하면 이 기능을 사용할 수 있습니다.",12))
		_button(body,"계정 연결",open.bind("계정 및 저장"))
	elif page == "우편함": _mailbox(body)
	elif page == "리더보드": _leaderboard(body)
	else: _command(body)
	if pending: body.add_child(T.label("처리 중…",12))
	if not notice.is_empty(): body.add_child(T.label(notice,12))

func _update(body: VBoxContainer) -> void:
	var update = _services().updates
	body.add_child(T.label(update.message,14))
	if not update.release.is_empty():
		body.add_child(T.label(str(update.release.versionName),16))
		body.add_child(T.label(str(update.release.notes),12))
	var action := _button(body,"업데이트하기" if not update.release.is_empty() else "다시 시도",_update_action)
	action.disabled = update.busy
	if not update.release.is_empty() and not update.required():
		var later := _button(body,"나중에",func(): update.skip(); lobby.close_modal(),"secondary")
		later.disabled = update.busy

func _update_action() -> void:
	var captured := view_epoch
	await _services().updates.update()
	if _active_view(captured): _render()

func _active_view(captured: int) -> bool:
	return captured == view_epoch and is_instance_valid(lobby.modal) and lobby.modal.get_meta("service_view_epoch", -1) == captured

func _account(body: VBoxContainer) -> void:
	var service = _services()
	if not _connected():
		var offline_account: bool = service != null and service.account != null and not service.account.account_id_hint.is_empty()
		body.add_child(T.label("계정 저장 · 오프라인" if offline_account else "게스트",18))
		body.add_child(T.label("이 기기에 보관된 계정 진행 상황입니다. 연결이 복구되면 서버 저장을 확인합니다." if offline_account else "이 기기에 진행 상황이 저장됩니다. Google 계정을 연결하면 다른 기기에서도 이어갈 수 있습니다.",12))
		if offline_account:
			_button(body,"동기화 다시 시도",_retry,"secondary")
			_button(body,"로그아웃",_logout,"danger")
		var login := _button(body,"Google 계정 연결",_login)
		login.disabled = login.disabled or service == null or not service.configured()
		if service == null or not service.configured(): body.add_child(T.label("이 실행 환경에서는 계정 연결을 사용할 수 없습니다.",12))
		return
	var profile: Dictionary = service.profile
	if profile.get("nickname") is String and not profile.nickname.is_empty():
		body.add_child(T.label(str(profile.nickname)+"#"+str(profile.get("tag","")),18))
		body.add_child(T.label("온라인 저장 연결됨" if service.online_ready and service.issue.is_empty() else "온라인 저장 상태를 확인해 주세요",12))
	else:
		body.add_child(T.label("사용할 닉네임을 설정해 주세요",16))
		body.add_child(T.label("한글·영문·숫자·밑줄, 2자 이상. 한글 최대 8자 또는 영문 최대 16자. 설정 후 변경할 수 없습니다.",12))
		var input := LineEdit.new()
		input.name = "NicknameInput"
		input.placeholder_text = "닉네임"
		input.text = nickname_draft
		input.max_length = 16
		input.text_changed.connect(func(value): nickname_draft = value)
		body.add_child(input)
		_button(body,"닉네임 확정",_nickname)
	_button(body,"동기화 다시 시도",_retry,"secondary")
	_button(body,"로그아웃",_logout,"danger")
	if not service.issue.is_empty(): body.add_child(T.label(_error(service.issue),12))

func _show_result(result: Dictionary) -> void:
	notice = "완료했습니다" if result.get("ok",false) else _error(str(result.get("code","REQUEST_FAILED")))

func _error(code: String) -> String:
	return {"ACCOUNT_REQUIRED":"계정 연결이 필요합니다.","BUSY":"이전 요청을 처리하고 있습니다.","NICKNAME_REQUIRED":"닉네임을 먼저 설정해 주세요.","NICKNAME_ALREADY_SET":"이미 닉네임이 설정되었습니다. 계정 상태를 다시 확인해 주세요.","SAVE_SYNC_REQUIRED":"진행 상황 동기화 후 다시 시도해 주세요.","SAVE_WRITER_REPLACED":"다른 기기에서 접속했습니다. 동기화 다시 시도를 눌러 주세요.","CLIENT_UPDATE_REQUIRED":"새 버전으로 업데이트해야 합니다.","GOOGLE_SIGN_IN_CANCELLED":"계정 연결을 취소했습니다.","sign_in_cancelled":"계정 연결을 취소했습니다.","SAVE_RELOAD_REQUIRED":"서버 진행 상황을 불러오고 있습니다.","INSUFFICIENT_DIAMONDS":"다이아가 부족합니다.","INSUFFICIENT_MODULE_TICKETS":"모듈권이 부족합니다.","ECONOMY_REVISION_CONFLICT":"재화 정보가 갱신되었습니다. 확인 후 다시 시도해 주세요.","MAIL_UNAVAILABLE":"수령할 수 없는 우편입니다."}.get(code,"요청을 완료하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.")

func _login() -> void:
	var captured := view_epoch
	pending = true
	_render()
	var result: Dictionary = await _services().login()
	if not _active_view(captured): return
	pending = false
	_show_result(result)
	if is_instance_valid(lobby.modal): _render()

func _logout() -> void:
	var captured := view_epoch
	pending = true
	_render()
	var result: Dictionary = await _services().logout()
	if not _active_view(captured): return
	pending = false
	_show_result(result)
	if is_instance_valid(lobby.modal): _render()

func _retry() -> void:
	var captured := view_epoch
	pending = true
	_render()
	var result: Dictionary = await _services().retry()
	if not _active_view(captured): return
	pending = false
	_show_result(result)
	if is_instance_valid(lobby.modal): _render()

func _nickname() -> void:
	var value := nickname_draft.strip_edges()
	var weight := 0
	for i in value.length(): weight += 2 if value.unicode_at(i) >= 0xac00 and value.unicode_at(i) <= 0xd7a3 else 1
	if value.length() < 2 or weight > 16 or RegEx.create_from_string("^[가-힣A-Za-z0-9_]+$").search(value) == null or "admin" in value.to_lower() or "운영자" in value:
		notice = "사용 가능한 닉네임 형식을 확인해 주세요."
		_render()
		return
	var captured := view_epoch
	pending = true
	_render()
	var result: Dictionary = await _services().request("PUT","v1/account/nickname",{"nickname":value})
	if not _active_view(captured): return
	pending = false
	_show_result(result)
	_render()

func _fetch(cursor := "") -> void:
	pending = true
	var captured := view_epoch
	_render()
	var path := "v1/leaderboards/progression" if page == "리더보드" else "v1/mailbox" + ("?cursor="+cursor.uri_encode() if not cursor.is_empty() else "")
	var result: Dictionary = await _services().request("GET",path)
	if not _active_view(captured): return
	pending = false
	if result.get("ok",false):
		if not cursor.is_empty() and data.has("mails"):
			data.mails.append_array(result.body.get("mails",[]))
			data.nextCursor = result.body.get("nextCursor")
		else: data = result.body
		notice = ""
	else: _show_result(result)
	_render()

func _mailbox(body: VBoxContainer) -> void:
	_button(body,"새로고침",_fetch,"secondary")
	var mails: Array = data.get("mails",[])
	if mails.is_empty() and not pending: body.add_child(T.label("도착한 우편이 없습니다.",12))
	var claimable: Array = []
	for mail in mails:
		if not mail is Dictionary: continue
		var card := VBoxContainer.new()
		body.add_child(card)
		card.add_child(T.label(str(mail.get("title","우편")),14))
		card.add_child(T.label(str(mail.get("body","")),12))
		card.add_child(T.label("다이아 %d · 모듈권 %d" % [int(mail.get("freeDiamonds",0)),int(mail.get("moduleTickets",0))],12))
		card.add_child(T.label("만료: "+str(mail.get("expiresAt","")),10))
		if mail.get("claimedAt") != null: card.add_child(T.label("수령 완료",12))
		else:
			claimable.append(mail.id)
			_button(card,"수령",_perform.bind("mail_claim",{"id":mail.id}))
		if mail.get("readAt") == null: _button(card,"읽음 표시",_mark_read.bind(str(mail.id)),"secondary")
	if not claimable.is_empty(): _button(body,"모두 수령 (최대 20개)",_perform.bind("mail_claim_all",{"ids":claimable.slice(0,20)}))
	if data.get("nextCursor") is String: _button(body,"더 보기",_fetch.bind(data.nextCursor),"secondary")

func _mark_read(id: String) -> void:
	var captured := view_epoch
	pending = true
	_render()
	var result: Dictionary = await _services().request("POST","v1/mailbox/"+id.uri_encode()+"/read")
	if not _active_view(captured): return
	pending = false
	if result.get("ok",false): _fetch()
	else:
		_show_result(result)
		_render()

func _leaderboard(body: VBoxContainer) -> void:
	body.add_child(T.label("전체 순위 · TOP 100",14))
	_button(body,"새로고침",_fetch,"secondary")
	var mine: Variant = data.get("myEntry")
	if mine is Dictionary: body.add_child(T.label("내 순위: %d위 · %s" % [int(mine.get("rank",0)),str(mine.get("displayName",""))],14))
	for entry in data.get("entries",[]):
		body.add_child(T.label("%d위  %s   스테이지 %d · %d라운드" % [int(entry.get("rank",0)),str(entry.get("displayName","")),int(entry.get("stageNumber",0)),int(entry.get("completedRounds",0))],12))
	if data.get("entries",[]).is_empty() and not pending: body.add_child(T.label("등록된 순위가 없습니다.",12))

func _command(body: VBoxContainer) -> void:
	var actions := {"모듈 뽑기":"draw_modules","모듈 분해":"disassemble_modules","모듈 일괄 분해":"disassemble_modules","연구 즉시 완료":"complete_research","연구 슬롯 구매":"unlock_research_slot_two"}
	if not actions.has(page):
		body.add_child(T.label("계정 메뉴에서 이용할 기능을 선택해 주세요.",12))
		return
	var values := context.duplicate(true)
	if data.has("economy"):
		body.add_child(T.label("서버에 반영했습니다",16))
		if data.has("drawnModules"):
			for item in data.drawnModules:
				body.add_child(T.label(str(lobby.collection.GRADES.get(item.get("grade",""),item.get("grade","")))+" · "+str(lobby.NAMES.get(item.get("turretType",""),item.get("turretType","")))+" · "+str(lobby.collection.PARTS.get(item.get("part",""),item.get("part",""))),12))
		if int(data.get("grantedDiamonds",0)) > 0: body.add_child(T.label("다이아 +%d" % int(data.grantedDiamonds),14))
		if int(data.get("grantedModuleTickets",0)) > 0: body.add_child(T.label("모듈권 +%d" % int(data.grantedModuleTickets),14))
		_button(body,"닫기",lobby.close_modal,"secondary")
		return
	var affordable := true
	if page == "모듈 뽑기":
		var count := int(values.get("count",1))
		var tickets := int(lobby._p().get("turretModules",{}).get("tickets",0))
		var diamonds := maxi(0,count-tickets)*40
		body.add_child(T.label("모듈 %d개를 획득합니다. 모듈권 %d장%s" % [count,mini(tickets,count)," · 다이아 %d개" % diamonds if diamonds > 0 else ""],14))
		values.buyMissingTicketsWithDiamonds = diamonds > 0
		affordable = lobby.diamonds() >= diamonds
	elif page in ["모듈 분해","모듈 일괄 분해"]:
		if values.has("id"): values.ids = [values.id]
		var equipped: Array = lobby._p().get("turretModules",{}).get("items",[]).filter(func(item): return item.get("equipped",false)).map(func(item): return item.id)
		values.ids = values.get("ids",[]).filter(func(id):return not id in equipped)
		var refund := 0
		for item in lobby._p().get("turretModules",{}).get("items",[]):
			if item.id in values.ids: refund += int({"normal":2,"magic":5,"rare":20,"unique":50}.get(item.get("grade","normal"),0))
		body.add_child(T.label("장착 중인 모듈을 제외한 %d개를 분해합니다. 분해한 모듈은 복구할 수 없습니다." % values.ids.size(),14))
		body.add_child(T.label("획득 다이아 %d개" % refund,14))
		affordable = not values.ids.is_empty()
	else:
		var cost := 0
		if page == "연구 슬롯 구매":
			cost = int(lobby.app.run_domain.growth.data.constants.researchSlotTwoUnlockCost)
			affordable = not lobby._p().get("researchSlotTwoUnlocked",false)
		else:
			var active: Array = lobby._p().get("activeResearches",[]).filter(func(item): return item.type == values.get("id"))
			affordable = not active.is_empty()
			if not active.is_empty(): cost = ceili(maxf(0,float(active[0].startedAtMillis)+float(active[0].durationMillis)-Time.get_unix_time_from_system()*1000.0)/60000.0)
		var diamonds: int = lobby.diamonds()
		body.add_child(T.label("필요 다이아 %d · 보유 %d · 남은 다이아 %d" % [cost,diamonds,maxi(0,diamonds-cost)],14))
		affordable = affordable and diamonds >= cost
	if data.has("drawnModules"):
		body.add_child(T.label("획득 결과",16))
		for item in data.drawnModules: body.add_child(T.label(str(item.get("grade",""))+" · "+str(item.get("turretType",""))+" · "+str(item.get("part","")),12))
	else:
		var confirm := _button(body,"확인",_perform.bind(actions[page],values))
		confirm.disabled = confirm.disabled or not affordable

func _perform(action: String, values: Dictionary) -> void:
	pending = true
	var captured := view_epoch
	_render()
	var result: Dictionary = await _services().perform(action,values)
	if not _active_view(captured): return
	pending = false
	_show_result(result)
	if result.get("ok",false):
		data = result.get("body",{})
		if page == "우편함":
			_fetch()
			return
	_render()
