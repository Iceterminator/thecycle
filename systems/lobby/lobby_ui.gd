class_name LobbyUi
extends CanvasLayer
## Écran du lobby (étape 9, joueur local), affiché pendant la phase LOBBY du MatchManager.
## Barre du haut : escouade, onglets, pseudo, compte à rebours, bouton PRÊT. Onglets :
## - Décollage : joueurs prêts, résumé de l'équipement ;
## - Équipement (LoadoutPage) : vue d'ensemble (départ + boutique), fiche d'un objet, sélecteur ;
##   voir loadout_page.gd ;
## - Arsenal : catégories à gauche, filtres, cartes (débloquées, puis verrouillées par
##   niveau de faction), fiche détaillée à droite avec les actions ;
## - Factions : faction de prédilection et ce que chaque niveau de réputation débloque ;
## - Escouade : créer, rejoindre, quitter.
## Chaque changement est envoyé au serveur (ProfileManager.request_set_loadout), qui vérifie tout.
## Ce script garde l'état de l'équipement et orchestre ; chaque onglet est dans lobby_ui_<onglet>.gd
## (launch, arsenal, factions, squad), la barre du haut dans lobby_ui_top_bar.gd, l'envoi au serveur
## dans lobby_ui_sync.gd, le catalogue dans lobby_ui_catalog.gd, les widgets dans lobby_ui_widgets.gd.

const Catalog := preload("res://systems/lobby/lobby_ui_catalog.gd")
const Sync := preload("res://systems/lobby/lobby_ui_sync.gd")
const TopBar := preload("res://systems/lobby/lobby_ui_top_bar.gd")
const LaunchPage := preload("res://systems/lobby/lobby_ui_launch.gd")
const ArsenalPage := preload("res://systems/lobby/lobby_ui_arsenal.gd")
const ArsenalActions := preload("res://systems/lobby/lobby_ui_arsenal_actions.gd")
const FactionsPage := preload("res://systems/lobby/lobby_ui_factions.gd")
const SquadPage := preload("res://systems/lobby/lobby_ui_squad.gd")

const SEND_DELAY := 0.3
const BG := UiStyle.BG_TOP
const BAR := UiStyle.BAR
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const RED := UiStyle.RED
const DIM := UiStyle.DIM

enum Page { LAUNCH, LOADOUT, ARSENAL, FACTIONS, SQUAD }
enum Cat { PRIMARY, SECONDARY, GADGET, ABILITY, KIT }
const CAT_NAMES := ["Armes principales", "Armes secondaires", "Gadgets", "Capacités", "Kits"]
const TYPE_NAMES := ["Pistolet-mitrailleur", "Fusil d'assaut", "Fusil de combat", "Fusil de précision",
		"Fusil à pompe", "Mitrailleuse", "Pistolet", "Lance-missiles", "Arme lourde", "Gadget"]

var _player: Player
var _world: Node

# --- État de l'équipement (envoyé au serveur) ---
var _preferred: int = 0
var _kit_id: String = String(Config.start_loadout.default_kit)
var _kit_mods: Dictionary = {}       # id de kit -> id de mod
var _weapon_mods: Dictionary = {}    # id d'arme -> id de mod
var _start_weapon: String = String(Config.start_loadout.base_weapon)
var _shop_weapons: Array = []
var _shop_gadgets: Array = []
var _send_left: float = -1.0
var _selected_case: int = -1
var _catalog: Array[Dictionary] = []         # { id, cat, name, faction, level, price, weapon, kit }

# --- Onglets ---
var _pages: Array[Control] = []
var _page: int = Page.LAUNCH
var _top := TopBar.new()
var _launch := LaunchPage.new()
var _loadout_page: LoadoutPage
var _arsenal := ArsenalPage.new()
var _factions := FactionsPage.new()
var _squad := SquadPage.new()

var _ready_players: Dictionary = {}
var _refresh_left: float = 0.0


func setup(player: Player) -> void:
	_player = player
	_world = player.get_parent().get_parent()
	layer = 9  # au-dessus du HUD et de la carte, sous la boutique et les menus (admin)
	visible = false
	var default_shop := ProfileManager.default_shop()
	_shop_weapons = Sync.padded(default_shop["weapons"], Config.SHOP_WEAPON_SLOTS)
	_shop_gadgets = Sync.padded(default_shop["gadgets"], Config.SHOP_GADGET_SLOTS)
	_catalog = Catalog.build()
	_build()
	_show_page(Page.LAUNCH)
	Events.match_clock_synced.connect(_on_clock)
	Events.lobby_synced.connect(func(ready: Dictionary) -> void: _ready_players = ready)
	Events.local_loadout_received.connect(_apply_saved)
	Events.match_clock_requested.emit()
	# Sur l'hôte, le profil peut être arrivé avant la création de cet écran.
	var profiles := _world.get_node_or_null("ProfileManager") as ProfileManager
	if profiles and not profiles.local_loadout.is_empty():
		_apply_saved(profiles.local_loadout)


func _on_clock(_elapsed: float, phase: int) -> void:
	var lobby := phase == MatchManager.Phase.LOBBY
	if lobby == visible:
		return
	visible = lobby
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if lobby else Input.MOUSE_MODE_CAPTURED
	if lobby:
		_set_ready(false, false)
		_show_page(Page.LAUNCH)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:  # pas de tir ; les touches (menus) passent
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _send_left >= 0.0:
		_send_left -= delta
		if _send_left < 0.0:
			_send()
	if not visible:
		return
	var total := _player.get_parent().get_child_count()
	var ready := _ready_count()
	_top.countdown.text = "PRÊTS  %d / %d" % [ready, total]
	_launch.update_clock(ready, total)
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.5
		_refresh()


func _me() -> int:
	return _player.get_peer_id()


func _ready_count() -> int:
	var n := 0
	for peer: int in _ready_players:
		if _ready_players[peer]:
			n += 1
	return n


func _set_ready(on: bool, send: bool) -> void:
	for button in [_top.ready_button, _launch.ready_button]:
		(button as Button).set_pressed_no_signal(on)
		(button as Button).text = "PRÊT ✔" if on else "PRÊT"
	if send:
		var match_manager := _world.get_node_or_null("MatchManager") as MatchManager
		if match_manager:
			match_manager.request_lobby_ready.rpc_id(1, on)


# --- État : chargement, envoi (voir lobby_ui_sync.gd) ---

func _apply_saved(loadout: Dictionary) -> void:
	Sync.apply_saved(self, loadout)


func _changed() -> void:
	_send_left = SEND_DELAY
	_arsenal.detail_key = ""
	_refresh()


func _send() -> void:
	Sync.send(self)


func _set_status(text: String, color: Color) -> void:
	_top.set_status(text, color)


# --- Accès partagés avec les onglets ---

func _unlocked(faction: int, level: int) -> bool:
	return ProfileManager.is_unlocked(_me(), faction, level)


func _lock_text(faction: int, level: int) -> String:
	return "" if _unlocked(faction, level) else "Verrouillé : " + FactionData.lock_text(faction, level)


func _rep_key() -> String:
	var parts: PackedStringArray = []
	for f in FactionData.all():
		parts.append(str(ProfileManager.rep_points(_me(), f.id)))
	return ",".join(parts)


func _kit_data(id: String) -> KitData:
	for e in _catalog:
		if e["cat"] == Cat.KIT and e["id"] == id:
			return e["kit"]
	return null


func _entry(id: String) -> Dictionary:
	for e in _catalog:
		if e["id"] == id:
			return e
	return {}


func _weapon_mod_option(weapon_id: String) -> OptionButton:
	return ArsenalActions.weapon_mod_option(self, weapon_id)


func _open_arsenal(cat: int) -> void:
	_arsenal.open(self, cat)


# --- Onglets : construction et rafraîchissement ---

func _refresh() -> void:
	if _top.countdown == null:
		return
	var squad := SquadManager.squad_of(_me())
	_top.squad_chip.text = "ESCOUADE %d/%d" % [SquadManager.members_of(squad).size() if squad != 0 else 1, Config.SQUAD_MAX]
	match _page:
		Page.LAUNCH:
			_launch.refresh(self)
		Page.LOADOUT:
			_loadout_page.refresh()
		Page.ARSENAL:
			_arsenal.refresh(self)
		Page.FACTIONS:
			_factions.refresh(self)
		Page.SQUAD:
			_squad.refresh(self)


func _build() -> void:
	var bg := UiStyle.make_lobby_background()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.theme = UiStyle.theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_top.build(self))
	var line := ColorRect.new()
	line.color = ACCENT.darkened(0.4)
	line.custom_minimum_size = Vector2(0, 2)
	root.add_child(line)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	root.add_child(margin)
	var stack := Control.new()
	margin.add_child(stack)
	_loadout_page = LoadoutPage.new()
	_loadout_page.setup(self)
	var builders: Array[Callable] = [_launch.build.bind(self), func() -> Control: return _loadout_page,
			_arsenal.build.bind(self), _factions.build.bind(self), _squad.build]
	for builder in builders:
		var page: Control = builder.call()
		stack.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pages.append(page)


func _show_page(page: int) -> void:
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
	_top.style_nav(page)
	if page == Page.ARSENAL:
		_arsenal.rebuild_grid(self)
	if page == Page.LOADOUT and _loadout_page:
		_loadout_page.show_overview()
	_launch.key = ""
	_squad.key = ""
	_refresh()
