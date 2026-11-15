extends Control

const Constants = preload("res://data/mvp_constants.gd")
const HarborBackdrop = preload("res://scripts/ui/harbor_backdrop.gd")
const SHIP_ICONS: Dictionary = {
	"wooden_sloop": "sloop_icon",
	"oak_brigantine": "brigantine_icon",
	"mahogany_galleon": "galleon_icon",
	"dragonwood_man_owar": "manowar_icon"
}
const TAB_ICONS: Dictionary = {"Bank": "icon_bank", "Shipyard": "icon_shipyard", "Market": "icon_market", "Chart Table": "icon_chart", "Bounty Board": "icon_chart", "Crew Roster": "icon_shipyard"}

var _selected_tab: String = "Bank"
var _selected_tier: int = 1
var _content: VBoxContainer
var _status: Label
var _resource_line: Label
var _ship_summary: Label
var _voyage_summary: Label
var _hero_action: Button
var _tab_buttons: Dictionary = {}
var _transitioning: bool = false

func _ready() -> void:
	if get_tree().root.has_meta("home_port_open_tab"):
		var requested: String = str(get_tree().root.get_meta("home_port_open_tab"))
		get_tree().root.remove_meta("home_port_open_tab")
		if requested == "chart":
			_selected_tab = "Chart Table"
		elif requested == "bank":
			_selected_tab = "Bank"
	_build_layout()
	if get_tree().root.has_meta("home_port_return_message"):
		_status.text = str(get_tree().root.get_meta("home_port_return_message"))
		get_tree().root.remove_meta("home_port_return_message")
	PlayerData.state_changed.connect(_on_player_state_changed)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	_render_tab()
	SettingsManager.apply_to_tree(self)

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := HarborBackdrop.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.08, 0.12, 0.15)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 58)
	header.add_theme_constant_override("separation", 10)
	var captain_portrait := TextureRect.new()
	captain_portrait.name = "CaptainPortrait"
	captain_portrait.texture = load("res://assets/ui/captain_portrait_reference.png") as Texture2D
	captain_portrait.custom_minimum_size = Vector2(54, 54)
	captain_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	captain_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	header.add_child(captain_portrait)
	var title := Label.new()
	title.text = "⚓  HOME PORT"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ffe1a0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_resource_line = Label.new()
	_resource_line.name = "PersistentResourceBadges"
	_resource_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resource_line.add_theme_font_size_override("font_size", 17)
	_resource_line.add_theme_color_override("font_color", Color("#f7e8c4"))
	_resource_line.custom_minimum_size.x = 620
	var resource_frame := PanelContainer.new()
	resource_frame.add_theme_stylebox_override("panel", _frame_style(Color("#19354a"), Color("#d9b45f"), 7, 7))
	resource_frame.add_child(_resource_line)
	header.add_child(resource_frame)
	var menu_button := _make_button("Main Menu", 142)
	menu_button.pressed.connect(_return_to_main_menu)
	header.add_child(menu_button)
	layout.add_child(header)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(0, 42)
	status_panel.add_theme_stylebox_override("panel", _frame_style(Color(0.06, 0.16, 0.21, 0.90), Color("#a98644"), 6, 6))
	_status = Label.new()
	_status.text = "Safe harbor. Bank loot, refit, stock provisions, or choose a voyage."
	_status.add_theme_font_size_override("font_size", 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_panel.add_child(_status)
	layout.add_child(status_panel)
	layout.add_child(_build_hero_panel())

	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(0.07, 0.16, 0.22, 0.84)
	content_style.border_color = Color("#d0a84e")
	content_style.set_border_width_all(2)
	content_style.set_corner_radius_all(10)
	content_style.content_margin_left = 16
	content_style.content_margin_right = 16
	content_style.content_margin_top = 10
	content_style.content_margin_bottom = 10
	content_panel.add_theme_stylebox_override("panel", content_style)
	layout.add_child(content_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "BountyBoardContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	var main_nav := HBoxContainer.new()
	main_nav.name = "PrimaryPortNavigation"
	main_nav.add_theme_constant_override("separation", 9)
	for tab in ["Bank", "Shipyard", "Market", "Chart Table"]:
		_add_tab_button(main_nav, tab, 64)
	layout.add_child(main_nav)
	var extra_nav := HBoxContainer.new()
	extra_nav.name = "SecondaryPortNavigation"
	extra_nav.add_theme_constant_override("separation", 9)
	for tab in ["Bounty Board", "Crew Roster"]:
		_add_tab_button(extra_nav, tab, 48)
	layout.add_child(extra_nav)
	_refresh_resource_line()

func _build_hero_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "HarborHeroBanner"
	panel.custom_minimum_size = Vector2(0, 122)
	panel.add_theme_stylebox_override("panel", _frame_style(Color("#17344a"), Color("#e0bd6c"), 9, 6))
	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 116)
	panel.add_child(root)
	var art := TextureRect.new()
	art.name = "HarborReferenceArt"
	art.texture = load("res://assets/ui/harbor_scene_strip.png") as Texture2D
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	var tint := ColorRect.new()
	tint.color = Color(0.03, 0.12, 0.17, 0.34)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(tint)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	root.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var current_ship := HBoxContainer.new()
	current_ship.name = "CurrentShipCard"
	current_ship.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_ship.add_theme_constant_override("separation", 10)
	row.add_child(current_ship)
	var ship_icon := TextureRect.new()
	ship_icon.name = "CurrentShipPortrait"
	ship_icon.custom_minimum_size = Vector2(94, 92)
	ship_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	current_ship.add_child(ship_icon)
	var active_ship_id := PlayerData.active_ship_id
	var ship_icon_id: String = str(SHIP_ICONS.get(active_ship_id, "sloop_icon"))
	var ship_icon_ref: WeakRef = weakref(ship_icon)
	AssetManager.request_texture(ship_icon_id, func(texture: Texture2D):
		var target_icon := ship_icon_ref.get_ref() as TextureRect
		if target_icon != null and texture != null:
			target_icon.texture = texture
	)
	var ship_copy := VBoxContainer.new()
	ship_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	current_ship.add_child(ship_copy)
	ship_copy.add_child(_subheading("CURRENT SHIP"))
	_ship_summary = Label.new()
	_ship_summary.name = "CurrentShipSummary"
	_ship_summary.add_theme_font_size_override("font_size", 15)
	_ship_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_copy.add_child(_ship_summary)

	var separator := VSeparator.new()
	row.add_child(separator)
	var voyage_card := VBoxContainer.new()
	voyage_card.name = "VoyageSummaryCard"
	voyage_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voyage_card.alignment = BoxContainer.ALIGNMENT_CENTER
	voyage_card.add_theme_constant_override("separation", 3)
	row.add_child(voyage_card)
	voyage_card.add_child(_subheading("VOYAGE SUMMARY"))
	_voyage_summary = Label.new()
	_voyage_summary.name = "VoyageSummaryText"
	_voyage_summary.add_theme_font_size_override("font_size", 14)
	_voyage_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voyage_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voyage_card.add_child(_voyage_summary)
	_hero_action = _make_button("Plan Voyage", 168)
	_hero_action.custom_minimum_size.y = 48
	_hero_action.pressed.connect(_on_hero_action_pressed)
	voyage_card.add_child(_hero_action)
	_refresh_hero_summary()
	return panel

func _refresh_hero_summary() -> void:
	if is_instance_valid(_ship_summary):
		var specs: Dictionary = Constants.SHIPS.get(PlayerData.active_ship_id, {})
		var ship_name: String = str(specs.get("name", "Ship"))
		var base_hull: int = int(specs.get("max_hp", 100))
		var cargo_slots: int = int(specs.get("cargo_slots", 8))
		_ship_summary.text = "%s  ·  Fleet Tier %d\nBase hull %d HP  ·  %d cargo slots" % [ship_name, _active_ship_tier(), base_hull, cargo_slots]
	if is_instance_valid(_voyage_summary):
		var chart_size: int = int(Constants.CHART_SIZE_BY_TIER.get(_selected_tier, 10))
		var risk: String = ["", "Low", "Moderate", "High", "Extreme"][clampi(_selected_tier, 1, 4)]
		_voyage_summary.text = "Tier %d  ·  %d × %d chart  ·  %s risk\nSafe return guarantees provision cost + 25%% Gold." % [_selected_tier, chart_size, chart_size, risk]
	if is_instance_valid(_hero_action):
		_hero_action.text = "Resume Voyage" if PlayerData.voyage.is_active else "Plan Voyage"

func _on_hero_action_pressed() -> void:
	if PlayerData.voyage.is_active:
		get_tree().change_scene_to_file("res://scenes/open_sea.tscn")
	else:
		_select_tab("Chart Table")

func _add_tab_button(parent: HBoxContainer, tab: String, height: float) -> void:
	var button := _make_button(tab, 0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = height
	button.pressed.connect(_select_tab.bind(tab))
	_tab_buttons[tab] = button
	var button_ref: WeakRef = weakref(button)
	var icon_id: String = str(TAB_ICONS[tab])
	AssetManager.request_texture(icon_id, func(texture: Texture2D):
		var target_button := button_ref.get_ref() as Button
		if target_button != null and texture != null:
			target_button.icon = texture
			target_button.expand_icon = true
	)
	parent.add_child(button)

func _make_button(label: String, min_width: float = 0.0) -> Button:
	var button := Button.new()
	button.name = label.replace(" ", "").replace("—", "") + "Button"
	button.text = label
	button.custom_minimum_size = Vector2(min_width, 56)
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_ALL
	_apply_button_style(button, false)
	return button

func _frame_style(fill: Color, border: Color, radius: int = 9, shadow: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = shadow
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _apply_button_style(button: Button, selected: bool) -> void:
	var normal := _frame_style(Color("#17344a") if not selected else Color("#785a28"), Color("#b38d42") if not selected else Color("#ffe09a"), 8, 2 if selected else 0)
	var hover := _frame_style(Color("#28516a") if not selected else Color("#987433"), Color("#f5d47e"), 8, 5)
	var pressed := _frame_style(Color("#102838") if not selected else Color("#62491f"), Color("#ffe09a"), 8, 1)
	var disabled := _frame_style(Color("#29343b"), Color("#606466"), 8, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color("#f5e9ca"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#a6a6a2"))

func _return_to_main_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	AssetManager.request_texture("loading_screen", _fade_to_menu)

func _fade_to_menu(texture: Texture2D) -> void:
	var duration: float = SettingsManager.transition_duration(0.22)
	if duration <= 0.0:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	var transition := TextureRect.new()
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	transition.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	transition.texture = texture if texture != null else load("res://assets/screens/loading_screen.jpg") as Texture2D
	transition.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(transition)
	var tween := create_tween()
	tween.tween_property(transition, "modulate:a", 1.0, duration)
	tween.finished.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

func _select_tab(tab: String) -> void:
	_selected_tab = tab
	_status.text = ""
	_render_tab()

func _on_player_state_changed() -> void:
	_refresh_resource_line()
	_render_tab()
	SettingsManager.apply_to_tree(self)

func _on_settings_changed() -> void:
	SettingsManager.apply_to_tree(self)

func _refresh_resource_line() -> void:
	if is_instance_valid(_resource_line):
		_resource_line.text = "Gold  %d     Doubloons  %d     Oak  %d     Cannonballs  %d     Repairs  %d" % [PlayerData.gold, PlayerData.doubloons, int(PlayerData.bank.get("oak_plank", 0)), int(PlayerData.bank.get("cannonball", 0)), int(PlayerData.bank.get("repair_plank", 0))]
	_refresh_hero_summary()
	for tab in _tab_buttons:
		var button: Button = _tab_buttons[tab]
		_apply_button_style(button, tab == _selected_tab)
		button.modulate = Color.WHITE

func _render_tab() -> void:
	if not is_instance_valid(_content):
		return
	for child in _content.get_children():
		child.queue_free()
	match _selected_tab:
		"Bank": _render_bank()
		"Shipyard": _render_shipyard()
		"Market": _render_market()
		"Chart Table": _render_chart_table()
		"Bounty Board": _render_bounty_board()
		"Crew Roster": _render_crew_roster()
	_refresh_resource_line()
	SettingsManager.apply_to_tree(self)

func _add_heading(text: String, detail: String = "") -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("#f2d58a"))
	_content.add_child(heading)
	if not detail.is_empty():
		var label := Label.new()
		label.text = detail
		label.add_theme_font_size_override("font_size", 16)
		_content.add_child(label)

func _render_bank() -> void:
	_add_heading("Permanent Bank", "Bank storage is persistent and stackable. Backpack and cargo are slot-limited.")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	_content.add_child(columns)
	var bank_box := VBoxContainer.new()
	bank_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(bank_box)
	var pack_box := VBoxContainer.new()
	pack_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(pack_box)
	bank_box.add_child(_subheading("BANKED ITEMS"))
	var bank_ids: Array = PlayerData.bank.keys()
	bank_ids.sort()
	if bank_ids.is_empty():
		bank_box.add_child(_body("No items banked yet. Buy provisions in the Market or return with voyage cargo."))
	for raw_id in bank_ids:
		var item_id: String = str(raw_id)
		var quantity: int = int(PlayerData.bank[item_id])
		var row := HBoxContainer.new()
		row.add_child(_body("%s  ×%d" % [_item_name(item_id), quantity], true))
		var withdraw_one := _make_button("Withdraw 1", 126)
		withdraw_one.pressed.connect(func(): _handle_transaction(PlayerData.withdraw(item_id, 1)))
		row.add_child(withdraw_one)
		var withdraw_all := _make_button("Withdraw all", 134)
		withdraw_all.pressed.connect(func(): _handle_transaction(PlayerData.withdraw(item_id, quantity)))
		row.add_child(withdraw_all)
		bank_box.add_child(row)
	bank_box.add_child(_body("Bank slots: unlimited; withdrawals require backpack space."))

	pack_box.add_child(_subheading("BACKPACK  %d/%d SLOTS" % [PlayerData.backpack.size(), Constants.MAX_BACKPACK_SLOTS]))
	var grouped := _backpack_counts()
	var backpack_ids: Array = grouped.keys()
	backpack_ids.sort()
	if backpack_ids.is_empty():
		pack_box.add_child(_body("Your backpack is empty."))
	for raw_id in backpack_ids:
		var item_id: String = str(raw_id)
		var quantity: int = int(grouped[item_id])
		var row := HBoxContainer.new()
		row.add_child(_body("%s  ×%d" % [_item_name(item_id), quantity], true))
		var deposit_one := _make_button("Deposit 1", 120)
		deposit_one.pressed.connect(func(): _handle_transaction(PlayerData.deposit(item_id, 1)))
		row.add_child(deposit_one)
		var deposit_all := _make_button("Deposit all", 126)
		deposit_all.pressed.connect(func(): _handle_transaction(PlayerData.deposit(item_id, quantity)))
		row.add_child(deposit_all)
		pack_box.add_child(row)

func _backpack_counts() -> Dictionary:
	var grouped: Dictionary = {}
	for slot in PlayerData.backpack:
		var item_id: String = str(slot.get("item_id", ""))
		if not item_id.is_empty():
			grouped[item_id] = int(grouped.get(item_id, 0)) + maxi(1, int(slot.get("qty", 1)))
	return grouped

func _render_shipyard() -> void:
	_add_heading("Shipyard", "Compare your active vessel with the next refit. Upgrades require its predecessor and are locked at sea.")
	for ship_id in Constants.SHIPS:
		var specs: Dictionary = Constants.SHIPS[ship_id]
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 112
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#202d36") if str(ship_id) == PlayerData.active_ship_id else Color("#18232b")
		card_style.border_color = Color("#c6a45c") if str(ship_id) == PlayerData.active_ship_id else Color("#3a4a55")
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(7)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(76, 76)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var icon_ref: WeakRef = weakref(icon)
		var icon_id: String = str(SHIP_ICONS.get(ship_id, ""))
		AssetManager.request_texture(icon_id, func(texture: Texture2D):
			var target_icon := icon_ref.get_ref() as TextureRect
			if target_icon != null and texture != null:
				target_icon.texture = texture
		)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		var name_label := _subheading(str(specs.get("name", ship_id)))
		name_label.add_theme_color_override("font_color", Color("#f2d58a") if str(ship_id) == PlayerData.active_ship_id else Color.WHITE)
		detail.add_child(name_label)
		var mats: Dictionary = specs.get("cost_materials", {})
		var mat_text: Array[String] = []
		for mat_id in mats:
			mat_text.append("%s ×%d" % [_item_name(str(mat_id)), int(mats[mat_id])])
		var requirements := "Sailing %d  |  %d HP  |  %d cargo slots  |  %d movement tiles/action  |  %d cannon(s)/side\nCost: %d Gold%s" % [int(specs.req_sailing), int(specs.max_hp), int(specs.cargo_slots), int(specs.get("movement_range", 1)), int(specs.cannons_per_side), int(specs.cost_gold), (" + " + ", ".join(mat_text) if not mat_text.is_empty() else " (starter)")]
		detail.add_child(_body(requirements))
		var is_active: bool = str(ship_id) == PlayerData.active_ship_id
		var is_next: bool = str(specs.get("previous_ship_id", "")) == PlayerData.active_ship_id
		var state_line: String = "YOUR ACTIVE VESSEL" if is_active else ("NEXT REFIT" if is_next else "FLEET PROGRESSION")
		var state_label := _body(state_line, true)
		state_label.add_theme_color_override("font_color", Color("#c6a45c"))
		detail.add_child(state_label)
		if is_active:
			var perk_text: String = "Captain perk: +10% extraction Gold" if PlayerData.captain_background == "merchant" else ("Captain perk: +1 movement tile/action" if PlayerData.captain_background == "navigator" else "Captain perk: 20% less hull damage")
			detail.add_child(_body(perk_text))
		var can_afford: bool = PlayerData.gold >= int(specs.get("cost_gold", 0))
		for material_id in mats:
			if int(PlayerData.bank.get(material_id, 0)) < int(mats[material_id]):
				can_afford = false
		var meets_level: bool = PlayerData.get_level("Sailing") >= int(specs.get("req_sailing", 1))
		var can_upgrade: bool = not PlayerData.voyage.is_active and is_next and can_afford and meets_level
		var action_text: String = "Active" if is_active else ("Upgrade" if can_upgrade else ("At Sea" if PlayerData.voyage.is_active else "Locked"))
		var action := _make_button(action_text, 150)
		action.disabled = is_active or not can_upgrade
		var captured_ship_id: String = str(ship_id)
		action.pressed.connect(func(): _handle_transaction(PlayerData.upgrade_ship(captured_ship_id)))
		row.add_child(action)
		_content.add_child(card)

	_add_heading("Crew & Equipment", "Craft permanent refits from gathered resources, Gold, and Doubloons. Each level directly improves ship performance.")
	for slot in ["cannons", "sails", "hull"]:
		var recipe: Dictionary = Constants.EQUIPMENT[slot]
		var level: int = int(PlayerData.equipment_levels.get(slot, 0))
		var row := HBoxContainer.new()
		var effect: String = "+15 cannon damage" if slot == "cannons" else ("+1 movement tile/action" if slot == "sails" else "+50 maximum hull HP")
		var label := _body("%s  ·  Level %d/%d  ·  %s" % [str(recipe.name), level, Constants.EQUIPMENT_MAX_LEVEL, effect], true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var upgrade := _make_button("Craft / Upgrade", 190)
		upgrade.disabled = level >= Constants.EQUIPMENT_MAX_LEVEL or PlayerData.voyage.is_active
		var captured_slot: String = slot
		upgrade.pressed.connect(func(): _handle_transaction(PlayerData.upgrade_equipment(captured_slot)))
		row.add_child(upgrade)
		_content.add_child(row)

func _render_market() -> void:
	_add_heading("Market & Trade", "Buy provisions into your Bank or sell banked goods for Gold. Selling is unavailable at sea.")
	for item_id in Constants.ITEMS:
		var offer: Dictionary = Constants.MARKET_ITEMS.get(item_id, {})
		var sell_price: int = int(Constants.ITEM_SELL_PRICES.get(item_id, 0))
		if offer.is_empty() and sell_price <= 0:
			continue
		var row := HBoxContainer.new()
		var buy_price: int = int(offer.get("price_gold", 0))
		var label := _body("%s  |  Banked %d%s%s" % [_item_name(str(item_id)), int(PlayerData.bank.get(item_id, 0)), "  |  Buy %d Gold" % buy_price if buy_price > 0 else "", "  |  Sell %d Gold" % sell_price if sell_price > 0 else ""], true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var captured_id: String = str(item_id)
		if not offer.is_empty():
			for quantity in [1, 5]:
				var buy := _make_button("Buy %d" % quantity, 100)
				buy.pressed.connect(func(): _handle_transaction(PlayerData.buy_market_item(captured_id, quantity)))
				row.add_child(buy)
		if sell_price > 0:
			for quantity in [1, 5]:
				var sell := _make_button("Sell %d" % quantity, 100)
				sell.disabled = int(PlayerData.bank.get(item_id, 0)) <= 0 or PlayerData.voyage.is_active
				sell.pressed.connect(func(): _handle_transaction(PlayerData.sell_market_item(captured_id, quantity)))
				row.add_child(sell)
		_content.add_child(row)
	_content.add_child(_body("Successful extraction guarantees the provision benchmark plus a 25% Gold margin. Cargo loot and exploration rewards are additional value; sinking/failure forfeits unbanked cargo."))

func _render_chart_table() -> void:
	_add_heading("Chart Table", "Select a voyage tier. Supplies are charged from your permanent bank on launch.")
	var tier_row := HBoxContainer.new()
	for tier in [1, 2, 3, 4]:
		var tier_button := _make_button("Tier %d" % tier, 140)
		tier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var captured_tier: int = tier
		tier_button.pressed.connect(func(): _selected_tier = captured_tier; _render_tab())
		tier_row.add_child(tier_button)
	_content.add_child(tier_row)
	var req: Dictionary = Constants.VOYAGE_TIER_REQUIREMENTS.get(_selected_tier, {})
	_content.add_child(_subheading("Tier %d  |  Requires Sailing Level %d and Ship Tier %d" % [_selected_tier, int(req.get("req_sailing", 1)), int(req.get("ship_tier", 1))]))
	var provisions: Dictionary = Constants.VOYAGE_PROVISIONS.get(_selected_tier, {})
	for item_id in provisions:
		var needed: int = int(provisions[item_id])
		var have: int = int(PlayerData.bank.get(item_id, 0))
		var line := _body("%s  %d required  /  %d banked" % [_item_name(str(item_id)), needed, have], true)
		line.modulate = Color("#f3d48b") if have >= needed else Color("#ff9898")
		_content.add_child(line)
	var actions := HBoxContainer.new()
	var market := _make_button("Visit Market", 180)
	market.pressed.connect(_select_tab.bind("Market"))
	actions.add_child(market)
	var launch := _make_button("Set Sail — Tier %d" % _selected_tier, 240)
	var can_launch: bool = not PlayerData.voyage.is_active and PlayerData.get_level("Sailing") >= int(req.get("req_sailing", 1)) and _active_ship_tier() >= int(req.get("ship_tier", 1))
	for item_id in provisions:
		if int(PlayerData.bank.get(item_id, 0)) < int(provisions[item_id]):
			can_launch = false
	launch.disabled = not can_launch
	launch.pressed.connect(_launch_selected_voyage)
	actions.add_child(launch)
	_content.add_child(actions)
	if PlayerData.voyage.is_active:
		_content.add_child(_body("Voyage active: Tier %d, seed %d. Ship upgrades and sales are locked until safe harbor." % [PlayerData.voyage.tier, PlayerData.voyage.seed_value]))
		var resume := _make_button("Resume Open Sea", 210)
		resume.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/open_sea.tscn"))
		_content.add_child(resume)

func _render_bounty_board() -> void:
	var contracts: Array[Dictionary] = PlayerData.get_bounty_contracts()
	var cycle: int = int(PlayerData.bounty_cycle) + 1
	_add_heading("Harbor Bounty Board", "Cycle %d · 3 active contracts · progresses across up to three launched voyages. Rewards are granted automatically on completion." % cycle)
	for contract in contracts:
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 112
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(_subheading(str(contract.get("title", "Voyage Contract"))))
		details.add_child(_body(str(contract.get("description", ""))))
		var progress_text: String = "Completed" if bool(contract.get("completed", false)) else "Progress %d/%d" % [int(contract.get("progress", 0)), int(contract.get("goal", 1))]
		details.add_child(_body(progress_text, true))
		row.add_child(details)
		var reward_item: String = str(contract.get("item", ""))
		var reward_text: String = "%d Gold · %d Doubloons · %s ×%d" % [int(contract.get("gold", 0)), int(contract.get("doubloons", 0)), _item_name(reward_item), int(contract.get("quantity", 0))]
		var reward_label := _body(reward_text)
		reward_label.custom_minimum_size.x = 250
		row.add_child(reward_label)
		_content.add_child(card)
	_content.add_child(_body("Defeating ships, completing site scavenging, and matching-tier safe extraction are tracked automatically. Progress and completed rewards persist through saves."))

func _render_crew_roster() -> void:
	_add_heading("Crew Roster", "Hire and assign up to two specialists. Effects stack with Captain perks and Relics.")
	for id in Constants.CREW_SPECIALISTS:
		var spec: Dictionary = Constants.CREW_SPECIALISTS[id]
		var row := HBoxContainer.new()
		var label := _body("%s · %s" % [str(spec.name), str(spec.bonus)], true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := _make_button("Assigned" if PlayerData.active_crew.has(id) else ("Assign" if PlayerData.hired_crew.has(id) else "Hire"), 140)
		button.custom_minimum_size.y = 60
		var cid: String = str(id)
		button.pressed.connect(func(): _handle_transaction(PlayerData.toggle_crew(cid) if PlayerData.hired_crew.has(cid) else PlayerData.hire_crew(cid)))
		row.add_child(button)
		_content.add_child(row)

func _active_ship_tier() -> int:
	var tier: int = 1
	for ship_id in Constants.SHIPS:
		if str(ship_id) == PlayerData.active_ship_id: return tier
		tier += 1
	return 1

func _launch_selected_voyage() -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) ^ randi()
	var result: Dictionary = PlayerData.launch_voyage(_selected_tier, seed_value)
	_handle_transaction(result)
	if bool(result.get("success", false)):
		get_tree().change_scene_to_file("res://scenes/open_sea.tscn")

func _handle_transaction(result: Dictionary) -> void:
	_status.text = str(result.get("message", "Transaction complete."))
	_refresh_resource_line()
	_render_tab()

func _item_name(item_id: String) -> String:
	return str(Constants.ITEMS.get(item_id, {}).get("name", item_id.replace("_", " ").capitalize()))

func _subheading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	return label

func _body(text: String, expand: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
