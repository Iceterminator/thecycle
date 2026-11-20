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
// Anti-répétition : variante tournée par zones, seconde échelle, taches de couleur.
uniform float taille_zones = 9.0;      // m : zones où la texture prend sa variante tournée
uniform float grande_echelle = 0.23;   // la même texture, 1 / 0.23 fois plus grande, mélangée
uniform float melange_proche = 0.25;   // part de la grande échelle de près
uniform float melange_loin = 0.6;      // et au loin (au-delà de distance_loin)
uniform float distance_loin = 60.0;
uniform float taille_taches = 70.0;    // m : taches de couleur (clair / sombre, sec / humide)
uniform float force_taches = 0.16;

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

// Bruit de valeur lisse (0..1), pour les zones et les taches : calculé, pas de texture.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

const mat2 ROT = mat2(vec2(-0.32, 0.95), vec2(-0.95, -0.32)); // ≈ 109° : la variante ne s'aligne pas

// Une texture sans répétition visible : variante tournée et décalée par zones (z = part de la
// variante), plus la même texture en grand (g = part de la grande échelle).
vec3 echant(sampler2D t, vec2 uv, float z, float g) {
	vec3 a = mix(texture(t, uv).rgb, texture(t, ROT * uv + vec2(0.37, 0.71)).rgb, z);
	return mix(a, texture(t, uv * grande_echelle + vec2(0.5)).rgb, g);
}

// Même chose pour une normal map : la variante tournée est remise dans le bon sens.
vec3 echant_normale(sampler2D n, vec2 uv, float z) {
	vec3 a = texture(n, uv).rgb;
	vec3 b = texture(n, ROT * uv + vec2(0.37, 0.71)).rgb * 2.0 - 1.0;
	b.xy = transpose(ROT) * b.xy;
	return mix(a, b * 0.5 + 0.5, z);
}

// Couleur (rgb) et moyenne (pour la teinte) d'une couche.
void couche(sampler2D t, sampler2D n, vec2 uv, float poids, float z, float g, inout vec3 col, inout vec3 moy, inout vec3 nor) {
	if (poids > 0.01) {
		col += echant(t, uv, z, g) * poids;
		moy += textureLod(t, uv, mip_moyenne).rgb * poids;
		if (relief) {
			nor += echant_normale(n, uv, z) * poids;
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
	// Zones de variante (transition assez nette pour ne pas flouter) et part de la grande échelle.
	float z = smoothstep(0.4, 0.6, bruit(v_monde.xz / taille_zones) * 0.75 + bruit(v_monde.xz / (taille_zones * 0.37)) * 0.25);
	float dist = length(v_monde - CAMERA_POSITION_WORLD);
	float g = mix(melange_proche, melange_loin, smoothstep(5.0, distance_loin, dist));
	vec3 col = vec3(0.0);
	vec3 moy = vec3(0.0);
	vec3 nor = vec3(0.0);
	couche(tex_herbe, nor_herbe, uv, b.x * sol, z, g, col, moy, nor);
	couche(tex_sable, nor_sable, uv, b.y * sol, z, g, col, moy, nor);
	couche(tex_neige, nor_neige, uv, b.z * sol, z, g, col, moy, nor);
	couche(tex_marais, nor_marais, uv, b.w * sol, z, g, col, moy, nor);
	couche(tex_terre, nor_terre, uv, (1.0 - roche) * terre * (1.0 - vase), z, g, col, moy, nor);
	couche(tex_marais, nor_marais, uv * 0.7, (1.0 - roche) * vase, z, g, col, moy, nor);
	if (roche > 0.01) {
		// projection sur le plan vertical le plus face à la pente
		vec2 uv_roche = (abs(v_normale_monde.x) > abs(v_normale_monde.z) ? v_monde.zy : v_monde.xy) / taille_roche;
		couche(tex_roche, nor_roche, uv_roche, roche, z, g * 0.5, col, moy, nor);
	}
	vec3 couleur_biome = pow(COLOR.rgb, vec3(2.2)); // couleurs de sommet en sRGB
	vec3 teinte = col / max(moy, vec3(0.02)) * couleur_biome;
	vec3 albedo = mix(col, teinte, fidelite_couleur);
	// Taches à grande échelle : plus clair / plus sombre, plus sec (chaud) / plus humide (froid).
	float clair = bruit(v_monde.xz / taille_taches) * 2.0 - 1.0;
	float sec = bruit(v_monde.xz / (taille_taches * 1.7) + vec2(17.3, 5.1)) * 2.0 - 1.0;
	albedo *= 1.0 + clair * force_taches;
	albedo *= vec3(1.0) + vec3(0.6, 0.15, -0.5) * sec * force_taches;
	ALBEDO = albedo;
	if (relief) {
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nor, force_relief);
	}
	ROUGHNESS = 0.95 - 0.1 * max(-sec, 0.0); // zones humides un peu plus brillantes
	SPECULAR = 0.3;
}
