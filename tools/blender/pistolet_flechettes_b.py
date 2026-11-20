# Pistolet à fléchettes, version B — pipeline « blender-director / hard-surface / texture-workflow / godot-export ».
# Différences avec la version A (pistolet_flechettes.py) :
#   - contours extraits AUTOMATIQUEMENT du masque de la photo (pas de coordonnées recopiées à la main) ;
#   - pièces = cages basse résolution + SOLIDIFY + SUBSURF (rebords arrondis = joints) ;
#   - version haute (SUBSURF 3) cuite vers la version jeu (SUBSURF 1) : couleur, ORM, normales, émission.
# Usage (dans Blender) : exec avec globals STAGE = "measure" | "build" | "bake" | "export".
import bpy, bmesh, math, json, os
import numpy as np
from mathutils import Vector

REF_IMAGE = globals().get("REF_IMAGE", "")
OUT_DIR = globals().get("OUT_DIR", "")
STAGE = globals().get("STAGE", "build")
ASSET = "SM_Weapon_FlechettePistol_B"
SCENE_NAME = "Pistolet_B"
LENGTH = 0.30                      # longueur réelle (m), arrière du corps -> bout du canon
MEASURE_FILE = os.path.join(OUT_DIR, "pistolet_b_mesures.json")


# =====================================================================
# 1. Mesures automatiques sur la photo
# =====================================================================

def _dil(a, r):
	out = a.copy(); pad = np.pad(a, r)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				out |= pad[r + dy:r + dy + a.shape[0], r + dx:r + dx + a.shape[1]]
	return out


def _runs(v, gap=1, minlen=1):
	idx = np.nonzero(v)[0]; out = []; i = 0
	while i < len(idx):
		j = i
		while j + 1 < len(idx) and idx[j + 1] - idx[j] <= gap:
			j += 1
		if j - i + 1 >= minlen:
			out.append((int(idx[i]), int(idx[j])))
		i = j + 1
	return out


def _smooth(vals, k=5):
	v = np.array(vals, float)
	if len(v) < k:
		return v
	pad = np.pad(v, k // 2, mode="edge")
	return np.convolve(pad, np.ones(k) / k, mode="valid")


def top_of(mask, x):
	"""Haut de la silhouette dans la colonne x."""
	return int(np.nonzero(mask[:, x])[0].min())


def segs_bottom(mask, x):
	"""Bas du premier segment de silhouette (le corps) dans la colonne x."""
	return _runs(mask[:, x], gap=3)[0][1]


def measure():
	img = bpy.data.images.load(REF_IMAGE, check_existing=True)
	w, h = img.size
	px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)[::-1, :, :3]
	bg = np.median(np.concatenate([px[:40].reshape(-1, 3), px[-40:].reshape(-1, 3)]), 0)
	mask = np.abs(px - bg).max(-1) > 0.12
	mask = _dil(~_dil(~mask, 2), 2)
	r, g, b = px[..., 0], px[..., 1], px[..., 2]
	glow = (g - r > 0.09) & (g - b > 0.02) & (g > 0.5) & mask
	xs = np.nonzero(mask.any(0))[0]; ys = np.nonzero(mask.any(1))[0]
	x0, x1 = int(xs.min()), int(xs.max())
	# Canon : colonnes de droite dont la hauteur est faible
	heights = [(x, mask[:, x].sum()) for x in range(x0, x1 + 1)]
	nose = max(x for x, hgt in heights if hgt > 150)                    # nez du corps
	barrel_rows = np.nonzero(mask[:, nose + 25])[0]
	axis = float((barrel_rows.min() + barrel_rows.max()) / 2)
	barrel_r = float((barrel_rows.max() - barrel_rows.min()) / 2)
	# Corps : haut = 1re ligne ; bas = bas du premier segment (au-dessus de la crosse / du puits)
	top, bot = {}, {}
	for x in range(x0, nose + 1, 4):
		segs = _runs(mask[:, x], gap=3)
		if not segs:
			continue
		top[x] = segs[0][0]
		bot[x] = segs[0][1]
	# le bas du corps n'est fiable qu'à l'arrière (avant la crosse) et devant le puits du chargeur ;
	# entre les deux il est caché : interpolation lisse
	keys = sorted(bot)
	grip_x = min(x for x in keys if bot[x] - top[x] > 330)                # début crosse (corps + crosse)
	front_free = min(x for x in keys if x > grip_x + 200 and bot[x] - top[x] < 400 and all(bot[k] - top[k] < 400 for k in keys if k >= x))
	for x in keys:
		if grip_x - 8 <= x < front_free:
			t = (x - (grip_x - 8)) / (front_free - grip_x + 8)
			bot[x] = bot[grip_x - 8] + (bot[front_free] - bot[grip_x - 8]) * (t ** 0.8)
	# Liserés : centres des bandes vertes par colonne (2 bandes : S en haut, bas en dessous)
	# Liseré en S : bande la plus haute, à partir du point où elle quitte le sommet (x > 615)
	# Liseré bas : suivi par continuité depuis l'arrière (évite de sauter sur le liseré de la crosse)
	s_line, low_line = {}, {}
	last_low = None
	for x in range(x0, nose, 4):
		c = [(a + bb) / 2 for a, bb in _runs(glow[:, x], gap=4, minlen=3) if a < 560]
		if not c:
			continue
		if x > 615 and c[0] < (380 if x < 700 else 420):
			s_line[x] = c[0]
			rest = c[1:]
		else:
			rest = c
		if x < 980 and rest:
			cand = min(rest, key=lambda v: abs(v - last_low) if last_low is not None else v)
			if last_low is None or abs(cand - last_low) < 25:
				low_line[x] = cand; last_low = cand
	# Panneau givré du dessus : son bord bas est un joint sombre (minimum de luminance sous le sommet)
	lum0 = px.mean(-1)
	panel = {}
	for x in range(650, 1012, 6):
		t0 = top_of(mask, x)
		col = lum0[t0 + 8:t0 + 100, x]
		panel[x] = float(t0 + 8 + int(np.argmin(col)))
	# Menton gris de l'avant (sans liseré) : on remonte depuis le bas du corps tant que c'est gris
	lum = px.mean(-1)
	chin = {}
	for x in range(d_front := 1020, nose - 6, 6):
		y = int(segs_bottom(mask, x)) - 4
		while y > 300 and lum[y, x] < 0.55:
			y -= 1
		chin[x] = float(y)
	# Crosse : bords par ligne entre le bas du corps et le bas de la crosse (zone x < grip_x + 200)
	grip = {}
	for y in range(int(bot[grip_x - 8]) + 10, int(ys.max())):
		segs = [s for s in _runs(mask[y, x0:grip_x + 220], gap=2) if s[1] - s[0] > 20]
		if segs:
			s = segs[0]
			grip[y] = (s[0] + x0, s[1] + x0)
	grip_seam = {}
	for y in grip:
		c = [(a + bb) / 2 + x0 for a, bb in _runs(glow[y, x0:grip_x + 220], gap=4, minlen=3)]
		if c:
			grip_seam[y] = c[0]
	data = dict(size=[w, h], x0=x0, nose=nose, x1=x1, axis=axis, barrel_r=barrel_r, grip_x=grip_x, front_free=front_free,
		top={k: float(v) for k, v in top.items()}, bot={k: float(v) for k, v in bot.items()},
		s_line=s_line, low_line={**low_line, **chin}, glow_low_end=max(low_line), panel=panel, grip={k: list(v) for k, v in grip.items()}, grip_seam=grip_seam)
	with open(MEASURE_FILE, "w") as f:
		json.dump(data, f)
	return data


# =====================================================================
# 2. Construction (cages + SOLIDIFY + SUBSURF)
# =====================================================================

def load_measures():
	with open(MEASURE_FILE) as f:
		d = json.load(f)
	for k in ("top", "bot", "s_line", "low_line", "grip", "grip_seam", "panel"):
		d[k] = {int(float(a)): v for a, v in d[k].items()}
	return d


class Frame:
	"""Repère image -> mètres : x vers l'avant, z vers le haut, origine = centre de la prise en main."""
	def __init__(self, d):
		self.S = LENGTH / (d["x1"] - d["x0"])
		self.ox = d["grip_x"] + 60
		self.oz = d["axis"] + 140
	def p(self, px, py):
		return Vector(((px - self.ox) * self.S, 0.0, -(py - self.oz) * self.S))


def curve_fn(dct, smooth=5):
	ks = sorted(dct)
	vs = _smooth([dct[k] for k in ks], smooth)
	def f(x):
		return float(np.interp(x, ks, vs))
	f.range = (ks[0], ks[-1]) if ks else (0, 0)
	return f


def scene():
	sc = bpy.data.scenes.get(SCENE_NAME) or bpy.data.scenes.new(SCENE_NAME)
	if bpy.context.window:
		bpy.context.window.scene = sc
	return sc


def collection(sc, name):
	c = bpy.data.collections.get(name)
	if c is None:
		c = bpy.data.collections.new(name)
		sc.collection.children.link(c)
	return c


def clear(sc):
	for o in list(sc.collection.all_objects):
		if o.name.startswith(("SM_", "ASSET_", "EMPTY_")) and not o.name.startswith("SM_Weapon_FlechettePistol_A"):
			bpy.data.objects.remove(o, do_unlink=True)
	for coll in (bpy.data.meshes,):
		for dd in list(coll):
			if dd.users == 0:
				coll.remove(dd)


def mat(name, color, metal, rough, emit=None, strength=0.0, alpha=1.0):
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree; nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputMaterial"); bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
	nt.links.new(bsdf.outputs[0], out.inputs[0])
	coord = nt.nodes.new("ShaderNodeTexCoord")
	noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 35; noise.inputs["Detail"].default_value = 6
	nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
	ramp = nt.nodes.new("ShaderNodeMapRange")
	ramp.inputs["To Min"].default_value = rough * 0.8; ramp.inputs["To Max"].default_value = min(rough * 1.25, 1)
	nt.links.new(noise.outputs["Fac"], ramp.inputs["Value"]); nt.links.new(ramp.outputs["Result"], bsdf.inputs["Roughness"])
	fine = nt.nodes.new("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 400
	nt.links.new(coord.outputs["Object"], fine.inputs["Vector"])
	bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.05; bump.inputs["Distance"].default_value = 0.0003
	nt.links.new(fine.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	bsdf.inputs["Base Color"].default_value = (*color, 1); bsdf.inputs["Metallic"].default_value = metal
	bsdf.inputs["Alpha"].default_value = alpha
	if emit:
		bsdf.inputs["Emission Color"].default_value = (*emit, 1); bsdf.inputs["Emission Strength"].default_value = strength
	if alpha < 1:
		m.surface_render_method = 'BLENDED'; m.use_backface_culling = False
	return m


def srgb(hexcode):
	c = [int(hexcode[i:i + 2], 16) / 255 for i in (1, 3, 5)]
	return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


def materials():
	return {
		"blanc": mat("MAT_Plastic_White_Satin", srgb("#dcdcd8"), 0.0, 0.25),
		"gris": mat("MAT_Plastic_Grey_Matte", srgb("#8e9598"), 0.0, 0.55),
		"givre": mat("MAT_Plastic_Frosted_Panel", srgb("#b4b9bc"), 0.0, 0.45),
		"lueur": mat("MAT_Emissive_Strip_Mint", srgb("#7ef2c4"), 0.0, 0.3, srgb("#7ef2c4"), 5.0),
		"acier": mat("MAT_Metal_Steel_Brushed", srgb("#c9c9cb"), 1.0, 0.3),
		"sombre": mat("MAT_Metal_Recess_Dark", srgb("#24292c"), 0.6, 0.5),
		"verre": mat("MAT_Glass_Mint", srgb("#a8e8cf"), 0.0, 0.08, srgb("#5ad8a6"), 0.8, alpha=0.5),
	}


def obj(sc, coll, name, bm, parent, mats):
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); coll.objects.link(o); o.parent = parent
	me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
	for m in mats:
		me.materials.append(m)
	return o


def stack(o, thickness, subsurf, crease_rims=0.0):
	"""Pile hard-surface : épaisseur (rebords) -> SUBSURF (arrondi des rebords = joints) -> normales pondérées."""
	if thickness:
		s = o.modifiers.new("Epaisseur", 'SOLIDIFY'); s.thickness = thickness; s.offset = -1; s.use_even_offset = True
		s.use_rim = True
	ss = o.modifiers.new("Lissage", 'SUBSURF'); ss.levels = subsurf; ss.render_levels = subsurf
	ss.boundary_smooth = 'PRESERVE_CORNERS'
	wn = o.modifiers.new("Normales", 'WEIGHTED_NORMAL'); wn.keep_sharp = True


def ring_cage(sections, regions_fn, n_each):
	"""Cage en anneaux : sections = [(x, zc, hh, hw)], régions = intervalles d'angle par section.
	Renvoie {région: bmesh} (bandes ouvertes, chaque région séparée)."""
	PW = 2.6
	def se(c): return math.copysign(abs(c) ** (2 / PW), c)
	rings = []
	for sec in sections:
		x, zc, hh, hw = sec
		bounds = regions_fn(sec)          # [(id, a0, a1), ...] couvrant 2π
		ring = []
		for (rid, a0, a1), n in zip(bounds, n_each):
			for k in range(n):
				a = a0 + (a1 - a0) * k / n
				ring.append((rid, (x, hw * se(math.cos(a)), zc + hh * se(math.sin(a)))))
		rings.append(ring)
	ids = sorted(set(rid for rid, _ in rings[0]))
	out = {}
	R = len(rings[0])
	for rid in ids:
		bm = bmesh.new()
		vs = [[bm.verts.new(p) for _, p in ring] for ring in rings]
		for i in range(len(vs) - 1):
			for k in range(R):
				if rings[i][k][0] != rid:
					continue
				bm.faces.new((vs[i][k], vs[i][(k + 1) % R], vs[i + 1][(k + 1) % R], vs[i + 1][k]))
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
		bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
		bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
		out[rid] = bm
	return out


def asin_h(z, zc, hh, PW=2.6):
	v = max(-1.0, min(1.0, (z - zc) / hh))
	return math.asin(math.copysign(abs(v) ** (PW / 2), v))


def build(game=True):
	d = load_measures()
	F = Frame(d); S = F.S
	sc = scene(); clear(sc)
	col = collection(sc, "COL_Pistolet_B")
	root = bpy.data.objects.new(ASSET, None); col.objects.link(root)
	M = materials()
	sub = 1 if game else 3
	TOP, BOT = curve_fn(d["top"], 5), curve_fn(d["bot"], 3)
	SL, LL = curve_fn(d["s_line"], 9), curve_fn(d["low_line"], 13)
	# panneau : le joint mesuré est bruité -> polynôme de degré 3 sur la plage fiable (version C)
	pk = [k for k in sorted(d["panel"]) if 680 <= k <= 1005]
	pc = np.polyfit(pk, [d["panel"][k] for k in pk], 3)
	PN = lambda x: float(np.polyval(pc, x))
	PN.range = (pk[0], pk[-1])
	x0, nose = d["x0"], d["nose"]
	DOME = 34   # px : l'avant du corps s'arrondit en dôme jusqu'au canon (remplace la pièce de nez)
	# --- Corps : coques (bas gris / bande blanche / haut blanc / panneau) ---
	sections = []
	N = 22 if game else 34
	for i in range(N + 1):
		t = i / N
		px = x0 + 3 + (nose - x0 - 3) * (0.5 - 0.5 * math.cos(math.pi * t))
		top, bot = TOP(min(px, nose - DOME)), BOT(min(px, nose - DOME))
		hh = max((bot - top) / 2, 2) * S
		zc = F.p(px, (top + bot) / 2).z
		u = (px - x0) / (nose - x0)
		hw = min(0.5 * hh, 0.03) * math.sin(min(max(u, 0.0), 1.0) * math.pi) ** 0.3 + 0.001
		if px > nose - DOME:   # dôme avant : rayon qui se referme en quart de cercle
			q = (px - (nose - DOME)) / DOME
			f = math.sqrt(max(1.0 - q * q, 0.0)) * 0.92 + 0.08
			hh *= f; hw = max(hw, min(0.5 * hh / f, 0.03) * 0.6) * f
			zc = zc + (F.p(0, d["axis"]).z - zc) * q
		sections.append((F.p(px, 0).x, zc, hh, hw))
	s_lo, s_hi = SL.range
	def regions(sec):
		x, zc, hh, hw = sec
		px = x / S + F.ox
		al = max(asin_h(F.p(px, LL(px)).z, zc, hh), -math.pi / 2 + 0.02)
		if s_lo + 8 < px < nose - 4:
			k = min(1.0, (px - s_lo - 8) / 40)
			a_s = math.pi / 2 + (asin_h(F.p(px, SL(px)).z, zc, hh) - math.pi / 2) * k
		else:
			a_s = math.pi / 2
		# panneau givré : demi-angle autour du sommet, bord latéral sur le joint mesuré
		p_lo, p_hi = PN.range
		be = 1e-4
		if p_lo + 4 < px < p_hi - 4:
			be = max(math.pi / 2 - asin_h(F.p(px, PN(px)).z, zc, hh), 1e-4)
		a_s = max(al + 0.02, min(a_s, math.pi / 2 - be - 0.01))
		return [(1, al, a_s), (2, a_s, math.pi / 2 - be), (3, math.pi / 2 - be, math.pi / 2 + be), (2, math.pi / 2 + be, math.pi - a_s),
			(1, math.pi - a_s, math.pi - al), (0, math.pi - al, 2 * math.pi + al)]
	shells = ring_cage(sections, regions, [3, 3, 4, 3, 3, 8] if game else [6, 5, 6, 5, 6, 10])
	names = {0: ("SM_Corps_Bas", "gris"), 1: ("SM_Corps_Bande", "blanc"), 2: ("SM_Corps_Haut", "blanc"), 3: ("SM_Corps_Panneau", "givre")}
	parts = {}
	for rid, bm in shells.items():
		n, m = names[rid]
		if rid == 3:   # panneau légèrement en retrait
			bm.normal_update()
			for v in bm.verts:
				v.co -= v.normal * 0.0008
		parts[n] = obj(sc, col, n, bm, root, [M[m]])
		stack(parts[n], 0.0018 if rid == 3 else 0.0025, sub)
	# --- Crosse : 2 coques (avant gris, arrière blanc) le long de y ---
	GR = d["grip"]; gy = sorted(GR)
	GS = curve_fn(d["grip_seam"], 9)
	BK = curve_fn({y: GR[y][0] for y in gy}, 9); FR = curve_fn({y: GR[y][1] for y in gy}, 9)
	gsec = []
	Ng = 14 if game else 22
	for i in range(Ng + 1):
		py = gy[0] - 30 + (gy[-1] - gy[0] + 30) * (0.5 - 0.5 * math.cos(math.pi * i / Ng))
		bx, fx = BK(py), FR(py)
		end = max(0.0, (py - (gy[-1] - 18)) / 18)
		k = math.sqrt(max(1 - end * end, 0.0))
		gsec.append((py, bx, fx, max(k, 0.06)))
	def grip_cage():
		PW = 2.6
		def se(c): return math.copysign(abs(c) ** (2 / PW), c)
		out = {0: bmesh.new(), 1: bmesh.new()}
		rings = []
		for py, bx, fx, k in gsec:
			xc, hx = (bx + fx) / 2, (fx - bx) / 2 * (0.4 + 0.6 * k)
			u = max(-0.95, min(0.95, (GS(py) - xc) / max(hx, 1)))
			ab = math.acos(math.copysign(abs(u) ** (PW / 2), u))
			angs = [(0, -ab + 2 * ab * j / 5) for j in range(5)] + [(1, ab + (2 * math.pi - 2 * ab) * j / 8) for j in range(8)]
			z = F.p(0, py).z
			rings.append([(rid, ((xc - F.ox) * S + hx * S * se(math.cos(a)), 0.018 * k * se(math.sin(a)), z)) for rid, a in angs])
		R = len(rings[0])
		for rid, bm in out.items():
			vs = [[bm.verts.new(p) for _, p in r] for r in rings]
			for i in range(len(vs) - 1):
				for j in range(R):
					if rings[i][j][0] == rid:
						bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][(j + 1) % R], vs[i][(j + 1) % R]))
			bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
		return out
	for rid, bm in grip_cage().items():
		n, m = ("SM_Crosse_Avant", "gris") if rid == 0 else ("SM_Crosse_Arriere", "blanc")
		parts[n] = obj(sc, col, n, bm, root, [M[m]])
		stack(parts[n], 0.0025, sub)
	# --- Pièces plates : contours pris sur le masque (enveloppe d'une zone de l'image) ---
	parts.update(flat_parts(sc, col, root, d, F, M, sub))
	# --- Canon : tube alésé posé au nez (position calculée depuis la bbox du corps) ---
	bpy.context.view_layer.update()
	nose_x = max((parts["SM_Corps_Haut"].matrix_world @ Vector(c)).x for c in parts["SM_Corps_Haut"].bound_box)
	parts["SM_Canon"] = barrel(sc, col, root, M, F, d, nose_x)
	# --- Liserés : tubes émissifs sur les joints ---
	parts.update(strips(sc, col, root, M, F, d, sections, SL, LL, GS, gsec))
	return root, parts


def mask_outline(d, F, x_range, y_range, step=6):
	"""Contour (gauche puis droite) de la silhouette dans une fenêtre de l'image -> polygone en px."""
	m = np.load(os.path.join(OUT_DIR, "v2_mask.npy"))
	left, right = [], []
	for y in range(y_range[0], y_range[1] + 1, step):
		row = m[y, x_range[0]:x_range[1]]
		idx = np.nonzero(row)[0]
		if len(idx) > 4:
			left.append((x_range[0] + int(idx.min()), y)); right.append((x_range[0] + int(idx.max()), y))
	return left + right[::-1]


def flat(sc, col, root, F, name, poly_px, half_w, m, sub, bevel=True):
	bm = bmesh.new()
	vs = [bm.verts.new(F.p(*q) + Vector((0, -half_w, 0))) for q in poly_px]
	f = bm.faces.new(vs)
	ext = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
		v.co.y += 2 * half_w
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	o = obj(sc, col, name, bm, root, [m])
	if bevel:
		bv = o.modifiers.new("Chanfrein", 'BEVEL'); bv.width = 0.0015; bv.segments = 2 if sub == 1 else 4; bv.limit_method = 'ANGLE'
	wn = o.modifiers.new("Normales", 'WEIGHTED_NORMAL'); wn.keep_sharp = True
	o.data.set_sharp_from_angle(angle=math.radians(35))
	return o


def flat_parts(sc, col, root, d, F, M, sub):
	gx, ff = d["grip_x"], d["front_free"]
	m = np.load(os.path.join(OUT_DIR, "v2_mask.npy"))
	out = {}
	# Chargeur : partie basse (sous y 640) entre x gx+250 et ff+150 -> verre ; bas (dernière bande) -> culot
	ys = [y for y in range(640, m.shape[0]) if m[y, gx + 250:ff + 200].any()]
	y_end = ys[-1]
	glass = mask_outline(d, F, (gx + 250, ff + 200), (640, y_end - 70))
	cap = mask_outline(d, F, (gx + 250, ff + 200), (y_end - 75, y_end))
	out["SM_Chargeur_Verre"] = flat(sc, col, root, F, "SM_Chargeur_Verre", glass[::2] if len(glass) > 60 else glass, 0.016, M["verre"], sub)
	out["SM_Chargeur_Culot"] = flat(sc, col, root, F, "SM_Chargeur_Culot", cap, 0.0185, M["gris"], sub)
	# Fléchettes : une fléchette répétée par ARRAY le long du bord gauche du chargeur (pente mesurée)
	rows = [y for y in range(680, y_end - 90, 2) if m[y, gx + 250:ff + 200].any()]
	lx = {y: gx + 250 + int(np.nonzero(m[y, gx + 250:ff + 200])[0].min()) for y in (rows[0], rows[-1])}
	step = (rows[-1] - rows[0]) / 7.0
	start = F.p(lx[rows[0]] + 28, rows[0] + 10)
	drift = (F.p(lx[rows[-1]] + 28, rows[-1] + 10) - start) / 7.0
	bm = bmesh.new()
	length, d_dir = 0.018, Vector((1.0, 0.0, 0.12)).normalized()
	for r1, r2, ln, off in ((0.0012, 0.0012, length, 0.0), (0.0022, 0.0, 0.005, length), (0.0026, 0.001, 0.004, 0.0)):
		mtx = d_dir.to_track_quat('Z', 'Y').to_matrix().to_4x4()
		mtx.translation = start + d_dir * (off + ln / 2)
		bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r1, radius2=r2, depth=ln, matrix=mtx)
	dart = obj(sc, col, "SM_Chargeur_Flechettes", bm, root, [M["acier"]])
	arr = dart.modifiers.new("Rangee", 'ARRAY'); arr.count = 8
	arr.use_relative_offset = False; arr.use_constant_offset = True; arr.constant_offset_displace = drift
	out["SM_Chargeur_Flechettes"] = dart
	# Puits : entre le bas du corps et y 660, x de gx+190 à ff+60
	well = mask_outline(d, F, (gx + 200, ff + 60), (int(d["bot"][min(d["bot"], key=lambda k: abs(k - (gx + 300)))]) - 20, 655))
	out["SM_Puits"] = flat(sc, col, root, F, "SM_Puits", well[::2], 0.02, M["gris"], sub)
	# Détente : petite zone entre la crosse et le puits
	trig = mask_outline(d, F, (gx + 120, gx + 180), (int(d["bot"][min(d["bot"], key=lambda k: abs(k - (gx + 150)))]) - 5, 605), step=4)
	if len(trig) >= 4:
		out["SM_Detente"] = flat(sc, col, root, F, "SM_Detente", trig, 0.0055, M["gris"], sub)
	return out


def barrel(sc, col, root, M, F, d, nose_x):
	S = F.S
	r_out, r_in = d["barrel_r"] * S, d["barrel_r"] * S * 0.45
	z = F.p(0, d["axis"]).z
	xa, xb = nose_x - 0.01, F.p(d["x1"], 0).x
	bm = bmesh.new(); seg = 24
	def circ(x, r): return [bm.verts.new((x, r * math.cos(2 * math.pi * k / seg), z + r * math.sin(2 * math.pi * k / seg))) for k in range(seg)]
	a, b2, c, e = circ(xa, r_out), circ(xb, r_out), circ(xb, r_in), circ(xb - 0.015, r_in)
	for k in range(seg):
		n = (k + 1) % seg
		bm.faces.new((a[k], a[n], b2[n], b2[k])); bm.faces.new((b2[k], b2[n], c[n], c[k])); bm.faces.new((c[k], c[n], e[n], e[k]))
	bm.faces.new(a[::-1]); bm.faces.new(e)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	o = obj(sc, col, "SM_Canon", bm, root, [M["acier"]])
	bv = o.modifiers.new("Chanfrein", 'BEVEL'); bv.width = 0.0008; bv.segments = 2; bv.limit_method = 'ANGLE'
	o.modifiers.new("Normales", 'WEIGHTED_NORMAL').keep_sharp = True
	o.data.set_sharp_from_angle(angle=math.radians(35))
	return o


def tube(points, normals, radius, sink, segs=6):
	bm = bmesh.new(); rings = []
	for i, (p, n) in enumerate(zip(points, normals)):
		t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
		n = (n - t * n.dot(t)).normalized(); bb = t.cross(n); c = p - n * sink
		rings.append([bm.verts.new(c + (n * math.cos(2 * math.pi * k / segs) + bb * math.sin(2 * math.pi * k / segs)) * radius) for k in range(segs)])
	for i in range(len(rings) - 1):
		for k in range(segs):
			bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
	bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
	return bm


def strips(sc, col, root, M, F, d, sections, SL, LL, GS, gsec):
	"""Liserés posés sur les joints : on prend les sommets de la coque au joint (surface réelle après lissage)."""
	S = F.S; PW = 2.6
	def se(c): return math.copysign(abs(c) ** (2 / PW), c)
	out = {}
	def body_pts(curve, px_a, px_b, side):
		pts, nr = [], []
		for i in range(41):
			px = px_a + (px_b - px_a) * i / 40
			x = F.p(px, 0).x
			for s0, s1 in zip(sections, sections[1:]):
				if s0[0] <= x <= s1[0]:
					t = (x - s0[0]) / (s1[0] - s0[0] + 1e-9)
					zc, hh, hw = [s0[j] + (s1[j] - s0[j]) * t for j in (1, 2, 3)]
					a = asin_h(F.p(px, curve(px)).z, zc, hh)
					y, z = side * hw * se(math.cos(a)), zc + hh * se(math.sin(a))
					pts.append(Vector((x, y, z))); nr.append(Vector((0, y / hw ** 2, (z - zc) / hh ** 2)).normalized())
					break
		return pts, nr
	s_a, s_b = SL.range[0], min(SL.range[1], d["nose"] - 30); l_a, l_b = LL.range[0], d["glow_low_end"]   # liseré bas : seulement là où il brille sur la photo
	for side, tag in ((-1, "G"), (1, "D")):
		for name, (pts, nr) in (("SM_Lisere_S_" + tag, body_pts(SL, s_a + 10, s_b, side)), ("SM_Lisere_Bas_" + tag, body_pts(LL, l_a, l_b, side))):
			if len(pts) > 2:
				out[name] = obj(sc, col, name, tube(pts, nr, 0.0018, 0.0006), root, [M["lueur"]])
		pts, nr = [], []
		for py, bx, fx, k in gsec[2:-2]:
			xc, hx = (bx + fx) / 2, (fx - bx) / 2 * (0.4 + 0.6 * k)
			u = max(-0.95, min(0.95, (GS(py) - xc) / max(hx, 1)))
			ab = math.acos(math.copysign(abs(u) ** (PW / 2), u))
			x = (xc - F.ox) * S + hx * S * se(math.cos(ab)); y = side * 0.018 * k * se(math.sin(ab))
			pts.append(Vector((x, y, F.p(0, py).z))); nr.append(Vector((math.cos(ab), side * math.sin(ab), 0)).normalized())
		if len(pts) > 2:
			out["SM_Lisere_Crosse_" + tag] = obj(sc, col, "SM_Lisere_Crosse_" + tag, tube(pts, nr, 0.0018, 0.0006), root, [M["lueur"]])
	return out


# =====================================================================
# 3. Cuisson (texture-workflow) : version haute -> version jeu, atlas unique
# =====================================================================

TEX = 2048
GLASS = "SM_Chargeur_Verre"


def _freeze(sc, objs, name):
	"""Applique les modificateurs (maillage évalué) et fusionne les objets en un seul."""
	dg = bpy.context.evaluated_depsgraph_get()
	bm = bmesh.new(); mats = []
	for o in objs:
		me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
		me.transform(o.matrix_world)
		slots = []                       # index local -> index dans la liste commune (sans doublon)
		for m in me.materials:
			if m not in mats:
				mats.append(m)
			slots.append(mats.index(m))
		local = [p.material_index for p in me.polygons]
		before = len(bm.faces)
		bm.from_mesh(me)
		bm.faces.ensure_lookup_table()
		for i, li in enumerate(local):
			bm.faces[before + i].material_index = slots[li] if slots else 0
		bpy.data.meshes.remove(me)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	for m in mats:
		me.materials.append(m)
	o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
	return o


def bake_all():
	sc = scene()
	# Version haute (lissage 3) -> figée sous le nom HI_*
	root, parts = build(game=False)
	hi = _freeze(sc, [o for n, o in parts.items() if n != GLASS], "HI_Pistolet_B")
	# Version jeu
	root, parts = build(game=True)
	lo = _freeze(sc, [o for n, o in parts.items() if n != GLASS], "SM_Weapon_FlechettePistol_B_Coque")
	glass = _freeze(sc, [parts[GLASS]], "SM_Weapon_FlechettePistol_B_Verre")
	for n, o in list(parts.items()):
		bpy.data.objects.remove(o, do_unlink=True)
	lo.parent = root; glass.parent = root
	lo.data.polygons.foreach_set("use_smooth", [True] * len(lo.data.polygons))
	lo.data.set_sharp_from_angle(angle=math.radians(40))
	# UV : dépliage automatique de la version jeu
	vl = bpy.context.view_layer
	for o in sc.objects: o.select_set(False)
	vl.objects.active = lo; lo.select_set(True)
	bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
	bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
	bpy.ops.uv.pack_islands(margin=0.004)
	bpy.ops.object.mode_set(mode='OBJECT')
	# Images de cuisson
	imgs = {}
	for key, cs in (("BC", 'sRGB'), ("N", 'Non-Color'), ("AO", 'Non-Color'), ("R", 'Non-Color'), ("M", 'Non-Color'), ("E", 'sRGB')):
		im = bpy.data.images.get("T_PistoletB_" + key) or bpy.data.images.new("T_PistoletB_" + key, TEX, TEX, alpha=False)
		im.colorspace_settings.name = cs; imgs[key] = im
	bake_mat = bpy.data.materials.new("MAT_PistoletB_Cuisson"); bake_mat.use_nodes = True
	node = bake_mat.node_tree.nodes.new("ShaderNodeTexImage")
	bake_mat.node_tree.nodes.active = node
	lo.data.materials.clear(); lo.data.materials.append(bake_mat)
	# Cycles, cuisson sélectionnée -> active
	sc.render.engine = 'CYCLES'; sc.cycles.samples = 24; sc.cycles.device = 'CPU'
	bk = sc.render.bake
	bk.use_selected_to_active = True; bk.cage_extrusion = 0.004; bk.max_ray_distance = 0.012; bk.margin = 16
	for o in sc.objects: o.select_set(False)
	hi.select_set(True); lo.select_set(True); vl.objects.active = lo
	def run(key, btype, **kw):
		node.image = imgs[key]
		bpy.ops.object.bake(type=btype, **kw)
	run("BC", 'DIFFUSE', pass_filter={'COLOR'})
	run("N", 'NORMAL')
	run("AO", 'AO')
	run("R", 'ROUGHNESS')
	run("E", 'EMIT')
	# Métal : on fait passer la valeur « Metallic » par l'émission, le temps d'une cuisson
	saved = []
	for m in hi.data.materials:
		b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		saved.append((b, tuple(b.inputs["Emission Color"].default_value), b.inputs["Emission Strength"].default_value))
		v = b.inputs["Metallic"].default_value
		b.inputs["Emission Color"].default_value = (v, v, v, 1); b.inputs["Emission Strength"].default_value = 1.0
	run("M", 'EMIT')
	for b, c, s in saved:
		b.inputs["Emission Color"].default_value = c; b.inputs["Emission Strength"].default_value = s
	# ORM : R = AO, G = rugosité, B = métal
	orm = bpy.data.images.get("T_PistoletB_ORM") or bpy.data.images.new("T_PistoletB_ORM", TEX, TEX, alpha=False)
	orm.colorspace_settings.name = 'Non-Color'
	ch = lambda im: np.array(im.pixels[:], np.float32).reshape(-1, 4)[:, 0]
	pix = np.ones((TEX * TEX, 4), np.float32)
	pix[:, 0], pix[:, 1], pix[:, 2] = ch(imgs["AO"]), ch(imgs["R"]), ch(imgs["M"])
	orm.pixels = pix.ravel()
	for key, im in (("BC", imgs["BC"]), ("N", imgs["N"]), ("ORM", orm), ("E", imgs["E"])):
		im.filepath_raw = os.path.join(OUT_DIR, "T_PistoletB_%s.png" % key); im.file_format = 'PNG'; im.save()
	game_material(lo, imgs["BC"], orm, imgs["N"], imgs["E"])
	bpy.data.objects.remove(hi, do_unlink=True)
	return lo, glass


def game_material(lo, bc, orm, nrm, emi):
	"""Matériau jeu (exportable glTF) : couleur, ORM (AO via glTF Material Output), normales, émission."""
	m = bpy.data.materials.get("MAT_PistoletB") or bpy.data.materials.new("MAT_PistoletB")
	m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputMaterial"); b = nt.nodes.new("ShaderNodeBsdfPrincipled")
	nt.links.new(b.outputs[0], out.inputs[0])
	t_bc = nt.nodes.new("ShaderNodeTexImage"); t_bc.image = bc
	t_orm = nt.nodes.new("ShaderNodeTexImage"); t_orm.image = orm
	t_n = nt.nodes.new("ShaderNodeTexImage"); t_n.image = nrm
	t_e = nt.nodes.new("ShaderNodeTexImage"); t_e.image = emi
	sep = nt.nodes.new("ShaderNodeSeparateColor")
	nm = nt.nodes.new("ShaderNodeNormalMap")
	nt.links.new(t_bc.outputs["Color"], b.inputs["Base Color"])
	nt.links.new(t_orm.outputs["Color"], sep.inputs["Color"])
	nt.links.new(sep.outputs["Green"], b.inputs["Roughness"]); nt.links.new(sep.outputs["Blue"], b.inputs["Metallic"])
	nt.links.new(t_n.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
	nt.links.new(t_e.outputs["Color"], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = 1.0
	# occlusion : groupe « glTF Material Output » reconnu par l'exporteur
	grp = bpy.data.node_groups.get("glTF Material Output")
	if grp is None:
		grp = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
		grp.interface.new_socket("Occlusion", in_out='INPUT', socket_type='NodeSocketFloat')
	gn = nt.nodes.new("ShaderNodeGroup"); gn.node_tree = grp
	nt.links.new(sep.outputs["Red"], gn.inputs["Occlusion"])
	lo.data.materials.clear(); lo.data.materials.append(m)


def bake_ao(size=1024):
	"""Cuisson légère (version C) : occlusion ambiante seule, version haute -> version jeu.
	Les couleurs, l'émission et le métal restent ceux des matériaux (pas de couleur cuite)."""
	sc = scene()
	root, parts = build(game=False)
	hi = _freeze(sc, [o for n, o in parts.items() if n != GLASS], "HI_Pistolet_B")
	root, parts = build(game=True)
	lo = _freeze(sc, [o for n, o in parts.items() if n != GLASS], "SM_Weapon_FlechettePistol_B_Coque")
	glass = _freeze(sc, [parts[GLASS]], "SM_Weapon_FlechettePistol_B_Verre")
	for n, o in list(parts.items()):
		bpy.data.objects.remove(o, do_unlink=True)
	lo.parent = root; glass.parent = root
	for o in (lo, glass):
		o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
		o.data.set_sharp_from_angle(angle=math.radians(40))
	vl = bpy.context.view_layer
	for o in sc.objects: o.select_set(False)
	vl.objects.active = lo; lo.select_set(True)
	bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
	bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
	bpy.ops.uv.pack_islands(margin=0.004)
	bpy.ops.object.mode_set(mode='OBJECT')
	ao = bpy.data.images.get("T_PistoletC_AO")
	if ao: bpy.data.images.remove(ao)
	ao = bpy.data.images.new("T_PistoletC_AO", size, size, alpha=False); ao.colorspace_settings.name = 'Non-Color'
	# matériaux jeu : valeurs constantes reprises des matériaux d'origine + occlusion (texture AO)
	grp = bpy.data.node_groups.get("glTF Material Output")
	if grp is None:
		grp = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
		grp.interface.new_socket("Occlusion", in_out='INPUT', socket_type='NodeSocketFloat')
	new_mats = []
	for src in lo.data.materials:
		sb = next(n for n in src.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		rough = next((n.inputs["To Max"].default_value / 1.25 for n in src.node_tree.nodes if n.type == "MAP_RANGE"), 0.5)
		m = bpy.data.materials.get(src.name + "_Jeu") or bpy.data.materials.new(src.name + "_Jeu")
		m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
		out = nt.nodes.new("ShaderNodeOutputMaterial"); b = nt.nodes.new("ShaderNodeBsdfPrincipled")
		nt.links.new(b.outputs[0], out.inputs[0])
		for k in ("Base Color", "Metallic", "Emission Color", "Emission Strength"):
			b.inputs[k].default_value = sb.inputs[k].default_value
		b.inputs["Roughness"].default_value = rough
		if b.inputs["Metallic"].default_value > 0.9:
			b.inputs["Metallic"].default_value = 0.8   # métal un peu moins pur : pas de canon noir sans reflets
		t = nt.nodes.new("ShaderNodeTexImage"); t.image = ao
		gn = nt.nodes.new("ShaderNodeGroup"); gn.node_tree = grp
		nt.links.new(t.outputs["Color"], gn.inputs["Occlusion"])
		nt.nodes.active = t
		new_mats.append(m)
	for i, m in enumerate(new_mats):   # remplacement emplacement par emplacement : garde l'index de chaque face
		lo.data.materials[i] = m
	# cuisson AO (sélection -> active)
	sc.render.engine = 'CYCLES'; sc.cycles.samples = 32; sc.cycles.device = 'CPU'
	bk = sc.render.bake
	bk.use_selected_to_active = True; bk.cage_extrusion = 0.003; bk.max_ray_distance = 0.008; bk.margin = 8
	for o in sc.objects: o.select_set(False)
	hi.select_set(True); lo.select_set(True); vl.objects.active = lo
	bpy.ops.object.bake(type='AO')
	ao.filepath_raw = os.path.join(OUT_DIR, "T_PistoletC_AO.png"); ao.file_format = 'PNG'; ao.save()
	bpy.data.objects.remove(hi, do_unlink=True)
	return lo, glass


def export_glb(path):
	sc = scene()
	root = bpy.data.objects[ASSET]
	for o in sc.objects: o.select_set(False)
	root.select_set(True)
	for o in root.children_recursive: o.select_set(True)
	bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_active_scene=True, use_selection=True,
		export_apply=True, export_yup=True, export_lights=False, export_cameras=False, export_image_format='AUTO')


if STAGE == "measure":
	r = measure()
	print({k: (v if not isinstance(v, dict) else len(v)) for k, v in r.items()})
elif STAGE == "build":
	root, parts = build(game=globals().get("GAME", True))
	print("pièces", len(parts))
elif STAGE == "bake":
	lo, glass = bake_all()
	print("cuit", len(lo.data.polygons))
elif STAGE == "export":
	export_glb(globals()["GLB_PATH"])
elif STAGE == "bake_ao":
	lo, glass = bake_ao()
	print("AO cuite", len(lo.data.polygons))
