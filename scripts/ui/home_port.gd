extends Control

const Constants = preload("res://data/mvp_constants.gd")
const SHIP_ICONS: Dictionary = {
	"wooden_sloop": "sloop_icon",
	"oak_brigantine": "brigantine_icon",
	"mahogany_galleon": "galleon_icon",
	"dragonwood_man_owar": "manowar_icon"
}
const TAB_ICONS: Dictionary = {"Bank": "icon_bank", "Shipyard": "icon_shipyard", "Market": "icon_market", "Chart Table": "icon_chart"}

var _selected_tab: String = "Bank"
var _selected_tier: int = 1
var _content: VBoxContainer
var _status: Label
var _resource_line: Label
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
	var background := ColorRect.new()
	background.color = Color("#15191f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 60)
	var title := Label.new()
	title.text = "UNCHARTED TIDES  /  HOME PORT"
	title.add_theme_font_size_override("font_size", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_resource_line = Label.new()
	_resource_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resource_line.add_theme_font_size_override("font_size", 19)
	header.add_child(_resource_line)
	var menu_button := _make_button("Main Menu", 148)
	menu_button.pressed.connect(_return_to_main_menu)
	header.add_child(menu_button)
	layout.add_child(header)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(0, 46)
	_status = Label.new()
	_status.text = "Safe harbor. Bank loot, refit, stock provisions, or choose a voyage."
	_status.add_theme_font_size_override("font_size", 17)
	status_panel.add_child(_status)
	layout.add_child(status_panel)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color("#1b252e")
	content_style.border_color = Color("#46525d")
	content_style.set_border_width_all(1)
	content_style.set_corner_radius_all(8)
	content_style.content_margin_left = 16
	content_style.content_margin_right = 16
	content_style.content_margin_top = 12
	content_style.content_margin_bottom = 12
	content_panel.add_theme_stylebox_override("panel", content_style)
	layout.add_child(content_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	for tab in ["Bank", "Shipyard", "Market", "Chart Table"]:
		var button := _make_button(tab, 0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 62
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
		nav.add_child(button)
	layout.add_child(nav)
	_refresh_resource_line()

func _make_button(label: String, min_width: float = 0.0) -> Button:
	var button := Button.new()
	button.name = label.replace(" ", "").replace("—", "") + "Button"
	button.text = label
	button.custom_minimum_size = Vector2(min_width, 54)
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_ALL
	return button

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
		_resource_line.text = "Gold %d    Doubloons %d    Sailing Lv %d" % [PlayerData.gold, PlayerData.doubloons, PlayerData.get_level("Sailing")]
	for tab in _tab_buttons:
		var button: Button = _tab_buttons[tab]
		button.modulate = Color("#f2d58a") if tab == _selected_tab else Color.WHITE

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
