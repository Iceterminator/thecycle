extends RefCounted
## Effets visuels réutilisables des armes (fonctions statiques, chez les clients) : traçant lumineux
## qui file vers l'impact, flash de bouche en étoile, poussière d'impact, explosion (boule de feu,
## éclair de lumière, fumée qui reste, débris). Couleurs « lumineuses » au-dessus de 1 : le glow
## de l'environnement les fait briller.

const VITESSE_TRACANT := 320.0  ## m/s : le trait file du canon vers l'impact
const LONGUEUR_TRACANT := 6.0   ## m : longueur max du trait lumineux

static var _mats: Dictionary = {}
static var _rond: GradientTexture2D


## Tache ronde et floue (bord transparent) : forme des plaques de particules.
static func rond() -> GradientTexture2D:
	if _rond == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.65))
		_rond = GradientTexture2D.new()
		_rond.gradient = g
		_rond.fill = GradientTexture2D.FILL_RADIAL
		_rond.fill_from = Vector2(0.5, 0.5)
		_rond.fill_to = Vector2(0.5, 0.0)
		_rond.width = 64
		_rond.height = 64
	return _rond


## Matériau additif (lumière) ou transparent (fumée, poussière), couleur par particule possible.
static func mat(color: Color, additif: bool, energie: float = 1.0) -> StandardMaterial3D:
	var cle := [color, additif, energie]
	if not _mats.has(cle):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additif else BaseMaterial3D.BLEND_MODE_MIX
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(color.r * energie, color.g * energie, color.b * energie, color.a)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = rond()
		_mats[cle] = m
	return _mats[cle]


## Traçant : un trait lumineux qui part du canon et file jusqu'à l'impact, puis s'éteint.
static func tracant(world: Node3D, from: Vector3, to: Vector3, color: Color, largeur: float) -> void:
	var dist := from.distance_to(to)
	if dist < 0.1:
		return
	var long := minf(LONGUEUR_TRACANT, dist)
	var ligne := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(largeur, largeur, long)
	ligne.mesh = box
	var m := mat(color, true, 3.0).duplicate() as StandardMaterial3D
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.vertex_color_use_as_albedo = false
	m.albedo_texture = null
	ligne.material_override = m
	ligne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ligne)
	var dir := (to - from) / dist
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	ligne.look_at_from_position(from + dir * long / 2.0, to, up)
	var duree := maxf((dist - long) / VITESSE_TRACANT, 0.01)
	var tween := ligne.create_tween()
	tween.tween_property(ligne, "global_position", to - dir * long / 2.0, duree)
	tween.tween_property(m, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(ligne.queue_free)


## Flash de bouche : petite étoile lumineuse (plaques croisées) pendant une image ou deux.
static func flash(world: Node3D, pos: Vector3, color: Color, echelle: float, tree: SceneTree) -> void:
	var p := particules(world, pos, 4, 0.05, mat(color.lightened(0.4), true, 4.0), 0.22 * echelle)
	p.initial_velocity_max = 0.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.angle_max = 360.0
	var lumiere := OmniLight3D.new()
	lumiere.light_color = color.lightened(0.5)
	lumiere.light_energy = 2.5 * echelle
	lumiere.omni_range = 4.0
	world.add_child(lumiere)
	lumiere.global_position = pos
	tree.create_timer(0.06).timeout.connect(lumiere.queue_free)


## Bouffée de particules (plaques face caméra) qui s'efface ; libérée à la fin.
static func particules(world: Node3D, pos: Vector3, nombre: int, vie: float, m: Material, taille: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = nombre
	p.lifetime = vie
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * taille
	p.mesh = quad
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gravity = Vector3.ZERO
	var fondu := Gradient.new()
	fondu.set_color(0, Color(1, 1, 1, 1))
	fondu.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fondu
	p.finished.connect(p.queue_free)
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


## Poussière d'impact : quelques bouffées grises qui gonflent et retombent (sol, rochers).
static func poussiere(world: Node3D, pos: Vector3, echelle: float) -> void:
	var p := particules(world, pos, 6, 0.9, mat(Color(0.62, 0.57, 0.5, 0.55), false), 0.35 * echelle)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.8
	var gonfle := Curve.new()
	gonfle.add_point(Vector2(0, 0.5))
	gonfle.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = gonfle
