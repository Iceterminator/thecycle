shader_type spatial;
// Herbe du décor (touffes Poly Haven) : texture + masque alpha séparé, vent, normales vers le haut
// (éclairage doux, pas de faces sombres), pied plus sombre. Utilisé via les .tres de assets/models/nature/herbe/.
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D texture_alpha : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float hauteur_ref = 0.3;   // hauteur du modèle (m, avant échelle)
uniform float vent_force = 0.04;
uniform float vent_vitesse = 1.6;
uniform float seuil_alpha = 0.3;
uniform bool alpha_dans_albedo = false;  // feuillage des arbres : alpha dans la même image

varying float v_hauteur;

void vertex() {
	vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_hauteur = clamp(VERTEX.y / hauteur_ref, 0.0, 1.0);
	float phase = TIME * vent_vitesse + monde.x * 0.35 + monde.z * 0.22;
	float souffle = (sin(phase) + 0.4 * sin(phase * 2.3 + 1.7)) * vent_force * v_hauteur * v_hauteur;
	VERTEX.x += souffle;
	VERTEX.z += souffle * 0.6;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.75));
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	vec3 couleur = tex.rgb * teinte.rgb;
	ALBEDO = couleur * mix(0.7, 1.15, v_hauteur);
	ALPHA = alpha_dans_albedo ? tex.a : texture(texture_alpha, UV).r;
	ALPHA_SCISSOR_THRESHOLD = seuil_alpha;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = couleur * 0.35;
}
