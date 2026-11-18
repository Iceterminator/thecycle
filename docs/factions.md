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
