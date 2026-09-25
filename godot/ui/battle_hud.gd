extends Control
const RuntimeProfile = preload("res://app/runtime_profile.gd")
## Presentation only. Transactions and prices remain owned by RunCommands.
const AppTheme = preload("res://ui/app_theme.gd")
const BattleTheme = preload("res://ui/battle_theme.gd")
const Components = preload("res://ui/combat_component_theme.gd")
const HudChrome = preload("res://ui/hud_chrome.gd")
const TOWERS := {"arrow":"기관총", "cannon":"대포", "magic":"화염", "frost":"냉각", "sniper":"저격", "lightning":"라이트닝"}
const DESCRIPTIONS := {"arrow":"빠른 연사로 앞선 적을 집중 공격하는 단일 대상 포탑입니다.","cannon":"느리지만 강한 포탄으로 주변 적까지 함께 타격합니다.","magic":"원소 화염으로 적을 태우는 지속피해 성향의 포탑입니다.","frost":"포탑 중심에서 냉기를 방출해 사거리 안 적 전체를 타격하고 잠시 둔화합니다.","sniper":"긴 사거리에서 1초간 조준한 뒤 즉시 타격하는 단일 대상 포탑입니다.","lightning":"코일 방전을 충전한 뒤 번개가 근처 적에게 이어지는 중화기 원소 포탑입니다."}
const UPGRADES := {"towerDamage":"포탑 화력", "killGold":"처치 보너스", "waveGold":"정비 보급"}
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
var _modal_max_width := 410.0
var _modal_fit_pending := false
var trait_preview := ""
var last_selected := Vector2i(-1,-1)
var total_dps := 0.0
var dps_key := -1
var configuration_cache = preload("res://ui/hud_configuration_cache.gd").new()
var _layout_key: Array = []

## Panel presenters borrow this live owner. Selection, modal lifetime, refresh keys
## and command dispatch stay here; presenters never duplicate the HUD state.
var turret_panel = preload("res://ui/hud_turret_panel.gd").new(self)
var gem_panel = preload("res://ui/hud_gem_panel.gd").new(self)
var build_panel = preload("res://ui/hud_build_panel.gd").new(self)
var menu_panel = preload("res://ui/hud_menu_panel.gd").new(self)

func _ready() -> void:
	get_viewport().size_changed.connect(func(): _insets_valid = false)
	get_viewport().size_changed.connect(_queue_modal_fit)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = BattleTheme.create(true)
	HudChrome.install(theme)
	labels = JSON.parse_string(FileAccess.get_file_as_string("res://ui/battle_labels.json"))
	top = VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8; top.offset_right = -8; top.offset_top = 8
	add_child(top)
	var resource_style := StyleBoxTexture.new()
	resource_style.texture = AppTheme.texture("ui/hud/resource_panel.png")
	resource_style.set_texture_margin_all(14)
	resource_style.set_content_margin_all(8)
	theme.set_type_variation("ResourceHUD","PanelContainer")
	theme.set_stylebox("panel","ResourceHUD",resource_style)
	var top_frame := PanelContainer.new(); top_frame.name = "ResourceHUD"
	top_frame.theme_type_variation = "ResourceHUD"; top.add_child(top_frame)
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
	home = _button(health_row,"",menu_panel._stage_menu); home.tooltip_text = "스테이지 메뉴"
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
	auto_start_popup.theme = theme; auto_start_popup.theme_type_variation = "HudPopup"
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
	tabs_panel.theme_type_variation = "HudTabs"; bottom.add_child(tabs_panel)
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
		if main_tab == "upgrades": build_panel._upgrades(state)
		elif main_tab == "gems": gem_panel._inventory(state)
		elif main_tab == "turrets":
			if not chosen.is_empty(): turret_panel._turret(state,chosen)
			else: build_panel._build(state)
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
		damage_label.text = "%.1f" % damage
	menu_panel._refresh_core()
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
	if role == "primary": button.theme_type_variation = "HudPrimary"
	for state in ["normal","hover","pressed","disabled","focus"]:
		if role == "primary": button.remove_theme_stylebox_override(state)
		else: button.add_theme_stylebox_override(state,HudChrome.quiet(state,selected,Color("65c9df"),padding))
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
	var integrated_dock := picker_only or main_tab == "upgrades"
	var turret_stats := main_tab == "turrets" and body.find_child("TurretStatsGrid",true,false) != null
	detail_panel.theme_type_variation = "HudDock" if integrated_dock else ""
	if integrated_dock: detail_panel.remove_theme_stylebox_override("panel")
	else: detail_panel.add_theme_stylebox_override("panel",BattleTheme.box(Color("0b1b2bf5" if turret_stats else "0b1b2baa"),Color("33d8ff55"),8))
	# Scroll only when content reaches its limit; an unselected picker has no panel.
	var limit := 198.0 if main_tab == "upgrades" else clampf(get_viewport_rect().size.y*0.28,150,280)
	var content_height := body.get_combined_minimum_size().y
	# The selected turret's two-column stat list and cumulative damage need
	# room below the action strip. Keep the dock bounded on short screens.
	if turret_stats:
		limit = maxf(limit,minf(content_height,get_viewport_rect().size.y*0.52))
	# Socket tags, the reserved detail row and inventory remain visible together.
	if main_tab == "turrets" and tab == "gems" and body.find_child("EquippedSocketRows",true,false) != null:
		limit = maxf(limit,content_height)
	scroll.custom_minimum_size.y = minf(content_height,limit)
	var height := bottom.get_combined_minimum_size().y
	dock.offset_top = -safe_insets().w-height
	dock.offset_bottom = -safe_insets().w

func _stat_input(state: Dictionary, turret: Dictionary) -> Dictionary:
	var input: Dictionary = configuration_cache.derived(state,app.run_domain.service).get("turretStatInputs",{}).get(turret.type,{}).duplicate(true)
	input.merge({"level":turret.level,"primaryTrait":turret.get("primaryTrait"),"secondaryTrait":turret.get("secondaryTrait"),"gems":turret.get("equippedGemSlots",[]).filter(func(g): return g != null)},true)
	return input

func _stats(state: Dictionary,turret: Dictionary) -> Dictionary:
	return app.catalog.turret_stats(turret.type,{"tileSize":48.0,"statInput":_stat_input(state,turret)})

func _dps(stats: Dictionary,type: String) -> float:
	return float(stats.damage)*float(stats.attackRate)+(float(stats.damage)*0.5*float(stats.damageOverTimeDamageMultiplier) if type == "magic" else 0.0)

func _track_purchase_button(button: Button,currency: String,cost: int,blocked: bool) -> void:
	body_purchase_buttons.append({"button":button,"currency":currency,"cost":cost,"blocked":blocked})

func _refresh_purchase_buttons(state: Dictionary) -> void:
	for entry in body_purchase_buttons:
		var button: Button = entry.button
		button.disabled = bool(entry.blocked) or int(state.get(entry.currency,0)) < int(entry.cost)
		if button.has_meta("gem_unlock_condition"):
			var condition: Label = button.get_meta("gem_unlock_condition")
			condition.text = "골드 부족" if int(state.get(entry.currency,0)) < int(entry.cost) else ""
			condition.visible = not condition.text.is_empty()
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
	_modal_max_width = max_width
	modal_panel = PanelContainer.new(); modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_panel.theme_type_variation = "CombatModal"
	modal_panel.custom_minimum_size.x = maxf(1.0,minf(_modal_max_width,get_viewport_rect().size.x-(24 if bottom_sheet else 36)))
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
	modal_body.minimum_size_changed.connect(_queue_modal_fit)
	modal_body.resized.connect(_queue_modal_fit)
	_queue_modal_fit()
	# Container owns position/size; entrance animation must not overwrite layout.
	modal_panel.modulate.a = 0
	_reveal_modal_after_layout(modal_panel)
	return modal_body

func _queue_modal_fit() -> void:
	if _modal_fit_pending or not is_instance_valid(modal): return
	_modal_fit_pending = true
	_fit_modal.call_deferred()

func _fit_modal() -> void:
	_modal_fit_pending = false
	if not is_instance_valid(modal) or not is_instance_valid(modal_scroll): return
	var width := maxf(1.0,minf(_modal_max_width,get_viewport_rect().size.x-(24 if modal_bottom_sheet else 36)))
	if not is_equal_approx(modal_panel.custom_minimum_size.x,width): modal_panel.custom_minimum_size.x = width
	var content_height := modal_body.get_combined_minimum_size().y+8.0
	var height := minf(content_height,get_viewport_rect().size.y*0.82)
	if not is_equal_approx(modal_scroll.custom_minimum_size.y,height): modal_scroll.custom_minimum_size.y = height

func _reveal_modal_after_layout(panel: PanelContainer) -> void:
	# Content is populated by the caller after open_modal returns. Let width and
	# wrapping settle before the entrance tween exposes the first rendered frame.
	await get_tree().process_frame
	if not is_instance_valid(modal) or not is_instance_valid(panel) or panel.is_queued_for_deletion() or panel != modal_panel: return
	_fit_modal()
	await get_tree().process_frame
	if not is_instance_valid(modal) or not is_instance_valid(panel) or panel.is_queued_for_deletion() or panel != modal_panel: return
	panel.create_tween().tween_property(panel,"modulate:a",1.0,0.16)

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
	menu_panel._stage_menu(); return true

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

func _stat_pill(parent: Node,title: String,value: String,color := Color("e8f8ff")) -> void:
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel",BattleTheme.box(Color(color,0.12),Color(color,0.55),7)); parent.add_child(panel)
	var caption := _label(panel,(title+" "+value).strip_edges(),11); caption.modulate = color
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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

## Gem text is also consumed by the reward presenter.
func _gem_name(type: String) -> String:
	return gem_panel._gem_name(type)

func _gem_description(type: String) -> String:
	return gem_panel._gem_description(type)

func _gem_effect(type: String,turret: Dictionary) -> String:
	return gem_panel._gem_effect(type,turret)
