class_name ShopUi
extends CanvasLayer
## Interface de la boutique (joueur local), construite en code. T ouvre / ferme, Échap ferme.
## Trois rangées de cartes : les 4 armes et les 4 gadgets / capacités configurés dans le lobby,
## puis les consommables. Chaque carte dit ce qu'un clic fait maintenant (acheter, palier de
## boost si l'arme est déjà portée, amélioration, recharge) et son prix (Shop.offer).
## Pendant qu'elle est ouverte, la souris est libre (pas de tir, de visée ni d'interaction).

var _player: Player
var _shop: Shop
var _credits_label: Label
var _status_label: Label
var _pending_label: Label
var _weapon_row: HBoxContainer
var _gadget_row: HBoxContainer
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
		var o := _shop.offer(id)
		var verb: String = {"buy": "Acheter", "boost": "Améliorer", "upgrade": "Améliorer", "refill": "Recharger", "pending": "Acheter"}.get(o["action"], "")
		var refusal: String = o["refusal"]
		if refusal != "":
			card.set_info(refusal, Color(1, 0.5, 0.45))
		else:
			card.set_info("%s — %d cr." % [verb, o["price"]])
		card.tooltip_text = "%s\n%s" % [Shop.entry_description(id), o["text"]]
		card.set_state(o["action"] in ["boost", "upgrade", "refill"], refusal != "" and refusal.begins_with("Verrouillé"))
		card.disabled = refusal != ""


## La boutique configurée a changé (lobby) : on refait les cartes.
func _rebuild_if_needed() -> void:
	var shop := ProfileManager.shop_of(_player.get_peer_id())
	var key := JSON.stringify(shop)
	if key == _shop_key:
		return
	_shop_key = key
	_cards = _cards.filter(func(e: Dictionary) -> bool: return Shop.entry_kind(e["id"]) == Shop.Entry.CONSUMABLE)
	for row in [_weapon_row, _gadget_row]:
		for child in row.get_children():
			child.queue_free()
	var weapons: Array = shop.get("weapons", [])
	var gadgets: Array = shop.get("gadgets", [])
	for i in Config.SHOP_WEAPON_SLOTS:
		_weapon_row.add_child(_make_card(String(weapons[i]) if i < weapons.size() else ""))
	for i in Config.SHOP_GADGET_SLOTS:
		_gadget_row.add_child(_make_card(String(gadgets[i]) if i < gadgets.size() else ""))


func _make_card(id: String) -> UiCard:
	var card := UiCard.make(Vector2(200, 104))
	if id == "":
		card.set_content("Case vide", "À configurer dans le lobby", "")
		card.disabled = true
		return card
	var lock := Shop.entry_lock(id)
	var kind := Shop.entry_kind(id)
	var sub: String = {Shop.Entry.WEAPON: "Arme", Shop.Entry.GADGET: "Gadget (Q / F)", Shop.Entry.ABILITY: "Capacité (Q / F)",
			Shop.Entry.CONSUMABLE: "Consommable"}.get(kind, "")
	card.set_content(Shop.entry_name(id), sub, "", FactionData.color_of(lock[0]))
	card.pressed.connect(func() -> void: _shop.request_buy.rpc_id(1, id))
	_cards.append({"id": id, "card": card})
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
	style.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	style.border_color = Color(0.95, 0.6, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(900, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "BOUTIQUE"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 24)
	_credits_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	header.add_child(_credits_label)

	box.add_child(_section("ARMES — largage en %d s ; arme déjà portée : palier de boost suivant" % int(Config.DROP_POD_FALL_TIME)))
	_weapon_row = _row()
	box.add_child(_weapon_row)
	box.add_child(_section("GADGETS ET CAPACITÉS — achetés, puis Q ou F pour les équiper ; déjà équipés : améliorer / recharger"))
	_gadget_row = _row()
	box.add_child(_gadget_row)
	var consumables := _row()
	if not Shop.consumables().is_empty():  # soins / cellules : seulement s'ils ont un prix
		box.add_child(_section("CONSOMMABLES"))
		box.add_child(consumables)
	else:
		consumables.queue_free()
	for id in Shop.consumables():
		var card := _make_card(id)
		card.custom_minimum_size = Vector2(200, 80)
		consumables.add_child(card)
	for i in maxi(Config.SHOP_WEAPON_SLOTS - consumables.get_child_count(), 0):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		consumables.add_child(spacer)

	_pending_label = Label.new()
	_pending_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
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
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return label


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	return row
