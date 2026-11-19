class_name Crystal
extends StaticBody3D
## Quête « cristal + foreuse ». Créé par le serveur (QuestManager -> CrystalSpawner),
## construit en code à partir d'un CrystalData (facile / moyen / difficile).
##
## Déroulement (tout décidé par le SERVEUR) :
##   IDLE     : maintenir E 3 s -> la foreuse se déploie.
##   DEFENSE  : des vagues de monstres arrivent et attaquent la foreuse (PV de foreuse).
##              Il faut tuer tous les monstres de toutes les vagues.
##              Si la foreuse est détruite -> FAILED, puis retour à IDLE après un délai.
##   EXTRACT  : maintenir E 5 s -> points d'objectif « Forage » pour celui qui extrait.
##   DONE     : épuisé ; réapparaît après Config.match_rules.crystal_respawn_delay (tests).
##
## La foreuse n'est PAS dans le groupe "damageable" : les armes des joueurs ne la
## touchent pas, seuls les monstres (cible `objective`) l'abîment.

const CrystalVisual := preload("res://systems/quests/crystal_visual.gd")
const CrystalServer := preload("res://systems/quests/crystal_server.gd")

enum State { IDLE, DEFENSE, EXTRACT, DONE, FAILED }

const HIT_RADIUS := 1.3

var data: CrystalData

## Synchronisés (serveur -> clients) pour l'affichage.
var state: int = State.IDLE:
	set(value):
		state = value
		if is_node_ready():
			_update_look()
var drill_health: float = 0.0:
	set(value):
		drill_health = value
		if is_node_ready():
			_update_label()
var wave_index: int = 0           ## vague en cours (1 = première), 0 = pas commencé
var monsters_left: int = 0:
	set(value):
		monsters_left = value
		if is_node_ready():
			_update_label()
var next_wave_in: float = 0.0     ## compte à rebours avant la prochaine vague (s)

var _visual: CrystalVisual
var _server: CrystalServer


## Appelé par la spawn_function, sur tous les peers, avant l'entrée dans l'arbre.
func setup(crystal_data: CrystalData) -> void:
	data = crystal_data
	_visual = CrystalVisual.new(self)
	_server = CrystalServer.new(self)
	drill_health = data.drill_health
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.1
	cylinder.height = 2.6
	shape.shape = cylinder
	shape.position.y = 1.3
	add_child(shape)
	_build_visual()
	_build_sync()


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("map_marker")  # écran Tab (systems/map/)
	_update_look()
	set_physics_process(multiplayer.is_server())


func _process(delta: float) -> void:
	if state == State.DEFENSE:
		_visual.bit.rotate_y(6.0 * delta)
		if next_wave_in > 0.0:
			next_wave_in = maxf(next_wave_in - delta, 0.0)  # affichage local seulement
			_update_label()


# =========================================================================
# Interaction (Interactor)
# =========================================================================

func get_prompt(_player: Player) -> String:
	match state:
		State.IDLE:
			return "Maintenir E (%d s) : lancer la foreuse — %s %s (+%d pts de Forage)" % [
				int(Config.match_rules.crystal_activate_time), data.display_name, data.difficulty_name, data.objective_points]
		State.EXTRACT:
			return "Maintenir E (%d s) : extraire le cristal (+%d pts de Forage)" % [
				int(Config.match_rules.crystal_extract_time), data.objective_points]
	return ""


## Durée de maintien de E (0 = pas d'interaction possible).
func get_hold_time(_player: Player) -> float:
	match state:
		State.IDLE:
			return Config.match_rules.crystal_activate_time
		State.EXTRACT:
			return Config.match_rules.crystal_extract_time
	return 0.0


## Serveur (après un maintien de E validé par l'Interactor).
func server_interact(player: Player) -> void:
	match state:
		State.IDLE:
			_server.start_defense(player)
		State.EXTRACT:
			_server.complete(player)


# =========================================================================
# Cible des monstres de vague (Monster.objective)
# =========================================================================

func can_be_hit() -> bool:
	return state == State.DEFENSE and drill_health > 0.0


func get_hit_radius() -> float:
	return HIT_RADIUS



## Serveur : un monstre frappe la foreuse.
func server_receive_hit(amount: float, _attacker_id: int) -> bool:
	if not can_be_hit():
		return false
	drill_health = maxf(drill_health - amount, 0.0)
	if drill_health <= 0.0:
		_server.fail()
		return true
	return false


func register_wave_monster(monster: Monster) -> void:
	_server.register_wave_monster(monster)


func on_wave_monster_died(monster: Monster) -> void:
	_server.on_wave_monster_died(monster)


func _physics_process(delta: float) -> void:
	_server.physics_step(delta)


# =========================================================================
# Construction : synchro et visuels
# =========================================================================

func _build_sync() -> void:
	var config := SceneReplicationConfig.new()
	for key in [".:state", ".:drill_health", ".:wave_index", ".:monsters_left", ".:next_wave_in"]:
		var path := NodePath(key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "CrystalSync"
	sync.replication_config = config
	add_child(sync)


func _build_visual() -> void:
	_visual.build()


func _update_look() -> void:
	if _visual == null:
		return
	_visual.update_look()


func _update_label() -> void:
	if _visual == null:
		return
	_visual.update_label()


## Écran Tab : état du cristal (même texte que le texte flottant).
func map_info() -> Dictionary:
	var label := _visual.label if _visual else null
	var color: Color = label.modulate if label else data.color
	return {"text": label.text if label else data.display_name, "color": color, "kind": "crystal"}


## Texte flottant visible seulement de près (appelé par le HUD du joueur local).
func set_map_tag_visible(value: bool) -> void:
	if _visual and _visual.label:
		_visual.label.visible = value
