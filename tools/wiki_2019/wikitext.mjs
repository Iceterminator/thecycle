// Conversion wikitexte (MediaWiki) -> HTML, suffisante pour les pages d'archive du wiki The Cycle (2019).
// ctx = { title, resolve(target) -> titre de page ou null, image(fileName) -> {url, thumb} | null, cats:Set }

const esc = (s) => s.replace(/&(?!#?\w+;)/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const ALLOWED = new Set(["span", "div", "center", "br", "small", "big", "b", "i", "u", "s", "sup", "sub", "font", "p", "code", "pre", "blockquote", "strong", "em"]);

// Découpe "a|b|{{c|d}}|[[e|f]]" au niveau supérieur
function splitTop(s, sep = "|") {
	const out = [];
	let depthT = 0, depthL = 0, cur = "";
	for (let i = 0; i < s.length; i++) {
		const two = s.substr(i, 2);
		if (two === "{{") { depthT++; cur += two; i++; continue; }
		if (two === "}}" && depthT > 0) { depthT--; cur += two; i++; continue; }
		if (two === "[[") { depthL++; cur += two; i++; continue; }
		if (two === "]]" && depthL > 0) { depthL--; cur += two; i++; continue; }
		if (s[i] === sep && depthT === 0 && depthL === 0) { out.push(cur); cur = ""; continue; }
		cur += s[i];
	}
	out.push(cur);
	return out;
}

// Trouve la fin d'un bloc ouvert en `start` (après les 2 caractères ouvrants)
function matchClose(s, start, open, close) {
	let depth = 1;
	for (let i = start; i < s.length - 1; i++) {
		if (s.substr(i, 2) === open) { depth++; i++; }
		else if (s.substr(i, 2) === close) { depth--; if (depth === 0) return i; i++; }
	}
	return -1;
}

function parseParams(parts) {
	const named = {}, pos = [];
	for (const p of parts) {
		const m = p.match(/^\s*([^=\[\]{}]+?)\s*=([\s\S]*)$/);
		if (m && !/^\s*</.test(p)) named[m[1].trim()] = m[2].trim();
		else pos.push(p.trim());
	}
	return { named, pos };
}

const pretty = (k) => k.replace(/^\/\*\*.*\*\*\/$/, "").replace(/_/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, (c) => c.toUpperCase());

export function render(text, ctx) {
	const raws = [];
	const hold = (html, block = false) => { raws.push(html); return block ? `\n\u0001${raws.length - 1}\u0001\n` : `\u0002${raws.length - 1}\u0002`; };
	const sub = (t) => render(t, ctx);
	const inl = (t) => inline(t, ctx, hold);

	let s = text.replace(/<!--[\s\S]*?-->/g, "").replace(/__\w+__/g, "").replace(/<ref[^>]*\/>/g, "").replace(/<ref[\s\S]*?<\/ref>/g, "");
	s = s.replace(/<noinclude>[\s\S]*?<\/noinclude>/g, "").replace(/<\/?(includeonly|onlyinclude|nowiki)>/g, "");

	// <tabber> : onglets -> sections
	s = s.replace(/<tabber>([\s\S]*?)<\/tabber>/g, (_, body) => hold(body.split(/\|-\|/).map((tab) => {
		const i = tab.indexOf("=");
		return `<div class="tab"><h4>${esc(tab.slice(0, i).trim())}</h4>${sub(tab.slice(i + 1))}</div>`;
	}).join(""), true));
	// <gallery>
	s = s.replace(/<gallery[^>]*>([\s\S]*?)<\/gallery>/g, (_, body) => hold(`<div class="gallery">${body.trim().split("\n").map((l) => {
		const [f, cap] = l.split("|");
		const img = ctx.image(f.replace(/^(File|Image):/i, "").trim());
		return img ? `<figure><img loading="lazy" src="${img.thumb}" alt=""><figcaption>${inl(cap || "")}</figcaption></figure>` : "";
	}).join("")}</div>`, true));

	// Modèles {{...}}
	let out = "", i = 0;
	while (i < s.length) {
		const j = s.indexOf("{{", i);
		if (j < 0) { out += s.slice(i); break; }
		out += s.slice(i, j);
		if (s[j + 2] === "{") { out += "{"; i = j + 1; continue; } // {{{param}}}
		const k = matchClose(s, j + 2, "{{", "}}");
		if (k < 0) { out += s.slice(j); break; }
		out += template(s.slice(j + 2, k), ctx, hold, sub, inl);
		i = k + 2;
	}
	let html = blocks(out, ctx, hold, inl);
	const re = /\u0001(\d+)\u0001|\u0002(\d+)\u0002/g;
	for (let n = 0; n < 20 && re.test(html); n++) html = html.replace(re, (_, a, b) => raws[a ?? b]);
	return html;
}

function infobox(kind, named, ctx, inl) {
	const title = named.name || named.title || ctx.title.replace(/^Archive:/, "");
	const img = named.image ? ctx.image(named.image.replace(/^(File|Image):/i, "").replace(/\[\[|\]\]/g, "").split("|")[0].trim()) : null;
	const rows = Object.entries(named).filter(([k, v]) => v && !/^(name|title|image|link|imagecaption)$/.test(k) && !k.startsWith("/"))
		.map(([k, v]) => `<tr><th>${esc(pretty(k))}</th><td>${inl(v)}</td></tr>`).join("");
	return `<aside class="infobox"><div class="ib-kind">${esc(kind)}</div><div class="ib-title">${esc(title)}</div>${img ? `<img src="${img.thumb}" alt="">` : ""}<table>${rows}</table></aside>`;
}

function template(body, ctx, hold, sub, inl) {
	const parts = splitTop(body);
	const name = parts[0].trim();
	const lname = name.toLowerCase().replace(/^template:/, "");
	const { named, pos } = parseParams(parts.slice(1));
	if (lname === "pagename") return ctx.title.replace(/^Archive:/, "");
	if (lname === "sitename" || lname === ":{{sitename") return "The Cycle Wiki";
	if (lname === "gamename") return "The Cycle";
	if (lname === "!") return "|";
	if (/^#ev:youtube/.test(lname)) { const id = name.split(":").pop() || pos[0]; return hold(`<a class="ext" href="https://www.youtube.com/watch?v=${esc((pos[0] && name.endsWith("youtube")) ? pos[0] : id)}" target="_blank">▶ Vidéo YouTube</a>`); }
	if (/^(nav |template:nav |patch notes header|compare legend|stub|translation stub|material map|doc|missing data|notice)/.test(lname)) return "";
	if (lname === "infobox weapon detail") {
		const rows = Object.entries(named).filter(([k, v]) => v && k !== "name").map(([k, v]) => `<tr><th>${esc(k)}</th><td>${esc(v)}</td></tr>`).join("");
		return hold(`<details class="detail"><summary>Données brutes : ${esc(named.name || "")}</summary><table class="wt small">${rows}</table></details>`, true);
	}
	if (lname.startsWith("infobox")) {
		const cell = (v) => sub(v).replace(/^<p>([\s\S]*)<\/p>$/, "$1");
		return hold(infobox(name.replace(/^infobox\s*/i, "") || "Fiche", named, ctx, cell), true);
	}
	if (lname === "update history") return hold(`<div class="history">${sub(named.update || pos.join("|"))}</div>`, true);
	if (lname === "item link") { const t = pos[0] || ""; return hold(link(t, t, ctx)); }
	if (lname === "fp icon") {
		const img = ctx.image(pos[0] || ""); const [target, label] = (pos[1] || "").split(/\{\{!\}\}|\|/);
		return hold(`<span class="fp">${img ? `<img src="${img.thumb}" alt="">` : ""}${link(target, label || target, ctx)}</span>`);
	}
	if (lname === "fp link") return hold(`<a class="ext" href="${esc(named.url || "#")}" target="_blank">${esc(pos[0] || named.url || "")}</a> `);
	if (lname === "quote") return hold(`<blockquote>${inl(pos[0] || named.quote || "")}${pos[1] ? `<cite>— ${inl(pos[1])}</cite>` : ""}</blockquote>`, true);
	if (lname === "faction levels" || lname === "story mission") {
		const head = named.title || `${named.faction || ""} — ${named.level || ""}`;
		const rest = Object.entries(named).filter(([k]) => !/^(title|faction|level|image)$/.test(k));
		return hold(`<section class="card"><h4>${inl(head)}</h4>${rest.map(([k, v]) => `<div class="card-row"><b>${esc(pretty(k))}</b>${sub(v)}</div>`).join("")}</section>`, true);
	}
	if (/^compare .* detail$/.test(lname) || lname === "compare weapon") {
		const target = lname === "compare weapon" ? null : "Archive:" + name;
		return target && ctx.resolve(target) ? hold(`<p class="note">Comparaison : ${link(target, name, ctx)}</p>`, true) : "";
	}
	// Compteurs de matériaux : {{Nickel 0/250}}
	const mat = name.match(/^(.+?)\s+0\/(\d+)$/);
	if (mat) return hold(`<span class="mat">${link(mat[1], mat[1], ctx)} ×${mat[2]}</span> `);
	// Modèle inconnu : on montre ses paramètres
	if (!pos.length && !Object.keys(named).length) return "";
	return hold(`<span class="tpl" title="modèle ${esc(name)}">${[...pos.map(inl), ...Object.entries(named).map(([k, v]) => `${esc(k)} : ${inl(v)}`)].join(" · ")}</span>`);
}

export function link(target, label, ctx) {
	const [t, anchor] = target.split("#");
	const page = t.trim() ? ctx.resolve(t.trim()) : ctx.title;
	const text = esc((label || target).replace(/^Archive:/, ""));
	if (!page) return `<span class="missing" title="page absente de l'archive">${text}</span>`;
	return `<a href="#/${encodeURIComponent(page)}${anchor ? "~" + encodeURIComponent(anchor) : ""}">${text}</a>`;
}

export function inline(t, ctx, hold) {
	let s = t;
	// Liens internes (en boucle : une image peut contenir un lien dans sa légende)
	let prev;
	do { prev = s; s = s.replace(/\[\[([^\[\]]+)\]\]/g, (_, inner) => linkOrFile(inner, ctx, hold)); } while (s !== prev);
	return inlineRest(s, ctx, hold);
}

function linkOrFile(inner, ctx, hold) {
	{
		const [target, ...rest] = inner.split("|");
		const tg = target.trim();
		if (/^:?(category):/i.test(tg)) { if (!tg.startsWith(":")) ctx.cats.add(tg.replace(/^category:/i, "")); return ""; }
		if (/^(file|image):/i.test(tg)) {
			const img = ctx.image(tg.replace(/^(file|image):/i, "").trim());
			if (!img) return "";
			const size = rest.find((r) => /^\d*x?\d+px$/.test(r.trim()));
			const w = size ? parseInt(size.split("x").pop() === size ? size : size.split("x")[0]) || 0 : 0;
			const big = rest.some((r) => /thumb|center|frameless/.test(r)) && (!w || w > 200);
			return hold(`<img class="${big ? "wide" : "icon"}" loading="lazy" src="${img.thumb}" ${w && w <= 200 ? `style="max-width:${w}px"` : ""} alt="">`);
		}
		return hold(link(tg, rest.length ? rest.join("|") : tg, ctx));
	}
}

function inlineRest(s, ctx, hold) {
	// Liens externes
	s = s.replace(/\[(https?:\/\/[^\s\]]+)\s*([^\]]*)\]/g, (_, u, l) => hold(`<a class="ext" href="${esc(u)}" target="_blank">${esc(l || u)}</a>`));
	// HTML autorisé
	s = s.replace(/<(\/?)([a-zA-Z]+)([^>]*)>/g, (m, slash, tag, attrs) => {
		tag = tag.toLowerCase();
		if (!ALLOWED.has(tag)) return "";
		const style = attrs.match(/style\s*=\s*"([^"]*)"/i);
		const color = attrs.match(/color\s*=\s*"?([#\w]+)"?/i);
		let a = "";
		if (style) a = ` style="${style[1].replace(/[^\w\s#:;%.,()-]/g, "").replace(/(position|width|height|float|margin)[^;]*;?/gi, "")}"`;
		else if (tag === "font" && color) a = ` style="color:${color[1]}"`;
		return hold(`<${slash}${tag === "font" ? "span" : tag}${slash ? "" : a}${tag === "br" ? "" : ""}>`);
	});
	s = esc(s);
	s = s.replace(/'''''(.+?)'''''/g, "<b><i>$1</i></b>").replace(/'''(.+?)'''/g, "<b>$1</b>").replace(/''(.+?)''/g, "<i>$1</i>");
	return s;
}

// Rendu des blocs : titres, listes, tableaux, paragraphes
function blocks(s, ctx, hold, inl) {
	const lines = s.split("\n");
	const out = [];
	let para = [];
	const flush = () => { if (para.length) { const p = para.join(" ").trim(); if (p) out.push(`<p>${inl(p)}</p>`); para = []; } };
	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const tl = line.trim();
		if (/^\u0001\d+\u0001$/.test(tl)) { flush(); out.push(tl); continue; }
		const h = tl.match(/^(={1,6})\s*(.+?)\s*\1$/);
		if (h) { flush(); const lvl = Math.min(6, Math.max(2, h[1].length)); const txt = h[2]; out.push(`<h${lvl} id="${encodeURIComponent(txt.replace(/\[\[|\]\]|'''/g, "").replace(/.*\|/, ""))}">${inl(txt)}</h${lvl}>`); continue; }
		if (/^\{\|/.test(tl)) {
			flush();
			let depth = 0, j = i; const tbl = [];
			for (; j < lines.length; j++) { const l = lines[j].trim(); if (/^\{\|/.test(l)) depth++; if (/^\|\}/.test(l)) depth--; tbl.push(lines[j]); if (depth === 0) break; }
			out.push(table(tbl, ctx, hold, inl)); i = j; continue;
		}
		if (/^[*#;:]/.test(tl)) {
			flush();
			const items = [];
			let j = i;
			for (; j < lines.length && /^[*#;:]/.test(lines[j].trim()); j++) items.push(lines[j].trim());
			out.push(list(items, inl)); i = j - 1; continue;
		}
		if (/^-{4,}$/.test(tl)) { flush(); out.push("<hr>"); continue; }
		if (tl === "") { flush(); continue; }
		para.push(line);
	}
	flush();
	return out.join("\n");
}

function list(items, inl) {
	let html = "", stack = [];
	const tagOf = (c) => (c === "#" ? "ol" : c === ";" || c === ":" ? "dl" : "ul");
	for (const it of items) {
		const m = it.match(/^([*#;:]+)\s*(.*)$/);
		const marks = m[1], txt = m[2];
		while (stack.length > marks.length) html += `</${tagOf(stack.pop())}>`;
		while (stack.length < marks.length) { const c = marks[stack.length]; stack.push(c); html += `<${tagOf(c)}>`; }
		const last = marks[marks.length - 1];
		html += last === ";" ? `<dt>${inl(txt)}</dt>` : last === ":" ? `<dd>${inl(txt)}</dd>` : `<li>${inl(txt)}</li>`;
	}
	while (stack.length) html += `</${tagOf(stack.pop())}>`;
	return html;
}

function table(lines, ctx, hold, inl) {
	// Retire la première et la dernière ligne, gère les tableaux imbriqués en les rendant à part
	const rows = []; let row = null, cell = null, caption = "";
	const body = lines.slice(1, -1);
	const pushCell = () => { if (cell && row) row.push(cell); cell = null; };
	for (let i = 0; i < body.length; i++) {
		const tl = body[i].trim();
		if (/^\{\|/.test(tl)) { // imbriqué
			let depth = 0, j = i; const sub = [];
			for (; j < body.length; j++) { const l = body[j].trim(); if (/^\{\|/.test(l)) depth++; if (/^\|\}/.test(l)) depth--; sub.push(body[j]); if (depth === 0) break; }
			if (!cell) { if (!row) { row = []; } cell = { th: false, attrs: "", lines: [] }; }
			cell.lines.push(table(sub, ctx, hold, inl).trim());
			i = j; continue;
		}
		if (/^\|\+/.test(tl)) { caption = tl.slice(2); continue; }
		if (/^\|-/.test(tl)) { pushCell(); if (row) rows.push(row); row = []; continue; }
		if (/^[|!]/.test(tl)) {
			pushCell(); if (!row) row = [];
			const th = tl[0] === "!";
			const cells = tl.slice(1).split(th ? /!!|\|\|/ : /\|\|/);
			cells.forEach((c, n) => {
				const parts = splitTop(c);
				let attrs = "", content = c;
				if (parts.length > 1 && /=/.test(parts[0]) && !/\[\[|\{\{/.test(parts[0])) { attrs = parts[0]; content = parts.slice(1).join("|"); }
				const obj = { th, attrs, lines: [content] };
				if (n < cells.length - 1) row.push(obj); else cell = obj;
			});
			continue;
		}
		if (cell) cell.lines.push(body[i]);
	}
	pushCell(); if (row && row.length) rows.push(row);
	const attr = (a) => { const cs = a.match(/colspan\s*=\s*"?(\d+)/i), rs = a.match(/rowspan\s*=\s*"?(\d+)/i); return (cs ? ` colspan="${cs[1]}"` : "") + (rs ? ` rowspan="${rs[1]}"` : ""); };
	const renderCell = (c) => {
		const txt = c.lines.join("\n").trim();
		const html = blocks(txt, ctx, hold, inl).replace(/^<p>([\s\S]*)<\/p>$/, "$1");
		return `<${c.th ? "th" : "td"}${attr(c.attrs)}>${html}</${c.th ? "th" : "td"}>`;
	};
	const html = `<div class="tw"><table class="wt">${caption ? `<caption>${inl(caption)}</caption>` : ""}${rows.filter((r) => r.length).map((r) => `<tr>${r.map(renderCell).join("")}</tr>`).join("")}</table></div>`;
	return hold(html, true);
}
