// Ajoute à la datasheet les paliers des contrats (points requis, VP, crédits, XP) lus dans les pages
// d'archive du wiki. Usage : node tools/wiki_2019/extract_contract_tiers.mjs <pages.json>
import fs from "node:fs";

const [, , PAGES] = process.argv;
const DS = new URL("../../data/reference/the_cycle_legacy_data.json", import.meta.url);
const { pages } = JSON.parse(fs.readFileSync(PAGES, "utf8"));
const d = JSON.parse(fs.readFileSync(DS, "utf8"));

const COLS = [[/^tiers?$/i, "tier"], [/amount requi?r?ed|facilities required|points thresholds/i, "amount"], [/total required/i, "total"],
	[/^vps? (reward|awarded)|^vp$/i, "vp"], [/vp squads and solos/i, "vp"], [/vp duos/i, "vp_duo"], [/credit/i, "credits"], [/xp/i, "xp"]];
const num = (s) => { const m = String(s).replace(/,/g, "").match(/-?\d+(\.\d+)?/); return m ? parseFloat(m[0]) : null; };

// Lit le premier tableau de paliers (en-têtes « Tier … Total Required ») : lignes de nombres
function tiers(text) {
	const tables = text.split(/\n\{\|/).slice(1);
	for (const t of tables) {
		const body = t.split(/\n\|\}/)[0];
		// Lignes du tableau : cellules en « | » ou en « ! », cellules vides gardées (colonnes alignées)
		const rows = body.split(/\n\|-/).map((r) => r.split(/\n[|!]/).slice(1).filter((c) => !c.startsWith("+")).map((c) => c.replace(/<[^>]+>|'''?/g, "").trim()));  // « |+ » = légende
		const headIdx = rows.findIndex((r) => r.some((c) => /^tiers?$/i.test(c)) && r.some((c) => /total required/i.test(c)));
		if (headIdx < 0) continue;
		const head = rows[headIdx].slice();
		while (head.length && head[0] === "") head.shift();  // cellule vide en tête (colonne d'images)
		const keys = head.map((h) => (COLS.find(([re]) => re.test(h)) || [null, null])[1]);
		const out = [];
		for (const r of rows.slice(headIdx + 1)) {
			if (/squad/i.test(r[0] || "") || (r[0] === "Duo")) continue; // mode solo seulement
			const row = {};
			keys.forEach((k, i) => { if (k && r[i] != null && num(r[i]) != null) row[k] = num(r[i]); });
			if (row.tier != null && row.total != null) out.push(row);
		}
		if (out.length) return out;
	}
	return [];
}

const EXTRA = {
	Uplink: "Le relais tenu rapporte 30 points toutes les 10 s ; capture en 10 s ; 3 relais successifs actifs 362 s chacun (à 18:06, 12:04, 06:02).",
	"Veltecite Minerals": "Minerais : moyen 200 pts (30 s d'extraction, 3 500 PV de foreuse ?), riche 400 (45 s), massif 600 (65 s), épique 1 000 (3 min). Une vague de créatures par tranche de 100.",
	"Drone Salvage": "Par drone livré selon son état : intact 100, bon 70, endommagé 40.",
	"Central Power": "Phase 2 : tenir une zone gardée par des Co-Bots ; points au fil du temps (Release 13 : en duo, 3 ticks de 30 VP par activation).",
	Bounty: "5 VP par élimination (10 en solo avant la saison 3).",
	"Letium Gas": "Raffineur de niveau 1 / 2 / 3 : 0,2 / 0,4 / 1 point par seconde ; niveau 2 après 60 s, niveau 3 après 120 s.",
	Hunt: "Créatures : 75, 150, 300 ou 450 points de contrat selon le type.",
	"Warden Alpha": "25 VP à chaque seuil de dégâts infligés à l'Alpha, +25 VP pour le coup fatal (125 VP au maximum).",
	"Mag-Train": "Chargement 5 min, puis capture à la console ; rapporte des points pendant le trajet, triple pendant le déchargement près de l'évac.",
};
for (const c of d.contracts) {
	const t = tiers(pages["Archive:" + c.name]?.text || "");
	if (t.length) c.tiers = t;
	if (EXTRA[c.name]) c.rules = EXTRA[c.name];
}
d.meta.how_to_read.push("contracts[].tiers : paliers du contrat (amount = points à gagner pour ce palier, total = cumul, vp = points de classement, credits, xp). Mode solo quand le wiki en donne plusieurs.");
fs.writeFileSync(DS, JSON.stringify(d, null, 2) + "\n");
for (const c of d.contracts) console.log(c.name.padEnd(20), (c.tiers || []).slice(0, 5).map((r) => `${r.tier}:${r.amount}/${r.total} vp${r.vp ?? "-"} cr${r.credits ?? "-"} xp${r.xp ?? "-"}`).join(" | "), c.tiers ? `(${c.tiers.length} paliers)` : "");
