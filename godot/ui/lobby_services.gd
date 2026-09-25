extends RefCounted
## Account-bound services keep requests alive when a modal is dismissed.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const GrowthUI = preload("res://ui/lobby_growth.gd")
const CollectionUI = preload("res://ui/lobby_collection.gd")
const MODULE_DIAMONDS := {"normal":2,"magic":5,"rare":20,"unique":50}
var lobby
var page := ""
var context := {}
var notice := ""
var data := {}
var pending := false
var view_epoch := 0
var nickname_draft := ""
var module_confirmation: Array = []

func _services(): return lobby.app.get("services")

func open(title: String, values: Dictionary = {}) -> void:
	page = title
	context = values.duplicate(true)
	notice = ""
	data = {}
	module_confirmation = []
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
		if service != null and not service.issue.is_empty() and notice.is_empty(): body.add_child(T.label(_error(service.issue),12))
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
	return {"ACCOUNT_REQUIRED":"계정 연결이 필요합니다.","BUSY":"이전 요청을 처리하고 있습니다.","NICKNAME_REQUIRED":"닉네임을 먼저 설정해 주세요.","NICKNAME_ALREADY_SET":"이미 닉네임이 설정되었습니다. 계정 상태를 다시 확인해 주세요.","SAVE_SYNC_REQUIRED":"진행 상황 동기화 후 다시 시도해 주세요.","SAVE_WRITER_REPLACED":"다른 기기에서 접속했습니다. 동기화 다시 시도를 눌러 주세요.","CLIENT_UPDATE_REQUIRED":"새 버전으로 업데이트해야 합니다.","GOOGLE_SIGN_IN_CANCELLED":"계정 연결을 취소했습니다.","sign_in_cancelled":"계정 연결을 취소했습니다.","invalid_credential":"Google 인증 정보를 확인하지 못했습니다. Google 계정을 다시 선택해 주세요.","sign_in_unavailable":"Google 로그인 요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.","SAVE_RELOAD_REQUIRED":"서버 진행 상황을 불러오고 있습니다.","INSUFFICIENT_DIAMONDS":"다이아가 부족합니다.","INSUFFICIENT_MODULE_TICKETS":"모듈권이 부족합니다.","ECONOMY_REVISION_CONFLICT":"재화 정보가 갱신되었습니다. 확인 후 다시 시도해 주세요.","MAIL_UNAVAILABLE":"수령할 수 없는 우편입니다."}.get(code,"요청을 완료하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.")

func _login() -> void:
	var captured := view_epoch
	notice = ""
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
	if data.has("economy"):
		body.add_child(T.label({"모듈 뽑기":"모듈을 획득했습니다.","모듈 분해":"모듈을 분해했습니다.","모듈 일괄 분해":"모듈을 분해했습니다.","연구 즉시 완료":"연구를 즉시 완료했습니다.","연구 슬롯 구매":"연구 슬롯을 해금했습니다."}.get(page,"완료했습니다."),16))
		if data.has("drawnModules"):
			for item in data.drawnModules:
				body.add_child(T.label(str(CollectionUI.GRADES.get(item.get("grade",""),item.get("grade","")))+" · "+str(lobby.NAMES.get(item.get("turretType",""),item.get("turretType","")))+" · "+str(CollectionUI.PARTS.get(item.get("part",""),item.get("part",""))),12))
		if int(data.get("grantedDiamonds",0)) > 0: body.add_child(T.label("다이아 +%d" % int(data.grantedDiamonds),14))
		if int(data.get("grantedModuleTickets",0)) > 0: body.add_child(T.label("모듈권 +%d" % int(data.grantedModuleTickets),14))
		_button(body,"닫기",lobby.close_modal,"secondary")
		return
	if page == "연구 즉시 완료":
		_research_confirmation(body)
		return
	if page == "연구 슬롯 구매":
		_slot_confirmation(body)
		return
	if page in ["모듈 분해","모듈 일괄 분해"]:
		_disassembly_confirmation(body)
		return
	var values := context.duplicate(true)
	if page == "모듈 뽑기":
		var count := int(values.get("count",1))
		var tickets := int(lobby._p().get("turretModules",{}).get("tickets",0))
		var diamonds := maxi(0,count-tickets)*40
		body.add_child(T.label("모듈 %d개를 획득합니다. 모듈권 %d장%s" % [count,mini(tickets,count)," · 다이아 %d개" % diamonds if diamonds > 0 else ""],14))
		values.buyMissingTicketsWithDiamonds = diamonds > 0
		var confirm := _button(body,"확인",_perform.bind(actions[page],values))
		confirm.disabled = confirm.disabled or lobby.diamonds() < diamonds

func _framed_row(parent: Node) -> HBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",Frame.new("ui/components/row_frame.png",8))
	parent.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	frame.add_child(row)
	return row

func _image(path: String, extent: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = T.texture(path)
	icon.custom_minimum_size = Vector2(extent,extent)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _diamond_amount(parent: Node, value: String, pixels := 17) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation",4)
	parent.add_child(row)
	var icon := _image("res://assets/ui/diamond_currency.png",18 if pixels >= 17 else 13)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var amount := T.label(value,pixels)
	amount.name = "DiamondAmount"
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.add_theme_color_override("font_color",Color("8ee6ff"))
	row.add_child(amount)

func _balance(body: VBoxContainer, cost: int) -> void:
	var diamonds: int = lobby.diamonds()
	var row := _framed_row(body)
	var label := T.label("사용 다이아",13)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_diamond_amount(row,str(cost))
	body.add_child(T.label("보유 %d  →  사용 후 %d" % [diamonds,diamonds-cost] if diamonds >= cost else "보유 %d · %d 부족" % [diamonds,cost-diamonds],12))

func _confirm_actions(body: VBoxContainer, label: String, callback: Callable, enabled: bool, name: String, role := "primary") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	var cancel := _button(row,"취소",lobby.close_modal,"secondary")
	cancel.name = "ServiceCancel"
	var confirm := _button(row,label,callback,role)
	confirm.name = name
	if name in ["CompleteResearchConfirm","UnlockResearchSlotConfirm"]:
		confirm.icon = T.texture("res://assets/ui/diamond_currency.png")
		confirm.expand_icon = true
		confirm.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		confirm.add_theme_constant_override("icon_max_width",16)
	for button in [cancel,confirm]:
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.disabled = confirm.disabled or not enabled

func _research_state(id: String) -> Dictionary:
	for active in lobby._p().get("activeResearches",[]):
		if str(active.get("type","")) == id: return active
	return {}

func _research_cost(active: Dictionary) -> int:
	return ceili(maxf(0,float(active.get("startedAtMillis",0))+float(active.get("durationMillis",0))-Time.get_unix_time_from_system()*1000.0)/60000.0)

func _research_confirmation(body: VBoxContainer) -> void:
	var id := str(context.get("id",""))
	var active := _research_state(id)
	if active.is_empty() or _research_cost(active) <= 0:
		body.add_child(T.label("진행 중인 연구가 없습니다. 완료 상태를 확인해 주세요.",13))
		_confirm_actions(body,"즉시 완료",Callable(),false,"CompleteResearchConfirm")
		return
	var heading := _framed_row(body)
	heading.add_child(_image(str(GrowthUI.ICONS.get(id,"research/"+id.to_snake_case()+".png")),40))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(detail)
	detail.add_child(T.label(str(GrowthUI.TITLES.get(id,id)),15))
	detail.add_child(T.label("Lv.%d  →  Lv.%d" % [int(active.get("targetLevel",1))-1,int(active.get("targetLevel",1))],12))
	var cost := _research_cost(active)
	_balance(body,cost)
	if lobby.diamonds() < cost: body.add_child(T.label("다이아가 부족합니다.",12))
	_confirm_actions(body,"즉시 완료 · %d" % cost,_perform.bind("complete_research",{"id":id,"quoted_cost":cost,"target_level":int(active.get("targetLevel",0))}),lobby.diamonds()>=cost,"CompleteResearchConfirm")

func _slot_confirmation(body: VBoxContainer) -> void:
	if lobby._p().get("researchSlotTwoUnlocked",false):
		body.add_child(T.label("두 번째 연구 슬롯이 이미 열려 있습니다.",13))
		_confirm_actions(body,"슬롯 해금",Callable(),false,"UnlockResearchSlotConfirm")
		return
	var row := _framed_row(body)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	detail.add_child(T.label("연구 슬롯 1  →  2",15))
	detail.add_child(T.label("연구 2개를 동시에 진행할 수 있습니다.",12))
	var cost := int(lobby.app.run_domain.growth.data.constants.researchSlotTwoUnlockCost)
	_balance(body,cost)
	if lobby.diamonds() < cost: body.add_child(T.label("다이아가 부족합니다.",12))
	_confirm_actions(body,"슬롯 해금 · %d" % cost,_perform.bind("unlock_research_slot_two",{"quoted_cost":cost}),lobby.diamonds()>=cost,"UnlockResearchSlotConfirm")

func _module_plan() -> Dictionary:
	var requested: Array = [context.id] if context.has("id") else context.get("ids",[]).duplicate()
	var seen := {}
	var eligible: Array = []
	var signature: Array = []
	var excluded := 0
	var total := 0
	var counts := {"normal":0,"magic":0,"rare":0,"unique":0}
	for raw_id in requested:
		var id := str(raw_id)
		if seen.has(id): continue
		seen[id] = true
		var matched: Dictionary = {}
		for item in lobby._p().get("turretModules",{}).get("items",[]):
			if str(item.get("id","")) == id: matched = item; break
		if matched.is_empty():
			signature.append([id,"missing"])
			excluded += 1
			continue
		var grade := str(matched.get("grade","normal"))
		signature.append([id,grade,str(matched.get("turretType","")),str(matched.get("part","")),bool(matched.get("equipped",false))])
		if matched.get("equipped",false): excluded += 1; continue
		eligible.append(matched)
		counts[grade] = int(counts.get(grade,0))+1
		total += int(MODULE_DIAMONDS.get(grade,0))
	return {"items":eligible,"signature":signature,"excluded":excluded,"counts":counts,"diamonds":total}

func _disassembly_confirmation(body: VBoxContainer) -> void:
	var plan := _module_plan()
	module_confirmation = plan.signature.duplicate(true)
	var count: int = plan.items.size()
	body.add_child(T.label("장착 중인 모듈은 제외됩니다. 분해한 모듈은 복구할 수 없습니다.",12))
	if int(plan.excluded) > 0: body.add_child(T.label("장착 중이거나 없는 대상 %d개 제외" % int(plan.excluded),11))
	var summary := _framed_row(body)
	var counts: Array = []
	for grade in ["normal","magic","rare","unique"]:
		if int(plan.counts[grade]) > 0: counts.append("%s %d" % [CollectionUI.GRADES[grade],int(plan.counts[grade])])
	var summary_text := T.label(" · ".join(counts) if not counts.is_empty() else "분해할 모듈이 없습니다.",12)
	summary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(summary_text)
	if count > 0:
		var preview := ScrollContainer.new()
		preview.name = "ModuleDisassemblyPreview"
		preview.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		preview.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		preview.custom_minimum_size.y = minf(180.0,maxf(54.0,float(count)*54.0))
		body.add_child(preview)
		var items := VBoxContainer.new()
		items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items.add_theme_constant_override("separation",5)
		preview.add_child(items)
		for item in plan.items:
			var row := _framed_row(items)
			row.get_parent().name = "ModulePreview_"+str(item.id)
			var glyph := CollectionUI.PartGlyph.new()
			glyph.name = "ModulePartGlyph"
			glyph.part = str(item.get("part","core"))
			glyph.tint = CollectionUI.COLORS.get(item.get("grade","normal"),Color.WHITE)
			glyph.custom_minimum_size = Vector2(28,28)
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(glyph)
			var names := VBoxContainer.new()
			names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(names)
			var grade := str(item.get("grade","normal"))
			var key := str(item.get("turretType",""))+"_"+str(item.get("part",""))
			names.add_child(T.label("%s · %s" % [CollectionUI.GRADES.get(grade,grade),CollectionUI.MODULE_NAMES.get(key,"모듈")],12))
			names.add_child(T.label("%s · %s" % [lobby.NAMES.get(item.get("turretType",""),item.get("turretType","")),CollectionUI.PARTS.get(item.get("part",""),item.get("part",""))],10))
			_diamond_amount(row,str(int(MODULE_DIAMONDS.get(grade,0))),12)
	var reward := _framed_row(body)
	var reward_title := T.label("획득 다이아",13)
	reward_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.add_child(reward_title)
	_diamond_amount(reward,"+%d" % int(plan.diamonds))
	_confirm_actions(body,"모듈 %d개 분해" % count,_perform.bind("disassemble_modules",{"ids":plan.items.map(func(item): return item.id)}),count>0,"DisassembleModulesConfirm","danger")

func _perform(action: String, values: Dictionary) -> void:
	if pending or _services() == null or _services().busy: return
	var request := values.duplicate(true)
	if action == "disassemble_modules":
		var current := _module_plan()
		if current.signature != module_confirmation or current.items.is_empty():
			notice = "분해 대상이 변경되었습니다. 새 목록을 확인해 주세요."
			_render()
			return
		request = {"ids":current.items.map(func(item): return item.id)}
	elif action == "complete_research":
		var active := _research_state(str(values.get("id","")))
		var cost := _research_cost(active) if not active.is_empty() else 0
		if cost <= 0 or int(active.get("targetLevel",0)) != int(values.get("target_level",-1)) or cost != int(values.get("quoted_cost",-1)) or lobby.diamonds() < cost:
			notice = "연구 상태나 비용이 변경되었습니다. 다시 확인해 주세요."
			_render()
			return
		request = {"id":values.id}
	elif action == "unlock_research_slot_two":
		var cost := int(lobby.app.run_domain.growth.data.constants.researchSlotTwoUnlockCost)
		if lobby._p().get("researchSlotTwoUnlocked",false) or cost != int(values.get("quoted_cost",-1)) or lobby.diamonds() < cost:
			notice = "슬롯 상태나 비용이 변경되었습니다. 다시 확인해 주세요."
			_render()
			return
		request = {}
	pending = true
	var captured := view_epoch
	_render()
	var result: Dictionary = await _services().perform(action,request)
	if not _active_view(captured): return
	pending = false
	_show_result(result)
	if result.get("ok",false):
		data = result.get("body",{})
		if action in ["draw_modules","disassemble_modules","complete_research","unlock_research_slot_two"]: notice = ""
		if page == "우편함":
			_fetch()
			return
	_render()
