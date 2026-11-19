class_name ShopUi
extends CanvasLayer
## Interface de la boutique (joueur local), construite en code. T ouvre / ferme, Échap ferme.
## Trois colonnes : les 4 gadgets / capacités, les 4 armes configurés dans le lobby, et le palier
## d'amélioration suivant de chaque arme (même ligne). Une carte dit ce qu'un clic fait maintenant
## (acheter, améliorer, recharger) et son prix (Shop.offer / Shop.upgrade_offer).
## Pendant qu'elle est ouverte, la souris est libre (pas de tir, de visée ni d'interaction).

var _player: Player
var _shop: Shop
var _credits_label: Label
var _status_label: Label
var _pending_label: Label
var _weapon_col: VBoxContainer
var _gadget_col: VBoxContainer
var _upgrade_col: VBoxContainer
var _cards: Array[Dictionary] = []  # { id, card }
var _status_tween: Tween
var _shop_key: String = ""


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
	elif event.is_action_pressed("open_shop") and not _player.health.is_dead and not MatchManager.is_lobby() \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		open()
		get_viewport().set_input_as_handled()


## Boutique ouverte : les clics et la molette restent dans le menu.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if _credits_label == null or not visible:
		return
	if _player.health.is_dead:
		close()
		return
	_rebuild_if_needed()
	_credits_label.text = "%d crédits" % _player.inventory.credits
	var pending := _player.abilities.pending
	_pending_label.text = ">> %s attend : appuyez sur Q ou F (en jeu) pour l'équiper" % Shop.entry_name(pending) if pending != "" else ""
	for entry in _cards:
		var id: String = entry["id"]
		var card: UiCard = entry["card"]
		if id == "":
			continue
		if entry["upgrade"]:
			_refresh_upgrade_card(id, card)
			continue
		var o := _shop.offer(id)
		var verb: String = {"buy": "Acheter", "upgrade": "Améliorer", "refill": "Recharger", "pending": "Acheter"}.get(o["action"], "")
		var refusal: String = o["refusal"]
		if refusal != "":
			card.set_info(refusal, UiStyle.RED)
		else:
			card.set_info("%s — %d cr." % [verb, o["price"]])
		card.tooltip_text = "%s\n%s" % [Shop.entry_description(id), o["text"]]
		card.set_state(o["action"] in ["upgrade", "refill"], refusal != "" and refusal.begins_with("Verrouillé"))
		card.disabled = refusal != ""


## Colonne 3 : palier d'amélioration suivant de l'arme de la même ligne.
func _refresh_upgrade_card(id: String, card: UiCard) -> void:
	var o := _shop.upgrade_offer(id)
	var refusal: String = o["refusal"]
	card.set_content("Palier %d / %d" % [o["level"], o["max"]], o["text"] if o["text"] != "" else "Au maximum", "")
	if refusal != "":
		card.set_info(refusal, UiStyle.RED)
	else:
		card.set_info("Améliorer — %d cr." % o["price"])
	card.set_state(o["level"] > 0, refusal.begins_with("Verrouillé"))
	card.disabled = refusal != ""


## La boutique configurée a changé (lobby) : on refait les cartes.
func _rebuild_if_needed() -> void:
	var shop := ProfileManager.shop_of(_player.get_peer_id())
	var key := JSON.stringify(shop)
	if key == _shop_key:
		return
	_shop_key = key
	_cards.clear()
	for column in [_gadget_col, _weapon_col, _upgrade_col]:
		for child in column.get_children():
			child.queue_free()
	var weapons: Array = shop.get("weapons", [])
	var gadgets: Array = shop.get("gadgets", [])
	for i in Config.SHOP_GADGET_SLOTS:
		_gadget_col.add_child(_make_card(String(gadgets[i]) if i < gadgets.size() else "", false))
	for i in Config.SHOP_WEAPON_SLOTS:
		var weapon_id := String(weapons[i]) if i < weapons.size() else ""
		_weapon_col.add_child(_make_card(weapon_id, false))
		_upgrade_col.add_child(_make_card(weapon_id, true))


func _make_card(id: String, upgrade: bool) -> UiCard:
	var card := UiCard.make(Vector2(270, 112))
	if id == "":
		card.set_content("Case vide" if not upgrade else "", "À configurer dans le lobby" if not upgrade else "", "")
		card.disabled = true
		return card
	var lock := Shop.entry_lock(id)
	if upgrade:
		card.set_content("", "", "", FactionData.color_of(lock[0]))
		card.pressed.connect(func() -> void: _shop.request_upgrade.rpc_id(1, id))
	else:
		var sub: String = {Shop.Entry.WEAPON: "Arme", Shop.Entry.GADGET: "Gadget (Q / F)", Shop.Entry.ABILITY: "Capacité (Q / F)"}.get(Shop.entry_kind(id), "")
		card.set_content(Shop.entry_name(id), sub, "", FactionData.color_of(lock[0]))
		card.set_visual(id)
		card.pressed.connect(func() -> void: _shop.request_buy.rpc_id(1, id))
	_cards.append({"id": id, "card": card, "upgrade": upgrade})
	return card


func _on_purchase_result(ok: bool, message: String) -> void:
	_status_label.text = message
	_status_label.modulate = Color(0.5, 1.0, 0.5) if ok else Color(1.0, 0.45, 0.4)
	if _status_tween:
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(2.5)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)


func _build() -> void:
	# Fond assombri qui capte les clics (ils ne doivent pas atteindre le jeu).
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.BG_TOP, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var style := UiStyle.panel_box()
	style.bg_color = Color(UiStyle.PANEL, 0.97)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.theme = UiStyle.theme()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(880, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "BOUTIQUE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_font_override("font", UiStyle.font("Bold"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 24)
	_credits_label.add_theme_color_override("font_color", UiStyle.GOLD)
	_credits_label.add_theme_font_override("font", UiStyle.font("SemiBold"))
	header.add_child(_credits_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	_gadget_col = _column(columns, "GADGETS ET CAPACITÉS — achetés, puis Q ou F ; déjà équipés : améliorer / recharger")
	_weapon_col = _column(columns, "ARMES — largage en %d s (livrées au palier acheté)" % int(Config.DROP_POD_FALL_TIME))
	_upgrade_col = _column(columns, "AMÉLIORATION — palier suivant de l'arme (gardé pour la partie)")

	_pending_label = Label.new()
	_pending_label.add_theme_color_override("font_color", UiStyle.ACCENT)
	_pending_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_pending_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)
	var hint := Label.new()
	hint.text = "T ou Échap : fermer — la boutique se configure dans le lobby (onglet Boutique)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.DIM)
	return label


## Une colonne de la boutique (titre + cartes), ajoutée à `parent`.
func _column(parent: HBoxContainer, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := _section(title)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(270, 64)
	column.add_child(label)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	column.add_child(cards)
	return cards
