extends RefCounted
## Niveaux de qualité graphique (Bas / Moyen / Haut), appliqués à l'environnement du monde.
## Pensé pour tourner sur un GPU intégré en Bas (défaut). Pas de SDFGI : trop coûteux avec la végétation.
## Bas = ombres légères + post-traitement ; Moyen = + SSAO demi-résolution, 4 cascades ;
## Haut = + brouillard volumétrique, SSIL, flou de profondeur.

const BAS := 0
const MOYEN := 1
const HAUT := 2
const NOMS := ["Bas", "Moyen", "Haut"]

const OMBRES_BAS_DISTANCE := 80.0
const OMBRES_HAUT_DISTANCE := 120.0
const ATLAS_OMBRES := 2048


## Réglages globaux du rendu (ombres, SSAO, volumétrique au moindre coût), appelés une fois au démarrage.
static func appliquer_global() -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.directional_shadow_atlas_set_size(ATLAS_OMBRES, true)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(64, 32)
	RenderingServer.environment_set_volumetric_fog_filter_active(false)


## Applique un niveau à l'environnement, aux attributs de caméra, au soleil et au post-traitement (tous optionnels).
static func appliquer(niveau: int, env: Environment, camera: CameraAttributes, soleil: DirectionalLight3D, post: PostTraitement) -> void:
	if env:
		env.sdfgi_enabled = false
		env.ssil_enabled = niveau >= HAUT
		env.ssao_enabled = niveau >= MOYEN
		env.volumetric_fog_enabled = niveau >= HAUT
	var pratique := camera as CameraAttributesPractical
	if pratique:
		pratique.dof_blur_far_enabled = niveau >= HAUT
	if soleil:
		soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if niveau <= BAS else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		soleil.directional_shadow_max_distance = OMBRES_BAS_DISTANCE if niveau <= BAS else OMBRES_HAUT_DISTANCE
	var sol := load(MapTerrainMesh.SOL_MATERIAL) as ShaderMaterial
	if sol:
		sol.set_shader_parameter("relief", niveau >= MOYEN)  # normal maps du sol
	if post:
		post.set_actif(true)


## Applique le niveau enregistré au monde (WorldEnvironment, Sun, PostTraitement).
static func appliquer_monde(monde: Node, niveau: int) -> void:
	var we := monde.get_node_or_null("WorldEnvironment") as WorldEnvironment
	appliquer(niveau, we.environment if we else null, we.camera_attributes if we else null,
		monde.get_node_or_null("Sun") as DirectionalLight3D, monde.get_node_or_null("PostTraitement") as PostTraitement)
