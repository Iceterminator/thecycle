class_name Pickup
extends Area3D
## Objet au sol (arme, ressource, crédits). Créé par le serveur via le
## LootSpawner (spawn_function de LootManager) : ses données arrivent à la création
## et ne changent plus. Ramasser = le serveur le supprime, le spawner le retire partout.
## Couche de collision 4 (« interaction ») : ne bloque ni les joueurs ni les balles.

var item: ItemData
var amount: int = 1
var ammo: int = -1  ## chargeur restant pour une arme lâchée (-1 = plein)

const GROUND_MODEL_SCALE := 1.6  ## modèle d'arme au sol, agrandi pour bien se voir

var _taken: bool = false
var _visual: Node3D  ## ce qui tourne : modèle 3D de l'arme, ou forme simple


func setup(item_data: ItemData, item_amount: int, item_ammo: int) -> void:
	item = item_data
	amount = item_amount
	ammo = item_ammo


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 3
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	add_child(shape)
	_build_visual()
	if multiplayer.is_server():
		get_tree().create_timer(Config.PICKUP_LIFETIME).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_visual.rotate_y(1.5 * delta)


func get_prompt(player: Player) -> String:
	var inv := player.inventory
	match item.kind:
		ItemData.Kind.WEAPON:
			if item.weapon and item.weapon.gadget != WeaponData.GadgetKind.NONE:
				return "E : Ramasser %s (puis Q ou F)" % item.display_name
			if inv.slot_ids.slice(0, Inventory.WEAPON_SLOTS).has(""):
				return "E : Ramasser %s   (1 / 2 : choisir l'emplacement)" % item.display_name
			return "Maintenir E / 1 / 2 : remplacer par %s" % item.display_name
		ItemData.Kind.ABILITY:
			return "E : Ramasser la capacité %s (puis Q ou F)" % item.display_name
		ItemData.Kind.CREDITS:
			return "E : Ramasser %d crédits" % amount
		ItemData.Kind.RESOURCE:
			if item.max_carry > 0 and inv.get_resource(item.id) >= item.max_carry:
				return "%s : vous en portez déjà le maximum" % item.display_name
			return "E : Ramasser %d %s" % [amount, item.display_name]
		ItemData.Kind.SHIELD_UPGRADE:
			return "%s : plus utilisé (le bouclier vient du kit)" % item.display_name
	return "E : Ramasser %s" % item.display_name


## Maintien de E (s) : seulement pour remplacer une arme quand les 2 emplacements sont pris.
func get_hold_time(player: Player) -> float:
	if WeaponPickup.is_weapon_pickup(self) and player.inventory.slot_ids[WeaponPickup.slot_for_e(player.inventory)] != "":
		return Config.economy.weapon_replace_hold_time
	return 0.0


func is_taken() -> bool:
	return _taken


## Serveur uniquement (appelé par Interactor après vérification de distance et de maintien).
func server_interact(player: Player) -> void:
	if _taken:
		return
	if player.inventory.server_take(item, amount, ammo):
		_taken = true
		Events.item_picked_up.emit(player.get_peer_id(), item.id, amount)
		queue_free()


## Serveur uniquement (WeaponPickup, touches 1 / 2) : prend l'arme dans l'emplacement demandé.
func server_take_into(player: Player, slot: int) -> void:
	if _taken:
		return
	_taken = true
	player.weapon_pickup.server_take(item, amount, ammo, slot)
	Events.item_picked_up.emit(player.get_peer_id(), item.id, amount)
	queue_free()


## Arme avec un modèle 3D : le modèle (un peu agrandi pour bien se voir au sol, avec son
## ombre). Sinon une forme simple de la couleur de l'objet.
func _build_visual() -> void:
	if item.kind == ItemData.Kind.WEAPON and item.weapon and item.weapon.model:
		_visual = WeaponModel.build(item.weapon)
		_visual.scale = Vector3.ONE * GROUND_MODEL_SCALE
		for node in _visual.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_visual.position.y = 0.35
		add_child(_visual)
		_add_label()
		return
	var mesh := MeshInstance3D.new()
	_visual = mesh
	if item.kind == ItemData.Kind.WEAPON:
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.18, 0.18)
		mesh.mesh = box
	elif item.kind == ItemData.Kind.ABILITY:  # capacité : cristal de données (prisme)
		var prism := PrismMesh.new()
		prism.size = Vector3(0.32, 0.4, 0.32)
		mesh.mesh = prism
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.color
	mat.emission_enabled = true
	mat.emission = item.color * 0.4
	mesh.material_override = mat
	mesh.position.y = 0.3
	add_child(mesh)
	_add_label()


func _add_label() -> void:
	var label := Label3D.new()
	label.text = "%d crédits" % amount if item.kind == ItemData.Kind.CREDITS else item.display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = 0.004
	label.position.y = 0.75
	add_child(label)
