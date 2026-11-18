class_name Allies
extends RefCounted
## Qui est allié avec qui (étape 9) : coéquipiers d'escouade ou partenaires de pacte.
## Utilisé partout où ça compte : pas de dégâts entre alliés, soin du Rayon vital, carte,
## alarme du scanner. Pour relever un joueur à terre : l'escouade, ou le partenaire de pacte
## si Config.PACT_PARTNER_IS_ALLY.


static func allied(a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or a == b:
		return false
	return SquadManager.same_squad(a, b) or PactManager.allied(a, b)


static func can_revive(a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or a == b:
		return false
	return SquadManager.same_squad(a, b) or (Config.PACT_PARTNER_IS_ALLY and PactManager.allied(a, b))
