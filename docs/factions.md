# Factions et progression

Code : `systems/profiles/profile_manager.gd`, `systems/lobby/` · Données : `data/factions/` (3 factions), `data/weapon_mods/`, `data/rules/economy.tres` (`rep_levels`, `preferred_faction_bonus`)

## Implémenté
- 3 factions (nos noms + équivalent d'origine en référence).
- Réputation = Fame des contrats de la faction, +50 % pour la faction de prédilection ; 10 niveaux.
- Déblocages par niveau : kits, capacités, armes de la boutique, mods de kit, mods d'arme.
- Profil JSON par pseudo côté serveur (`user://profiles/`) : réputation, équipement, stats.
- Lobby à onglets : Décollage, Équipement, Arsenal, Factions, Escouade.

## Reste à faire
- Récompenses de faction en fin de partie selon la position et l'évac.
- Noms et styles définitifs des factions (question ouverte dans DESIGN).

## Règles du jeu original : à compléter

## Conception détaillée (déplacé de DESIGN.md)

### 12. Factions et progression (hors partie)
- 3 factions inventées (équivalents de Korolev, ICA, Osiris) : puissance lourde, équilibre, technologie.
- Les contrats donnent de la réputation, qui débloque niveau par niveau des armes et gadgets.
- Entre les parties : mods d'armes et gadgets (feu, électricité, poison, chargeurs étendus…).
- Sauvegarde côté serveur (JSON par joueur au début, base de données plus tard).
- **Codé à l'étape 9 (18/11/2026)** : Forge Brask (Korolev, id 1 : Forage, Ambrine, Station),
  Lumen (Osiris, id 2 : Relais, Drones, Cœur stellaire), Consortium Vega (ICA, id 3 : collecteurs, Prime).
  Les vrais noms s'affichent pour l'instant (même interrupteur que les armes), nos noms sont prêts dans
  `data/factions/`. Réputation = Fame de contrat de la faction (+50 % pour la faction de prédilection),
  10 niveaux (`Config.economy.rep_levels`). Déblocage par niveau seulement : kits, capacités, armes (boutique),
  mods de kit (niveau du kit +2/+4/+6/+8), mods d'arme (chargeur étendu libre ; incendie Forge 3,
  électrique Vega 3, toxine Lumen 3). Profil `user://profiles/<pseudo>.json` (réputation, équipement, stats).
