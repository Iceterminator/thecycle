extends RefCounted
## Réactions d'état du joueur (mort, à terre, évacuation) et lecture de son équipement de profil.
## Fonctions statiques appelées par Player, qui garde les RPC, les signaux et les propriétés.


## Mod d'arme choisi par ce joueur pour cette arme (lobby, étape 9), ou null.
static func weapon_mod(p: Player, wdata: WeaponData) -> WeaponModData:
	if wdata == null:
		return null
	return WeaponModData.get_mod(String(ProfileManager.weapon_mods(p.get_peer_id()).get(String(wdata.id), "")))


## Taille de chargeur de cette arme pour ce joueur (mod « chargeur étendu » compris).
static func magazine_for(p: Player, wdata: WeaponData) -> int:
	if wdata == null:
		return 0
	var mod := weapon_mod(p, wdata)
	return maxi(roundi(wdata.magazine * (mod.magazine_mult if mod else 1.0)), 1)


## À terre : un allié peut nous relever (interaction E maintenue) ; tous les peers.
static func on_downed_changed(downed: bool, p: Player) -> void:
	if downed:
		p.add_to_group("downed_players")
		p.add_to_group("interactable")
	else:
		p.remove_from_group("downed_players")
		p.remove_from_group("interactable")


## Un mort ne bloque pas les tirs ; son corps reste visible (animation de mort) jusqu'à la réapparition.
static func on_dead_changed(dead: bool, p: Player) -> void:
	p.collision.set_deferred("disabled", dead)
	p.body_mesh.visible = not p.is_multiplayer_authority()
	if p.is_multiplayer_authority():
		p.velocity = Vector3.ZERO
		p.set_physics_process(not dead)


## Embarquement (spectateur) ou retour au jeu ; le garde « serveur » reste dans Player.set_evacuated.
static func apply_evacuated(p: Player, value: bool) -> void:
	p.is_evacuated = value
	p.collision.set_deferred("disabled", value or p.health.is_dead)
	p.body_mesh.visible = not value and not p.health.is_dead and not p.is_multiplayer_authority()
	if p.is_multiplayer_authority():
		p.velocity = Vector3.ZERO
		p.is_crouching = false
		if value:
			p.global_position += Vector3.UP * Player.SPECTATOR_LIFT
	p.evacuated_changed.emit(value)


## Interaction (relever) : texte, seulement pour un allié et seulement si `p` est à terre.
static func revive_prompt(p: Player, viewer: Player) -> String:
	if not p.health.is_downed or viewer == p or not Allies.can_revive(viewer.get_peer_id(), p.get_peer_id()):
		return ""
	return "Maintenir E : relever %s" % ProfileManager.name_of(p.get_peer_id())


## Serveur : `viewer` relève `p` (ni lui ni l'allié ne doivent être trahis par un état périmé).
static func revive(p: Player, viewer: Player) -> void:
	if p.health.is_downed and Allies.can_revive(viewer.get_peer_id(), p.get_peer_id()) and not viewer.health.is_downed:
		p.health.server_revive_downed(viewer.get_peer_id())
