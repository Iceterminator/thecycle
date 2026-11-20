extends RefCounted
## Plan de la salle de test (positions locales, identiques sur tous les peers) : zones, rangées de
## l'armurerie (tirées du registre Items), monstres du bestiaire (data/monsters/), étiquettes.

const MONSTRES_DIR := "res://data/monsters/"
const SORTIE := Vector3(0, 0, -6)
const ARMURERIE := Rect2(-70, -60, 64, 52)
const BESTIAIRE := Rect2(6, -60, 64, 52)
const GALERIE := Rect2(-70, 10, 140, 92)
const PAS_OBJET := 2.6        ## m entre deux objets d'une rangée
const PAS_RANGEE := 3.2
const PAS_MONSTRE := 15.0
const NIVEAUX_MONSTRES: Array[int] = [1, 3]


static func zones() -> Array:
	return [["ARMURERIE", ARMURERIE], ["BESTIAIRE (figés)", BESTIAIRE], ["GALERIE", GALERIE]]


## Catégories de l'armurerie : [titre, objets].
static func categories() -> Array:
	var armes: Array[ItemData] = []
	var gadgets: Array[ItemData] = []
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		(gadgets if item.weapon.gadget != WeaponData.GadgetKind.NONE else armes).append(item)
	var objets: Array[ItemData] = []
	for kind in [ItemData.Kind.HEAL, ItemData.Kind.SHIELD_RECHARGE, ItemData.Kind.RESOURCE, ItemData.Kind.CREDITS]:
		objets.append_array(Items.get_items_of_kind(kind))
	return [["ARMES", armes], ["GADGETS", gadgets], ["CAPACITÉS", Items.get_items_of_kind(ItemData.Kind.ABILITY)], ["OBJETS", objets]]


## Objets posés : [id, quantité, position locale].
static func armurerie() -> Array:
	var result: Array = []
	var par_rangee := int((ARMURERIE.size.x - 4.0) / PAS_OBJET)
	var z := ARMURERIE.position.y + 4.0
	for cat: Array in categories():
		var items: Array = cat[1]
		for i in items.size():
			var item: ItemData = items[i]
			var pos := Vector3(ARMURERIE.position.x + 2.0 + (i % par_rangee) * PAS_OBJET, 0.3, z + (i / par_rangee) * PAS_RANGEE)
			result.append([item.id, item.amount if item.kind == ItemData.Kind.CREDITS else (5 if item.kind == ItemData.Kind.RESOURCE else 1), pos])
		z += (ceili(float(items.size()) / par_rangee)) * PAS_RANGEE + 3.0
	return result


## Monstres : [chemin du MonsterData, niveau, position locale].
static func bestiaire() -> Array:
	var result: Array = []
	var i := 0
	for file in ResourceLoader.list_directory(MONSTRES_DIR):
		if not file.ends_with(".tres"):
			continue
		for j in NIVEAUX_MONSTRES.size():
			var pos := Vector3(BESTIAIRE.position.x + 8.0 + i * PAS_MONSTRE, 0.2, BESTIAIRE.position.y + 12.0 + j * 18.0)
			result.append([MONSTRES_DIR + file, NIVEAUX_MONSTRES[j], pos])
		i += 1
	return result


## Textes au sol : [texte, position locale].
static func etiquettes() -> Array:
	var result: Array = []
	var par_rangee := int((ARMURERIE.size.x - 4.0) / PAS_OBJET)
	var z := ARMURERIE.position.y + 4.0
	for cat: Array in categories():
		result.append([cat[0], Vector3(ARMURERIE.position.x + 2.0, 1.4, z - 1.4)])
		z += (ceili(float((cat[1] as Array).size()) / par_rangee)) * PAS_RANGEE + 3.0
	for m: Array in bestiaire():
		var data := load(m[0]) as MonsterData
		result.append(["%s — niveau %d" % [data.display_name if data else "?", m[1]], (m[2] as Vector3) + Vector3(-2.0, 4.5, 0)])
	result.append(["TÉLÉPORTEUR : RETOUR AU LOBBY", SORTIE + Vector3(-3.5, 3.2, 0)])
	return result
