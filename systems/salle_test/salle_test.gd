class_name SalleTest
extends Node3D
## Salle de test (Niveaux.SALLE_TEST) : grande plateforme hors de la carte, construite sur chaque peer
## (décor local). Zones : armurerie (armes, gadgets, capacités, objets au sol), bestiaire (monstres
## figés), galerie (textures du sol, modèles du décor), téléporteur de retour au lobby.
## Le serveur y entretient les objets et les monstres (salle_test_stock.gd).
## Coordonnées locales : sol à y = 0, centre (0, 0) = point d'arrivée.

const Build := preload("res://systems/briefing/briefing_room_build.gd")
const Plan := preload("res://systems/salle_test/salle_test_plan.gd")
const Galerie := preload("res://systems/salle_test/salle_test_galerie.gd")
const Stock := preload("res://systems/salle_test/salle_test_stock.gd")
const Sortie := preload("res://systems/salle_test/salle_test_sortie.gd")

const ORIGIN := Vector3(0, 80, 420)       ## loin de la carte (au sud, en hauteur)
const SOL_MIN := Vector2(-72, -62)        ## coin du sol (x, z)
const SOL_MAX := Vector2(72, 104)
const COULEUR_SOL := Color(0.2, 0.22, 0.25)
const COULEUR_ZONE := Color(0.13, 0.15, 0.18)
const COULEUR_BORD := Color(0.35, 0.85, 1.0)


static func spawn_point(index: int) -> Vector3:
	return ORIGIN + Vector3(-6.0 + (index % 5) * 3.0, 1.0, 2.0)


func _ready() -> void:
	position = ORIGIN
	var taille := SOL_MAX - SOL_MIN
	var centre := (SOL_MIN + SOL_MAX) / 2.0
	Build.box(self, Vector3(taille.x, 1.0, taille.y), Vector3(centre.x, -0.5, centre.y), Build.material(COULEUR_SOL, 0.2, 0.8))
	_bordures(taille, centre)
	for zone: Array in Plan.zones():
		var r: Rect2 = zone[1]
		Build.box(self, Vector3(r.size.x, 0.04, r.size.y), Vector3(r.get_center().x, 0.02, r.get_center().y), Build.material(COULEUR_ZONE, 0.1, 0.9), false)
		_texte(zone[0], Vector3(r.position.x + 1.0, 4.0, r.position.y - 0.5), 260, Color.WHITE, false)
	for etiquette: Array in Plan.etiquettes():
		_texte(etiquette[0], etiquette[1], 72, Color(0.75, 0.85, 0.95), false)
	var sortie := Sortie.new()
	sortie.name = "Sortie"
	sortie.position = Plan.SORTIE
	add_child(sortie)
	if DisplayServer.get_name() != "headless":
		Galerie.build(self)
	if multiplayer.is_server():
		var stock := Stock.new()
		stock.name = "Stock"
		add_child(stock)


## Murets lumineux autour du sol (on ne tombe pas par accident).
func _bordures(taille: Vector2, centre: Vector2) -> void:
	var mat := Build.material(COULEUR_BORD, 0.0, 0.5, COULEUR_BORD, 1.5)
	for cote in [-1.0, 1.0]:
		Build.box(self, Vector3(taille.x, 1.2, 0.4), Vector3(centre.x, 0.6, centre.y + cote * taille.y / 2.0), mat)
		Build.box(self, Vector3(0.4, 1.2, taille.y), Vector3(centre.x + cote * taille.x / 2.0, 0.6, centre.y), mat)


## Texte 3D (titre de zone, nom d'un objet). `face` : tourné vers la caméra.
func _texte(texte: String, pos: Vector3, taille: int, couleur: Color, face: bool) -> void:
	var label := Label3D.new()
	label.text = texte
	label.font_size = taille
	label.outline_size = 12
	label.modulate = couleur
	label.pixel_size = 0.01
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if face else BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = pos
	add_child(label)
