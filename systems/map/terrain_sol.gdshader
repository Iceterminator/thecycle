shader_type spatial;
// Sol du terrain : textures Poly Haven (assets/textures/sol/) mélangées par biome (CUSTOM0 = poids
// plaine, désert, neige, marais), plaques de terre et vase (CUSTOM1.x, .y), roche selon la pente
// (projection sur 2 axes). COLOR = couleur du biome (data/biomes/) : les textures en gardent le détail
// mais prennent cette teinte (fidelite_couleur), pour rester fidèles à la direction artistique.
render_mode diffuse_burley;

uniform sampler2D tex_herbe : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_sable : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_neige : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_marais : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_terre : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_roche : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nor_herbe : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nor_sable : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nor_neige : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nor_marais : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nor_terre : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nor_roche : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float taille_sol = 3.0;        // m couverts par une répétition des textures de sol
uniform float taille_roche = 6.0;
uniform float fidelite_couleur = 0.35; // 0 = couleurs des photos, 1 = teinte du biome
uniform float force_relief = 0.8;
uniform bool relief = true;            // normal maps (coupées en qualité Bas)
uniform float mip_moyenne = 10.0;      // niveau de mip ≈ 1 pixel : couleur moyenne d'une texture

varying vec3 v_monde;
varying vec3 v_normale_monde;
varying vec4 v_biomes;
varying vec2 v_masques;

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_biomes = CUSTOM0;
	v_masques = CUSTOM1.xy;
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
}

// Couleur (rgb) et moyenne (pour la teinte) d'une couche.
void couche(sampler2D t, sampler2D n, vec2 uv, float poids, inout vec3 col, inout vec3 moy, inout vec3 nor) {
	if (poids > 0.01) {
		col += texture(t, uv).rgb * poids;
		moy += textureLod(t, uv, mip_moyenne).rgb * poids;
		if (relief) {
			nor += texture(n, uv).rgb * poids;
		}
	}
}

void fragment() {
	vec2 uv = v_monde.xz / taille_sol;
	vec4 b = v_biomes / max(v_biomes.x + v_biomes.y + v_biomes.z + v_biomes.w, 0.001);
	float terre = v_masques.x;
	float vase = v_masques.y;
	float roche = smoothstep(0.82, 0.68, v_normale_monde.y);
	float sol = (1.0 - roche) * (1.0 - terre) * (1.0 - vase);
	vec3 col = vec3(0.0);
	vec3 moy = vec3(0.0);
	vec3 nor = vec3(0.0);
	couche(tex_herbe, nor_herbe, uv, b.x * sol, col, moy, nor);
	couche(tex_sable, nor_sable, uv, b.y * sol, col, moy, nor);
	couche(tex_neige, nor_neige, uv, b.z * sol, col, moy, nor);
	couche(tex_marais, nor_marais, uv, b.w * sol, col, moy, nor);
	couche(tex_terre, nor_terre, uv, (1.0 - roche) * terre * (1.0 - vase), col, moy, nor);
	couche(tex_marais, nor_marais, uv * 0.7, (1.0 - roche) * vase, col, moy, nor);
	if (roche > 0.01) {
		// projection sur le plan vertical le plus face à la pente
		vec2 uv_roche = (abs(v_normale_monde.x) > abs(v_normale_monde.z) ? v_monde.zy : v_monde.xy) / taille_roche;
		couche(tex_roche, nor_roche, uv_roche, roche, col, moy, nor);
	}
	vec3 couleur_biome = pow(COLOR.rgb, vec3(2.2)); // couleurs de sommet en sRGB
	vec3 teinte = col / max(moy, vec3(0.02)) * couleur_biome;
	ALBEDO = mix(col, teinte, fidelite_couleur);
	if (relief) {
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nor, force_relief);
	}
	ROUGHNESS = 0.95;
	SPECULAR = 0.3;
}
