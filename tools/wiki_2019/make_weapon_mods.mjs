// Génère data/weapon_mods/<arme>_<emplacement>_<n>.tres à partir des mods de la datasheet
// (data/reference/the_cycle_legacy_data.json). Effets convertis en multiplicateurs (mult) ou ajouts
// (add) sur les champs de WeaponData. Usage : node tools/wiki_2019/make_weapon_mods.mjs
import fs from "node:fs";

const ROOT = new URL("../../", import.meta.url);
const d = JSON.parse(fs.readFileSync(new URL("data/reference/the_cycle_legacy_data.json", ROOT), "utf8"));
// MODS_OUT (dossier, avec / final) : pour un essai hors du projet
const OUT = process.env.MODS_OUT ? new URL("file:///" + process.env.MODS_OUT.replace(/\\/g, "/")) : new URL("data/weapon_mods/", ROOT);

// Nos noms (descriptifs, en français)
const NAMES = {
	"The Splinter": "Éclateur", "1.5x Scope": "Lunette x1,5", "16x Scope": "Lunette x16", "2x Scope": "Lunette x2", "4x Scope": "Lunette x4",
	"8x Scope": "Lunette x8", "Aerodynamic Scope": "Lunette profilée", "Aerodynamic Shells": "Obus profilés", "Anti-Personnel Wavelengths": "Fréquences antipersonnel",
	"Anti-Xeno Calibration": "Calibrage anti-faune", "Automatic Slicer": "Tranchoir automatique", "Barrel Coils": "Bobines de canon", "Big Bertha": "Charge lourde",
	"Booster Chamber": "Chambre d'appoint", "Bundle Ejector": "Éjecteur en gerbe", "Burn Modulator": "Modulateur thermique", "Burst Fire": "Tir en rafale",
	"Burst Increase": "Rafale allongée", "Burst Mode": "Mode rafale", "Chain Reaction": "Réaction en chaîne", "Charged Capacitor": "Condensateur chargé",
	"Cluster Shells": "Obus à fragmentation", "Control Chamber": "Chambre de contrôle", "Conversion Chamber Stabilizer": "Stabilisateur de conversion",
	"Coolant Chamber": "Chambre refroidie", "Crossed Resistor": "Résistance croisée", "Direct Haze Injectors": "Injecteurs directs", "Double Action": "Double action",
	"Double-Tap Trigger": "Détente double", "EM Charged Rounds": "Balles électromagnétiques", "Energy Cycler": "Recycleur d'énergie", "Enriched Material": "Matière enrichie",
	"Ergonomic Grip": "Poignée ergonomique", "Ergonomic Stock": "Crosse ergonomique", "Expanded Caliber": "Calibre élargi", "Expanded Container": "Réservoir élargi",
	"Explosive Rounds": "Balles explosives", "Express": "Chargement express", "Extended Barrel": "Canon allongé", "Extended Magazine": "Chargeur étendu",
	"Extended Stock": "Crosse allongée", "Flash Modulator": "Modulateur éclair", "Focal Chamber": "Chambre focale", "Focus Core": "Noyau focalisé",
	"Focus Crystals": "Cristaux focalisés", "Fractal Batteries": "Batteries fractales", "Fractal Crystal": "Cristal fractal", "Full Auto": "Tout automatique",
	"Gyroscopic Stabilizers": "Stabilisateurs gyroscopiques", "Hallowed Rounds": "Balles évidées", "Hardkick Hammers": "Percuteurs renforcés",
	"Heavy Battery": "Batterie lourde", "Heavy Battery Drum": "Tambour de batteries lourd", "Heavy Duty Container": "Réservoir renforcé",
	"Heavy Flechettes": "Fléchettes lourdes", "Heavy Frame": "Carcasse lourde", "Heavy Handle": "Poignée lourde", "Heavy Slicer": "Tranchoir lourd",
	"Heavy Stock": "Crosse lourde", "High Caliber Chamber": "Chambre gros calibre", "High Caliber Mag Rail": "Rail gros calibre",
	"High Frequency Chamber": "Chambre haute fréquence", "High Frequency Emitter": "Émetteur haute fréquence", "High-Efficiency Battery": "Batterie haut rendement",
	"High-Grade Spring": "Ressort de qualité", "Hollow Frame": "Carcasse évidée", "Hollow Stock": "Crosse évidée", "Hollow-Point Rounds": "Balles à pointe creuse",
	"Holographic Sight": "Viseur holographique", "Hyper Core": "Hyper-noyau", "Improved Holo-Dot": "Point holo amélioré", "Internal Catalyst": "Catalyseur interne",
	"Internal Damper": "Amortisseur interne", "Internal Stabilizer": "Stabilisateur interne", "Ionized Chamber": "Chambre ionisée", "Light Alloy Body": "Corps en alliage léger",
	"Light Alloy Container": "Réservoir en alliage léger", "Light Alloy Drum Battery": "Tambour en alliage léger", "Light Container": "Réservoir léger",
	"Light Stock": "Crosse légère", "Light Weight Stock": "Crosse allégée", "Lightweight Batteries": "Batteries allégées", "Lightweight Battery": "Batterie allégée",
	"Lightweight Container": "Réservoir allégé", "Lightweight Handle": "Poignée allégée", "Lightweight Stock": "Crosse allégée", "Long Barrel": "Canon long",
	"Long Fuse Grenades": "Grenades à mèche longue", "Low Caliber Mag Rail": "Rail petit calibre", "Low Caliber Slabs": "Plaques petit calibre",
	"Lower Caliber Rounds": "Balles petit calibre", "Magnetic Slabs": "Plaques magnétiques", "Missile Flechettes": "Fléchettes explosives", "Mortar Launcher": "Lance-mortier",
	"Murcury-Infused Needles": "Aiguilles au mercure", "Overclocked Core": "Noyau surcadencé", "Penetrating Rods": "Tiges perforantes", "Phase Repeater": "Répéteur de phase",
	"Phasic Chamber": "Chambre phasique", "Piercing Needles": "Aiguilles perforantes", "Piercing Rounds": "Balles perforantes", "Porous Material": "Matière poreuse",
	"Power Chamber": "Chambre de puissance", "Power Ejector": "Éjecteur puissant", "Precision Chamber": "Chambre de précision", "Propellant Flechettes": "Fléchettes propulsées",
	"Quick-load Cylinders": "Barillets rapides", "Quicksilver Coating": "Enduit de vif-argent", "Quickswap Magazine": "Chargeur rapide", "Rapid Cartridge Feeder": "Alimentation rapide",
	"Rapid Cycler": "Cycle rapide", "Rapid Ejector": "Éjecteur rapide", "Rapid Launcher": "Lanceur rapide", "Rapid Rockets": "Roquettes rapides", "Rapid Slicer": "Tranchoir rapide",
	"Reactive Lever": "Levier réactif", "Scattershot": "Tir dispersé", "Shell Devider": "Diviseur de cartouches", "Shock Absorber": "Amortisseur de recul",
	"Short Barrel": "Canon court", "Shredder Pellets": "Plombs déchiqueteurs", "Shredder Rounds": "Balles déchiqueteuses", "Single Shot Chamber": "Chambre coup par coup",
	"Sleek Stock": "Crosse fine", "Slug Rounds": "Balles pleines", "Solid Matter Reactor": "Réacteur à matière solide", "Spring Assisted Bolt": "Culasse à ressort",
	"Stabilizer": "Stabilisateur", "Streamlined Core Port": "Port de noyau profilé", "Streamlined Chamber": "Chambre profilée", "T.N.T Payload": "Charge explosive",
	"T.N.T Rockets": "Roquettes explosives", "The Capacitor": "Condensateur", "Unstable Material": "Matière instable", "Xenotoxic Rods": "Tiges toxiques",
	"Xenotoxic Shards": "Éclats toxiques", "Xenotoxic Slabs": "Plaques toxiques", "Xenotoxin Needles": "Aiguilles toxiques", "Xenotoxin-coated Rounds": "Balles enduites de toxine",
};
const ALIAS = { "1.5x scope": "1.5x Scope", "4x scope": "4x Scope", "Hollow-point Rounds": "Hollow-Point Rounds", "Light Aloy Body": "Light Alloy Body",
	"Long barrel": "Long Barrel", "Shord Barrel": "Short Barrel", "Streamline Core Port": "Streamlined Core Port", "Xenotoxin Shards": "Xenotoxic Shards" };
const frName = (n) => NAMES[ALIAS[n] || n.replace(/^"|"$/g, "")] || NAMES[n.replace(/"/g, "")] || n;

const SLOTS = { rail: 0, stock: 1, handle: 1, body: 2, magazine: 3 };
// Stat du wiki -> [champ, mode] ; mode : ratio (mult = valeur / base), inv (mult = base / valeur),
// pct (valeur en % = multiplicateur), recoil (pourcentage d'augmentation), add (ajout de l'écart)
const STATS = [
	[/^damage$/i, "damage", "ratio"], [/^(rpm|rounds per minute)$/i, "fire_interval_s", "inv"],
	[/^(magazine|clip size|magazine size)$/i, "magazine", "ratio"], [/^reload_s$/, "reload_s", "ratio"],
	[/^ads_time_s$/, "ads_time_s", "ratio"], [/^time to equip$/i, "equip_time_s", "ratio"], [/^base spread$/i, "hip_spread_deg", "ratio"],
	[/^(projectile_speed_mps|projectile? spe[ae]d|projectil speed)$/i, "projectile_speed_mps", "ratio"], [/^range$/i, "range", "ratio"],
	[/^damage to monsters$/i, "damage_vs_creatures", "pct"], [/^damage to rivals$/i, "damage_vs_players", "pct"],
	[/^(spread_increase_pct|weapon spread increase ?%?)$/i, "recoil_deg", "recoil"], [/^aoe[_ ]damage$/i, "aoe_damage", "ratio_or_add"],
	[/^burst_count$/, "burst_count", "add"], [/^interval (per )?burst$/i, "burst_interval_s", "ratio"], [/^weak(spot|shot) damage$/i, "weakspot_multiplier", "ratio"],
	[/^radius$/i, "aoe_radius_m", "ratio"], [/^spin_up_s$/, "spin_up", "ratio"], [/^(move_speed|movement speed)$/i, "move_speed", "ratio"],
	[/^stability$/i, "recoil_deg", "inv"],  // plus de stabilité = moins de recul
];
// « 5,750 » = milliers ; « 43,5 » = virgule décimale
const num = (s) => { if (s == null) return null; const t = String(s).replace(/(\d),(\d{3})(?!\d)/g, "$1$2").replace(/(\d),(\d)/g, "$1.$2"); const m = t.match(/-?\d+(\.\d+)?/); return m ? parseFloat(m[0]) : null; };
const FR = { damage: "dégâts", fire_interval_s: "cadence", magazine: "chargeur", reload_s: "rechargement", ads_time_s: "visée", equip_time_s: "sortie de l'arme",
	hip_spread_deg: "dispersion", projectile_speed_mps: "vitesse du projectile", range: "portée", damage_vs_creatures: "dégâts aux créatures",
	damage_vs_players: "dégâts aux joueurs", recoil_deg: "recul", aoe_damage: "dégâts de zone", burst_count: "tirs par rafale", burst_interval_s: "intervalle de rafale",
	weakspot_multiplier: "point faible", aoe_radius_m: "rayon d'explosion", spin_up: "montée en régime", move_speed: "vitesse de marche" };

// Retouches de la Release 14 (balles explosives : dégâts de zone fixes, dégâts directs à 50 %)
const R14 = { hammer: 40, kor_47: 18, advocate: 20, kbr_longshot: 60 };

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
let count = 0; const skipped = [];
for (const w of d.weapons) {
	const counters = {};
	for (const m of w.mods || []) {
		const slot = SLOTS[m.slot];
		if (slot == null) { skipped.push(`${w.id}/${m.name} : emplacement ${m.slot}`); continue; }
		counters[slot] = (counters[slot] || 0) + 1;
		const id = `${w.id}_${m.slot === "handle" ? "stock" : m.slot}_${counters[slot]}`;
		const mult = {}, add = {}, flags = [], notes = [];
		for (const e of m.effects) {
			if (/piercing|pirecing/i.test(e.stat)) { flags.push("piercing"); continue; }
			if (/explode on impact/i.test(e.stat)) { flags.push("explode_on_impact"); continue; }
			const rule = STATS.find(([re]) => re.test(e.stat.trim()));
			if (!rule) continue; // stabilité, DPS, récupération du recul… : pas utilisés par le jeu
			const [, field, mode] = rule;
			const v = num(e.value), c = num(e.change);
			let r = null;
			if (mode === "pct") r = v != null ? v / 100 : null;
			else if (mode === "recoil") r = v != null ? 1 + v / 100 : null;
			else if (mode === "add") { if (c != null && c !== 0) add[field] = c; continue; }
			else if (v != null && c != null) {
				const base = v - c;
				if (mode === "ratio_or_add" && base <= 0) { add[field] = v; continue; }
				r = mode === "inv" ? (v !== 0 ? base / v : null) : (base !== 0 ? v / base : null);
			}
			if (r == null || !isFinite(r) || r <= 0.1 || r >= 10) { notes.push(`${e.stat} ${e.value}/${e.change} ignoré`); continue; }
			if (Math.abs(r - 1) < 0.005) continue;
			mult[field] = +((mult[field] ?? 1) * r).toFixed(3);  // plusieurs stats peuvent viser le même champ (recul)
		}
		// Lunettes : le grossissement n'est que dans le nom (« 4x Scope »)
		const set = {};
		const zoom = m.name.match(/(\d+(?:\.\d+)?)x scope/i);
		if (zoom) set.scope_zoom = parseFloat(zoom[1]);
		if (/explosive rounds/i.test(m.name) && R14[w.id]) { mult.damage = 0.5; add.aoe_damage = R14[w.id]; add.aoe_radius_m = 2.0; notes.push("Release 14 : zone fixe, dégâts directs 50 %"); }
		const parts = [];
		for (const [f, r] of Object.entries(mult)) {
			const shown = f === "fire_interval_s" ? 1 / r : r; // cadence : on affiche le gain de cadence
			const pct = Math.round((shown - 1) * 100);
			if (pct) parts.push(`${pct > 0 ? "+" : ""}${pct} % ${FR[f] || f}`);
		}
		for (const [f, a] of Object.entries(add)) parts.push(`${a > 0 ? "+" : ""}${a}${f === "aoe_radius_m" ? " m" : ""} ${FR[f] || f}`);
		if (set.scope_zoom) parts.unshift(`lunette x${String(set.scope_zoom).replace(".", ",")}`);
		if (flags.includes("piercing")) parts.push("balles perforantes");
		if (flags.includes("explode_on_impact")) parts.push("explose à l'impact");
		const dict = (o) => `{${Object.entries(o).map(([k, v]) => `"${k}": ${Number.isInteger(v) ? v.toFixed(1) : v}`).join(", ")}}`;
		const tres = `[gd_resource type="Resource" script_class="WeaponModData" format=3]

[ext_resource type="Script" path="res://resources/weapon_mod_data.gd" id="1_mod"]

[resource]
script = ExtResource("1_mod")
id = &"${id}"
display_name = "${frName(m.name)}"
description = "${parts.join(", ") || "aucun effet chiffré"}"
weapon_id = &"${w.id}"
slot = ${slot}
mult = ${dict(mult)}
add = ${dict(add)}
overrides = ${dict(set)}
flags = PackedStringArray(${flags.map((f) => `"${f}"`).join(", ")})
reference_name = "${m.name.replace(/"/g, "")}"
notes = "${notes.join(" ; ")}"
`;
		fs.writeFileSync(new URL(id + ".tres", OUT), tres);
		count++;
		if (!NAMES[ALIAS[m.name] || m.name.replace(/"/g, "")]) skipped.push(`nom non traduit : ${m.name}`);
	}
}
console.log(count, "mods écrits");
if (skipped.length) console.log(skipped.join("\n"));
