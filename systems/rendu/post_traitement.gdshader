shader_type canvas_item;
// Post-traitement léger : aberration chromatique sur les bords, vignette douce, grain animé.

uniform sampler2D ecran : hint_screen_texture, repeat_disable, filter_linear;
uniform float aberration : hint_range(0.0, 0.01) = 0.0012;
uniform float vignette : hint_range(0.0, 1.0) = 0.28;
uniform float grain : hint_range(0.0, 0.1) = 0.018;

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centre = SCREEN_UV - vec2(0.5);
	float bord = dot(centre, centre) * 4.0; // 0 au centre, 2 dans les coins
	vec2 decalage = centre * aberration * bord;
	vec3 couleur;
	couleur.r = texture(ecran, SCREEN_UV + decalage).r;
	couleur.g = texture(ecran, SCREEN_UV).g;
	couleur.b = texture(ecran, SCREEN_UV - decalage).b;
	couleur *= 1.0 - vignette * smoothstep(0.3, 1.6, bord);
	couleur += (hasard(SCREEN_UV * vec2(1920.0, 1080.0) + fract(TIME) * 100.0) - 0.5) * grain;
	COLOR = vec4(couleur, 1.0);
}
