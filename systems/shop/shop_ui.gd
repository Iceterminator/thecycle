class_name ShopUi
extends CanvasLayer
## Interface de la boutique (joueur local), construite en code.
## T ouvre / ferme, Échap ferme. Pendant qu'elle est ouverte, la souris est libre
## (donc pas de tir, pas de visée, pas d'interaction).

var _player: Player
var _shop: Shop
var _credits_label: Label
var _status_label: Label
var _rows: Array[Dictionary] = []  # { item, button, info }
var _status_tween: Tween


func setup(player: Player, shop: Shop) -> void:
	_player = player
	_shop = shop
	layer = 10
	visible = false
	_build()
	player.inventory.changed.connect(_refresh)
	player.health.changed.connect(_refresh)
	shop.purchase_result.connect(_on_purchase_result)
	_refresh()


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("open_shop") or event.is_action_pressed("toggle_mouse"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_shop") and not _player.health.is_dead:
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	if _credits_label == null:
		return
	if visible and _player.health.is_dead:
		close()
	_credits_label.text = "%d crédits" % _player.inventory.credits
	for row in _rows:
		var item: ItemData = row["item"]
		var refusal := _shop.check_purchase(item)
		var button: Button = row["button"]
		button.disabled = refusal != ""
		(row["info"] as Label).text = refusal
	_refresh_ability_upgrades()
	_refresh_weapon_boost()


# --- Boost de l'arme en main (étape 8e) ---

var _boost_name: Label
var _boost_info: Label
var _boost_button: Button


func _build_weapon_boost(box: VBoxContainer) -> void:
	var section := Label.new()
	section.text = "Boost de l'arme en main (3 paliers, gardés si elle tombe au sol)"
	section.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(section)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_boost_name = Label.new()
	_boost_name.add_theme_font_size_override("font_size", 20)
	_boost_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_boost_name)
	_boost_info = Label.new()
	_boost_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	row.add_child(_boost_info)
	_boost_button = Button.new()
	_boost_button.custom_minimum_size = Vector2(110, 36)
	_boost_button.pressed.connect(func() -> void: _shop.request_boost.rpc_id(1))
	row.add_child(_boost_button)
	box.add_child(row)


func _refresh_weapon_boost() -> void:
	if _boost_button == null:
		return
	var weapon := _player.inventory.get_active_weapon()
	var level := _player.inventory.get_active_boost()
	var max_level := mini(weapon.boosts.size(), Config.WEAPON_BOOST_PRICES.size()) if weapon else 0
	_boost_name.text = "%s (palier %d/%d)" % [weapon.display_name if weapon else "?", level, max_level]
	if level >= max_level:
		_boost_info.text = "Au maximum"
		_boost_button.text = "—"
		_boost_button.disabled = true
		return
	var price: int = Config.WEAPON_BOOST_PRICES[level]
	_boost_info.text = Shop.boost_text(weapon, level)
	_boost_button.text = "%d cr." % price
	_boost_button.disabled = _player.inventory.credits < price


# --- Améliorations des capacités (étape 8c) ---

var _upgrade_rows: Array[Dictionary] = []  # { name, info, button }


func _build_ability_upgrades(box: VBoxContainer) -> void:
	var section := Label.new()
	section.text = "Capacités : chaque amélioration réduit la recharge"
	section.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(section)
	for slot in AbilityController.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var info := Label.new()
		info.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		row.add_child(info)
		var button := Button.new()
		button.text = "%d cr." % Config.ABILITY_UPGRADE_PRICE
		button.custom_minimum_size = Vector2(110, 36)
		button.pressed.connect(func() -> void: _player.abilities.request_upgrade.rpc_id(1, slot))
		row.add_child(button)
		box.add_child(row)
		_upgrade_rows.append({"name": name_label, "info": info, "button": button})


func _refresh_ability_upgrades() -> void:
	var abilities := _player.abilities
	if abilities == null:
		return
	var keys := ["Q", "F"]
	for slot in _upgrade_rows.size():
		var row: Dictionary = _upgrade_rows[slot]
		var a := abilities.get_slot(slot)
		var level: int = abilities.upgrades[slot]
		(row["name"] as Label).text = "[%s] %s (%d/%d)" % [keys[slot], a.get_display_name() if a else "?", level, Config.ABILITY_MAX_UPGRADES]
		var refusal := ""
		if level >= Config.ABILITY_MAX_UPGRADES:
			refusal = "Au maximum"
		elif _player.inventory.credits < Config.ABILITY_UPGRADE_PRICE:
			refusal = "Pas assez de crédits"
		elif a:
			refusal = "-%d s de recharge" % int(a.upgrade_cooldown_s)
		(row["info"] as Label).text = refusal
		(row["button"] as Button).disabled = a == null or level >= Config.ABILITY_MAX_UPGRADES \
				or _player.inventory.credits < Config.ABILITY_UPGRADE_PRICE


func _on_purchase_result(ok: bool, message: String) -> void:
	_status_label.text = message
	_status_label.modulate = Color(0.5, 1.0, 0.5) if ok else Color(1.0, 0.45, 0.4)
	if _status_tween:
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(2.5)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)
	if ok:
		close()  # on referme pour voir arriver la capsule


func _build() -> void:
	# Fond assombri qui capte les clics (ils ne doivent pas atteindre le jeu).
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	style.border_color = Color(0.95, 0.6, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "BOUTIQUE — largage en %d s" % int(Config.DROP_POD_FALL_TIME)
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 22)
	_credits_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	header.add_child(_credits_label)

	box.add_child(HSeparator.new())
	var last_kind := -1
	for item in Items.get_shop_items():
		if item.kind != last_kind:
			last_kind = item.kind
			var section := Label.new()
			section.text = "Armes" if item.kind == ItemData.Kind.WEAPON else "Objets"
			section.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
			box.add_child(section)
		box.add_child(_make_row(item))
	_build_weapon_boost(box)
	_build_ability_upgrades(box)

	box.add_child(HSeparator.new())
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)
	var hint := Label.new()
	hint.text = "T ou Échap : fermer"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)


func _make_row(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var swatch := ColorRect.new()
	swatch.color = item.color
	swatch.custom_minimum_size = Vector2(8, 28)
	row.add_child(swatch)
	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var info := Label.new()
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	row.add_child(info)
	var button := Button.new()
	button.text = "%d cr." % item.price
	button.custom_minimum_size = Vector2(110, 36)
	button.pressed.connect(func() -> void: _shop.request_buy.rpc_id(1, String(item.id)))
	row.add_child(button)
	_rows.append({"item": item, "button": button, "info": info})
	return row
