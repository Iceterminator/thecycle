# Créatures (monstres)

Code : `systems/monsters/` (`monster.gd`, `monster_manager.gd`, `monster_camp.gd`) · Données : `data/monsters/` (`MonsterData`, champ `model`), `data/camps/`, `data/rules/match.tres` (niveaux)

## Implémenté
- 4 monstres : Rôdeur (mêlée rapide), Colosse (mêlée lourde), Cracheur (à distance), Tique (apparaît autour des porteurs de Lumicèpes).
- IA serveur : patrouille, poursuite, préparation du coup visible (voile rouge), recul après un coup, retour au camp.
- Camps de niveau 1 et 2, repeuplés après `camp_respawn_delay` ; navmesh généré depuis les collisions (décor compris).
- Niveaux 1 à 3 selon le temps de partie (PV, dégâts, crédits) ; plus forts pendant la Grande Marée.
- Modèles animés Quaternius (robots du Sci-Fi Essentials Kit) ; sans modèle : capsule colorée.

## Reste à faire
- Animation de mort des monstres (ils disparaissent aujourd'hui).
- Événements à 5 et 10 min, largages de ravitaillement.

## Règles du jeu original : à compléter
