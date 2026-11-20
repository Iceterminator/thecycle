shader_type sky;
// Ciel de la planète : dégradé, soleil (DirectionalLight3D « Sun »), planète géante à anneaux,
// deux lunes et nuages procéduraux qui défilent. Matériau : systems/rendu/ciel.tres.
// La Grande Marée (storm_manager.gd) fait varier couleur_haut, couleur_horizon, couverture et nuages_sombres.

uniform vec3 couleur_haut : source_color = vec3(0.12, 0.36, 0.45);
uniform vec3 couleur_horizon : source_color = vec3(0.92, 0.8, 0.62);
uniform vec3 couleur_sol : source_color = vec3(0.16, 0.17, 0.11);
uniform float courbe = 0.35;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable; // bruit sans couture (nuages, bandes)
uniform float couverture : hint_range(0.0, 1.0) = 0.45;
uniform float nuages_sombres : hint_range(0.0, 1.0) = 0.0;
uniform float nuages_echelle = 0.18;
uniform vec2 nuages_vent = vec2(0.004, 0.0015);
uniform vec3 nuages_couleur : source_color = vec3(1.0, 0.95, 0.88);
uniform vec3 nuages_ombre : source_color = vec3(0.55, 0.55, 0.6);

uniform vec3 planete_dir = vec3(-0.75, 0.32, -0.58);
uniform float planete_rayon = 0.3;     // tangente du rayon apparent
uniform vec3 planete_a : source_color = vec3(0.75, 0.6, 0.48);
uniform vec3 planete_b : source_color = vec3(0.58, 0.55, 0.55);
uniform float planete_opacite = 0.8;   // < 1 : vue à travers l'atmosphère
uniform float anneaux_inclinaison = 0.22;
uniform float anneaux_angle = 0.35;

uniform vec3 lune1_dir = vec3(0.35, 0.45, -0.82);
uniform float lune1_rayon = 0.025;
uniform vec3 lune2_dir = vec3(-0.2, 0.6, -0.77);
uniform float lune2_rayon = 0.012;
uniform vec3 lunes_couleur : source_color = vec3(0.8, 0.78, 0.75);

// Repère tangent autour d'une direction ; p = position projetée (plan perpendiculaire).
vec2 projeter(vec3 d, vec3 axe, out vec3 t1, out vec3 t2) {
	t1 = normalize(cross(axe, vec3(0.0, 1.0, 0.0)));
	t2 = cross(t1, axe);
	return vec2(dot(d, t1), dot(d, t2)) / max(dot(d, axe), 0.001);
}

// Astre sphérique éclairé par le soleil : rgb = couleur, a = couverture du disque.
vec4 astre(vec3 d, vec3 axe, float r, vec3 couleur, vec3 soleil, bool bandes) {
	vec3 t1; vec3 t2;
	if (dot(d, axe) <= 0.0) return vec4(0.0);
	vec2 p = projeter(d, axe, t1, t2) / r;
	float l = length(p);
	if (l > 1.0) return vec4(0.0);
	vec3 n = t1 * p.x + t2 * p.y - axe * sqrt(1.0 - l * l);
	float lum = smoothstep(-0.1, 0.4, dot(-n, soleil)) * 0.95 + 0.05;
	vec3 c = couleur;
	if (bandes) {
		float lat = p.y + p.x * 0.15;
		float b = texture(bruit, vec2(lat * 0.6, 0.31)).r;
		c = mix(planete_a, planete_b, smoothstep(0.3, 0.7, b + 0.2 * sin(lat * 7.0)));
	} else {
		c *= mix(0.75, 1.05, texture(bruit, p * 0.5 + axe.xz).r);
	}
	return vec4(c * lum * (1.0 - 0.35 * l * l), 1.0 - smoothstep(0.97, 1.0, l));
}

void sky() {
	vec3 d = EYEDIR;
	vec3 soleil = LIGHT0_DIRECTION;
	float h = max(d.y, 0.0);
	vec3 ciel = mix(couleur_horizon, couleur_haut, pow(h, courbe));
	if (d.y < 0.0) {
		ciel = mix(couleur_horizon, couleur_sol, smoothstep(0.0, 0.25, -d.y));
	}
	// Halo et disque du soleil.
	float cs = dot(d, soleil);
	ciel += LIGHT0_COLOR * (pow(max(cs, 0.0), 8.0) * 0.25 + pow(max(cs, 0.0), 120.0) * 0.6);
	ciel += LIGHT0_COLOR * LIGHT0_ENERGY * 6.0 * smoothstep(cos(radians(1.6)), cos(radians(1.2)), cs);

	// Planète géante et ses anneaux (la moitié arrière des anneaux est cachée par la planète).
	vec3 axe = normalize(planete_dir);
	vec3 t1; vec3 t2;
	vec2 p = projeter(d, axe, t1, t2) / planete_rayon;
	vec2 q = vec2(p.x * cos(anneaux_angle) - p.y * sin(anneaux_angle), p.x * sin(anneaux_angle) + p.y * cos(anneaux_angle));
	float re = length(vec2(q.x, q.y / anneaux_inclinaison));
	float anneau = (dot(d, axe) > 0.0 ? 1.0 : 0.0) * smoothstep(1.35, 1.4, re) * (1.0 - smoothstep(2.1, 2.3, re));
	anneau *= 0.35 + 0.5 * texture(bruit, vec2(re * 0.9, 0.73)).r;
	vec4 pl = astre(d, axe, planete_rayon, planete_a, soleil, true);
	vec3 anneau_c = mix(planete_a, vec3(1.0), 0.4) * (0.55 + 0.45 * max(soleil.y, 0.0));
	float derriere = q.y > 0.0 ? 1.0 - pl.a : 1.0;
	float voile = planete_opacite * smoothstep(-0.02, 0.12, d.y); // brume à l'horizon
	ciel = mix(ciel, pl.rgb + ciel * 0.15, pl.a * voile);
	ciel = mix(ciel, anneau_c, anneau * derriere * voile * 0.8);
	// Lunes.
	vec4 l1 = astre(d, normalize(lune1_dir), lune1_rayon, lunes_couleur, soleil, false);
	vec4 l2 = astre(d, normalize(lune2_dir), lune2_rayon, lunes_couleur * vec3(1.0, 0.85, 0.75), soleil, false);
	ciel = mix(ciel, l1.rgb, l1.a * voile);
	ciel = mix(ciel, l2.rgb, l2.a * voile);

	// Nuages : plan projeté au-dessus de la caméra, deux octaves de bruit qui défilent.
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.12) * nuages_echelle;
		float n = texture(bruit, uv + TIME * nuages_vent).r * 0.65 + texture(bruit, uv * 2.7 - TIME * nuages_vent * 1.7).r * 0.35;
		float seuil = 1.0 - couverture;
		float dens = smoothstep(seuil - 0.05, seuil + 0.25, n) * smoothstep(0.0, 0.18, d.y);
		float epais = smoothstep(seuil, seuil + 0.45, n);
		vec3 lumiere = mix(nuages_couleur * (0.7 + 0.5 * max(soleil.y, 0.0)), nuages_ombre, epais * 0.7);
		lumiere += LIGHT0_COLOR * pow(max(cs, 0.0), 6.0) * (1.0 - epais) * 0.6; // bords éclairés côté soleil
		lumiere = mix(lumiere, nuages_ombre * 0.35, nuages_sombres);
		ciel = mix(ciel, lumiere, dens * 0.92);
	}
	COLOR = ciel;
}
