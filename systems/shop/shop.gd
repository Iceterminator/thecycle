class_name Shop
extends Node
## Boutique du joueur (touche T) : armes et améliorations de bouclier contre des crédits.
## Client propriétaire : affiche l'interface (ShopUi) et DEMANDE un achat.
## Serveur : vérifie (propriétaire, vivant, objet en vente, crédits, palier de bouclier),
## débite, puis fait tomber une capsule de largage devant le joueur (LootManager).
## Ce qui est dans la capsule est un objet au sol normal : n'importe qui peut le prendre.

signal purchase_result(ok: bool, message: String)

const SHOP_UI_SCRIPT := preload("res://systems/shop/shop_ui.gd")

@onready var player: Player = get_parent()

var ui: ShopUi


func _ready() -> void:
	if player.is_multiplayer_authority():
		# Les @onready du Player (inventory, health…) ne sont prêts qu'après ses enfants.
		await player.ready
		ui = SHOP_UI_SCRIPT.new()
		add_child(ui)
		ui.setup(player, self)


## Côté client : vrai si l'objet peut être acheté maintenant (sinon, la raison).
func check_purchase(item: ItemData) -> String:
	if player.health.is_dead:
		return "Indisponible : vous êtes mort"
	if item.kind == ItemData.Kind.SHIELD_UPGRADE and player.health.shield_tier >= item.shield_tier:
		return "Déjà acquis"
	if player.inventory.credits < item.price:
		return "Pas assez de crédits"
	return ""


@rpc("any_peer", "call_local", "reliable")
func request_buy(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	var item := Items.get_item(StringName(item_id))
	if item == null or item.price <= 0:
		return
	var refusal := check_purchase(item)
	if refusal != "" or not player.inventory.spend_credits(item.price):
		_purchase_result.rpc_id(player.get_peer_id(), false, refusal if refusal != "" else "Pas assez de crédits")
		return
	var forward := -player.global_basis.z
	forward.y = 0.0
	var pos := player.global_position + forward.normalized() * Config.DROP_POD_DISTANCE
	Events.item_purchased.emit(player.get_peer_id(), item.id, item.price)
	Events.drop_pod_requested.emit(item.id, pos)
	print("[Boutique] Joueur %d achète %s (%d crédits)" % [player.get_peer_id(), item.id, item.price])
	_purchase_result.rpc_id(player.get_peer_id(), true, "%s : largage en approche !" % item.display_name)


@rpc("any_peer", "call_local", "reliable")
func _purchase_result(ok: bool, message: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	purchase_result.emit(ok, message)
