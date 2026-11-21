# Créatures (monstres)

Code : `systems/monsters/` (`monster.gd`, `monster_manager.gd`, `monster_camp.gd`) · Données : `data/monsters/` (`MonsterData`, champ `model`), `data/camps/`, `data/rules/match.tres` (niveaux)

## Implémenté
- 8 monstres : Rôdeur (mêlée rapide), Colosse (mêlée lourde), Cracheur (à distance), Tique (apparaît autour des porteurs de Lumicèpes), Gardiens ×3 et Guetteur (robots à distance).
- IA serveur : patrouille, poursuite, préparation du coup visible (voile rouge), recul après un coup, retour au camp.
- Camps de niveau 1 et 2, repeuplés après `camp_respawn_delay` ; navmesh généré depuis les collisions (décor compris).
- Niveaux 1 à 3 selon le temps de partie (PV, dégâts, crédits) ; plus forts pendant la Grande Marée.
- Modèles animés Quaternius (robots du Sci-Fi Essentials Kit) ; sans modèle : capsule colorée.
- Performance (MonsterLod) : `move_and_slide` coûtait ~0,17 ms par monstre (105 monstres = serveur à 8 FPS). Un monstre en patrouille à plus de 50 m de tout joueur avance sans collision, posé sur le relief ; à l'arrêt au sol il ne calcule plus rien ; dès qu'un joueur approche (détection max 31 m), physique normale.
- **Valeurs alignées sur le jeu d'origine** (PV, régénération, dégâts, crédits, XP) :
  | Créature | Rôle d'origine | PV | Régén. | Dégâts | Crédits | XP |
  | --- | --- | --- | --- | --- | --- | --- |
  | Rôdeur | petit mêlée | 200 | 8/s après 3 s | 120 | 10 | 200 |
  | Colosse | gros mêlée | 600 | 20/s après 3 s | 180 | 14 | 300 |
  | Cracheur | cracheur | 450 | 5/s après 8 s | 20 par projectile, salve de 13 (0,08 s) | 10 | 300 |
  Le Colosse lance aussi des projectiles dans l'original : ici il reste en mêlée.
- **Régénération** (`monster_regen.gd`, serveur) : `regen_delay_s` (-1 = aucune) sans dégâts, puis `regen_per_s` PV/s ; un coup relance le délai. La vie est répliquée par le MonsterSync (ON_CHANGE).
- **Salves** : `ranged_burst_count` projectiles espacés de `ranged_burst_interval_s` (`monster_projectiles.gd`), dispersion aléatoire ± 1,5° entre projectiles dès qu'il y en a plus d'un.
- **XP de kit** : `MonsterData.xp × Config.economy.kit_xp_monster_scale` (0,05), minimum 1 ; sans `xp`, ancienne valeur fixe `kit_xp_monster_kill`. Le monstre est retrouvé par `Events.monster_killed(id)` -> `data/monsters/<id>.tres`.
- **Nouvelles créatures** (robots, à distance, camps) : Gardien (`gardien_1`, camp 1), Gardien d'élite (`gardien_2`), Gardien écarlate (`gardien_3`), Guetteur (tireur d'élite, 125 dégâts, visée 1,5 s). Les 3 derniers sont dans le camp 2 (0 à 1 chacun). Gardiens : palier blanc / jaune / rouge, salves de 5 (7 pour l'écarlate). Valeurs d'origine : PV, dégâts, salve, crédits, XP. **Estimées** : portées, préparation, délai, vitesses, détection, rayon, hauteur, vitesse de projectile.
- **Biomasse (21/11/2026, comme la Chasse d'origine)** : à sa mort, un monstre lâche `biomass_drop` échantillons au sol ; chacun vaut `biomass_value` points d'objectif (ou `biomass_rare_value` avec la probabilité `biomass_rare_chance`). Rôdeur, Colosse (3 échantillons), Cracheur : 75 / 150 / 25 % ; Guetteur : 150 / 300 / 30 % ; Gardiens et Tique : rien. Ramasser l'échantillon (E) donne ses points au ramasseur (serveur, `ItemData.objective_track`), sans dépôt ni limite de port. Couleur au sol selon la valeur (`ItemData.amount_colors` : 75 vert, 150 bleu, 300 violet, 450 or). L'objectif Biomasse est toujours actif (`MatchRules.always_objectives`).
- Modèles Alien_Cyclop / Alien_Scolitex : seule l'animation « Alien_Idle » existe (pas de marche ni d'attaque) ; `monster_visual.gd` l'utilise comme repos. Les monstres glissent donc sans animation de marche.

- **Boss Alpha (21/11/2026)** : `data/monsters/alpha.tres` (`boss = true`), modèle Alien_Oculichrysalis de 4 m, 8000 PV (valeur d'origine en solo), mêlée lourde de 300 (estimé) : un monstre est soit à distance soit en mêlée, donc pas de salve ; la préparation du coup est une charge sur la cible. Lent (1,5 / 3,5 m/s), sans camp : zone de `leash_radius` (80 m) autour de son apparition, il y rentre s'il en sort. Hors niveaux de monstres (`MonsterManager.server_spawn_boss`, PV et dégâts de base). Lâche 1 biomasse or (450). Dégâts suivis par `Events.monster_damaged`. Voir `docs/quetes.md`.

## Reste à faire
- Animation de mort des monstres (ils disparaissent aujourd'hui).
- Événements à 5 et 10 min, largages de ravitaillement.

## Règles du jeu original : à compléter

## Conception détaillée (déplacé de DESIGN.md)

### 7. Monstres (PvE)
- 3 types de départ : petit rapide (meute), moyen à distance, gros tank. Plus tard, un boss pour les événements.
- Patrouille par zones, IA simple : patrouille → poursuite → attaque → retour.
- **Niveaux (codé 17/11/2026)** : niveau 1 au départ, **2 à 5:00, 3 à 10:00** (`Config.match_rules.monster_level_*`). Appliqué aux monstres qui apparaissent ensuite : PV ×1,25 / ×1,5, dégâts ×1,15 / ×1,3, **crédits ×1,5 / ×2**. Affiché au-dessus du monstre (« niv. 2 »).
- **Cristaux à 10:00** : les cristaux pas encore commencés montent d'un niveau (le niveau max reste max) ; ceux en cours ou faits ne bougent pas.
- **Cracheur (codé)** : monstre à distance (`data/monsters/cracheur.tres`) ; tire un projectile lent et esquivable à 20 m, recule si on l'approche à moins de 7 m. 1-2 par camp de niveau 1, 2-3 par camp de niveau 2.
- **Camps (meutes)** : les monstres vivent en camps de 2 niveaux. Niveau 1 = 1 Colosse (tank) + 3 à 5 Rôdeurs (petits rapides). Niveau 2 = 2 à 3 Colosses + 7 à 10 Rôdeurs. Quand un monstre repère ou se fait attaquer par un joueur, toute la meute réagit.
- **Récompenses** : pour l'instant, un monstre tué donne seulement des crédits, versés directement au tueur. À terme, **vider un camp rapportera des points de quête** (`Events.camp_cleared` est déjà émis). Il faudra aussi les autres types (à distance, boss).
- Pour les tests, un camp vidé réapparaît après 60 s (`Config.match_rules.camp_respawn_delay`).
