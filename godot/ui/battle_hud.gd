extends Control
const RuntimeProfile = preload("res://app/runtime_profile.gd")
## Presentation only. Transactions and prices remain owned by RunCommands.
const AppTheme = preload("res://ui/app_theme.gd")
const BattleTheme = preload("res://ui/battle_theme.gd")
const Components = preload("res://ui/combat_component_theme.gd")
const HudChrome = preload("res://ui/hud_chrome.gd")
const TOWERS := {"arrow":"기관총", "cannon":"대포", "magic":"화염", "frost":"냉각", "sniper":"저격", "lightning":"라이트닝"}
const DESCRIPTIONS := {"arrow":"빠른 연사로 앞선 적을 집중 공격하는 단일 대상 포탑입니다.","cannon":"느리지만 강한 포탄으로 주변 적까지 함께 타격합니다.","magic":"원소 화염으로 적을 태우는 지속피해 성향의 포탑입니다.","frost":"포탑 중심에서 냉기를 방출해 사거리 안 적 전체를 타격하고 잠시 둔화합니다.","sniper":"긴 사거리에서 1초간 조준한 뒤 즉시 타격하는 단일 대상 포탑입니다.","lightning":"코일 방전을 충전한 뒤 번개가 근처 적에게 이어지는 중화기 원소 포탑입니다."}
const UPGRADES := {"towerDamage":"포탑 피해", "killGold":"처치 골드", "waveGold":"웨이브 골드"}
const PRIORITIES := {"first":"선두", "last":"후미", "strongest":"최대 체력", "weakest":"최저 체력", "nearest":"가까운 적"}
const PRIORITY_HELP := {"first":"코어에 가장 가까이 다가간 적을 먼저 공격합니다.","last":"진행 경로의 뒤쪽에 있는 적을 먼저 공격합니다.","strongest":"남은 체력이 가장 높은 적을 공격합니다.","weakest":"남은 체력이 가장 낮은 적을 공격합니다.","nearest":"포탑에서 가장 가까운 적을 공격합니다."}
var app
var labels: Dictionary
var resources: Label
var gold_label: Label
var shard_label: Label
var wave_label: Label
var reward_label: Label
var reward_caption: Label
var enemy_caption: Label
var status: Label
var enemy_intel: HBoxContainer
var intel_key: Variant = ""
var hp: ProgressBar
var message: Label
var home: Button
var start: Button
var pause_button: Button
var camera_button: Button
var retry_save: Button
var auto_start: Button
var auto_start_popup: PopupMenu
const AUTO_MODES := ["pauseEachRound", "skipBossRounds", "fullAuto"]
const AUTO_LABELS := ["웨이브마다 정지", "보스 제외 자동", "전부 자동"]
const AUTO_CAPTIONS := ["수동", "보스 대기", "자동"]
var bottom: VBoxContainer
var detail_panel: PanelContainer
var _dock_layout_pending := false
var body: VBoxContainer
var scroll: ScrollContainer
var top: Control
var dock: PanelContainer
var overlay: PanelContainer
var overlay_body: VBoxContainer
var rewards
var tab := "stats"
var main_tab := "turrets"
var selected_slot := -1
var selected_gem := ""
var elapsed := 0.0
var body_key: Variant = ""
var body_purchase_buttons: Array[Dictionary] = []
var overlay_key := ""
var main_buttons := {}
var speed_buttons := {}
var _cached_stage_index := -1
var _cached_stage_source: Dictionary = {}
var _cached_insets := Vector4.ZERO
var _insets_valid := false
var damage_label: Label
var core_label: Label
var core_bar: ProgressBar
var core_metric: Label
var modal: ColorRect
var modal_body: VBoxContainer
var modal_scroll: ScrollContainer
var modal_resume := false
var modal_panel: PanelContainer
var modal_bottom_sheet := false
var trait_preview := ""
var last_selected := Vector2i(-1,-1)
var total_dps := 0.0
var dps_key := -1
var configuration_cache = preload("res://ui/hud_configuration_cache.gd").new()
var _layout_key: Array = []

func _ready() -> void:
	get_viewport().size_changed.connect(func(): _insets_valid = false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = BattleTheme.create()
	labels = JSON.parse_string(FileAccess.get_file_as_string("res://ui/battle_labels.json"))
	top = VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8; top.offset_right = -8; top.offset_top = 8
	add_child(top)
	var top_frame := PanelContainer.new(); top_frame.name = "ResourceHUD"
	top_frame.add_theme_stylebox_override("panel",HudChrome.panel(8)); top.add_child(top_frame)
	var top_row := HBoxContainer.new(); top_row.add_theme_constant_override("separation",7)
	top_frame.add_child(top_row)
	var wallet := VBoxContainer.new(); wallet.name = "Wallet"; wallet.custom_minimum_size.x = 88
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER; wallet.add_theme_constant_override("separation",5); top_row.add_child(wallet)
	for item in [["gold",""],["shard",""],["power","전투력 "]]:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",5); wallet.add_child(row)
		var icon := _icon(row,"ui/hud/icons/"+item[0]+".png",15); icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var value := _label(row,item[1],11 if item[0] == "power" else 14)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF; value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_color_override("font_color",Color("e8f8ff"))
		if item[0] == "gold": gold_label = value
		elif item[0] == "shard": shard_label = value
		else: resources = value
	top_row.add_child(HudChrome.divider())
	var status_box := VBoxContainer.new(); status_box.name = "WaveInformation"
	status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; status_box.add_theme_constant_override("separation",3)
	top_row.add_child(status_box)
	var health_row := HBoxContainer.new(); health_row.add_theme_constant_override("separation",4); status_box.add_child(health_row)
	status = _label(health_row,"",12); status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; status.add_theme_color_override("font_color",Color("e8f8ff"))
	wave_label = _label(health_row,"",11); wave_label.size_flags_horizontal = Control.SIZE_SHRINK_END; wave_label.autowrap_mode = TextServer.AUTOWRAP_OFF; wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home = _button(health_row,"",_stage_menu); home.tooltip_text = "스테이지 메뉴"
	home.custom_minimum_size = Vector2(32,32); home.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["normal","hover","pressed","disabled","focus"]:
		home.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var home_art := TextureRect.new(); home_art.name = "HomeArtwork"
	var home_region := AtlasTexture.new(); home_region.atlas = AppTheme.texture("ui/hud/icons/home_button.png")
	home_region.region = Rect2(207,207,840,840); home_region.filter_clip = true
	home_art.texture = home_region; home_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	home_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	home_art.mouse_filter = Control.MOUSE_FILTER_IGNORE; home.add_child(home_art)
	home_art.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	home_art.offset_left = -14; home_art.offset_top = -14
	home_art.offset_right = 14; home_art.offset_bottom = 14
	hp = ProgressBar.new(); hp.custom_minimum_size = Vector2(28,4); hp.show_percentage = false; hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.add_theme_stylebox_override("background",BattleTheme.box(Color("1a2a39"),Color.TRANSPARENT,0))
	hp.add_theme_stylebox_override("fill",BattleTheme.box(Color("6ef6a5"),Color.TRANSPARENT,0)); status_box.add_child(hp)
	var intel_row := HBoxContainer.new(); intel_row.add_theme_constant_override("separation",5); status_box.add_child(intel_row)
	var enemies := VBoxContainer.new(); enemies.add_theme_constant_override("separation",0); intel_row.add_child(enemies)
	enemy_caption = _label(enemies,"다음 적",10); enemy_caption.autowrap_mode = TextServer.AUTOWRAP_OFF; enemy_caption.add_theme_color_override("font_color",Color("91adba"))
	enemy_intel = HBoxContainer.new(); enemy_intel.add_theme_constant_override("separation",1); enemies.add_child(enemy_intel)
	var reward_box := VBoxContainer.new(); reward_box.add_theme_constant_override("separation",0); reward_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; intel_row.add_child(reward_box)
	reward_caption = _label(reward_box,"예상 보상",10); reward_caption.autowrap_mode = TextServer.AUTOWRAP_OFF; reward_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; reward_caption.add_theme_color_override("font_color",Color("91adba"))
	reward_label = _label(reward_box,"",11); reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; reward_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	reward_label.add_theme_color_override("font_color",Color("d9d3b8"))
	reward_label.custom_minimum_size.y = 24; reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	camera_button = _button(self,"고정 ↔",func(): app.toggle_camera(); refresh())
	camera_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	camera_button.custom_minimum_size = Vector2(68,32); camera_button.size = Vector2(68,32)
	_style_hud_button(camera_button,"quiet",false,Vector2(5,2))
	message = _label(top,"",11)
	retry_save = _button(top,"저장 다시 시도",func(): app.persist_progression(); refresh())
	dock = PanelContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_left = 0; dock.offset_right = 0; dock.offset_bottom = 0
	add_child(dock)
	dock.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	bottom = VBoxContainer.new(); bottom.add_theme_constant_override("separation",0); dock.add_child(bottom)
	var action_margin := MarginContainer.new(); action_margin.name = "ActionMargin"
	action_margin.add_theme_constant_override("margin_left",8); action_margin.add_theme_constant_override("margin_right",8)
	action_margin.add_theme_constant_override("margin_bottom",4); bottom.add_child(action_margin)
	var actions := HBoxContainer.new(); actions.name = "BattleActions"; actions.add_theme_constant_override("separation",4); action_margin.add_child(actions)
	var speed_group := PanelContainer.new(); speed_group.name = "SpeedGroup"; speed_group.custom_minimum_size.y = 36
	speed_group.add_theme_stylebox_override("panel",HudChrome.quiet("normal",false,Color("65c9df"),Vector2.ZERO)); actions.add_child(speed_group)
	var speeds := HBoxContainer.new(); speeds.add_theme_constant_override("separation",0); speed_group.add_child(speeds)
	for value in [1,2,4]:
		if value != 1: speeds.add_child(HudChrome.divider())
		var b := _button(speeds,"%dx" % value,func(): app.set_speed(value); refresh())
		b.custom_minimum_size = Vector2(32,36); b.add_theme_font_size_override("font_size",11)
		b.toggle_mode = true; speed_buttons[value] = b
	var space := Control.new(); space.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(space)
	pause_button = _button(actions,"Ⅱ",func(): app.toggle_pause(); refresh())
	pause_button.name = "PauseBattle"; pause_button.tooltip_text = "일시정지"; pause_button.custom_minimum_size = Vector2(32,36)
	_style_hud_button(pause_button,"quiet",false,Vector2(3,0))
	auto_start = _button(actions,"수동 ▾",_open_auto_start)
	auto_start.custom_minimum_size = Vector2(68,36)
	_style_hud_button(auto_start,"quiet",false,Vector2(5,0))
	auto_start_popup = PopupMenu.new(); auto_start_popup.name = "AutoStartModes"; add_child(auto_start_popup)
	auto_start_popup.add_theme_stylebox_override("panel",HudChrome.panel(10))
	auto_start_popup.add_theme_font_size_override("font_size",13)
	auto_start_popup.add_theme_constant_override("v_separation",16)
	auto_start_popup.about_to_popup.connect(func(): auto_start.text = AUTO_CAPTIONS[maxi(0,AUTO_MODES.find(app.auto_start_mode))]+" ▴")
	auto_start_popup.popup_hide.connect(func(): if is_inside_tree(): refresh())
	for index in AUTO_MODES.size(): auto_start_popup.add_radio_check_item(AUTO_LABELS[index],index)
	auto_start_popup.id_pressed.connect(func(index: int): app.set_auto_start_mode(AUTO_MODES[index]); refresh())
	start = _button(actions,"▶ 시작",_primary_action)
	start.custom_minimum_size = Vector2(76,36)
	_style_hud_button(start,"primary",false,Vector2(10,0))
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	detail_panel = PanelContainer.new(); detail_panel.name = "Details"; bottom.add_child(detail_panel); detail_panel.add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(body)
	body.minimum_size_changed.connect(_queue_dock_layout)
	body.resized.connect(_queue_dock_layout)
	bottom.minimum_size_changed.connect(_queue_dock_layout)
	var tabs_panel := PanelContainer.new(); tabs_panel.name = "RunPanelTabs"; tabs_panel.custom_minimum_size.y = 40
	tabs_panel.add_theme_stylebox_override("panel",HudChrome.docked_panel(4)); bottom.add_child(tabs_panel)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation",0); tabs_panel.add_child(tabs)
	for spec in [["turrets","포탑"],["upgrades","업그레이드"],["gems","젬"]]:
		if spec[0] != "turrets": tabs.add_child(HudChrome.divider())
		var b := _button(tabs,spec[1],func(): _select_main(spec[0]))
		b.custom_minimum_size.y = 34
		b.toggle_mode = true; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; main_buttons[spec[0]] = b
		b.icon = AppTheme.texture("ui/hud/icons/"+spec[0]+".png"); b.expand_icon = true; b.add_theme_constant_override("icon_max_width",18)
	overlay = PanelContainer.new(); add_child(overlay); overlay.hide()
	var modal_scroll := ScrollContainer.new(); modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; modal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; overlay.add_child(modal_scroll)
	overlay_body = VBoxContainer.new(); overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; modal_scroll.add_child(overlay_body)
	rewards = load("res://ui/battle_rewards.gd").new(); rewards.setup(self)
	refresh()

func _process(delta: float) -> void:
	if not visible: return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0; refresh()

func on_board_selection() -> void:
	if app.selected != last_selected:
		selected_slot = -1; selected_gem = ""; tab = "stats"
		app.selection_view.level_preview = false
	last_selected = app.selected
	main_tab = "turrets" if _selected_tile() != "" else "closed"
	body_key = ""

func _select_main(value: String) -> void:
	main_tab = "closed" if main_tab == value else value
	if main_tab == "closed":
		app.selected = Vector2i(-1,-1); app.selection_view.level_preview = false; app.refresh_selection()
	body_key = ""; refresh()

func refresh() -> void:
	if not is_node_ready() or app == null or app.run_domain.state.is_empty(): return
	if RuntimeProfile.options.get("hide_hud", false) and app.run_domain.state.get("phase") == "wave":
		hide()
		return
	var hud_tick := RuntimeProfile.begin()
	var state: Dictionary = app.run_domain.state
	var runtime = app.scene._native_combat
	var phase := str(state.get("phase","preparation"))
	var viewport := get_viewport_rect().size
	var insets := safe_insets()
	var details := main_tab != "closed" and phase in ["preparation","wave"]
	var layout_key := [viewport,insets,phase,details,main_tab,_selected_tile()]
	if layout_key != _layout_key:
		_layout_key = layout_key
		top.offset_top = 8+insets.y; top.offset_left = 8+insets.x; top.offset_right = -8-insets.z
		dock.offset_left = insets.x; dock.offset_right = -insets.z; dock.offset_bottom = -insets.w
		dock.visible = phase in ["preparation","wave"]
		scroll.visible = details
		detail_panel.visible = details
		_queue_dock_layout()
	var dk := configuration_cache.sync(state,app.run_domain.growth.data)
	if dk != dps_key:
		dps_key = dk; total_dps = 0
		for turret in state.get("turrets",[]):
			var stats := _stats(state,turret)
			var projectile := str(turret.type) in ["arrow","cannon"]
			total_dps += _dps(stats,str(turret.type)) + float(stats.damage)*float(stats.attackRate)*(int(stats.projectileCount)-1 if projectile else 0)
	gold_label.text = str(state.gold); shard_label.text = str(state.gemShards); resources.text = "전투력 %.1f" % total_dps
	var waves: Array = _stage_source().waves
	_refresh_intel(state,waves)
	status.text = "♡ %d/%d" % [ceili(runtime.defense.hp),ceili(runtime.defense.max_hp)]
	wave_label.text = "웨이브 %d/%d" % [mini(int(state.get("completedRounds",0))+1,waves.size()),waves.size()]
	hp.max_value = maxf(1,runtime.defense.max_hp); hp.value = runtime.defense.hp
	for value in speed_buttons:
		var selected: bool = int(runtime.session.get("speed",1)) == value
		var button: Button = speed_buttons[value]
		if button.button_pressed != selected or not button.has_meta("hud_role"):
			button.button_pressed = selected
			_style_hud_button(button,"segment",selected,Vector2.ZERO)
	for value in main_buttons:
		var button: Button = main_buttons[value]
		var selected: bool = main_tab == value
		if button.button_pressed != selected or not button.has_meta("hud_role"):
			button.button_pressed = selected
			_style_hud_button(button,"secondary",selected,Vector2(6,4),true)
		button.disabled = phase not in ["preparation","wave"]
	var paused: bool = bool(runtime.session.get("paused",false))
	var resumable := phase == "wave" and paused
	start.text = "▶ 재개" if resumable else ("진행 중" if phase == "wave" else "▶ 시작")
	start.disabled = phase not in ["preparation","wave"] or (phase == "wave" and not paused) or app.get("save_failed") == true
	pause_button.visible = phase == "wave" and not paused
	camera_button.text = ("드론" if app.scene.options.get("camera","angled") == "drone" else "고정")+" ↔"
	camera_button.offset_right = -8-insets.z; camera_button.offset_left = camera_button.offset_right-68
	camera_button.offset_top = top.offset_top+top.size.y+6; camera_button.offset_bottom = camera_button.offset_top+32
	home.disabled = phase == "reward"
	var auto_index: int = maxi(0,AUTO_MODES.find(app.auto_start_mode))
	auto_start.text = AUTO_CAPTIONS[auto_index]+(" ▴" if auto_start_popup.visible else " ▾")
	auto_start.tooltip_text = AUTO_LABELS[auto_index]
	auto_start.disabled = phase not in ["preparation","wave"]
	message.text = _error(str(app.checkpoint.message)); retry_save.visible = app.get("save_failed") == true
	if retry_save.visible: message.text = "저장하지 못해 전투를 정지했습니다. 다시 시도해 주세요."
	message.visible = not message.text.is_empty()
	var chosen: Dictionary = app.run_domain.service.turret(state,app.run_domain.selected_id(app.selected))
	# Prices depend on turret/gem diversity and upgrades, but not wallet balances.
	var key := [viewport.x,app.selected,app.turret_type,dk,state.gemInventory,phase,tab,main_tab,selected_slot,selected_gem,app.selection_view.level_preview]
	if not body_key is Array or key != body_key:
		body_key = key.duplicate(true)
		var previous_scroll := scroll.scroll_vertical
		var old_picker := body.get_node_or_null("TurretPicker") as ScrollContainer
		var picker_offset := old_picker.scroll_horizontal if old_picker != null else 0
		body_purchase_buttons.clear()
		_clear(body); damage_label = null; core_label = null; core_bar = null; core_metric = null
		if main_tab == "upgrades": _upgrades(state)
		elif main_tab == "gems": _inventory(state)
		elif main_tab == "turrets":
			if not chosen.is_empty(): _turret(state,chosen)
			else: _build(state)
		scroll.set_deferred("scroll_vertical",previous_scroll)
		var picker := body.get_node_or_null("TurretPicker") as ScrollContainer
		if picker != null: picker.set_deferred("scroll_horizontal",picker_offset)
		_queue_dock_layout()
	_refresh_purchase_buttons(state)
	if is_instance_valid(damage_label):
		var damage := float(chosen.get("damageDealt",0))
		var live: Dictionary = runtime.get("turrets") if runtime.get("turrets") is Dictionary else {}
		if live.has(str(chosen.get("id"))):
			damage = 0
			for field in ["directDamageDealt","splashDamageDealt","chainDamageDealt","burnDamageDealt"]: damage += float(live[str(chosen.id)].get(field,0))
		damage_label.text = "누적 피해  %.1f" % damage
	_refresh_core()
	if rewards != null: rewards.refresh(state)
	RuntimeProfile.finish("hud", hud_tick)

func _open_auto_start() -> void:
	for index in AUTO_MODES.size(): auto_start_popup.set_item_checked(index,app.auto_start_mode == AUTO_MODES[index])
	# The original HUD opens its three choices immediately above the mode icon.
	auto_start_popup.reset_size()
	var rect := auto_start.get_global_rect()
	var popup_size := auto_start_popup.get_contents_minimum_size()
	auto_start_popup.popup(Rect2i(Vector2i(maxf(0,rect.end.x-popup_size.x),maxf(0,rect.position.y-popup_size.y-6)),Vector2i(popup_size)))

func _primary_action() -> void:
	if app.run_domain.state.get("phase") == "wave": app.toggle_pause()
	else: app.start_wave()
	refresh()

func _style_hud_button(button: Button, role: String, selected: bool, padding: Vector2, tab_button := false) -> void:
	button.set_meta("hud_role",role)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := HudChrome.primary(state) if role == "primary" else HudChrome.quiet(state,selected,Color("65c9df"),padding)
		button.add_theme_stylebox_override(state,style)
	var foreground := Color("b7c8d8") if tab_button and not selected else Color("e8f8ff")
	for color_role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","icon_normal_color","icon_hover_color","icon_pressed_color"]:
		button.add_theme_color_override(color_role,foreground)

func _queue_dock_layout() -> void:
	if _dock_layout_pending: return
	_dock_layout_pending = true
	_fit_dock_to_content.call_deferred()

func _fit_dock_to_content() -> void:
	_dock_layout_pending = false
	if not is_instance_valid(body): return
	var picker_only := main_tab == "turrets" and _selected_tile() == ""
	detail_panel.add_theme_stylebox_override("panel",HudChrome.docked_panel(5) if picker_only else BattleTheme.box(Color("0b1b2baa"),Color("33d8ff55"),8))
	# Scroll only when content reaches its limit; an unselected picker has no panel.
	var limit := 198.0 if main_tab == "upgrades" else clampf(get_viewport_rect().size.y*0.28,150,280)
	var gem_rows := body.find_child("EquippedSocketRows",true,false)
	if gem_rows != null and gem_rows.get_child_count() > 1:
		limit = clampf(get_viewport_rect().size.y*0.42,220,340)
	var content_height := body.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(content_height,limit)
	var height := bottom.get_combined_minimum_size().y
	dock.offset_top = -safe_insets().w-height
	dock.offset_bottom = -safe_insets().w

func _build(state: Dictionary) -> void:
	var tile := _selected_tile()
	if tile in ["core","spawn"]: _board_detail(tile,state); return
	var available: Array = configuration_cache.derived(state,app.run_domain.service).get("availableTurretTypes",[])
	if app.turret_type not in available and not available.is_empty():
		app.turret_type = available[0]
		app.refresh_selection()
	var type := str(app.turret_type)
	var cost: int = app.run_domain.service.build_cost(state,type)
	if tile == "build":
		var heading := HBoxContainer.new(); body.add_child(heading)
		_label(heading,TOWERS.get(type,type)+" 포탑",14)
		var install := _button(heading,"설치 · %d 골드" % cost,func(): app.build_selected(); refresh())
		_track_purchase_button(install,"gold",cost,tile != "build")
		_label(body,DESCRIPTIONS.get(type,""),11)
		var definition: Dictionary = app.catalog.data.turrets[type].configuration.statInput.definition
		_label(body,("물리" if definition.damageFamily == "physical" else "원소")+" · "+str({"arrow":"경량화기","cannon":"중화기 · 폭발","magic":"지속 피해","frost":"감속","sniper":"중화기 · 조준","lightning":"연쇄"}.get(type,"")),10)
		var stats := _stats(state,{"type":type,"level":1,"equippedGemSlots":[],"primaryTrait":null,"secondaryTrait":null})
		_label(body,"피해 %.1f     초당 %.2f회     사거리 %.0f" % [stats.damage,stats.attackRate,stats.range],11)
	var picker_scroll := ScrollContainer.new(); picker_scroll.name = "TurretPicker"
	picker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	picker_scroll.custom_minimum_size.y = 78; body.add_child(picker_scroll)
	var row := HBoxContainer.new(); row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_theme_constant_override("separation",0); picker_scroll.add_child(row)
	for kind in TOWERS:
		if kind not in available: continue
		if row.get_child_count() > 0: row.add_child(HudChrome.divider())
		var b := _button(row,"%s\n%d" % [TOWERS[kind],app.run_domain.service.build_cost(state,kind)],func():
			if app.turret_type == kind and _selected_tile() == "build": app.build_selected()
			else: app.turret_type = kind; app.refresh_selection()
			refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.add_theme_font_size_override("font_size",10)
		b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0,78)
		# Explicit vertical content avoids Button icon/text width arbitration.
		for color_role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: b.add_theme_color_override(color_role,Color.TRANSPARENT)
		var content := VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_theme_constant_override("separation",0); b.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); content.offset_top = 4; content.offset_bottom = -4; content.offset_left = 2; content.offset_right = -2
		var art := _icon(content,"ui/hud/turrets_3d/"+kind+".png",40); art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _label(content,TOWERS[kind],10); name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; name_label.autowrap_mode = TextServer.AUTOWRAP_OFF; name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var price_label := _label(content,"%d G" % app.run_domain.service.build_cost(state,kind),9); price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		for style in ["normal","hover","pressed","disabled","focus"]:
			b.add_theme_stylebox_override(style,HudChrome.quiet(style,type == kind,Color("e7c66a"),Vector2(3,3)))
		b.toggle_mode = true; b.button_pressed = type == kind

func _stat_input(state: Dictionary, turret: Dictionary) -> Dictionary:
	var input: Dictionary = configuration_cache.derived(state,app.run_domain.service).get("turretStatInputs",{}).get(turret.type,{}).duplicate(true)
	input.merge({"level":turret.level,"primaryTrait":turret.get("primaryTrait"),"secondaryTrait":turret.get("secondaryTrait"),"gems":turret.get("equippedGemSlots",[]).filter(func(g): return g != null)},true)
	return input

func _stats(state: Dictionary,turret: Dictionary) -> Dictionary:
	return app.catalog.turret_stats(turret.type,{"tileSize":48.0,"statInput":_stat_input(state,turret)})

func _dps(stats: Dictionary,type: String) -> float:
	return float(stats.damage)*float(stats.attackRate)+(float(stats.damage)*0.5*float(stats.damageOverTimeDamageMultiplier) if type == "magic" else 0.0)

func _turret(state: Dictionary,turret: Dictionary) -> void:
	var q: Dictionary = app.run_domain.service.quotes(state,int(turret.id))
	var heading := HBoxContainer.new(); heading.add_theme_constant_override("separation",4); body.add_child(heading)
	var identity := VBoxContainer.new(); identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER; identity.add_theme_constant_override("separation",1); heading.add_child(identity)
	var turret_name := _label(identity,TOWERS.get(turret.type,turret.type),12)
	turret_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	var level_name := _label(identity,"Lv.%d%s" % [turret.level," → %d" % (int(turret.level)+1) if app.selection_view.level_preview else ""],11)
	level_name.modulate = Color("e7c66a"); level_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	var level := _turret_action(heading,"강화 확정" if app.selection_view.level_preview else "레벨업","최대 레벨" if int(q.level)<=0 else "%d G" % q.level,"ui/hud/icons/upgrades.png",Color("e7c66a"),80,_preview_level)
	level.name = "TurretLevelAction"
	_track_purchase_button(level,"gold",int(q.level),int(q.level)<=0)
	level.tooltip_text = "강화 확정" if app.selection_view.level_preview else "다음 레벨 능력치 미리보기"
	var sell := _turret_action(heading,"판매","+%d G" % q.sell,"upgrades/turret_refund.png",Color("edab78"),72,func(): _sell_confirm(turret,q))
	sell.name = "TurretSellAction"; sell.tooltip_text = "판매 금액 확인"
	var trait_count := int(turret.get("primaryTrait") != null)+int(turret.get("secondaryTrait") != null)
	var traits := _turret_action(heading,"특성","%d/2 선택" % trait_count,"ui/hud/icons/rune.png",Color("bba5ed"),76,func(): _traits(turret,q))
	traits.name = "TurretTraitAction"; traits.tooltip_text = "특성 확인 및 선택"
	var active_tab := "stats" if app.selection_view.level_preview else tab
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation",0); body.add_child(tabs)
	for spec in [["stats","스탯"],["gems","젬 링크"]]:
		var b := _button(tabs,spec[1],func(): tab = spec[0]; refresh())
		b.toggle_mode = true; b.button_pressed = active_tab == spec[0]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if active_tab == "gems": _gems(state,turret,q); return
	var damage_row := HBoxContainer.new(); body.add_child(damage_row)
	_label(damage_row,"물리 · 경량화기" if turret.type == "arrow" else ("원소" if turret.type in ["magic","frost","lightning"] else "물리 · 중화기"),11)
	if configuration_cache.derived(state,app.run_domain.service).get("canSetTurretTargetPriority",false):
		var priority := _button(damage_row,"목표 · "+PRIORITIES.get(turret.get("targetPriority","first"),"선두")+" ▾",_priority)
		priority.tooltip_text = "공격 목표 변경"
		priority.add_theme_font_size_override("font_size",11)
		priority.custom_minimum_size.y = 30
		_style_hud_button(priority,"quiet",false,Vector2(6,4))
	damage_label = _label(damage_row,"",10); damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	damage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var stats := _stats(state,turret)
	var next := {}; var future := turret.duplicate(true); future.level += 1
	if app.selection_view.level_preview: next = _stats(state,future)
	var stat_scroll := ScrollContainer.new(); stat_scroll.name = "TurretStatsScroll"; stat_scroll.custom_minimum_size.y = 96; stat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; stat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; body.add_child(stat_scroll)
	var grid := GridContainer.new(); grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",16); grid.add_theme_constant_override("v_separation",0); stat_scroll.add_child(grid)
	stats.dps = _dps(stats,turret.type)
	if not next.is_empty(): next.dps = _dps(next,turret.type)
	var specs := [["피해","damage"],["DPS","dps"],["공격 속도","attackRate"],["사거리","range"],["치명 확률","criticalChance"],["치명 피해","criticalDamageMultiplier"]]
	if float(stats.splashRadius) > 0 or turret.type == "magic": specs.append(["효과 범위","effectAreaMultiplier"])
	if float(stats.slowDuration) > 0:
		specs.append(["감속","slowMultiplier"]); specs.append(["감속 지속","slowDuration"])
	if turret.type in ["arrow","cannon"]: specs.append(["투사체","projectileCount"])
	if turret.type == "sniper": specs.append(["조준 시간","aimDuration"])
	if turret.type == "magic":
		stats.burnDuration = 2.0*float(stats.damageOverTimeDurationMultiplier)
		if not next.is_empty(): next.burnDuration = 2.0*float(next.damageOverTimeDurationMultiplier)
		specs.append(["화상 지속","burnDuration"])
	if int(stats.chainCount) > 0: specs.append(["연쇄","chainCount"])
	for spec in specs:
		var cell := VBoxContainer.new(); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation",0); grid.add_child(cell)
		var row := HBoxContainer.new(); row.custom_minimum_size.y = 30; row.add_theme_constant_override("separation",4); cell.add_child(row)
		var title := _label(row,spec[0],11); title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.modulate = Color("a6bcc8")
		var values := VBoxContainer.new(); values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		values.size_flags_vertical = Control.SIZE_SHRINK_CENTER; values.add_theme_constant_override("separation",0); row.add_child(values)
		var changed: bool = not next.is_empty() and not is_equal_approx(float(stats[spec[1]]),float(next[spec[1]]))
		var current := _label(values,_stat_value(stats,spec[1]),10 if changed else 13)
		current.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; current.autowrap_mode = TextServer.AUTOWRAP_OFF
		current.modulate = Color("91a6b2") if changed else Color("e8f8ff")
		if changed:
			var future_value := _label(values,"→ "+_stat_value(next,spec[1]),12)
			future_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; future_value.autowrap_mode = TextServer.AUTOWRAP_OFF
			future_value.modulate = Color("8ee6ff")
		cell.tooltip_text = spec[0]+" · "+_stat_value(stats,spec[1])+(" → "+_stat_value(next,spec[1]) if changed else "")
		cell.add_child(HSeparator.new())

func _turret_action(parent: Node,title: String,detail: String,icon_path: String,accent: Color,width: float,callback: Callable) -> Button:
	var button := _button(parent,"",callback)
	button.custom_minimum_size = Vector2(width,38)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := HudChrome.quiet(state,false,accent,Vector2(4,3))
		style.border_color = Color(accent,0.32 if state == "normal" else 0.7)
		style.border_width_bottom = 1
		button.add_theme_stylebox_override(state,style)
	var content := HBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",4); button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 4; content.offset_right = -4; content.offset_top = 3; content.offset_bottom = -3
	var icon := _icon(content,icon_path,20); icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon_path.ends_with("upgrades.png"): icon.modulate = accent
	var text := VBoxContainer.new(); text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation",0); content.add_child(text)
	var name_label := _label(text,title,11); name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value_label := _label(text,detail,10); value_label.autowrap_mode = TextServer.AUTOWRAP_OFF; value_label.modulate = accent
	button.set_meta("action_content",content)
	return button

func _stat_value(stats: Dictionary,key: String) -> String:
	if key == "slowMultiplier": return "%.0f%%" % ((1.0-float(stats[key]))*100)
	if key in ["criticalChance","criticalDamageMultiplier","effectAreaMultiplier"]: return "%.0f%%" % (float(stats[key])*100)
	if key == "range": return "%.2f칸" % (float(stats[key])/48.0)
	if key == "attackRate": return "%.2f회/초" % float(stats[key])
	if key in ["aimDuration","slowDuration","burnDuration"]: return "%.2f초" % float(stats[key])
	if key == "projectileCount": return "%d발" % int(stats[key])
	if key == "chainCount": return "%d회" % int(stats[key])
	return "%.1f" % float(stats[key])

func _preview_level() -> void:
	if app.selection_view.level_preview:
		app.selection_view.level_preview = false; _selected_command("level")
	else:
		app.selection_view.level_preview = true; app.refresh_selection(); refresh()

func _sell_confirm(turret: Dictionary,q: Dictionary) -> void:
	var box := open_modal("포탑 판매")
	_label(box,"%s Lv.%d 포탑을 판매할까요?\n%d 골드를 돌려받고 장착 젬은 보관함으로 돌아갑니다." % [TOWERS.get(turret.type,turret.type),turret.level,q.sell],13)
	Components.apply(_button(box,"판매 · +%d 골드" % q.sell,func(): _selected_command("sell"); close_modal()),"danger")
	_button(box,"취소",close_modal)

func _traits(turret: Dictionary,q: Dictionary,tier: int = 0) -> void:
	if tier == 0: tier = 2 if turret.get("primaryTrait") != null else 1
	var box := open_modal(TOWERS.get(turret.type,turret.type)+" 특성",390,false,true,Color("63e6a5"),"reward")
	var wallet := HBoxContainer.new(); box.add_child(wallet)
	_icon(wallet,"ui/hud/icons/shard.png",15)
	_label(wallet,"%d  ·  1차 %d / 2차 %d" % [app.run_domain.state.gemShards,q.primaryTrait,q.secondaryTrait],11)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation",0); box.add_child(tabs)
	for value in [1,2]:
		var chosen_trait = turret.get("primaryTrait" if value == 1 else "secondaryTrait")
		var name: String = str(labels.traitNames.get(chosen_trait,"무기 개조" if value == 1 else "전투 교리"))
		var button := _button(tabs,"%d차 · %s" % [value,name],func(): trait_preview = ""; _traits(turret,q,value))
		button.toggle_mode = true; button.button_pressed = value == tier; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_hud_button(button,"secondary",value == tier,Vector2(8,8),true)
		button.disabled = q.get("primaryTraits" if value == 1 else "secondaryTraits",[]).is_empty()
	var kind := "primaryTrait" if tier == 1 else "secondaryTrait"
	var required := 3 if tier == 1 else 7
	_label(box,"%d차 · %s" % [tier,"무기 개조" if tier == 1 else "전투 교리"],13)
	if turret.get(kind) != null:
		_label(box,str(labels.traitNames.get(turret[kind],turret[kind]))+"\n"+str(labels.traitDescriptions.get(turret[kind],"")),12)
	else:
		var blocked := ""
		if tier == 2 and turret.get("primaryTrait") == null: blocked = "2차 특성은 1차 특성을 먼저 선택해야 합니다."
		elif int(turret.level)<required: blocked = "%d차 특성은 Lv.%d부터 선택할 수 있습니다." % [tier,required]
		elif int(app.run_domain.state.gemShards)<int(q[kind]): blocked = "젬 파편이 %d개 부족합니다." % (int(q[kind])-int(app.run_domain.state.gemShards))
		if not blocked.is_empty(): _label(box,blocked,11).modulate = Color("ffa68a")
		if q[kind+"s"].is_empty(): _label(box,"선택 가능한 특성이 없습니다.",12)
		for value in q[kind+"s"]:
			var button := _option_button(box,("✓ " if trait_preview == value else "")+str(labels.traitNames.get(value,value)),str(labels.traitDescriptions.get(value,"")),func():
				if trait_preview == value: _selected_command(kind,{"type":value}); close_modal()
				else: trait_preview = value; _traits(turret,q,tier),trait_preview == value)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.disabled = not blocked.is_empty()
	_label(box,"선택한 특성은 이번 런 동안 변경할 수 없습니다.",10)

func _option_button(parent: Node,title: String,description: String,callback: Callable,selected := false) -> Button:
	var button := _button(parent,title+"\n"+description,callback)
	Components.apply(button,"selected" if selected else "secondary")
	for role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		button.add_theme_color_override(role,Color.TRANSPARENT)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var content := VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",5); button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16; content.offset_right = -16; content.offset_top = 12; content.offset_bottom = -12
	var heading := _label(content,title,14); heading.add_theme_font_override("font",AppTheme.font(800))
	heading.modulate = Color("ffe19a") if selected else Color.WHITE
	var detail := _label(content,description.replace(", ","\n"),12); detail.add_theme_font_override("font",AppTheme.font(500)); detail.modulate = Color("b2c5d0")
	var fit := func(): button.custom_minimum_size.y = maxf(72,content.get_combined_minimum_size().y+24)
	content.minimum_size_changed.connect(fit); button.resized.connect(fit); fit.call_deferred()
	button.draw.connect(func(): content.modulate.a = 0.48 if button.disabled else 1.0)
	return button

func _priority() -> void:
	var box := open_modal("공격 목표")
	var turret: Dictionary = app.run_domain.service.turret(app.run_domain.state,app.run_domain.selected_id(app.selected))
	for value in PRIORITIES:
		var b := _option_button(box,PRIORITIES[value],PRIORITY_HELP[value],func(): _selected_command("targetPriority",{"type":value}); close_modal(),str(turret.get("targetPriority","first")) == value)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(box,"취소",close_modal)

func _gems(state: Dictionary,turret: Dictionary,q: Dictionary) -> void:
	var max_slots := int(configuration_cache.derived(state,app.run_domain.service).get("maxTurretLinkSlots",3))
	var socket_rows := VBoxContainer.new(); socket_rows.name = "EquippedSocketRows"; socket_rows.add_theme_constant_override("separation",6); body.add_child(socket_rows)
	var sockets: HBoxContainer
	for i in range(int(turret.slotLimit)):
		if i % 3 == 0:
			sockets = HBoxContainer.new(); sockets.add_theme_constant_override("separation",0); socket_rows.add_child(sockets)
		else:
			var link := TextureRect.new(); link.texture = AppTheme.texture("ui/components/gem_link_active.png"); link.custom_minimum_size = Vector2(12,12); link.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; link.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; sockets.add_child(link)
		var socket := _button(sockets,"",func(): selected_slot = i; selected_gem = ""; refresh())
		socket.name = "EquippedSlot%d" % i; socket.custom_minimum_size = Vector2(54,54)
		for style in ["normal","hover","pressed","disabled","focus"]: socket.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		var file := "gem_socket_selected.png" if i == selected_slot else "gem_socket_empty.png"
		socket.icon = AppTheme.texture("ui/components/"+file); socket.expand_icon = true
		var gem = turret.equippedGemSlots[i]
		if gem != null:
			var icon := TextureRect.new(); icon.texture = AppTheme.texture("gems/"+str(gem)+".png"); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; socket.add_child(icon); icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.offset_left = 9; icon.offset_right = -9; icon.offset_top = 9; icon.offset_bottom = -9
	var link_cost := int(q.get("link",0))
	var buy_caption := "슬롯 추가 · %d G" % link_cost if link_cost > 0 else ("최대 슬롯입니다" if int(turret.slotLimit) >= max_slots else "슬롯 추가 · 포탑 Lv.5 필요")
	var buy_slot := _button(body,buy_caption,func(): _selected_command("link"))
	buy_slot.name = "BuyGemSlot"
	_track_purchase_button(buy_slot,"gold",link_cost,int(turret.slotLimit) >= max_slots or link_cost <= 0)
	if selected_slot < 0: _label(body,"장착할 소켓을 선택하세요.",11)
	elif selected_slot < turret.equippedGemSlots.size() and turret.equippedGemSlots[selected_slot] != null:
		var equipped := str(turret.equippedGemSlots[selected_slot])
		var equipped_row := HBoxContainer.new(); body.add_child(equipped_row)
		var equipped_text := VBoxContainer.new(); equipped_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; equipped_row.add_child(equipped_text)
		_label(equipped_text,_gem_name(equipped)+" · "+_gem_effect(equipped,turret),11)
		_gem_rule(equipped_text,equipped)
		_button(equipped_row,"해제",func(): _selected_command("removeGem",{"slot":selected_slot}))
	_inventory_strip(body,state,turret)
	if selected_gem != "" and int(state.gemInventory.get(selected_gem,0))>0:
		var selected_row := HBoxContainer.new(); body.add_child(selected_row)
		var detail := VBoxContainer.new(); detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; selected_row.add_child(detail)
		_label(detail,_gem_name(selected_gem)+" · "+_gem_effect(selected_gem,turret),11)
		_gem_rule(detail,selected_gem)
		var reason := _gem_block_reason(selected_gem,turret)
		if not reason.is_empty(): _label(detail,reason,10).modulate = Color("ffa68a")
		var install := _button(selected_row,"장착",func(): _selected_command("equipGem",{"type":selected_gem,"slot":selected_slot}); selected_gem = ""; refresh())
		install.disabled = not reason.is_empty()

func _inventory_strip(parent: Node,state: Dictionary,turret: Dictionary = {}) -> void:
	var inv_scroll := ScrollContainer.new(); inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; parent.add_child(inv_scroll)
	var inventory := HBoxContainer.new(); inv_scroll.add_child(inventory)
	for type in state.gemInventory:
		if int(state.gemInventory[type]) <= 0: continue
		var b := _button(inventory,"%s ×%d" % [_gem_name(type),state.gemInventory[type]],func():
			if selected_gem == type and not turret.is_empty() and _gem_block_reason(type,turret).is_empty(): _selected_command("equipGem",{"type":type,"slot":selected_slot}); selected_gem = ""
			else: selected_gem = type
			refresh())
		b.icon = AppTheme.texture("gems/"+type+".png"); b.expand_icon = true; b.add_theme_constant_override("icon_max_width",30); b.toggle_mode = true; b.button_pressed = selected_gem == type
		if not turret.is_empty():
			b.disabled = state.phase not in ["preparation","wave"]
			b.tooltip_text = _gem_block_reason(type,turret)
	if inventory.get_child_count() == 0: _label(parent,"보유 젬이 없습니다.",12)

func _inventory(state: Dictionary) -> void:
	var heading := HBoxContainer.new(); body.add_child(heading); _label(heading,"젬 보관함",14); _purchase(heading,state)
	var owned := []
	for type in app.run_domain.growth.data.gems:
		if int(state.gemInventory.get(type,0))>0: owned.append(type)
	if owned.is_empty():
		_label(body,"보유한 젬이 없습니다. 5라운드 보상 또는 파편 구매로 젬을 획득하세요.",11)
		return
	_label(body,"보유 젬",11)
	var wrap := HFlowContainer.new(); wrap.add_theme_constant_override("h_separation",6); wrap.add_theme_constant_override("v_separation",6); body.add_child(wrap)
	for type in owned:
		var accent := Color(str(rewards.GEM_COLORS.get(type,"69D7FF")))
		var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel",BattleTheme.box(Color(accent,0.12),Color(accent,0.55),7)); wrap.add_child(panel)
		var card := VBoxContainer.new(); panel.add_child(card)
		var title := HBoxContainer.new(); card.add_child(title)
		_icon(title,"gems/"+type+".png",14)
		_label(title,"%s x%d" % [_gem_name(type),state.gemInventory[type]],11)
		var effect := _label(card,_gem_inventory_effect(type),10); effect.custom_minimum_size.x = 112
		_gem_rule(card,type)

func _upgrades(state: Dictionary) -> void:
	for type in UPGRADES:
		var q: Dictionary = app.run_domain.service.run_upgrade_quote(state,type)
		var values: Array = app.run_domain.growth.data.runUpgrades[type].effects
		var current := float(values[mini(int(q.level),values.size()-1)])
		var next := float(values[mini(int(q.level)+1,values.size()-1)])
		var row := HBoxContainer.new(); body.add_child(row)
		var effect := "+%.0f → +%.0f 골드" % [current,next] if type == "waveGold" else "+%.0f%% → +%.0f%%" % [current*100,next*100]
		_label(row,"%s  Lv.%d/%d\n%s" % [UPGRADES[type],q.level,q.maxLevel,effect],12)
		var b := _button(row,"%d 골드" % q.cost if int(q.cost)>0 else "최대",func(): _command({"kind":"runUpgrade","type":type}))
		_track_purchase_button(b,"gold",int(q.cost),int(q.cost)<=0)

func _purchase(parent: Node,state: Dictionary) -> void:
	var cost: int = app.run_domain.growth.data.constants.gemChoicePurchaseCost
	var b := _button(parent,"젬 구매 · %d 조각" % cost,func(): _command({"kind":"purchaseGemChoice"}))
	_track_purchase_button(b,"gemShards",cost,state.phase not in ["preparation","wave"])

func _track_purchase_button(button: Button,currency: String,cost: int,blocked: bool) -> void:
	body_purchase_buttons.append({"button":button,"currency":currency,"cost":cost,"blocked":blocked})

func _refresh_purchase_buttons(state: Dictionary) -> void:
	for entry in body_purchase_buttons:
		var button: Button = entry.button
		button.disabled = bool(entry.blocked) or int(state.get(entry.currency,0)) < int(entry.cost)
		if button.has_meta("action_content"):
			button.get_meta("action_content").modulate = Color("78848a") if button.disabled else Color.WHITE

func open_modal(title: String,max_width: float = 410,bottom_sheet := false,show_close := true,accent := Color("8ee6ff"),tone := "standard") -> VBoxContainer:
	if not is_instance_valid(modal):
		modal_resume = app.begin_modal_pause()
		modal = ColorRect.new(); modal.color = Color("02070dd9"); add_child(modal); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modal.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: close_modal()
			elif event is InputEventScreenTouch and event.pressed: close_modal())
	else: _clear(modal)
	modal_bottom_sheet = bottom_sheet
	modal_panel = PanelContainer.new(); modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_panel.theme_type_variation = "CombatModal"
	modal_panel.custom_minimum_size.x = minf(max_width,get_viewport_rect().size.x-(24 if bottom_sheet else 36))
	if bottom_sheet:
		var column := VBoxContainer.new(); modal.add_child(column); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var spacer := Control.new(); spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(spacer)
		var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.alignment = BoxContainer.ALIGNMENT_CENTER; column.add_child(row); row.add_child(modal_panel)
	else:
		var center := CenterContainer.new(); center.mouse_filter = Control.MOUSE_FILTER_IGNORE; modal.add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); center.add_child(modal_panel)
	var s := ScrollContainer.new(); s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; s.custom_minimum_size.y = 40; modal_panel.add_child(s); modal_scroll = s
	modal_body = VBoxContainer.new(); modal_body.add_theme_constant_override("separation",10); modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; s.add_child(modal_body)
	var header := HBoxContainer.new(); modal_body.add_child(header)
	_label(header,title,18).add_theme_font_override("font",AppTheme.font(900))
	if show_close:
		var close := _button(header,"×",close_modal); close.tooltip_text = "취소"; close.custom_minimum_size = Vector2(30,30)
		_style_hud_button(close,"quiet",false,Vector2(3,0))
	var separator := HSeparator.new(); separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := StyleBoxLine.new(); line.color = Color("51879b88"); line.thickness = 1
	separator.add_theme_stylebox_override("separator",line); modal_body.add_child(separator)
	_fit_modal.call_deferred()
	if not get_tree().process_frame.is_connected(_fit_modal): get_tree().process_frame.connect(_fit_modal,CONNECT_ONE_SHOT)
	# Container owns position/size; entrance animation must not overwrite layout.
	modal_panel.modulate.a = 0
	modal_panel.create_tween().tween_property(modal_panel,"modulate:a",1.0,0.16)
	return modal_body

func _fit_modal() -> void:
	if not is_instance_valid(modal) or not is_instance_valid(modal_scroll): return
	modal_scroll.custom_minimum_size.y = minf(modal_body.get_combined_minimum_size().y+8,get_viewport_rect().size.y*(0.82 if modal_bottom_sheet else 0.82))

func close_modal() -> void:
	if not is_instance_valid(modal): return
	preload("res://ui/game_modal_frame.gd").dismiss(modal); modal = null
	app.end_modal_pause(modal_resume); modal_resume = false; trait_preview = ""
	refresh()

func modal_active() -> bool:
	return is_instance_valid(modal)

func blocks_board_input() -> bool:
	return auto_start_popup.visible or modal_active() or (app.run_domain.state.get("phase") in ["reward","success","failure"] and (rewards == null or not rewards.targeting() or rewards.replacing()))

func close_back() -> bool:
	if auto_start_popup.visible: auto_start_popup.hide(); return true
	if modal_active(): close_modal(); return true
	if rewards != null and rewards.close_back(): return true
	if main_tab != "closed": _select_main(main_tab); return true
	_stage_menu(); return true

func _stage_menu() -> void:
	if app.run_domain.state.get("phase") == "reward": return
	var box := open_modal("스테이지 메뉴",390)
	var header: HBoxContainer = box.get_child(0)
	var icon := _material_icon(header,0xf107,20); header.move_child(icon,0)
	var actions: BoxContainer = VBoxContainer.new() if get_viewport_rect().size.x < 380 else HBoxContainer.new(); actions.add_theme_constant_override("separation",8); box.add_child(actions)
	var end := _action(actions,"스테이지 종료",_end_stage_confirm,"danger")
	end.size_flags_stretch_ratio = 5
	end.disabled = not _has_stage_progress() or app.run_domain.state.phase in ["success","failure"]
	_action(actions,"메인화면으로 이동",_save_to_stage,"primary").size_flags_stretch_ratio = 6

func _has_stage_progress() -> bool:
	var state: Dictionary = app.run_domain.state
	if int(state.get("roundIndex",0))>0 or int(state.get("completedRounds",0))>0 or not state.get("turrets",[]).is_empty() or state.get("phase") in ["wave","reward","restored"]: return true
	if not state.get("runUpgradeLevels",{}).is_empty() or int(state.get("savedTurretCountForMenu",0))>0: return true
	var runtime = app.scene._native_combat
	var enemies = runtime.get("enemies")
	if enemies != null and not enemies.is_empty(): return true
	var wave = runtime.get("wave")
	if wave != null and not wave.is_empty(): return true
	return float(state.get("killGoldFractionWallet",0))>0 or not state.get("rewardOptions",[]).is_empty()

func _projected_failure_reward() -> int:
	var state: Dictionary = app.run_domain.state
	var estimate: Dictionary = app.run_domain.quests.finish(state.progression,{"stageNumber":app.stage+1,"completedRounds":int(state.get("completedRounds",0)),"success":false,"runeResonanceBonusRate":float(configuration_cache.derived(state,app.run_domain.service).get("runeResonanceBonusRate",0.0))})
	return int(estimate.lastRunRuneReward)

func _end_stage_confirm() -> void:
	var box := open_modal("정말 종료할까요?",340,false,false,Color("ff7043"),"danger")
	var header: HBoxContainer = box.get_child(0)
	var flag := _material_icon(header,0xf07b,20); flag.modulate = Color("ff7043"); header.move_child(flag,0)
	var reward := _projected_failure_reward()
	_label(box,"스테이지 %d 진행을 종료하고 +%d 룬을 정산합니다." % [app.stage+1,reward],12)
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel",BattleTheme.box(Color("272116"),Color("88785835"),14)); box.add_child(panel)
	var summary := VBoxContainer.new(); panel.add_child(summary)
	var reward_title := HBoxContainer.new(); summary.add_child(reward_title)
	_rune_icon(reward_title,24)
	_label(reward_title,"종료 시 보상",12)
	_stat_pill(reward_title,"정산 예상","",Color("e7c66a"))
	var reward_row := HBoxContainer.new(); summary.add_child(reward_row)
	_label(reward_row,"%d웨이브 기준" % int(app.run_domain.state.get("completedRounds",0)),12)
	_rune_icon(reward_row,22)
	_label(reward_row,"+%d 룬" % reward,26).modulate = Color("ffd166")
	var actions: BoxContainer = VBoxContainer.new() if get_viewport_rect().size.x < 380 else HBoxContainer.new(); box.add_child(actions)
	_action(actions,"계속 진행",close_modal,"ghost")
	_action(actions,"종료",_end_to_stage,"danger")

func _save_to_stage() -> void:
	if app.open_stage_menu_destination():
		modal_resume = false
		close_modal()

func _end_to_stage() -> void:
	if app.abandon_run():
		modal_resume = false
		close_modal()

func _action(parent: Node,value: String,callback: Callable,variant: String) -> Button:
	var button := AppTheme.button(value,callback,variant)
	Components.apply(button,variant)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	var glyph: int = {"스테이지 종료":0xf07b,"종료":0xf07b,"메인화면으로 이동":0xf107,"계속 진행":0xe092}.get(value,0)
	if glyph != 0:
		var content := HBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.alignment = BoxContainer.ALIGNMENT_CENTER; button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_material_icon(content,glyph,17)
		var caption := Label.new(); caption.text = value; caption.mouse_filter = Control.MOUSE_FILTER_IGNORE; caption.add_theme_font_override("font",AppTheme.font(800)); caption.add_theme_font_size_override("font_size",13); content.add_child(caption)
		for role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: button.add_theme_color_override(role,Color.TRANSPARENT)
		button.draw.connect(func():
			var color := Color("e8f8ff")
			content.modulate = Color(color,0.48 if button.disabled else 1.0))
	return button

func _material_icon(parent: Node,codepoint: int,extent: int) -> Label:
	var icon := Label.new(); icon.text = char(codepoint); icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_font_override("font",load("res://assets/ui/MaterialIcons-Regular.otf")); icon.add_theme_font_size_override("font_size",extent)
	parent.add_child(icon)
	return icon

func battlefield_rect() -> Rect2:
	# Stable reference bounds: opening detail/reward targeting never reframes camera.
	var viewport := get_viewport_rect().size
	var insets := safe_insets()
	return Rect2(Vector2(8+insets.x,110+insets.y),Vector2(maxf(1,viewport.x-16-insets.x-insets.z),maxf(1,viewport.y-302-insets.y-insets.w)))

func _board_detail(tile: String,state: Dictionary) -> void:
	if tile == "core":
		_label(body,"코어 방어",16)
		var defense = app.scene._native_combat.defense
		core_label = _label(body,"체력 %d / %d" % [ceili(defense.hp),ceili(defense.max_hp)],13)
		var bar := ProgressBar.new(); bar.max_value = maxf(1,defense.max_hp); bar.value = defense.hp; bar.show_percentage = false; bar.custom_minimum_size.y = 10; body.add_child(bar); core_bar = bar
		core_metric = _label(body,"",12)
		return
	var preparing: bool = state.phase == "preparation"
	var waves: Array = _stage_source().waves
	var index := int(state.get("completedRounds",0))
	if index >= waves.size(): _label(body,"모든 웨이브를 완료했습니다.",12); return
	var wave: Dictionary = waves[index]
	var summary := _button(body,("포탈 1" if preparing else "전투 진행 중")+"\n"+(str(wave.get("previewText",""))+" · %d/%d" % [index+1,waves.size()] if preparing else "진행 상태 확인"),func(): _portal_details(wave))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.disabled = not preparing

func _portal_details(wave: Dictionary) -> void:
	var box := open_modal("포탈 1 · %d/%d 웨이브" % [int(app.run_domain.state.get("completedRounds",0))+1,_stage_source().waves.size()],720,true,true,Color("b16dff"))
	var header: HBoxContainer = box.get_child(0)
	var icon := _material_icon(header,0xe283,20); icon.modulate = Color("e3b7ff"); header.move_child(icon,0)
	_label(box,str(wave.get("previewText","")),13)
	var counts := {}
	for spawn in wave.get("spawnQueue",[]):
		var type := str(spawn.get("enemyType","")); counts[type] = int(counts.get(type,0))+1
	for type in counts:
		var enemy: Dictionary = app.catalog.data.enemies.get(type,{})
		var durability: Dictionary = wave.get("enemyDurability",{}).get(type,{})
		var panel := PanelContainer.new(); box.add_child(panel)
		var content := VBoxContainer.new(); panel.add_child(content)
		var heading := HBoxContainer.new(); content.add_child(heading)
		_icon(heading,"ui/hud/enemies/"+type+".png",28)
		_label(heading,"%s x%d" % [enemy.get("name",type),counts[type]],12)
		var pills := HFlowContainer.new(); content.add_child(pills)
		_stat_pill(pills,"체력",str(roundi(float(durability.get("maxHp",enemy.get("maxHp",0))))))
		for spec in [["방어구","maxArmor"],["보호막","maxShield"]]:
			if float(durability.get(spec[1],0))>0: _stat_pill(pills,spec[0],str(roundi(float(durability[spec[1]]))))
		_stat_pill(pills,"속도",str(roundi(float(enemy.get("speed",0)))))
		_stat_pill(pills,"넥서스 피해","-%d" % int(enemy.get("coreDamage",0)))
		_stat_pill(pills,"보상","+%d" % int(enemy.get("rewardGold",0)))
		var resistances := HFlowContainer.new(); content.add_child(resistances)
		var names := {"physical":"물리","elemental":"원소","light":"경량화기","heavy":"중화기","damageOverTime":"지속피해","cooling":"냉각"}
		for field in ["familyResistances","tagResistances"]:
			for kind in enemy.get(field,{}):
				var value := float(enemy[field][kind])
				if value != 0: _stat_pill(resistances,str(names.get(kind,kind))+" 저항",("+" if value>0 else "")+str(roundi(value*100))+"%",Color("ff8a8a") if value>0 else Color("9fffe8"))

func _stat_pill(parent: Node,title: String,value: String,color := Color("e8f8ff")) -> void:
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel",BattleTheme.box(Color(color,0.12),Color(color,0.55),7)); parent.add_child(panel)
	var caption := _label(panel,(title+" "+value).strip_edges(),11); caption.modulate = color
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _gem_name(type: String) -> String:
	return str(labels.gems.get(type,{}).get("name",type))

func _gem_description(type: String) -> String:
	var gem: Dictionary = labels.gems.get(type,{})
	return str(gem.get("description",""))

func _gem_rule(parent: Node,type: String) -> void:
	if rewards.RULES.has(type):
		var note := _label(parent,"("+str(rewards.RULES[type])+")",10)
		note.modulate = Color("939aa4"); note.custom_minimum_size.x = 200

func _gem_block_reason(type: String,turret: Dictionary) -> String:
	if type in turret.equippedGemSlots: return "이미 이 포탑에 장착됨"
	if selected_slot<0 or selected_slot>=int(turret.slotLimit): return "링크 홈을 선택하세요"
	if type not in app.run_domain.growth.data.turretRules[turret.type].compatibleGems:
		return {"multipleProjectiles":"투사체 공격 포탑에만 장착 가능","chain":"투사체 공격 또는 기본 연쇄 포탑에만 장착 가능","heavyWeapon":"중화기 포탑에만 장착 가능","aimSpeed":"조준 속도 적용 포탑에만 장착 가능"}.get(type,"이 포탑에는 장착할 수 없습니다")
	return ""

func _gem_effect(type: String,turret: Dictionary) -> String:
	var definition: Dictionary = app.catalog.data.turrets[turret.type].configuration.statInput.definition
	var tags: Array = definition.get("attackTags",[])
	if type == "physicalDamage" and definition.damageFamily != "physical": return "현재 적용되는 물리 피해 없음"
	if type == "elementalDamage" and definition.damageFamily != "elemental": return "현재 적용되는 원소 피해 없음"
	if type == "lightWeapon" and "light" not in tags: return "현재 적용되는 경량화기 피해 없음"
	if type == "damageOverTime" and "damageOverTime" not in tags: return "현재 적용되는 지속피해 없음"
	if type == "aimSpeed" and (not definition.instantHit or float(definition.aimDuration)<=0): return "현재 적용되는 조준 속도 없음"
	return {"attackSpeed":"공격 속도 40% 증폭","range":"사거리 20% 증폭","physicalDamage":"물리 피해 40% 증폭","elementalDamage":"원소 피해 40% 증폭","lightWeapon":"경량화기 피해 20% 증폭, 초당 발사 20% 증폭","heavyWeapon":"피해 30% 증폭, 효과 범위 20% 증가 (중화기 전용)","damageOverTime":"지속피해 30% 증가, 지속시간 30% 증가","explosion":"범위 피해 부여, 효과 범위 25% 증가","chain":"연쇄 횟수 +2","multipleProjectiles":"투사체 +2 · 피해 50% 감폭","criticalChance":"치명 확률 +30%p","aimSpeed":"조준 속도 75% 증폭","damageAmplifier":"타격 피해 25% 증폭","armorPiercing":"방어구 감쇄 무시"}.get(type,_gem_description(type))

func _gem_inventory_effect(type: String) -> String:
	return {"lightWeapon":"경량화기 강화","damageOverTime":"지속피해 증가","multipleProjectiles":"투사체 +2\n피해 50% 감폭"}.get(type,_gem_description(type))

func _command(request: Dictionary) -> void:
	app.apply_run_command(request)
	refresh()

func _selected_command(kind: String, values: Dictionary = {}) -> void:
	app.selected_run_command(kind,values)
	refresh()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := AppTheme.button(text,callback)
	Components.apply(button)
	button.custom_minimum_size.y = 32
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := AppTheme.label(text,font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _error(error: String) -> String:
	if error.begins_with("Saved "): return ""
	if error.begins_with("Loaded "): return "저장한 전투를 불러왔습니다."
	return str({"gold":"골드가 부족합니다.","gemShards":"젬 조각이 부족합니다.","tile":"건설 가능한 칸을 선택하세요.","occupied":"이미 포탑이 있는 칸입니다.","locked":"연구로 해금해야 합니다.","phase":"현재 단계에서는 사용할 수 없습니다.","gem":"이 포탑에 장착할 수 없는 젬입니다.","research":"연구가 필요합니다.","trait":"특성 선택 조건을 확인하세요.","inventory":"보유 젬이 없습니다.","requirement":"강화 조건을 확인하세요.","turret":"포탑을 선택하세요."}.get(error,error))

func _selected_tile() -> String:
	var map: Dictionary = _stage_source().map
	var tile: Vector2i = app.selected
	if tile.x < 0 or tile.y < 0 or tile.x >= int(map.columns) or tile.y >= int(map.rows): return ""
	return str(map.tiles[tile.y*int(map.columns)+tile.x])


func _refresh_core() -> void:
	if not is_instance_valid(core_label): return
	var runtime = app.scene._native_combat
	core_label.text = "체력 %d / %d" % [ceili(runtime.defense.hp),ceili(runtime.defense.max_hp)]
	core_bar.max_value = maxf(1,runtime.defense.max_hp); core_bar.value = runtime.defense.hp
	var core = runtime.get("core")
	if core == null: core_metric.text = "전투 스킬 없음"; return
	if core.skill == "guardianBeam":
		var damage: float = maxf(float(core.config.get("normalMaxHp",0))*float(core.config.get("guardianMinNormalHpRate",0.1)),total_dps*float(core.config.get("guardianBeamInterval",5))*float(core.config.get("guardianDpsRate",0.08)))*core.power_for_activation(core.activation_count+1)
		core_metric.text = "수호 광선 · 코어에 가까운 적에게 집중 피해\n광선 피해 %.1f    총 피해 %.1f" % [damage,core.direct_damage_dealt]
	elif core.skill == "riftMark":
		var power: float = 25.0*core.power_for_activation(core.activation_count+1)
		core_metric.text = "균열 낙인 · 내구도 높은 적 4명\n다음 낙인 %.1f%% 증폭 (보스 %.1f%%)\n총 추가 피해 %.1f" % [power,power/2.0,core.bonus_damage_dealt]
	else: core_metric.text = "전투 스킬 없음\n코어 전투 스킬이 장착되어 있지 않습니다."

func _stage_source() -> Dictionary:
	# Catalog stage() returns a defensive deep copy of all waves/spawn queues.
	# HUD readers share one copy until the selected stage changes.
	if _cached_stage_index != app.stage or _cached_stage_source.is_empty():
		_cached_stage_index = app.stage
		_cached_stage_source = app.stage_source(app.stage)
	return _cached_stage_source

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: _insets_valid = false

func safe_insets() -> Vector4:
	if not _insets_valid:
		_cached_insets = _read_safe_insets()
		_insets_valid = true
	return _cached_insets

func _read_safe_insets() -> Vector4:
	if not OS.has_feature("mobile"): return Vector4.ZERO
	var area := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var ratio := get_viewport_rect().size / Vector2(screen)
	if OS.has_feature("android"):
		return preload("res://ui/lobby_home.gd")._cutout_insets(DisplayServer.get_display_cutouts(),Vector2(screen))*Vector4(ratio.x,ratio.y,ratio.x,ratio.y)
	return Vector4(area.position.x*ratio.x,area.position.y*ratio.y,(screen.x-area.end.x)*ratio.x,(screen.y-area.end.y)*ratio.y)

func _refresh_intel(state: Dictionary,waves: Array) -> void:
	var index := int(state.get("completedRounds",0))
	var key := [index,state.phase,configuration_cache.revision]
	if intel_key is Array and key == intel_key: return
	intel_key = key; _clear(enemy_intel)
	if index >= waves.size(): reward_label.text = "완료"; return
	var derived: Dictionary = configuration_cache.derived(state,app.run_domain.service)
	var gold := roundi((int(waves[index].get("clearRewardGold",0))+int(derived.get("waveClearGoldBonus",0)))*float(derived.get("roundClearGoldMultiplier",1)))
	var shard_rewards: Array = app.run_domain.growth.data.get("roundShardRewards",[])
	var shards := int(shard_rewards[index+1]) if index+1 < shard_rewards.size() else 0
	enemy_caption.text = "다음 적" if state.phase == "preparation" else "등장 적"
	reward_label.text = "+%d G · 파편 %d" % [gold,shards]
	var types := []
	for entry in waves[index].get("spawnQueue",[]):
		if entry.enemyType not in types: types.append(entry.enemyType)
	for type in types.slice(0,3):
		var button := _button(enemy_intel,"",func():
			app.selected = Vector2i(-1,-1)
			var map: Dictionary = app.stage_source(app.stage).map
			var tile: int = map.tiles.find("spawn")
			app.board_tap(Vector2i(tile % int(map.columns),tile / int(map.columns))))
		button.custom_minimum_size = Vector2(20,24)
		_style_hud_button(button,"quiet",false,Vector2.ZERO)
		button.icon = AppTheme.texture("ui/hud/enemies/"+str(type)+".png"); button.expand_icon = true; button.add_theme_constant_override("icon_max_width",18)
	if types.size()>3:
		var remaining := _label(enemy_intel,"+%d" % (types.size()-3),10)
		remaining.autowrap_mode = TextServer.AUTOWRAP_OFF
		remaining.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _icon(parent: Node,path: String,extent: float) -> TextureRect:
	var icon := TextureRect.new(); icon.texture = AppTheme.texture(path); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.custom_minimum_size = Vector2.ONE*extent; parent.add_child(icon); return icon

func _rune_icon(parent: Node,extent: float) -> void:
	var socket := PanelContainer.new(); socket.custom_minimum_size = Vector2.ONE*extent; socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := BattleTheme.box(Color("221d1233"),Color("e7c66a88"),extent/2); style.set_content_margin_all(extent*0.19); socket.add_theme_stylebox_override("panel",style); parent.add_child(socket)
	_icon(socket,"ui/hud/icons/rune.png",extent*0.62)
