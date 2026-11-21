# Tempêtes (Grande Marée)

Code : `systems/storm/storm_manager.gd` · Données : `data/storm/*.tres` (`StormPhaseData`), `data/rules/match.tres` (`storm_monster_mult`)

## Implémenté
- Tempête sur toute la carte (plus de zone qui se referme), sans dégâts.
- Annonce `warning_time` s avant (bandeau vert), transition ciel / brume / pluie / éclairs sur `fade_time`.
- Phase 1 : démarre à 10:00 et dure jusqu'à la fin de la partie.
- Pendant la tempête : Éclats d'orage (`shard_count`) ; ils se portent, plus de collecteur (voir `docs/quetes.md`, `StormShards`).
- Monstres plus vigilants et plus rapides (`storm_monster_mult`).
- **Surtension** : `surge_lead` s avant le début de chaque tempête (`SurgeCrystals`, voir `docs/quetes.md`).

## Reste à faire
- Ambiance jour → tempête → nuit (après 16:00) en transitions douces.
- Ressenti à vérifier en jeu : lisibilité sous la pluie, nombre et place des éclats.

## Règles du jeu original : à compléter

## Conception détaillée (déplacé de DESIGN.md)

### 8. Tempête
> **Grande Marée (18/11/2026, d'après la vidéo de référence ; remplace la zone qui se referme).** Tempête
> sur **toute la carte**, sans zone ni dégâts. `data/storm/phase_1.tres` : annoncée à **9:00** (bandeau vert
> « La Grande Marée débute dans 60 s »), elle commence à **10:00** et dure jusqu'à la fin. Le ciel passe en 20 s
> au bleu-gris violet : pluie, éclairs violets, brouillard, soleil faible. Les monstres détectent et courent ×1,3
> pendant la tempête (`Config.match_rules.storm_monster_mult`). Au début de la tempête : **12 Éclats d'orage** tombent au hasard sur la carte (signal `Events.storm_started`, `StormShards`) ; ils rapportent des points d'objectif tant qu'on les porte (objectif « Éclats d'orage » à paliers) ; `shard_count` dans `phase_1.tres`.
