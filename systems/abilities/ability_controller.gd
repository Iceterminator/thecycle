class_name AbilityController
extends Node
## Emplacements Q et F du joueur (étapes 8c et 9) : chacun contient une capacité OU un gadget.
## On commence sans rien : capacités et gadgets s'achètent en boutique, puis attendent (« pending »)
## que le joueur appuie sur Q ou F pour les y mettre (remplace l'ancien contenu). Racheter une
## capacité équipée l'améliore (-recharge, 2 fois max) ; racheter un gadget équipé le recharge.
## À la mort, Q et F sont vidés. Un gadget sur Q / F vit dans l'inventaire (emplacements 2 et 3) :
## la touche le prend en main (ou rend l'arme), le clic l'utilise. Créé en code par le Player sur
## tous les peers (nœud « Abilities », autorité serveur ; AbilitySync envoie l'état).
##
## Client propriétaire : Q / F -> assigner l'achat en attente, prendre le gadget, ou
## request_use(emplacement, origine et direction de visée) pour une capacité.
## Serveur : vérifie (vivant, pas embarqué, recharge), applique selon la catégorie :
## - stim / camouflage / bouclier / soin : effet sur soi (BuffController) ;
## - grenade / sphère : objet lancé en arc ; tourelle, barrières, frappes, bombe, portail,
##   balise : objets réseau créés par l'AbilityManager (Events.ability_object_requested) ;
## - piège (Entrave) : ralentit la première cible visée.

const Activation := preload("res://systems/abilities/ability_controller_activation.gd")
const InputHandler := preload("res://systems/abilities/ability_controller_input.gd")
const Status := preload("res://systems/abilities/ability_controller_status.gd")
const Slots := preload("res://systems/abilities/ability_controller_slots.gd")
const Catalog := preload("res://systems/abilities/ability_controller_catalog.gd")

const ABILITIES_DIR := Catalog.ABILITIES_DIR
const SLOTS := 2

## Synchronisés (serveur -> tous).
var loadout: PackedStringArray = PackedStringArray(["", ""])
var upgrades: PackedInt32Array = PackedInt32Array([0, 0])
var cooldown_left: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
## Capacité ou gadget acheté, en attente d'être mis sur Q ou F ("" = rien).
var pending: String = ""

var player: Player
var _input: InputHandler
var _activation: Activation
var _slots: Slots


func _init() -> void:
	Slots.build_sync(self)


func _ready() -> void:
	player = get_parent() as Player
	player = get_parent() as Player
	_input = InputHandler.new(self)
	_activation = Activation.new(self)
	_slots = Slots.new(self)
	set_physics_process(multiplayer.is_server())
	set_process(player.is_multiplayer_authority())
	if multiplayer.is_server():
		Events.match_reset_requested.connect(server_reset)
		player.health.dead_changed.connect(func(dead: bool) -> void:
			if dead:
				server_reset())


static func get_ability(id: String) -> AbilityData:
	return Catalog.get_ability(id)


static func list_abilities() -> Array[AbilityData]:
	return Catalog.list_abilities()


## Un gadget (objet arme de type gadget) ?
static func is_gadget(id: String) -> bool:
	return Catalog.is_gadget(id)


## Capacité de l'emplacement (null si vide ou si c'est un gadget).
func get_slot(slot: int) -> AbilityData:
	return get_ability(loadout[slot]) if slot >= 0 and slot < SLOTS else null


## Texte du HUD : « [Q] Grenade à choc : prête   [F] Grenade ×2 ».
func status_text() -> String:
	return Status.build(self)


# --- Client propriétaire ---

func _process(_delta: float) -> void:
	_input.update()


# --- Serveur ---

func _physics_process(delta: float) -> void:
	var changed := false
	var left := cooldown_left.duplicate()
	for slot in SLOTS:
		if left[slot] > 0.0:
			left[slot] = maxf(left[slot] - delta, 0.0)
			changed = true
	if changed:
		cooldown_left = left


func _sender_ok() -> bool:
	return multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_peer_id()


## Serveur : un achat (ou un gadget ramassé) attend Q ou F. Renvoie la raison d'un refus, ou "".
func server_offer(id: String) -> String:
	if pending != "":
		return "Équipez d'abord %s (Q ou F)" % Shop.entry_name(pending)
	if get_ability(id) == null and not is_gadget(id):
		return "Objet inconnu"
	pending = id
	return ""


## Q ou F pressée avec un achat en attente : il prend cet emplacement (remplace l'ancien).
@rpc("any_peer", "call_local", "reliable")
func request_assign(slot: int) -> void:
	if not _sender_ok() or slot < 0 or slot >= SLOTS or pending == "" or player.health.is_dead:
		return
	var id := pending
	pending = ""
	_slots.drop_slot(slot)  # l'ancien contenu tombe au sol
	server_set_slot(slot, id)
	player.score.notify.rpc_id(player.get_peer_id(), "%s équipé sur %s" % [Shop.entry_name(id), ["Q", "F"][slot]], Color(0.6, 1.0, 0.6))


## Serveur : met une capacité ou un gadget sur Q (0) / F (1), à la place de l'ancien contenu.
## Si c'était déjà sur l'autre emplacement, il quitte l'autre (menu admin).
func server_set_slot(slot: int, id: String) -> bool:
	return _slots.set_slot(slot, id)


## Serveur : vide Q (0) ou F (1) (gadget épuisé, remplacement, mort).
func server_clear_slot(slot: int) -> void:
	_slots.clear_slot(slot)


## Serveur (boutique, déjà payé) : améliore la capacité de l'emplacement.
func server_upgrade(slot: int) -> void:
	_slots.upgrade(slot)


## Serveur : nouvelle partie ou mort : Q et F vides, plus d'achat en attente.
func server_reset() -> void:
	_slots.reset()


func server_reset_cooldowns() -> void:
	cooldown_left = PackedFloat32Array([0.0, 0.0])


@rpc("any_peer", "call_local", "reliable")
func request_use(slot: int, origin: Vector3, direction: Vector3) -> void:
	if not _sender_ok() or slot < 0 or slot >= SLOTS:
		return
	if player.health.is_dead or player.health.is_downed or player.is_evacuated or player.is_dropping() or cooldown_left[slot] > 0.0:
		return
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.01:
		return
	if origin.distance_to(player.camera.global_position) > Config.SHOT_ORIGIN_TOLERANCE:
		return
	var ability := get_slot(slot)
	if ability == null:
		return
	direction = direction.normalized()
	if not _server_activate(ability, origin, direction):
		return
	var left := cooldown_left.duplicate()
	left[slot] = ability.get_cooldown(upgrades[slot], player.kit.get_effect("ability_cooldown_mult"), player.kit.get_effect("ability_cooldown_add"))
	cooldown_left = left
	print("[Capacité] Joueur %d : %s" % [player.get_peer_id(), ability.get_display_name()])


## Applique la capacité. Renvoie false si elle n'a pas pu partir (pas de cible…).
func _server_activate(a: AbilityData, origin: Vector3, dir: Vector3) -> bool:
	return _activation.activate(a, origin, dir)
