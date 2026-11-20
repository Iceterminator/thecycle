# Pistolet à fléchettes — génération procédurale (API de données bpy / bmesh, pas de bpy.ops).
# Exécution : STAGE = "blockout" | "full" ; FINAL = True applique les modificateurs.
import bpy, bmesh, math
from mathutils import Vector

ASSET = "ASSET_PistoletFlechettes"
PREFIX = "FLE_"
LENGTH = 0.30                      # longueur totale réelle (m), arrière -> bout du canon
S = LENGTH / 1073.0                # mètres par pixel : 0,30 m = 1073 px (arrière -> bout du canon) sur la photo
AXIS = 407                         # ligne du canon sur la photo (px)
REAR, FRONT = 494, 1484            # arrière et nez du corps (px)
SCENE = bpy.data.scenes.get("Arme_flechettes") or bpy.data.scenes.new("Arme_flechettes")
STAGE = globals().get("STAGE", "blockout")
FINAL = globals().get("FINAL", False)
GAME = globals().get("GAME", False)    # version jeu : moins de sections, chanfreins à 2 segments
Q = 0.5 if GAME else 1.0


def P(px, py):
	"""Pixel de l'image -> position (x avant, z haut), axe du canon à z = 0."""
	return Vector(((px - 1000) * S, 0.0, -(py - AXIS) * S))


def catmull(pts, n=10):
	out = []
	q = [pts[0]] + pts + [pts[-1]]
	for i in range(1, len(q) - 2):
		p0, p1, p2, p3 = [Vector(p) for p in q[i - 1:i + 3]]
		for k in range(n):
			t = k / n
			out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
	out.append(pts[-1])
	return out


def interp(curve, x):
	for (x0, y0), (x1, y1) in zip(curve, curve[1:]):
		if x0 <= x <= x1 and x1 != x0:
			return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
	return curve[0][1] if x < curve[0][0] else curve[-1][1]


# --- Contours mesurés sur la photo de profil (docs : masque + liserés détectés en vert, px pleine résolution) ---
TOP = catmull([(494, 378), (500, 352), (516, 319), (536, 296), (556, 280), (576, 268), (596, 257), (616, 249), (636, 243), (656, 236), (696, 226), (736, 217), (776, 209), (816, 203), (856, 198), (896, 195), (936, 194), (976, 195), (1016, 197), (1056, 200), (1096, 203), (1136, 209), (1176, 216), (1216, 225), (1256, 236), (1296, 248), (1336, 262), (1376, 278), (1416, 296), (1446, 312), (1466, 332), (1478, 360), (1484, 410)])
BOT = catmull([(494, 378), (500, 400), (516, 438), (536, 450), (556, 463), (576, 482), (620, 494), (680, 500), (736, 508), (776, 518), (816, 530), (900, 545), (1000, 560), (1076, 571), (1116, 564), (1176, 549), (1236, 538), (1296, 527), (1356, 522), (1396, 530), (1436, 546), (1462, 549), (1476, 528), (1484, 410)])
LOW = catmull([(494, 392), (520, 394), (560, 396), (600, 397), (640, 399), (680, 402), (720, 406), (760, 413), (800, 426), (840, 444), (880, 468), (920, 495), (960, 517), (985, 500), (1012, 472), (1100, 473), (1200, 470), (1290, 466), (1370, 478), (1440, 496), (1484, 505)])
SLINE = catmull([(600, 254), (620, 269), (640, 301), (660, 321), (680, 333), (700, 340), (720, 342), (760, 336), (800, 326), (840, 316), (880, 310), (920, 308), (960, 308), (1000, 312), (1040, 322), (1080, 335), (1120, 353), (1160, 372), (1200, 388), (1240, 398), (1280, 404), (1320, 406), (1484, 406)])
PANEL_LOW = catmull([(650, 238), (680, 268), (700, 282), (780, 283), (820, 270), (860, 264), (940, 260), (980, 248), (1005, 224)])
GRIP_BACK = catmull([(500, 592), (516, 599), (536, 602), (556, 596), (576, 586), (596, 575), (616, 563), (636, 552), (656, 544), (676, 538), (696, 535), (716, 534), (736, 537), (756, 551), (776, 572), (796, 602), (806, 630)])   # (py, px)
GRIP_FRONT = catmull([(500, 726), (516, 724), (536, 725), (556, 714), (576, 713), (596, 710), (616, 712), (636, 707), (656, 701), (676, 694), (696, 686), (716, 678), (736, 673), (756, 672), (776, 675), (796, 670), (806, 650)])
GRIP_SEAM = catmull([(500, 638), (505, 641), (520, 651), (535, 656), (550, 657), (565, 655), (580, 650), (595, 641), (610, 628), (625, 615), (640, 606), (655, 599), (670, 593), (685, 590), (700, 590), (715, 592), (730, 597), (745, 605), (760, 615), (775, 632), (806, 640)])
PW = 2.7      # exposant de super-ellipse des sections (plus grand = plus « carré »)
GRIP_HALF_WIDTH = 0.019


# =====================================================================
# Scène
# =====================================================================

def clear_scene():
	for o in list(SCENE.collection.all_objects):
		if o.type in ('MESH', 'EMPTY', 'CURVE'):
			bpy.data.objects.remove(o, do_unlink=True)
	for coll in (bpy.data.meshes, bpy.data.curves):
		for d in list(coll):
			if d.users == 0:
				coll.remove(d)


def new_object(name, mesh, root):
	o = bpy.data.objects.new(PREFIX + name, mesh)
	SCENE.collection.objects.link(o)
	o.parent = root
	return o


def mesh_from_bm(name, bm):
	me = bpy.data.meshes.new(PREFIX + name)
	bm.to_mesh(me)
	bm.free()
	return me


def smooth(me, angle=40):
	me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
	me.set_sharp_from_angle(angle=math.radians(angle))


def add_bevel(o, width, segments=3, angle=30):
	b = o.modifiers.new("Chanfrein", 'BEVEL')
	b.width = width
	b.segments = segments
	b.limit_method = 'ANGLE'
	b.angle_limit = math.radians(angle)
	b.harden_normals = False
	return b


def add_solidify(o, thickness):
	s = o.modifiers.new("Epaisseur", 'SOLIDIFY')
	s.thickness = thickness
	s.offset = -1.0
	s.use_even_offset = True
	return s


def bbox_world(o):
	bpy.context.view_layer.update()
	pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
	return Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))), \
		Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))


# =====================================================================
# Géométrie de base
# =====================================================================

def se(c):
	"""Composante de super-ellipse."""
	return math.copysign(abs(c) ** (2 / PW), c)


def se_inv(v):
	return math.copysign(abs(v) ** (PW / 2), v)


def body_sections(n=None):
	n = n or int(150 * Q)
	out = []
	for i in range(n + 1):
		t = i / n
		px = REAR + 2 + (FRONT - REAR - 4) * (0.5 - 0.5 * math.cos(t * math.pi))
		top, bot = interp(TOP, px), interp(BOT, px)
		hh = max((bot - top) / 2, 1.5) * S
		zc = -((top + bot) / 2 - AXIS) * S
		u = (px - REAR) / (FRONT - REAR)
		hw = min(0.5 * hh, 0.03) * math.sin(min(max(u, 0.0), 1.0) * math.pi) ** 0.3 + 0.0008
		out.append((px, (px - 1000) * S, zc, hh, hw))
	return out


def angle_of_height(z, zc, hh, side_right=True):
	v = max(-1.0, min(1.0, (z - zc) / hh))
	return math.asin(max(-1.0, min(1.0, se_inv(v))))


def panel_beta(px, zc, hh):
	"""Demi-angle du panneau du dessus : son bord latéral suit PANEL_LOW (mesuré), nul ailleurs."""
	if not (652 < px < 1003):
		return 1e-5
	a = angle_of_height(-(interp(PANEL_LOW, px) - AXIS) * S, zc, hh)
	return max(math.pi / 2 - a, 1e-5)


def s_angle(px, zc, hh):
	"""Angle du joint en S : part du sommet (px 600) et descend en douceur jusqu'au canon."""
	if px <= 590 or px > FRONT - 4:
		return math.pi / 2
	a = angle_of_height(-(interp(SLINE, max(px, 600)) - AXIS) * S, zc, hh)
	t = min(max((px - 590) / 40, 0.0), 1.0)
	t = t * t * (3 - 2 * t)
	return math.pi / 2 + (a - math.pi / 2) * t


def arc(a0, a1, n):
	return [a0 + (a1 - a0) * k / n for k in range(n)]


def body_grid(split):
	"""Grille du corps. Colonnes calées sur les joints (bas gris, bande blanche, haut blanc, panneau).
	Retourne {région: bmesh} si split, sinon un seul bmesh fermé. Régions : 0 bas, 1 bande, 2 haut, 3 panneau."""
	NB, NU, NP, NL = [max(4, int(c * Q)) for c in (16, 18, 12, 26)]
	regions = [1] * NB + [2] * NU + [3] * NP + [2] * NU + [1] * NB + [0] * NL
	rings = []
	for (px, x, zc, hh, hw) in body_sections():
		al = max(angle_of_height(-(interp(LOW, px) - AXIS) * S, zc, hh), -math.pi / 2 + 1e-4)
		be = panel_beta(px, zc, hh)
		a_s = max(al + 1e-4, min(s_angle(px, zc, hh), math.pi / 2 - be - 1e-4))
		angs = arc(al, a_s, NB) + arc(a_s, math.pi / 2 - be, NU) + arc(math.pi / 2 - be, math.pi / 2 + be, NP) \
			+ arc(math.pi / 2 + be, math.pi - a_s, NU) + arc(math.pi - a_s, math.pi - al, NB) + arc(math.pi - al, 2 * math.pi + al, NL)
		rings.append([(x, hw * se(math.cos(a)), zc + hh * se(math.sin(a))) for a in angs])
	R = len(regions)
	wanted = sorted(set(regions)) if split else [None]
	result = {}
	for reg in wanted:
		bm = bmesh.new()
		vs = [[bm.verts.new(p) for p in r] for r in rings]
		for i in range(len(vs) - 1):
			for k in range(R):
				if reg is not None and regions[k] != reg:
					continue
				bm.faces.new((vs[i][k], vs[i][(k + 1) % R], vs[i + 1][(k + 1) % R], vs[i + 1][k]))
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
		bmesh.ops.dissolve_degenerate(bm, dist=2e-5, edges=bm.edges)
		bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
		result[reg] = bm
	return result if split else result[None]


def grip_grid(split):
	"""Crosse : sections horizontales le long de py. Régions : 0 avant (gris), 1 arrière (blanc)."""
	NF, NR = [max(6, int(c * Q)) for c in (22, 28)]
	regions = [0] * NF + [1] * NR
	rings = []
	n = int(80 * Q)
	for i in range(n + 1):
		py = 500 + (812 - 500) * (0.5 - 0.5 * math.cos(math.pi * i / n))
		bx, fx = interp(GRIP_BACK, py), interp(GRIP_FRONT, py)
		xc, hx = (bx + fx) / 2, (fx - bx) / 2
		end = max(0.0, (py - 792) / 20)                  # fond arrondi
		k = math.sqrt(max(1 - end * end, 0.0)) if end > 0 else 1.0
		hw = GRIP_HALF_WIDTH * max(k, 0.05)
		hxs = hx * max(0.35 + 0.65 * k, 0.05)
		u = max(-0.98, min(0.98, (interp(GRIP_SEAM, py) - xc) / hx))
		ab = math.acos(se_inv(u))
		angs = arc(-ab, ab, NF) + arc(ab, 2 * math.pi - ab, NR)
		z = -(py - AXIS) * S
		rings.append([((xc - 1000) * S + hxs * S * se(math.cos(a)), hw * se(math.sin(a)), z) for a in angs])
	R = len(regions)
	result = {}
	for reg in ([0, 1] if split else [None]):
		bm = bmesh.new()
		vs = [[bm.verts.new(p) for p in r] for r in rings]
		for i in range(len(vs) - 1):
			for kk in range(R):
				if reg is not None and regions[kk] != reg:
					continue
				bm.faces.new((vs[i][kk], vs[i + 1][kk], vs[i + 1][(kk + 1) % R], vs[i][(kk + 1) % R]))
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
		bmesh.ops.dissolve_degenerate(bm, dist=2e-5, edges=bm.edges)
		result[reg] = bm
	return result if split else result[None]


def prism_bm(outline_px, half_w, origin=Vector()):
	"""Pièce plate : contour (px, py) extrudé sur ±half_w (origine déplacée en `origin`)."""
	bm = bmesh.new()
	ring = [bm.verts.new(P(*q) - origin + Vector((0, -half_w, 0))) for q in outline_px]
	f = bm.faces.new(ring)
	ext = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
		v.co.y += 2 * half_w
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def tube_bm(x0, x1, r_out, r_in, segs=40):
	"""Tube le long de X, alésé (face avant annulaire, fond fermé)."""
	bm = bmesh.new()
	def circle(x, r):
		return [bm.verts.new((x, r * math.cos(2 * math.pi * k / segs), r * math.sin(2 * math.pi * k / segs))) for k in range(segs)]
	o0, o1, i1, i0 = circle(x0, r_out), circle(x1, r_out), circle(x1, r_in), circle(x1 - 0.02, r_in)
	for k in range(segs):
		n = (k + 1) % segs
		bm.faces.new((o0[k], o0[n], o1[n], o1[k]))       # extérieur
		bm.faces.new((o1[k], o1[n], i1[n], i1[k]))       # couronne avant
		bm.faces.new((i1[k], i1[n], i0[n], i0[k]))       # âme
	bm.faces.new(o0[::-1])
	bm.faces.new(i0)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


# =====================================================================
# Étapes
# =====================================================================

def create_blockout(root):
	parts = {}
	parts["Corps"] = new_object("Corps", mesh_from_bm("Corps", body_grid(False)), root)
	parts["Crosse"] = new_object("Crosse", mesh_from_bm("Crosse", grip_grid(False)), root)
	parts["Puits"] = new_object("Puits", mesh_from_bm("Puits", prism_bm([(812, 528), (1066, 566), (1070, 600), (1060, 606), (916, 624), (900, 662), (856, 662), (846, 604), (828, 556)], 0.02)), root)
	parts["Detente"] = new_object("Detente", mesh_from_bm("Detente", prism_bm([(733, 520), (760, 522), (765, 560), (762, 598), (745, 603), (736, 596), (748, 574), (746, 545)], 0.0055)), root)
	# Chargeur : origine en haut au centre, posé sous le puits (calculé)
	mag_top = P(985, 625)
	mag = new_object("Chargeur", mesh_from_bm("Chargeur", prism_bm([(902, 650), (1068, 600), (1150, 843), (993, 932)], 0.016, mag_top)), root)
	lo, hi = bbox_world(parts["Puits"])
	mag.location = Vector((mag_top.x, 0.0, lo.z + 37 * S))   # haut du chargeur 37 px au-dessus du bas du puits (mesuré)
	parts["Chargeur"] = mag
	mlo, _ = bbox_world(mag)
	base_top = P(1070, 880)
	base = new_object("Chargeur_culot", mesh_from_bm("Chargeur_culot", prism_bm([(989, 926), (1151, 834), (1186, 876), (1176, 895), (1000, 972), (992, 955)], 0.0185, base_top)), root)
	base.location = Vector((mag.location.x + (base_top - mag_top).x, 0.0, mlo.z + 52 * S))   # milieu du haut du culot 52 px au-dessus du point le plus bas du verre (mesuré)
	parts["Culot"] = base
	# Canon : sort de l'avant du corps (calculé)
	blo, bhi = bbox_world(parts["Corps"])
	x0 = bhi.x - 0.012
	parts["Canon"] = new_object("Canon", mesh_from_bm("Canon", tube_bm(x0, x0 + 0.012 + 80 * S, 37 * S, 16 * S)), root)
	return parts


def setup_materials():
	def mat(name, color, metal, rough, rough_var, bump, scale, emit=None, strength=0.0, alpha=1.0, transmission=0.0):
		m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
		m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		out = nt.nodes.new("ShaderNodeOutputMaterial")
		bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
		nt.links.new(bsdf.outputs[0], out.inputs[0])
		coord = nt.nodes.new("ShaderNodeTexCoord")
		noise = nt.nodes.new("ShaderNodeTexNoise")
		noise.inputs["Scale"].default_value = scale
		noise.inputs["Detail"].default_value = 8.0
		nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
		ramp = nt.nodes.new("ShaderNodeValToRGB")
		ramp.color_ramp.elements[0].position = 0.35
		ramp.color_ramp.elements[0].color = (rough - rough_var,) * 3 + (1,)
		ramp.color_ramp.elements[1].position = 0.7
		ramp.color_ramp.elements[1].color = (rough + rough_var,) * 3 + (1,)
		nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
		nt.links.new(ramp.outputs["Color"], bsdf.inputs["Roughness"])
		fine = nt.nodes.new("ShaderNodeTexNoise")
		fine.inputs["Scale"].default_value = scale * 12
		nt.links.new(coord.outputs["Object"], fine.inputs["Vector"])
		bmp = nt.nodes.new("ShaderNodeBump")
		bmp.inputs["Strength"].default_value = bump
		bmp.inputs["Distance"].default_value = 0.0005
		nt.links.new(fine.outputs["Fac"], bmp.inputs["Height"])
		nt.links.new(bmp.outputs["Normal"], bsdf.inputs["Normal"])
		bsdf.inputs["Base Color"].default_value = (*color, 1)
		bsdf.inputs["Metallic"].default_value = metal
		bsdf.inputs["Alpha"].default_value = alpha
		bsdf.inputs["Transmission Weight"].default_value = transmission
		if emit:
			bsdf.inputs["Emission Color"].default_value = (*emit, 1)
			bsdf.inputs["Emission Strength"].default_value = strength
		if alpha < 1.0:
			m.surface_render_method = 'BLENDED'
			m.use_backface_culling = False
		return m
	return {
		"blanc": mat("FLE_Plastique_blanc", (0.80, 0.80, 0.77), 0.0, 0.18, 0.06, 0.08, 40),
		"gris": mat("FLE_Plastique_gris", (0.22, 0.23, 0.24), 0.0, 0.5, 0.1, 0.15, 30),
		"panneau": mat("FLE_Panneau_givre", (0.26, 0.29, 0.32), 0.0, 0.42, 0.08, 0.1, 25),
		"lueur": mat("FLE_Lueur_verte", (0.12, 1.0, 0.45), 0.0, 0.3, 0.05, 0.02, 20, (0.12, 1.0, 0.45), 6.0),
		"acier": mat("FLE_Acier_brosse", (0.62, 0.63, 0.66), 1.0, 0.28, 0.08, 0.2, 60),
		"sombre": mat("FLE_Acier_sombre", (0.05, 0.05, 0.055), 0.9, 0.4, 0.1, 0.2, 60),
		"verre": mat("FLE_Verre_vert", (0.35, 1.0, 0.65), 0.0, 0.08, 0.04, 0.02, 15, (0.25, 0.85, 0.55), 1.2, 0.55, 0.0),
		"flechette": mat("FLE_Flechette", (0.75, 0.76, 0.8), 1.0, 0.25, 0.06, 0.1, 80),
	}


def assign(o, *mats):
	o.data.materials.clear()
	for m in mats:
		o.data.materials.append(m)


def seam_tube_bm(points, normals, radius, sink, segs=8):
	"""Tube lumineux posé dans un joint : cercle balayé le long de `points`, enfoncé de `sink`."""
	bm = bmesh.new()
	rings = []
	for i, (p, n) in enumerate(zip(points, normals)):
		t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
		n = (n - t * n.dot(t)).normalized()
		b = t.cross(n)
		c = p - n * sink
		rings.append([bm.verts.new(c + (n * math.cos(2 * math.pi * k / segs) + b * math.sin(2 * math.pi * k / segs)) * radius) for k in range(segs)])
	for i in range(len(rings) - 1):
		for k in range(segs):
			bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
	bm.faces.new(rings[0][::-1])
	bm.faces.new(rings[-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def body_seam(px_from, px_to, curve, side):
	"""Points et normales du joint du corps (sur la surface) le long de `curve` (px -> py) ; None = joint en S."""
	pts, nrm = [], []
	for (px, x, zc, hh, hw) in body_sections(300):
		if not (px_from <= px <= px_to):
			continue
		a = s_angle(px, zc, hh) if curve is None else angle_of_height(-(interp(curve, px) - AXIS) * S, zc, hh)
		y, z = side * hw * se(math.cos(a)), zc + hh * se(math.sin(a))
		pts.append(Vector((x, y, z)))
		nrm.append(Vector((0.0, y / (hw * hw), (z - zc) / (hh * hh))).normalized())
	return pts, nrm


def grip_seam(side):
	pts, nrm = [], []
	for i in range(121):
		py = 505 + (772 - 505) * i / 120
		bx, fx = interp(GRIP_BACK, py), interp(GRIP_FRONT, py)
		xc, hx = (bx + fx) / 2, (fx - bx) / 2
		u = max(-0.98, min(0.98, (interp(GRIP_SEAM, py) - xc) / hx))
		ab = math.acos(se_inv(u))
		x = (xc - 1000) * S + hx * S * se(math.cos(ab))
		y = side * GRIP_HALF_WIDTH * se(math.sin(ab))
		pts.append(Vector((x, y, -(py - AXIS) * S)))
		nrm.append(Vector(((x - (xc - 1000) * S) / (hx * S) ** 2, y / GRIP_HALF_WIDTH ** 2, 0.0)).normalized())
	return pts, nrm


def shell(name, bm, root, mat_list, thickness=0.0022, bevel=0.0006, recess=0.0):
	if recess > 0:
		bm.normal_update()
		for v in bm.verts:
			v.co -= v.normal * recess
	o = new_object(name, mesh_from_bm(name, bm), root)
	smooth(o.data, 40)
	add_solidify(o, thickness)
	add_bevel(o, bevel, 2 if GAME else 3, 30)
	assign(o, *mat_list)
	return o


def add_details(root, parts, M):
	# Coques séparées : chaque pièce a son épaisseur, ses bords chanfreinés forment les joints.
	for key in ("Corps", "Crosse"):
		bpy.data.objects.remove(parts.pop(key), do_unlink=True)
	body = body_grid(True)
	parts["Coque_basse"] = shell("Coque_basse", body[0], root, [M["gris"]])
	parts["Coque_bande"] = shell("Coque_bande", body[1], root, [M["blanc"]])
	parts["Coque_haute"] = shell("Coque_haute", body[2], root, [M["blanc"]])
	parts["Panneau"] = shell("Panneau", body[3], root, [M["panneau"]], 0.0015, 0.0005, recess=0.0007)
	grip = grip_grid(True)
	parts["Crosse_avant"] = shell("Crosse_avant", grip[0], root, [M["gris"]])
	parts["Crosse_arriere"] = shell("Crosse_arriere", grip[1], root, [M["blanc"]])
	# Liserés lumineux dans les joints (deux côtés)
	for side, tag in ((-1, "g"), (1, "d")):
		for name, seam in (("Lisere_S", body_seam(606, 1438, None, side)), ("Lisere_bas", body_seam(505, 978, LOW, side)), ("Lisere_crosse", grip_seam(side))):
			o = new_object(f"{name}_{tag}", mesh_from_bm(name, seam_tube_bm(seam[0], seam[1], 0.0019, 0.0004)), root)
			smooth(o.data, 60)
			assign(o, M["lueur"])
	# Bouton de chargeur
	btn = new_object("Bouton_chargeur", mesh_from_bm("Bouton", prism_bm([(852, 598), (880, 594), (882, 607), (854, 611)], 0.0207)), root)
	add_bevel(btn, 0.0005, 2, 30)
	assign(btn, M["sombre"])
	# Bague claire sur le haut du culot : placée par rapport au culot (son origine = milieu de son bord haut)
	ring = new_object("Culot_bague", mesh_from_bm("Bague", prism_bm([(989, 46), (1151, -46), (1153, -36), (991, 56)], 0.0192, P(1070, 0))), root)
	ring.location = parts["Culot"].location.copy()
	add_bevel(ring, 0.0006, 2, 30)
	assign(ring, M["blanc"])
	# Fléchettes : une seule, répétée par un modificateur ARRAY dans le chargeur
	mag = parts["Chargeur"]
	top = P(985, 625)
	a, b = P(935, 700) - top, P(1000, 690) - top
	d = (b - a).normalized()
	bm = bmesh.new()
	ax = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
	def piece(r1, r2, length, start):
		m = ax.copy()
		m.translation = a + d * (start + length / 2)
		bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r1, radius2=r2, depth=length, matrix=m)
	shaft = (b - a).length
	piece(0.0013, 0.0013, shaft, 0.0)
	piece(0.0024, 0.0, 0.006, shaft)
	piece(0.0028, 0.0012, 0.004, 0.0)
	dart = bpy.data.objects.new(PREFIX + "Flechettes", mesh_from_bm("Flechette", bm))
	SCENE.collection.objects.link(dart)
	dart.parent = mag
	smooth(dart.data, 40)
	arr = dart.modifiers.new("Rangee", 'ARRAY')
	arr.count = 8
	arr.use_relative_offset = False
	arr.use_constant_offset = True
	arr.constant_offset_displace = (P(1056, 862) - top) * (30.0 / 237.0)
	assign(dart, M["flechette"])
	# Chanfreins des pièces rigides + matériaux
	for key, w, mats in (("Puits", 0.0015, ["gris"]), ("Detente", 0.0008, ["gris"]), ("Chargeur", 0.0015, ["verre"]), ("Culot", 0.0012, ["gris"]), ("Canon", 0.0006, ["acier"])):
		add_bevel(parts[key], w, 3, 30)
		assign(parts[key], *[M[m] for m in mats])
	parts["Flechettes"] = dart


def apply_modifiers():
	"""Applique les modificateurs (API de données) : maillage évalué -> nouveau maillage."""
	dg = bpy.context.evaluated_depsgraph_get()
	for o in list(SCENE.collection.all_objects):
		if o.type == 'MESH' and o.modifiers and o.name.startswith(PREFIX):
			me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
			old = o.data
			o.modifiers.clear()
			o.data = me
			if old.users == 0:
				bpy.data.meshes.remove(old)


def build():
	clear_scene()
	root = bpy.data.objects.new(ASSET, None)
	SCENE.collection.objects.link(root)
	root.empty_display_size = 0.05
	parts = create_blockout(root)
	for o in parts.values():
		smooth(o.data, 40)
	if STAGE == "full":
		M = setup_materials()
		add_details(root, parts, M)
		if FINAL:
			apply_modifiers()
	return root, parts


root, parts = build()
print("blockout", {k: tuple(round(v, 3) for v in o.dimensions) for k, o in parts.items()})
