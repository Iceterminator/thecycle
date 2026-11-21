extends RefCounted
## Construction en code des composants du joueur (appelée par Player._ready, même ordre qu'avant) :
## admin, kit, mouvement, buffs, capacités, largage, arme tenue, avatar, balise, interface locale.

const HUD_SCRIPT := preload("res://systems/combat/hud.gd")
const ADMIN_SCRIPT := preload("res://systems/admin/admin.gd")
const MAP_OVERLAY_SCRIPT := preload("res://systems/map/map_overlay.gd")
const KIT_SCRIPT := preload("res://systems/kits/kit_controller.gd")
const MOVEMENT_SCRIPT := preload("res://systems/kits/kit_movement.gd")
const BUFFS_SCRIPT := preload("res://systems/abilities/buff_controller.gd")
const ABILITIES_SCRIPT := preload("res://systems/abilities/ability_controller.gd")
const PACT_UI_SCRIPT := preload("res://systems/pacts/pact_ui.gd")
const PAUSE_MENU_SCRIPT := preload("res://systems/settings/pause_menu.gd")
const LOBBY_UI_SCRIPT := preload("res://systems/lobby/lobby_ui.gd")
const DROP_POD_SCRIPT := preload("res://systems/match/drop_pod_ride.gd")


## Composants communs à tous les peers (admin, kit, mouvement, buffs, capacités, largage, arme, avatar, balise).
static func build_components(p: Player, is_local: bool) -> void:
	p.admin = ADMIN_SCRIPT.new()
	p.admin.name = "Admin"
	p.add_child(p.admin)
	p.kit = KIT_SCRIPT.new()
	p.kit.name = "Kit"
	p.kit.set_multiplayer_authority(1)  # le serveur décide du kit, du niveau et de l'XP
	p.add_child(p.kit)
	p.movement = MOVEMENT_SCRIPT.new()
	p.movement.name = "Movement"
	p.add_child(p.movement)
	p.buffs = BUFFS_SCRIPT.new()
	p.buffs.name = "Buffs"
	p.buffs.set_multiplayer_authority(1)
	p.add_child(p.buffs)
	p.abilities = ABILITIES_SCRIPT.new()
	p.abilities.name = "Abilities"
	p.abilities.set_multiplayer_authority(1)
	p.add_child(p.abilities)
	p.drop = DROP_POD_SCRIPT.new()
	p.drop.name = "Drop"
	p.drop.set_multiplayer_authority(1)
	p.add_child(p.drop)
	# Arme tenue en main (modèle 3D), visible par tous : à la première personne pour le joueur local.
	p.held_weapon = WeaponModel.new()
	p.held_weapon.name = "HeldWeapon"
	p.head.add_child(p.held_weapon)
	p.held_weapon.setup(p)
	# Corps animé, pour les autres joueurs seulement (le joueur local ne voit pas son corps).
	if not is_local and not Net.is_dedicated_server:
		p.avatar = PlayerAvatar.new()
		p.avatar.name = "Avatar"
		p.body_mesh.add_child(p.avatar)
		p.avatar.setup(p, p.body_mesh)
	if not is_local:
		_build_beacon(p)


## Interface du joueur local : HUD, carte, profil, pactes, lobby, écran de largage.
static func build_local_ui(p: Player) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var hud: CombatHud = HUD_SCRIPT.new()
	p.add_child(hud)
	hud.setup(p)
	var map_overlay: MapOverlay = MAP_OVERLAY_SCRIPT.new()
	map_overlay.name = "MapOverlay"
	p.add_child(map_overlay)
	map_overlay.setup(p)
	# Profil : le serveur charge réputation et équipement de ce pseudo.
	var profiles := p.get_parent().get_parent().get_node_or_null("ProfileManager")
	if profiles:
		profiles.request_register.rpc_id(1, Net.player_name)
	var contract_ui: ContractUi = ContractUi.new()
	contract_ui.name = "ContractUi"
	p.add_child(contract_ui)
	contract_ui.setup(p)
	var pact_ui: PactUi = PACT_UI_SCRIPT.new()
	pact_ui.name = "PactUi"
	p.add_child(pact_ui)
	pact_ui.setup(p)
	var pause_menu: PauseMenu = PAUSE_MENU_SCRIPT.new()
	pause_menu.name = "PauseMenu"
	p.add_child(pause_menu)
	pause_menu.setup(p)
	var lobby_ui: LobbyUi = LOBBY_UI_SCRIPT.new()
	lobby_ui.name = "LobbyUi"
	p.add_child(lobby_ui)
	lobby_ui.setup(p)


## Balise au-dessus des AUTRES joueurs, visible de loin et à travers le décor,
## quand leur Score.beacon n'est pas vide.
static func _build_beacon(p: Player) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0009
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(1, 0.85, 0.2)
	label.position.y = 2.4
	p.add_child(label)
	var refresh := func() -> void:
		label.text = p.score.beacon
		label.visible = p.score.beacon != "" and not p.health.is_dead
	p.score.changed.connect(refresh)
	p.health.dead_changed.connect(func(_d: bool) -> void: refresh.call())
	refresh.call()
