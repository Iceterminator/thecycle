// Construit docs/wiki_2019/index.html à partir des pages d'archive téléchargées.
// Usage : node tools/wiki_2019/build_site.mjs <pages.json> <sortie.html>
import fs from "node:fs";
import path from "node:path";
import { render } from "./wikitext.mjs";

const [, , SRC, OUT] = process.argv;
const { pages, redirects } = JSON.parse(fs.readFileSync(SRC, "utf8"));
const API = "https://thecyclefrontier.fandom.com/api.php";
const titles = new Set(Object.keys(pages));

const norm = (t) => { t = t.replace(/_/g, " ").trim(); return t.charAt(0).toUpperCase() + t.slice(1); };
function resolve(target) {
	const t = norm(target);
	for (const c of [t, "Archive:" + t, "Archive:" + t.replace(/^Archive:/, "")]) {
		let x = c;
		for (let n = 0; n < 3 && redirects[x]; n++) x = redirects[x];
		if (titles.has(x)) return x;
	}
	return null;
}

// Images : toutes les références File: / image =
const files = new Set();
for (const p of Object.values(pages)) {
	for (const m of p.text.matchAll(/\[\[\s*(?:File|Image):([^|\]]+)/gi)) files.add(norm(m[1]));
	for (const m of p.text.matchAll(/\|\s*image\s*=\s*(?:\[\[)?(?:File:|Image:)?([^|\]\n}]+\.(?:png|jpg|jpeg|gif|webp))/gi)) files.add(norm(m[1]));
	for (const m of p.text.matchAll(/\{\{\s*FP icon\s*\|\s*([^|}]+)/gi)) files.add(norm(m[1]));
}
const images = {};
const list = [...files];
for (let i = 0; i < list.length; i += 50) {
	const q = new URLSearchParams({ action: "query", format: "json", prop: "imageinfo", iiprop: "url", iiurlwidth: "320", titles: list.slice(i, i + 50).map((f) => "File:" + f).join("|") });
	const j = await (await fetch(API + "?" + q, { headers: { "User-Agent": "wiki-reader/1.0" } })).json();
	const back = {};
	for (const n of j.query.normalized || []) back[n.to] = n.from;
	for (const p of Object.values(j.query.pages)) {
		const ii = p.imageinfo?.[0];
		if (ii) images[norm(p.title.replace(/^File:/, ""))] = { url: ii.url, thumb: ii.thumburl || ii.url };
	}
}
console.log("images trouvées :", Object.keys(images).length, "/", files.size);

// Rubriques de navigation (ordre = priorité)
const SECTIONS = [
	["Armes — ICA", (c) => c.includes("ICA Weapons")],
	["Armes — Korolev", (c) => c.includes("Korolev Weapons")],
	["Armes — Osiris", (c) => c.includes("Osiris Weapons")],
	["Armes — Co-Tec", (c) => c.includes("Co-Tec Weapons")],
	["Armes — autres", (c) => c.includes("Weapons")],
	["Comparatifs", (c) => c.includes("Compare")],
	["Kits", (c) => c.includes("Kits") || c.includes("Gear")],
	["Capacités", (c) => c.includes("Abilities")],
	["Gadgets", (c) => c.includes("Gadgets")],
	["Créatures", (c) => c.includes("Creatures")],
	["Matériaux", (c) => c.includes("Materials")],
	["Contrats", (c) => c.includes("Contracts")],
	["Factions et sociétés", (c) => c.includes("Factions") || c.includes("Companies")],
	["Personnages et lore", (c) => c.includes("Characters") || c.includes("Lore")],
	["Notes de mise à jour", (c) => c.includes("Patch Notes")],
	["Guides", (c) => c.includes("Guides")],
];
const nav = SECTIONS.map(([n]) => ({ name: n, pages: [] }));
nav.push({ name: "Autres pages", pages: [] });

const out = {};
for (const [title, p] of Object.entries(pages)) {
	if (/\/(nl|Flex section|Bottom section|Section \d)/.test(title) || /Frontier Wiki/.test(title)) continue;
	const cats = new Set();
	let html;
	try {
		html = render(p.text, { title, resolve, image: (f) => images[norm(f)] || null, cats });
	} catch (e) {
		html = `<p class="note">Erreur de conversion : ${String(e.message)}</p>`;
	}
	const allCats = [...new Set([...p.cats, ...cats])].filter((c) => !/broken file|Stubs|translation|Front page|Notice|Pages using/i.test(c));
	out[title] = { html, cats: allCats };
	const idx = SECTIONS.findIndex(([, f]) => f(allCats));
	nav[idx < 0 ? nav.length - 1 : idx].pages.push(title);
}
for (const s of nav) s.pages.sort((a, b) => a.localeCompare(b, "fr", { numeric: true }));

const tpl = fs.readFileSync(new URL("./site_template.html", import.meta.url), "utf8");
const data = JSON.stringify({ pages: out, nav: nav.filter((s) => s.pages.length) }).replace(/</g, "\\u003c");
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, tpl.replace("/*__DATA__*/null", data));
console.log("ok :", Object.keys(out).length, "pages ->", OUT);
