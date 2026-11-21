class_name LobbyUi
extends CanvasLayer
## Écran du lobby (étape 9, joueur local) : phase LOBBY du MatchManager, et BRIEFING tant que le
## joueur n'est pas dans la salle. Barre du haut : escouade, onglets, pseudo, compteur, PRÊT. Onglets :
## Décollage (joueurs prêts, résumé), Équipement (LoadoutPage : départ + boutique, fiche, sélecteur), Arsenal
## (catégories, filtres, cartes par niveau de faction, fiche, actions), Factions, Escouade. Chaque
## changement est envoyé au serveur (ProfileManager.request_set_loadout), qui vérifie tout.
## Ce script orchestre ; un onglet = lobby_ui_<onglet>.gd, plus top_bar, sync, catalog, widgets, build, access.

const Catalog := preload("res://systems/lobby/lobby_ui_catalog.gd")
const Sync := preload("res://systems/lobby/lobby_ui_sync.gd")
const TopBar := preload("res://systems/lobby/lobby_ui_top_bar.gd")
const LaunchPage := preload("res://systems/lobby/lobby_ui_launch.gd")
const ArsenalPage := preload("res://systems/lobby/lobby_ui_arsenal.gd")
const ArsenalActions := preload("res://systems/lobby/lobby_ui_arsenal_actions.gd")
const FactionsPage := preload("res://systems/lobby/lobby_ui_factions.gd")
const SquadPage := preload("res://systems/lobby/lobby_ui_squad.gd")
const Build := preload("res://systems/lobby/lobby_ui_build.gd")
const Access := preload("res://systems/lobby/lobby_ui_access.gd")

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
var _phase: int = MatchManager.Phase.LOBBY
var _world: Node

# --- État de l'équipement (envoyé au serveur) ---
var _preferred: int = 0
var _appearance: String = ""          # id de data/appearances/, "" = automatique
var _kit_id: String = String(Config.start_loadout.default_kit)
var _kit_mods: Dictionary = {}       # id de kit -> { "core" / "1" / "2" / "3" -> id de mod }
var _weapon_mods: Dictionary = {}    # id d'arme -> { emplacement (texte) -> id de mod }
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
	Build.build(self)
	_show_page(Page.LAUNCH)
	Events.match_clock_synced.connect(_on_clock)
	Events.lobby_synced.connect(func(ready: Dictionary) -> void:
		_ready_players = ready
		Access.on_clock(self, _phase))
	Events.local_loadout_received.connect(_apply_saved)
	Events.match_clock_requested.emit()
	# Sur l'hôte, le profil peut être arrivé avant la création de cet écran.
	var profiles := _world.get_node_or_null("ProfileManager") as ProfileManager
	if profiles and not profiles.local_loadout.is_empty():
		_apply_saved(profiles.local_loadout)


func _on_clock(_elapsed: float, phase: int) -> void:
	Access.on_clock(self, phase)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:  # pas de tir ; les touches (menus) passent
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _send_left >= 0.0:
		_send_left -= delta
		if _send_left < 0.0:
			_send()
	if visible:
		Access.update_clock(self, delta)


func _me() -> int:
	return _player.get_peer_id()


func _set_ready(on: bool, send: bool) -> void:
	Access.set_ready(self, on, send)


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
	return Access.unlocked(self, faction, level)


func _lock_text(faction: int, level: int) -> String:
	return "" if _unlocked(faction, level) else "Verrouillé : " + FactionData.lock_text(faction, level)


func _rep_key() -> String:
	return Access.rep_key(self)


func _kit_data(id: String) -> KitData:
	return Access.kit_data(_catalog, id)


func _entry(id: String) -> Dictionary:
	return Access.entry(_catalog, id)


func _weapon_mod_option(weapon_id: String) -> Control:
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
		Page.LAUNCH: _launch.refresh(self)
		Page.LOADOUT: _loadout_page.refresh()
		Page.ARSENAL: _arsenal.refresh(self)
		Page.FACTIONS: _factions.refresh(self)
		Page.SQUAD: _squad.refresh(self)


func _show_page(page: int) -> void:
	Access.show_page(self, page)
