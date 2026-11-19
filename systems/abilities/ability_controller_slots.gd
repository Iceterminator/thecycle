extends RefCounted
## Gestion serveur des emplacements Q / F d'un AbilityController : équiper, vider,
## améliorer, réinitialiser. L'état synchronisé reste sur le contrôleur.

var c: AbilityController


func _init(controller: AbilityController) -> void:
	c = controller


## Serveur : met une capacité ou un gadget sur Q (0) / F (1), à la place de l'ancien contenu.
## Si c'était déjà sur l'autre emplacement, il quitte l'autre (menu admin).
func set_slot(slot: int, id: String) -> bool:
	if slot < 0 or slot >= AbilityController.SLOTS or (AbilityController.get_ability(id) == null and not AbilityController.is_gadget(id)):
		return false
	var other := 1 - slot
	if c.loadout[other] == id:
		clear_slot(other)
	clear_slot(slot)
	var l := c.loadout.duplicate()
	l[slot] = id
	c.loadout = l
	if AbilityController.is_gadget(id):
		c.player.inventory.server_set_gadget(slot, StringName(id))
	return true


## Serveur : vide Q (0) ou F (1) (gadget épuisé, remplacement, mort).
func clear_slot(slot: int) -> void:
	if AbilityController.is_gadget(c.loadout[slot]):
		c.player.inventory.server_clear_gadget(slot)
	var l := c.loadout.duplicate()
	l[slot] = ""
	c.loadout = l
	var up := c.upgrades.duplicate()
	up[slot] = 0
	c.upgrades = up
	var left := c.cooldown_left.duplicate()
	left[slot] = 0.0
	c.cooldown_left = left


## Serveur (boutique, déjà payé) : améliore la capacité de l'emplacement.
func upgrade(slot: int) -> void:
	if slot < 0 or slot >= AbilityController.SLOTS or c.get_slot(slot) == null:
		return
	var up := c.upgrades.duplicate()
	up[slot] = mini(up[slot] + 1, Config.economy.ability_max_upgrades)
	c.upgrades = up


## Serveur : nouvelle partie ou mort : Q et F vides, plus d'achat en attente.
func reset() -> void:
	for slot in AbilityController.SLOTS:
		clear_slot(slot)
	c.pending = ""




## AbilitySync : réplique l'état du contrôleur (loadout, upgrades, cooldown_left, pending).
static func build_sync(controller: Node) -> void:
	var config := SceneReplicationConfig.new()
	for key in ["loadout", "upgrades", "cooldown_left", "pending"]:
		var path := NodePath(".:" + key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "AbilitySync"
	sync.replication_config = config
	controller.add_child(sync)
