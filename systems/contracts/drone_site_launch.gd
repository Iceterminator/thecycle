extends RefCounted
## Décollage du porteur du contrat « Sauvetage de drones » (serveur) : démarrage, vagues, issue.

const DroneSiteWaves := preload("res://systems/contracts/drone_site_waves.gd")


## Un drone vient d'être relancé ou détruit : les monstres changent de cible, et si plus aucun
## drone n'est utilisable, le décollage commence (ou le contrat échoue si tous sont détruits).
static func after_drone_change(site: DroneSite, peer_id: int) -> void:
	if not site.alive_drone_parts().is_empty():
		DroneSiteWaves.retarget(site)
	elif site.sent_mask == 0:
		DroneSiteWaves.clear(site)
		site.announce("Tous les drones ont été détruits")
		site.finish()
	else:
		start(site, peer_id)


static func start(site: DroneSite, peer_id: int) -> void:
	site.state = DroneSite.State.LAUNCH
	site.time_left = site.data.launch_time
	site.waves_spawned = 0
	site.launcher_id = peer_id
	DroneSiteWaves.retarget(site)
	site.announce("%s déclenche le décollage du porteur" % ContractSite.player_name(peer_id))
	DroneSiteWaves.warn_others(site, peer_id, "Empêchez le décollage !")


static func tick(site: DroneSite, delta: float) -> void:
	site.time_left = maxf(site.time_left - delta, 0.0)
	DroneSiteWaves.spawn_due_waves(site)
	if site.time_left > 0.0:
		return
	DroneSiteWaves.clear(site)
	var launcher := site.find_player(site.launcher_id)
	if launcher:
		launcher.score.add_contract_fame(site.data.launch_fame, site.data.faction, true, ContractBoard.is_active(launcher.get_peer_id(), site.data.track))
	site.announce("Le porteur a décollé !")
	site.finish()


## Le porteur est détruit : le décollage échoue, sans récompense.
static func carrier_destroyed(site: DroneSite) -> void:
	DroneSiteWaves.clear(site)
	site.announce("Le porteur a été détruit")
	site.finish()
