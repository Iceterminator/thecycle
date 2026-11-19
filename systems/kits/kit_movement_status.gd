extends RefCounted
## Texte du HUD pour les capacités de mouvement du kit (ressource et recharges).


## Texte du HUD : ressource et recharges de la capacité du kit.
static func text(m: KitMovement) -> String:
	match m.mobility():
		KitData.MobilityType.JETPACK:
			var dive := "prête (Accroupi en l'air)" if m._jet.dive_cd <= 0.0 else "%d s" % ceili(m._jet.dive_cd)
			return "Jetpack %d %%  —  Plongée %s" % [roundi(100.0 * m.fuel / maxf(m._jet.fuel_max(), 1.0)), dive]
		KitData.MobilityType.JETBOOSTERS:
			return "Propulseurs %d %%" % roundi(100.0 * m.fuel / maxf(m._jet.fuel_max(), 1.0))
		KitData.MobilityType.DASH:
			var full := int(m.charges)
			return "Énergie %s" % ("■".repeat(full) + "□".repeat(maxi(int(m._dash.charges_max()) - full, 0)))
		KitData.MobilityType.SUPER_JUMP:
			var jump := "prêt (maintenir Saut)" if m._bastion.super_cd <= 0.0 else "%d s" % ceili(m._bastion.super_cd)
			var punch := "prêt (V)" if m._bastion.punch_cd <= 0.0 else "%d s" % ceili(m._bastion.punch_cd)
			return "Super saut %s  —  Coup de poing %s" % [jump, punch]
	return ""
