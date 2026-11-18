# Tempêtes (Grande Marée)

Code : `systems/storm/storm_manager.gd` · Données : `data/storm/*.tres` (`StormPhaseData`), `data/rules/match.tres` (`storm_monster_mult`)

## Implémenté
- Tempête sur toute la carte (plus de zone qui se referme), sans dégâts.
- Annonce `warning_time` s avant (bandeau vert), transition ciel / brume / pluie / éclairs sur `fade_time`.
- Phase 1 : démarre à 10:00 et dure jusqu'à la fin de la partie.
- Pendant la tempête : Éclats d'orage (`shard_count`) et un collecteur (contrat de collecte).
- Monstres plus vigilants et plus rapides (`storm_monster_mult`).

## Reste à faire
- Ambiance jour → tempête → nuit (après 16:00) en transitions douces.
- Ressenti à vérifier en jeu : lisibilité sous la pluie, nombre et place des éclats.

## Règles du jeu original : à compléter
