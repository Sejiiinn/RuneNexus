extends Control
## Independent Godot lobby shell; original Flutter game pages share saved progression.
const AppTheme = preload("res://ui/app_theme.gd")
const MenuTheme = preload("res://ui/battle_theme.gd")
const ModalFrame = preload("res://ui/game_modal_frame.gd")
const Home = preload("res://ui/lobby_home.gd")
const Device = preload("res://app/device_preferences.gd")
const Growth = preload("res://ui/lobby_growth.gd")
const Core = preload("res://ui/lobby_core.gd")
const Collection = preload("res://ui/lobby_collection.gd")
const Stages = preload("res://ui/lobby_stages.gd")
const NAMES := {"startingGold":"초기 자금", "nexusHp":"코어 내구도", "supply":"보급", "fireTraining":"화력 훈련", "physicalDamageTraining":"물리 피해 훈련", "elementalDamageTraining":"원소 피해 훈련", "criticalDamage":"치명타 피해", "killGold":"처치 골드", "bossBounty":"보스 현상금", "linkCostOptimization":"링크 비용 최적화", "turretLevelUpOptimization":"포탑 강화 비용 최적화", "researchEfficiency":"연구 효율", "researchCostEfficiency":"연구 비용 효율", "turretTargetPriority":"포탑 목표 우선순위", "linkExpansionOne":"링크 확장", "gemAttunement":"젬 조율", "criticalChance":"치명타 확률", "emergencySale":"긴급 매각", "linkMaintenance":"링크 정비", "crystalRecovery":"결정 회수", "runeResonance":"룬 공명", "runUpgradeCostOptimization":"전투 강화 비용 최적화", "towerDamageLimitExpansion":"화력 한계 확장", "killGoldLimitExpansion":"처치 보상 한계 확장", "waveGoldLimitExpansion":"보급 한계 확장", "guardianBeam":"수호 광선", "riftMark":"균열 낙인", "arrow":"기관총", "cannon":"대포", "magic":"화염", "frost":"냉각", "sniper":"저격", "lightning":"번개"}
var app
var page := "로비"
var home: Control
var body: VBoxContainer
var safe: MarginContainer
var message := ""
var core_names: Dictionary = {}
var core_draft: Dictionary = {}
var growth = Growth.new()
var core = Core.new()
var collection = Collection.new()
var stages = Stages.new()
var modal: Control
var modal_position: Control
var modal_visual: Control
var modal_frame: PanelContainer
var modal_body: VBoxContainer
var modal_scroll: ScrollContainer
var modal_asset: TextureRect
var modal_fill: ColorRect
var _rendered_page := ""
var _page_scroll: ScrollContainer
var _services
var _refreshing := false

func _ready() -> void:
	theme = MenuTheme.create()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	core_names = JSON.parse_string(FileAccess.get_file_as_string("res://ui/core_names.json"))
	for helper in [growth, core, collection, stages]: helper.setup(self)
	resized.connect(_safe_layout)
	refresh()

func _p() -> Dictionary: return app.progression_inputs
func _title(id: String) -> String: return str(Growth.TITLES.get(id, NAMES.get(id, core_names.get(id,id))))

func _insets() -> Vector4:
	if not OS.has_feature("mobile"): return Vector4.ZERO
	var screen := Vector2(DisplayServer.screen_get_size())
	var ratio := size / screen
	if OS.has_feature("android"):
		return Home._cutout_insets(DisplayServer.get_display_cutouts(), screen) * Vector4(ratio.x, ratio.y, ratio.x, ratio.y)
	var area := DisplayServer.get_display_safe_area()
	return Vector4(area.position.x * ratio.x, area.position.y * ratio.y, (screen.x - area.end.x) * ratio.x, (screen.y - area.end.y) * ratio.y)

func _safe_layout() -> void:
	if is_instance_valid(safe):
		var inset := _insets()
		for i in range(4): safe.add_theme_constant_override(["margin_left", "margin_top", "margin_right", "margin_bottom"][i], int(inset[i]))
	_layout_modal.call_deferred()

func _image(path: String, dimensions: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = AppTheme.texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = dimensions
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _text(value: String, font_size := 12) -> Label:
	var label := AppTheme.label(value, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func _plain_button(value: String, callback: Callable) -> Button:
	var b := AppTheme.button(value, callback)
	b.custom_minimum_size.y = 36
	for state in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return b

func _margin(parent: Node, pad: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", pad)
	margin.add_theme_constant_override("margin_right", pad)
	parent.add_child(margin)
	return margin

func refresh() -> void:
	if _refreshing: return
	_refreshing = true
	var same_page := _rendered_page == page
	var scroll_position := _page_scroll.scroll_vertical if same_page and is_instance_valid(_page_scroll) else 0
	var kept_modal: Control = modal if same_page and is_instance_valid(modal) else null
	if kept_modal != null: remove_child(kept_modal)
	else:
		modal = null
		modal_frame = null
	_page_scroll = null
	_rendered_page = page
	for child in get_children():
		remove_child(child)
		child.queue_free()
	home = null
	safe = null
	if page == "로비":
		home = Home.new()
		home.lobby = self
		add_child(home)
		_finish_refresh(kept_modal, scroll_position)
		return
	var bg := _image("main_menu_background.jpg", Vector2.ZERO)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color("02070d38")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	safe = MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	_safe_layout()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	safe.add_child(column)
	_header(column)
	var content := _margin(column, 24 if page == "스테이지" else (0 if page == "코어" else 12))
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = VBoxContainer.new()
	body.name = "PageBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	if page in ["코어", "스테이지"]:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if page == "스테이지":
			var centered := CenterContainer.new()
			centered.size_flags_vertical = Control.SIZE_EXPAND_FILL
			centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.add_child(centered)
			centered.add_child(body)
			var fit := func(): body.custom_minimum_size = Vector2(minf(400,centered.size.x),centered.size.y)
			centered.resized.connect(fit)
			fit.call_deferred()
		else: content.add_child(body)
	else:
		var scroll := ScrollContainer.new()
		_page_scroll = scroll
		scroll.name = "PageScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)
		scroll.add_child(body)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.alignment = BoxContainer.ALIGNMENT_CENTER
	match page:
		"스테이지": stages.render()
		"강화": growth.upgrades()
		"연구": growth.research()
		"코어": core.render()
		"포탑": collection.modules()
		"설정": _settings()
	if not message.is_empty(): _margin(column, 12).add_child(AppTheme.label(message, 12))
	if page == "강화" and growth.has_method("upgrades_tabs"): growth.upgrades_tabs(column)
	_footer(column)
	_finish_refresh(kept_modal, scroll_position)

func _finish_refresh(kept_modal: Control, scroll_position: int) -> void:
	_refreshing = false
	if kept_modal != null:
		add_child(kept_modal)
		var update: Callable = kept_modal.get_meta("refresh",Callable())
		if update.is_valid(): update.call_deferred()
	if is_instance_valid(_page_scroll):
		var weak_scroll: WeakRef = weakref(_page_scroll)
		var restore := func():
			var target: ScrollContainer = weak_scroll.get_ref()
			if target != null: target.scroll_vertical = scroll_position
		restore.call_deferred()
		get_tree().process_frame.connect(restore,CONNECT_ONE_SHOT)

func _quest_ready() -> bool:
	var p := _p()
	if p.get("dailyQuestClockRollbackDetected",false): return false
	if not p.get("dailyAttendanceRewardClaimed",false): return true
	var targets: Dictionary = preload("res://app/quest_progress.gd").DAILY
	var complete := 0
	for key in targets:
		if int(p.get("dailyQuestProgress",{}).get(key,0)) >= int(targets[key]):
			complete += 1
			if not key in p.get("claimedDailyQuestRewards",[]): return true
	return complete == targets.size() and not p.get("dailyQuestAllCompleteClaimed",false)

func _currency(parent: Node, icon: String, value: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	row.add_child(_image(icon, Vector2(14,14)))
	var label := _text(str(value), 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)

func _header(parent: Node) -> void:
	var inset := _margin(parent, 12)
	inset.name = "MenuHeader"
	inset.add_theme_constant_override("margin_top", 8)
	inset.add_theme_constant_override("margin_bottom", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inset.add_child(row)
	var identity := GridContainer.new()
	identity.name = "MenuIdentity"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("h_separation", 6)
	identity.add_theme_constant_override("v_separation", 0)
	row.add_child(identity)
	var back := _plain_button("‹  로비", open_page.bind("로비"))
	back.name = "MenuBack"
	back.custom_minimum_size = Vector2(42,36)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	identity.add_child(back)
	var heading := HBoxContainer.new()
	heading.name = "MenuHeading"
	heading.custom_minimum_size.x = 102
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_theme_constant_override("separation", 6)
	identity.add_child(heading)
	if page == "스테이지":
		var event := _plain_button("", open_quests)
		event.name = "StageQuests"
		event.custom_minimum_size = Vector2(38,38)
		event.icon = AppTheme.texture("quests/entry_reward_ready.jpg" if _quest_ready() else "quests/entry_default.jpg")
		event.expand_icon = true
		event.add_theme_constant_override("icon_max_width",38)
		heading.add_child(event)
		var logo := _image("rune_nexus_logo_serif.png", Vector2(0,44))
		logo.name = "StageHeaderLogo"
		logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(logo)
	else:
		var path: String = {"코어":"core","강화":"upgrade","연구":"research","포탑":"turret"}.get(page,"stage")
		var icon := _image("stage_rewards/reward_%s.png" % path, Vector2(24,24))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading.add_child(icon)
		var title := _text({"코어":"넥서스 코어", "강화":"영구 강화", "연구":"연구", "포탑":"포탑 모듈"}.get(page, page), 15)
		title.name = "MenuTitle"
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading.add_child(title)
	var resources := PanelContainer.new()
	resources.name = "MenuResources"
	resources.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resources.add_theme_stylebox_override("panel", preload("res://ui/lobby_frame.gd").new("ui/components/row_frame.png",8))
	row.add_child(resources)
	var wallet := VBoxContainer.new()
	wallet.name = "MenuWallet"
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet.custom_minimum_size.x = 56
	wallet.add_theme_constant_override("separation", 4)
	resources.add_child(wallet)
	_currency(wallet,"res://assets/ui/diamond_currency.png",int(_p().get("freeDiamonds",0))+int(_p().get("paidDiamonds",0)))
	if page == "포탑": _currency(wallet,"stage_rewards/reward_module_ticket.png",int(_p().get("turretModules",{}).get("tickets",0)))
	else: _currency(wallet,"ui/hud/icons/rune.png",int(_p().get("runes",0)))
	# Keep navigation and title together on one line when both groups fit.
	# Long balances may wrap only the identity group; the wallet stays complete.
	var arrange := func():
		var available := size.x - _insets().x - _insets().z - 24 - 12 - resources.get_combined_minimum_size().x
		identity.columns = 2 if available >= back.get_combined_minimum_size().x + 6 + 102 else 1
	inset.resized.connect(arrange)
	arrange.call_deferred()

func _navigation_style(selected: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = AppTheme.texture("ui/hud/turret_actions/native/tab_active.png" if selected else "ui/hud/turret_actions/native/tab_idle.png")
	style.set_texture_margin(SIDE_LEFT,8)
	style.set_texture_margin(SIDE_RIGHT,8)
	style.set_texture_margin(SIDE_TOP,6)
	style.set_texture_margin(SIDE_BOTTOM,6)
	style.set_content_margin_all(0)
	return style

func _footer(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.name = "MenuTabs"
	var dock := StyleBoxTexture.new()
	dock.texture = AppTheme.texture("ui/hud/dock_panel.png")
	dock.set_texture_margin_all(2)
	dock.content_margin_left = 4
	dock.content_margin_right = 4
	dock.content_margin_top = 4
	dock.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel",dock)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",2)
	panel.add_child(row)
	var paths := ["stage", "core", "upgrade", "research", "turret"]
	var tabs := ["스테이지", "코어", "강화", "연구", "포탑"]
	for i in range(5):
		var tab: String = tabs[i]
		var selected := page == tab
		var b := _plain_button("", open_page.bind(tab))
		b.name = "Tab" + paths[i].capitalize()
		b.tooltip_text = tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 56
		b.add_theme_stylebox_override("normal",_navigation_style(true) if selected else StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover",_navigation_style(selected))
		b.add_theme_stylebox_override("pressed",_navigation_style(true))
		b.add_theme_stylebox_override("focus",_navigation_style(true))
		row.add_child(b)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_top = 4
		box.offset_bottom = -4
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation",2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var icon := _image("stage_rewards/reward_%s.png" % paths[i],Vector2.ONE*26)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.modulate = Color.WHITE if selected else Color("b1c7d2")
		box.add_child(icon)
		var label := _text(tab,12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",AppTheme.font(800 if selected else 700))
		label.add_theme_color_override("font_color",Color("f1d18a") if selected else Color("aac3ce"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)

func open_page(value: String) -> void:
	if value == "퀘스트":
		open_quests()
		return
	if value == "스테이지" and page != value: stages.reset_navigation()
	page = value
	message = ""
	if page == "코어": core_draft = _p().get("corePassiveNodeRanks", {}).duplicate()
	refresh()

func open_quests() -> void:
	if is_instance_valid(home): home.close_modal()
	var content := open_modal("임무")
	modal.set_meta("max_width", 430)
	set_modal_asset("quests/ui/dialog_frame.png")
	collection.quests(content)

func set_modal_asset(path: String) -> void:
	if is_instance_valid(modal_asset):
		modal_asset.texture = AppTheme.texture(path)
		modal_fill.visible = modal_asset.texture != null
		modal_frame.add_theme_stylebox_override("panel", MenuTheme.box(Color.TRANSPARENT,Color.TRANSPARENT,16) if modal_asset.texture != null else ModalFrame.create(Color("8fa8ba"),"standard",16))
		modal_frame.queue_redraw()

func set_modal_stylebox(style: StyleBox) -> void:
	modal_asset.texture = null
	modal_fill.hide()
	modal_frame.add_theme_stylebox_override("panel",style)
	_layout_modal.call_deferred()

func open_modal(title: String) -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.name = "LobbyModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var barrier := ColorRect.new()
	barrier.color = Color("02070dd9")
	barrier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	barrier.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: close_modal()
	)
	modal.add_child(barrier)
	# Keep container placement separate from the entrance animation's local offset.
	modal_position = Control.new()
	modal_position.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(modal_position)
	modal_visual = Control.new()
	modal_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_position.add_child(modal_visual)
	modal_frame = PanelContainer.new()
	modal_frame.name = "ModalFrame"
	modal_frame.add_theme_stylebox_override("panel", MenuTheme.box(Color("091624"), Color("7493a4"), 16))
	modal_visual.add_child(modal_frame)
	modal_fill = ColorRect.new()
	modal_fill.color = Color("07111b")
	modal_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_fill.hide()
	modal_visual.add_child(modal_fill)
	modal_visual.move_child(modal_fill,modal_frame.get_index())
	modal_asset = _image("", Vector2.ZERO)
	modal_asset.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	modal_asset.stretch_mode = TextureRect.STRETCH_SCALE
	# Top-level avoids PanelContainer assigning the background its content margins.
	modal_visual.add_child(modal_asset)
	modal_visual.move_child(modal_asset, modal_frame.get_index())
	modal_frame.add_theme_stylebox_override("panel", ModalFrame.create(Color("8fa8ba"),"standard",16))
	var column := VBoxContainer.new()
	modal_frame.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var label := _text(title, 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var close := _plain_button("×", close_modal)
	close.name = "CloseModal"
	close.custom_minimum_size = Vector2(32,32)
	header.add_child(close)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(modal_scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 8)
	modal_scroll.add_child(modal_body)
	modal_body.minimum_size_changed.connect(func(): _layout_modal.call_deferred())
	_layout_modal()
	_layout_modal.call_deferred()
	AppTheme.animate_modal(modal_visual)
	return modal_body

func set_modal_header(header: Control) -> void:
	var column: Control = modal_frame.get_child(0)
	var previous := column.get_child(0)
	column.remove_child(previous)
	previous.queue_free()
	column.add_child(header)
	column.move_child(header,0)
	_layout_modal.call_deferred()

func _layout_modal() -> void:
	if not is_instance_valid(modal_frame): return
	var inset := _insets()
	var available := size - Vector2(inset.x+inset.z, inset.y+inset.w)
	var width := minf(float(modal.get_meta("max_width", 420)), available.x - 32)
	var header: Control = modal_frame.get_child(0).get_child(0)
	var header_height := header.get_combined_minimum_size().y + 8 if header.visible else 0.0
	var height := minf(maxf(100, modal_body.get_combined_minimum_size().y + 32 + header_height), available.y - 32)
	modal_frame.size = Vector2(width, height)
	modal_position.position = Vector2(inset.x,inset.y) + (available - modal_frame.size) / 2
	modal_position.size = modal_frame.size
	modal_visual.size = modal_frame.size
	modal_visual.pivot_offset = modal_frame.size / 2
	modal_fill.position = Vector2.ONE * 6
	modal_fill.size = modal_frame.size - Vector2.ONE * 12
	modal_asset.position = Vector2.ZERO
	modal_asset.size = modal_frame.size

func close_modal() -> bool:
	if not is_instance_valid(modal): return false
	ModalFrame.dismiss(modal)
	modal = null
	modal_frame = null
	return true

func _has_run() -> bool:
	return not app.run_domain.state.is_empty() and not app.run_domain.is_finished()

func _failure() -> void:
	message = "처리하지 못했습니다. " + str(app.checkpoint.message)
	refresh()

func open_service(label_text: String, context: Dictionary = {}) -> void:
	if is_instance_valid(home): home.close_modal()
	if _services == null:
		_services = load("res://ui/lobby_services.gd").new()
		_services.lobby = self
	_services.open(label_text,context)

func _service(label_text: String, context: Dictionary = {}) -> void:
	open_service(label_text,context)

func _change(command: Dictionary) -> void:
	if app.apply_growth_command(command): message = "저장했습니다."
	else: message = "변경하지 못했습니다. 비용·해금 조건 또는 저장 상태를 확인하세요."
	refresh()

func _start(index: int) -> void:
	if index < 0 or index >= int(_p().get("unlockedStageCount", 1)) or app.get("startup_blocked") == true: return
	if _has_run():
		var content := open_modal("새 전투 시작")
		content.add_child(AppTheme.label("진행 중인 전투를 종료하고 스테이지 %d에 도전할까요?" % (index + 1), 13))
		var confirm := AppTheme.button("새 전투 시작", func():
			close_modal()
			if not app.start_stage(index): _failure()
		)
		confirm.name = "ConfirmNewRun"
		content.add_child(confirm)
		content.add_child(AppTheme.button("취소", close_modal))
	else:
		close_modal()
		if not app.start_stage(index): _failure()

func _node_details(id: String) -> void: core.node_details(id)
func _skills() -> void: core.skills()
func go_back() -> void:
	if close_modal(): return
	if is_instance_valid(home) and home.close_modal(): return
	if page != "로비": open_page("로비")
	else: app.request_quit()

func _settings() -> void:
	body.add_child(AppTheme.label("그래픽", 20))
	_radio("MSAA", "msaa", [0, 2], ["끄기", "2배"], 2)
	_radio("그림자 품질", "shadow", [0, 512, 1024, 2048], ["끄기", "낮음", "중간", "높음"], 2048)
	body.add_child(AppTheme.button("지금 저장", func():
		message = "저장했습니다." if app.persist_progression() else "저장 실패. 기존 저장을 유지합니다."
		refresh()
	))
	body.add_child(AppTheme.button("계정 및 저장", _service.bind("계정 로그인 · 온라인 저장")))
	body.add_child(AppTheme.label("자동 저장은 이 기기의 진행 상황을 보관합니다. 계정 로그인과 온라인 저장은 아직 연결되지 않았습니다."))

func _radio(title: String, key: String, values: Array, labels: Array, fallback: Variant) -> void:
	body.add_child(AppTheme.label(title))
	var flow := HFlowContainer.new()
	body.add_child(flow)
	var group := ButtonGroup.new()
	for i in range(values.size()):
		var b := CheckBox.new()
		b.text = labels[i]
		b.button_group = group
		b.button_pressed = Device.read().get(key, fallback) == values[i]
		b.pressed.connect(func():
			var settings: Dictionary = Device.read()
			settings[key] = values[i]
			if not Device.write(settings):
				message = "설정을 저장하지 못했습니다."
			else:
				Device.apply(app.scene.options)
				app.scene._apply_options()
				message = "설정을 저장하고 적용했습니다."
			refresh()
		)
		flow.add_child(b)

func _core_effect_text(definition: Dictionary, rank: int) -> String:
	var names := {"cooldownRecoveryRate":"재사용 대기시간 회복 속도", "turretAttackRateAmplification":"스킬 후 포탑 공격 속도", "turretDamageAmplification":"스킬 후 포탑 피해", "coreSkillPowerMultiplier":"코어 스킬 위력", "thirdCoreSkillPowerMultiplier":"세 번째 코어 스킬 위력", "nexusMaxHpMultiplier":"코어 최대 체력", "roundRecoveryRate":"라운드 체력 회복", "damageRestorationRate":"손상 복원", "impactDispersionRate":"충격 분산", "threatWeakeningRate":"위협 약화", "emergencyRecoveryRate":"비상 회복", "hasFinalDefense":"최종 방위선", "hasCombinedFront":"통합 전선", "buildCostMultiplier":"건설 비용", "combinedFrontMultiplier":"통합 전선 비용", "roundClearGoldMultiplier":"라운드 보상", "traitShardCostMultiplier":"특성 파편 비용", "diversityDiscountPerType":"포탑 종류별 할인", "gemSpectrumPerType":"젬 종류별 효과", "linkCostMultiplier":"링크 비용"}
	var text := "다음 등급 효과"
	var effect: Dictionary = definition.effects[rank]
	var base: Dictionary = definition.effects[0]
	for key in effect:
		if effect[key] == base.get(key): continue
		var value := "활성" if effect[key] is bool else ("×%.2f" % float(effect[key]) if str(key).ends_with("Multiplier") else "%.1f%%" % (float(effect[key]) * 100))
		text += "\n%s %s" % [names.get(key, key), value]
	return text
