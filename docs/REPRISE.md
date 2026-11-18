# Reprise de session — récap pour la prochaine IA

> Mis à jour le 18/11/2026. À lire **après** `CLAUDE.md` et `docs/DESIGN.md` : ce fichier
> contient ce qui n'est écrit nulle part ailleurs (état réel, pièges rencontrés, façon de
> travailler de l'utilisatrice).

## Où on en est

- Feuille de route : étapes **0 à 4, 6, 7 et 9 faites** ; étape **8 faite en pratique**
  (8a à 8e : armes, kits, capacités, gadgets, boosts, pactes, état « à terre » ; les
  escouades ont été faites à l'étape 9). Étape **5** : Fame et contrats faits, mais pas de
  tableau « 4 contrats proposés, 2 actifs » (tous les contrats sont ouverts à tous).
  Étape **10** (en ligne, VPS) pas commencée.
- Tout a été validé par tests automatisés à 2 instances ; **presque rien n'a été vérifié
  à la main en jeu** par l'utilisatrice.
- Travail récent : rapprocher le jeu d'une vidéo de référence (`docs/REFERENCE_VIDEO.md`).
  Déjà fait :
  - **Grande Marée** : tempête sur toute la carte vers 10:00, sans dégâts (ciel sombre,
    pluie, éclairs), phases dans `data/storm/` ;
  - **Éclats d'orage** + collecteur pendant la tempête (contrat de collecte) ;
  - **Navette** : annonce à 16:00, arrivée à 17:00, décollage à 20:00 ; la plateforme est
    bloquée par un camp de monstres (« NAVETTE BLOQUÉE — NETTOYER LA PLATEFORME ») et la
    navette ne se pose qu'une fois le camp tué.
  - Décisions prises (18/11) : garder le low-poly stylisé ; touches boutique T → G,
    kit K → L (Q / F / E inchangées) ; Fame d'un kill de joueur à 10 (au lieu de 50, pas
    encore appliqué) ; pas de véhicule ni de défis personnels pour l'instant.
- L'ancienne checklist de ce travail a été supprimée le 18/11 ; si besoin, elle est dans
  git : `git show 5a77b3e:docs/CHECKLIST_REFERENCE.md`. **Demander à l'utilisatrice
  sur quoi on travaille ensuite.**

## Historique (git log, du plus récent au plus ancien)

| Commit | Contenu |
|---|---|
| 5a77b3e | Navette à 17:00, bloquée tant que la plateforme n'est pas nettoyée |
| ce67a46 | Calendrier de l'évac de la vidéo |
| f1cbf7b | Éclats d'orage et leur collecteur pendant la Grande Marée |
| 1e65326 | Correction : fenêtre de changement de kit envoyée 1 s après l'apparition |
| 0fb9123 | Grande Marée (tempête globale au lieu d'une zone) |
| 4062750 | Interface « Nuit polaire », visuels et premiers modèles 3D d'armes |
| e63a6e7 | Étape 9 : profils, factions, lobby, escouades, mods, boutique configurable |
| 8d5dec9 | Étapes 8d et 8e : gadgets, boosts d'arme, pactes, état « à terre » |
| 25e5783 | Étape 8b : kits |
| ea3ee91 | Étape 8a : armes complètes et ressenti |
| 2ca08aa | Écran Tab (carte, objectifs, classement), minimap |
| 8f21bb4 | Étape 7 (tempête, niveaux de monstres, Cracheur) + Fame |
| df04c9b | Étape 6 (partie complète) + menu admin |
| 86bdbc0 et avant | Étapes 0 à 4, boutique, quête cristal, contrats, points d'objectif |

## Façon de travailler de l'utilisatrice

- Elle écrit en français, souvent vite, avec des fautes : comprendre l'intention.
- **Sur une étape de la feuille de route, elle demande souvent le plan avant de coder.**
  Pour une correction ou un ajout précis, elle veut que ce soit fait directement.
- Elle teste en jeu (2 instances dans l'éditeur) et revient avec des retours de ressenti.
  Les mécaniques sont **volontairement provisoires** : garder les valeurs dans les `.tres`
  et `Config`.
- **Un commit par fonctionnalité qui marche** (messages en français, détaillés).
- Elle veut un récap clair à la fin, avec ce qui reste à vérifier en jeu.
- Si le budget de tokens approche ~95 % : faire un récap de ce qui reste à faire et s'arrêter.
- Noms : le jeu doit avoir ses propres noms (pas ceux de The Cycle). Exemples :
  Cœur stellaire, Ambrine, Lumicèpes, Tiques, Rôdeur, Colosse, Grande Marée, Éclats d'orage.

## Retours en jeu déjà traités (ne pas refaire)

- **Monstres** : ne s'arrêtent plus pour préparer un coup, portée ×1,5, Rôdeur à 7 m/s,
  Colosse prépare en 0,6 s, pause en reculant après un coup réussi (`post_hit_pause`).
- Les crédits des monstres vont directement au tueur (rien au sol).

## Pièges techniques rencontrés (important)

1. **L'éditeur Godot réécrit `project.godot`** depuis sa mémoire. Les nouvelles touches se
   déclarent en code dans `Config.CODE_KEY_ACTIONS` (`autoload/config.gd`). Éviter de
   modifier `project.godot` ou les `.tscn` quand l'éditeur est ouvert. Si une touche « ne
   marche pas » : `git diff project.godot`.
2. **Nouvelle `class_name`** : lancer `--headless --path . --import` avant l'analyse, sinon
   le cache des classes ne la connaît pas.
3. **`.tscn` / SceneReplicationConfig** : les `properties/N/...` doivent apparaître dans
   l'ordre croissant de N, sinon « Index idx = N is out of bounds ». Vérifier après chaque ajout.
4. **Autorité réseau** : `Player._enter_tree` donne l'autorité du joueur au client, puis
   remet `Health`, `Inventory` et `Score` à 1 (le serveur). Les RPC du serveur vers un nœud
   à autorité client sont en `any_peer` avec la vérification `get_remote_sender_id() == 1`.
5. **Les objets construits en code** (monstres, cristaux, contrats, objets au sol, capsules)
   sont créés via la `spawn_function` d'un `MultiplayerSpawner`, avec un nom stable.
   Le `MultiplayerSynchronizer` est créé dans `setup()`, avant l'entrée dans l'arbre.
6. **Navmesh** : généré par le serveur à partir des **collisions** des CSG
   (`MonsterManager._bake_navmesh`). `NavigationAgent3D.get_next_path_position()` doit être
   appelé **avant** `is_navigation_finished()`.
7. **Les `@onready` du Player** ne sont prêts qu'après ses enfants : un enfant qui en a
   besoin dans `_ready` doit faire `await player.ready`.
8. **Données envoyées au client juste après l'apparition du joueur** : attendre un peu
   (voir 1e65326, fenêtre de kit envoyée 1 s après), sinon le nœud n'existe pas encore chez lui.
9. **Python n'est pas installé** sur la machine. Utiliser Bash (sed, awk, heredoc) ou l'outil Edit.

## Comment tester (scripts hors projet)

- Analyse : `../../../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`
- **Test réseau scripté** : un hôte (`-- --host`, ou un script `-s`) et un client
  `--headless --path . -s mon_test.gd`, avec un script `extends SceneTree` qui charge
  `res://scenes/main/main.tscn` **en différé**, rejoint, puis appelle les RPC comme un joueur.
  - Ne pas typer avec les classes du projet ni référencer les autoloads par leur nom :
    utiliser `root.get_node("Events")`.
  - Avancer le temps de partie : `Events.time_skip_requested`.
  - Lancer avec `timeout`, puis `taskkill //F //IM Godot_v4.7.2-stable_win64_console.exe`.
    Attendre la libération du port 7777 entre deux tests.
- **Captures d'écran** : lancer sans `--headless`, puis
  `root.get_viewport().get_texture().get_image().save_png(...)` ; les ranger dans `docs/captures/`.
- « BUG: Unreferenced static string » à la fermeture : dû à l'arrêt forcé, pas un bug du jeu.

## À vérifier en jeu / à faire

- Ressenti de la Grande Marée (pluie, éclairs, lisibilité), nombre et place des éclats
  d'orage, difficulté du camp de la plateforme d'évac, temps d'embarquement.
- Les kits de soin et cellules de bouclier ne s'obtiennent plus : touches 3 et 4 inutiles.
- Équilibrage complet à faire : valeurs dans `data/` et `Config`.
- `DESIGN.md` : cocher les étapes 5 et 8 si l'utilisatrice les considère finies.
