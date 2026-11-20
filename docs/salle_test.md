# Niveaux et salle de test

## Ce qui est construit, et quand (`systems/niveaux/niveaux.gd`)
Le serveur décide, chaque peer construit lui-même (rien de lourd sur le réseau) :

| Activité | Construit | Phase (`MatchManager`) |
| --- | --- | --- |
| Lobby (menus) | salle de briefing seule, les joueurs y attendent | `LOBBY` |
| Partie normale | carte (relief, décor) générée au début du briefing ; salle de briefing supprimée au largage | `BRIEFING` → `PLAYING` … |
| Salle de test | salle de test seule (briefing supprimé, carte jamais générée) | `SALLE_TEST` (pas d'horloge) |

- Retour au lobby (fin de partie, téléporteur de la salle de test) : tout est supprimé, la salle de briefing est recréée.
- Une seule activité à la fois par serveur : la salle de test n'est possible qu'au lobby, et tout le monde y part.
- Serveur : `Events.carte_chargee` (navmesh des monstres) et `Events.carte_liberee` (monstres, objets, quêtes retirés).
- Le relief (`MapTerrain.height_at`) est connu même sans carte construite ; `MapTerrain.construire()` / `detruire()` font la collision et le rendu.

## Choix du mode
PRÊT au lobby ouvre la fenêtre « mode de jeu » (`systems/lobby/lobby_ui_mode.gd`) : partie normale
(`request_lobby_ready`) ou salle de test (`Niveaux.request_salle_test`). Si le briefing est déjà ouvert, PRÊT rejoint la partie.

## Salle de test (`systems/salle_test/`)
Plateforme hors carte (`SalleTest.ORIGIN`), plan dans `salle_test_plan.gd` :
- **Armurerie** : toutes les armes, gadgets, capacités et objets du registre `Items`, au sol, reposés par le serveur
  dès qu'ils sont ramassés (`salle_test_stock.gd`, via `Events.loot_drop_requested`).
- **Bestiaire** : chaque monstre de `data/monsters/` aux niveaux 1 et 3, figés (`MonsterManager.server_spawn_fige` :
  pas d'IA ni de déplacement), réapparaissent après leur mort.
- **Galerie** (visuel local) : une dalle par texture de `assets/textures/sol/`, puis une colonne par biome avec tous ses
  modèles de décor par catégorie (`salle_test_galerie.gd`).
- **Téléporteur** (`salle_test_sortie.gd`) : E ramène tout le serveur au lobby.

Nouvel objet, arme, capacité ou modèle de biome : il apparaît tout seul dans la salle (rien à déclarer).

## Capacités au sol
Chaque capacité de `data/abilities/` a un objet (`ItemData.Kind.ABILITY`, créé par `Items`) : on la ramasse (E), puis
Q ou F l'équipe ; ce qui occupait l'emplacement tombe au sol (capacité, ou gadget avec ses munitions).

Test réseau : `tests/test_13_salle_test.gd` (et `test_12_capacite_sol.gd`).
