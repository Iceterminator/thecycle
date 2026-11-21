# Factions et progression

Code : `systems/profiles/profile_manager.gd`, `systems/lobby/` · Données : `data/factions/` (3 factions), `data/weapon_mods/`, `data/rules/economy.tres` (`rep_levels`, `preferred_faction_bonus`)

## Implémenté
- 3 factions (nos noms + équivalent d'origine en référence).
- Réputation = Fame des contrats de la faction, +50 % pour la faction de prédilection ; 10 niveaux.
- Déblocages par niveau : kits, capacités, armes de la boutique, mods de kit, mods d'arme.
- Profil JSON par pseudo côté serveur (`user://profiles/`) : réputation, équipement, apparence (`data/appearances/`, choisie dans l'onglet Factions du lobby, "" = automatique), stats.
- Lobby à onglets : Décollage, Équipement, Arsenal, Factions, Escouade.

## Reste à faire
- Récompenses de faction en fin de partie selon la position et l'évac.
- Noms et styles définitifs des factions (question ouverte dans DESIGN).

## Règles du jeu original : à compléter

## Conception détaillée (déplacé de DESIGN.md)

### 12. Factions et progression (hors partie)
- 3 factions inventées (équivalents de Korolev, ICA, Osiris) : puissance lourde, équilibre, technologie.
- Les contrats donnent de la réputation, qui débloque niveau par niveau des armes et gadgets.
- Entre les parties : mods d'armes (voir ci-dessous) et gadgets.
- Sauvegarde côté serveur (JSON par joueur au début, base de données plus tard).
- **Codé à l'étape 9 (18/11/2026)** : Forge Brask (Korolev, id 1 : Forage, Ambrine, Station),
  Lumen (Osiris, id 2 : Relais, Drones, Cœur stellaire), Consortium Vega (ICA, id 3 : collecteurs, Prime).
  Les vrais noms s'affichent pour l'instant (même interrupteur que les armes), nos noms sont prêts dans
  `data/factions/`. Réputation = Fame de contrat de la faction (+50 % pour la faction de prédilection),
  10 niveaux (`Config.economy.rep_levels`). Déblocage par niveau seulement : kits, capacités, armes (boutique),
  cœurs de kit (niveau du kit +2/+4/+6/+8 ; les mods de niveau 1 à 3 sont ouverts à tous). Profil `user://profiles/<pseudo>.json` (réputation, équipement, stats).

## Mods d'arme
- 247 mods dans `data/weapon_mods/`, générés par `tools/wiki_2019/make_weapon_mods.mjs` (`node tools/wiki_2019/make_weapon_mods.mjs` ; ne pas modifier les .tres à la main).
- Un mod = UNE arme (`weapon_id`) et UN emplacement (`slot` : 0 viseur, 1 crosse, 2 corps, 3 chargeur). Au plus un mod par emplacement et par arme, choisi au lobby (listes déroulantes du détail d'arme). Disponible dès que l'arme est débloquée (pas de faction propre).
- Profil : `weapon_mods` = `{ id_arme: { "0": id_mod, "2": id_mod } }` (validé par `ProfileLoadoutRules.clean_weapon_mods` ; ancien format texte ignoré).
- Effets : `WeaponModApply.apply(base, mods)` (resources/) renvoie une copie de la `WeaponData` ; `Weapon.data` et `Player.magazine_for` l'utilisent (cache dans `PlayerState.modded_weapon`), donc identique serveur / clients.
- Clés gérées : `mult` (dégâts, cadence, chargeur, rechargement, visée, dispersion, recul, portée, montée en régime, dégâts contre créatures / joueurs…), `add` (zone d'explosion, rafale), `set` (zoom), `flags`.
- Balles explosives sur arme hitscan : `WeaponData.is_explosive()` = `aoe_damage > 0 et aoe_radius_m > 0` (explosion au point d'impact).
- À faire : `piercing` et `explode_on_impact` (champs stockés, sans comportement) ; `move_speed_multiplier` (stocké, lot « maniement »).

## Mods de kit (4 emplacements)
- Un kit a 4 emplacements, un mod au plus par emplacement, choisis au lobby (listes déroulantes « Cœur », « Niveau 1 » à « Niveau 3 », description en infobulle) :
  - **Cœur** : propre au kit (`KitData.mods`, 4 par kit pour Martinet, Furet, Bastion), débloqué par la réputation (`unlock_level`). « Kit de prospecteur » et « Kit nu » n'en ont pas.
  - **Niveaux 1 à 3** : communs à tous les kits, ouverts à tous (`KitModData`, `data/kit_mods/<id>.tres`, champ `tier`).
- Profil : `loadout.kit_mods = { kit_id: { "core": id, "1": id, "2": id, "3": id } }` (ancien format texte = le cœur). Validation serveur : `systems/profiles/profile_loadout_rules.gd` (`kit_slots`, `kit_mods_error`). La demande du lobby envoie `kit_mod` = les 4 emplacements du kit choisi.
- Effets : `KitController.get_effect` additionne bonus de niveau + cœur + 3 mods (cache dans `kit_controller_effects.gd`). Le texte `mod_ids` (« cœur,n1,n2,n3 ») est synchronisé à tous.
- Effets de combat (`systems/kits/kit_combat_effects.gd`, accessible par `player.kit.combat`) : dégâts subis (`Health`, serveur : en l'air, en sprint via `Player.is_sprinting`, sous le seuil de PV), dégâts infligés (`WeaponDamage` : cumuls d'éliminations, en l'air), soin par élimination, maniement des armes (`WeaponEquip.handling` : rechargement, visée, sortie, recul ; pistolets et Dernier souffle).
- **À faire** : « Concentration » (`interrupt_mult`) est stocké mais sans effet, car aucune interaction n'est interrompue par les dégâts dans le jeu. Les dégâts de capacités / gadgets ne profitent pas de « Rage du chasseur » (seulement les armes).
