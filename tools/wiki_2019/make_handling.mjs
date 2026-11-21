// Écrit le maniement des armes (vitesse de marche, recul accroupi, dispersion accroupi / en mouvement /
// en l'air, dispersion à la hanche) dans data/weapons/<id>.tres, d'après data/reference/the_cycle_legacy_data.json.
// Même logique que tools/import_legacy_handling.gd (utilisé par l'importeur) : modifier les deux ensemble.
// Idempotent (la dispersion part toujours du tableau par type, pas de la valeur déjà écrite).
// Usage : node tools/wiki_2019/make_handling.mjs
import fs from "node:fs";

const ROOT = new URL("../../", import.meta.url);
const d = JSON.parse(fs.readFileSync(new URL("data/reference/the_cycle_legacy_data.json", ROOT), "utf8"));

// Dispersion à la hanche par type (HANDLING_BY_TYPE de tools/import_legacy_data.gd, 1re valeur).
const HIP_BY_TYPE = { smg: 2.5, assault_rifle: 1.5, battle_rifle: 1.5, sniper_rifle: 4.0, shotgun: 1.0, lmg: 2.5,
	pistol: 1.0, missile_launcher: 1.0, heavy: 1.0 };
// champ .tres -> [clé de l'arme, clé de handling_raw]. Clé d'arme = null : handling_raw seulement.
const FIELDS = {
	move_speed_multiplier: ["move_speed_multiplier", "move_speed_multiplier"],
	ads_move_speed_multiplier: [null, "ads_move_speed_multiplier"],
	crouch_recoil_multiplier: ["crouch_recoil_multiplier", "crouch_recoil_multiplier"],
	crouch_spread_multiplier: [null, "crouch_spread_multiplier"],
	moving_spread_multiplier: [null, "moving_spread_multiplier"],
	in_air_spread_multiplier: [null, "in_air_spread_multiplier"],
};
const round3 = (x) => Math.round(x * 1000) / 1000;
const num = (v) => (typeof v === "number" ? v : undefined);
const fmt = (x) => (Number.isInteger(x) ? x.toFixed(1) : String(x));

// Valeur propre à l'arme (ou undefined)
const own = (w, field) => {
	const [wk, rk] = FIELDS[field];
	return (wk ? num(w[wk]) : undefined) ?? num((w.handling_raw || {})[rk]);
};
// Moyenne du type : les 0 (Gorgon, jeu d'origine) sont ignorés, ils fausseraient la valeur typique.
const mean = (xs) => { xs = xs.filter((x) => x > 0); return xs.length ? round3(xs.reduce((a, b) => a + b, 0) / xs.length) : undefined; };
const sameType = (w) => d.weapons.filter((o) => o.type === w.type);

let count = 0;
for (const w of d.weapons) {
	const path = new URL(`data/weapons/${w.id}.tres`, ROOT);
	if (!fs.existsSync(path)) continue;
	const lines = {};
	const estimated = [];
	for (const field of Object.keys(FIELDS)) {
		let v = own(w, field);
		if (v === undefined) {
			v = mean(sameType(w).map((o) => own(o, field)).filter((x) => x !== undefined));
			estimated.push(field);
		}
		lines[field] = round3(v ?? 1.0);
	}
	// Dispersion à la hanche : valeur du type x (base_spread de l'arme / moyenne du type).
	const bases = sameType(w).map((o) => num(o.base_spread_deg)).filter((x) => x !== undefined);
	const ratio = num(w.base_spread_deg) !== undefined && bases.length ? w.base_spread_deg / (bases.reduce((a, b) => a + b, 0) / bases.length) : 1.0;
	lines.hip_spread_deg = round3(HIP_BY_TYPE[w.type] * ratio);

	let text = fs.readFileSync(path, "utf8");
	text = text.split("\n").filter((l) => !Object.keys(lines).some((k) => l.startsWith(k + " = "))).join("\n");
	const block = Object.entries(lines).map(([k, v]) => `${k} = ${fmt(v)}`).join("\n");
	text = text.replace(/^(script = .*)$/m, `$1\n${block}`);
	// estimated_fields : ajoute les champs estimés (sans doublon)
	text = text.replace(/^estimated_fields = PackedStringArray\((.*)\)$/m, (_, inner) => {
		const names = [...inner.matchAll(/"([^"]*)"/g)].map((m) => m[1]);
		for (const f of estimated) if (!names.includes(f)) names.push(f);
		return `estimated_fields = PackedStringArray(${names.map((n) => `"${n}"`).join(", ")})`;
	});
	fs.writeFileSync(path, text);
	count++;
}
console.log(`maniement écrit dans ${count} armes`);
