# Créatures (monstres)

Code : `systems/monsters/` (`monster.gd`, `monster_manager.gd`, `monster_camp.gd`) · Données : `data/monsters/` (`MonsterData`, champ `model`), `data/camps/`, `data/rules/match.tres` (niveaux)

## Implémenté
- 4 monstres : Rôdeur (mêlée rapide), Colosse (mêlée lourde), Cracheur (à distance), Tique (apparaît autour des porteurs de Lumicèpes).
- IA serveur : patrouille, poursuite, préparation du coup visible (voile rouge), recul après un coup, retour au camp.
- Camps de niveau 1 et 2, repeuplés après `camp_respawn_delay` ; navmesh généré depuis les collisions (décor compris).
- Niveaux 1 à 3 selon le temps de partie (PV, dégâts, crédits) ; plus forts pendant la Grande Marée.
- Modèles animés Quaternius (robots du Sci-Fi Essentials Kit) ; sans modèle : capsule colorée.
- Performance (MonsterLod) : `move_and_slide` coûtait ~0,17 ms par monstre (105 monstres = serveur à 8 FPS). Un monstre en patrouille à plus de 50 m de tout joueur avance sans collision, posé sur le relief ; à l'arrêt au sol il ne calcule plus rien ; dès qu'un joueur approche (détection max 31 m), physique normale.

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
