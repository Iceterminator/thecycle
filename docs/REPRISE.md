# Reprise de session — récap pour la prochaine IA

> Écrit le 17/11/2026 à la fin d'une longue session. À lire **après** `CLAUDE.md` et
> `docs/DESIGN.md` : ce fichier contient ce qui n'est écrit nulle part ailleurs
> (état réel, pièges rencontrés, façon de travailler de l'utilisatrice).

## Où on en est

- Étapes 0 à 4 de la feuille de route faites, plus beaucoup de contenu demandé en dehors
  de l'ordre prévu : boutique, quêtes, contrats, deux types de points.
- **Contrats : 9 sur 10 faits.** Il manque l'**Évac**, qui dépend du minuteur de partie,
  du vaisseau et de l'embarquement (**étape 6**). Il n'y a pas encore de tableau
  « 4 contrats proposés, 2 actifs » : tous les contrats sont ouverts à tous.
- **Points :**
  - les **points de classement** (`Score.rank_points`) sont le score général ;
  - les **points d'objectif** sont propres à chacun des objectifs Forage, Relais, Ambrine,
    Cœur, Biomasse et Lumicèpes ;
  - chaque palier d'objectif donne du classement (`data/objectives/*.tres`) ;
  - la station, les drones et la prime donnent directement du classement, avec des montants réduits ;
  - le HUD montre, pour chaque objectif, le prochain palier et le gain par seconde.
- Prochaine étape logique : **étape 5** (Fame, classement en direct) ou **étape 6**
  (partie complète + Évac). **Demander à l'utilisatrice.**

## Historique (git log, du plus récent au plus ancien)

| Commit | Contenu |
|---|---|
| 86bdbc0 | Sous-agents chercheur (Haiku) et analyste (Sonnet) + règle de délégation |
| de61873 | HUD : prochain palier et gain/s ; l'extracteur d'Ambrine verse directement |
| 9517baa | Points d'objectif à paliers + points de classement |
| 960eed0 | Contrats : relais, extracteur, Cœur stellaire, biomasse, Lumicèpes + Tiques, station, drones, prime |
| 8963c71 | Monstres : pause en reculant après un coup réussi |
| 7b61d0a | Quête cristal + foreuse (3 difficultés) ; monstres plus durs à esquiver |
| cb29960 | Touche T déclarée en code |
| 965f57b | Boutique + capsules de largage (remplace les caisses) |
| 689b839 | Étape 4 : monstres |
| 8b126c2 | Étape 3 : loot et inventaire |
| 5115448 | Étape 2 : combat |
| 5815275 | Étape 1 : joueurs en réseau |

## Façon de travailler de l'utilisatrice

- Elle écrit en français, souvent vite, avec des fautes : comprendre l'intention.
- **Sur une étape de la feuille de route, elle demande souvent le plan avant de coder.**
  Pour une correction ou un ajout précis, elle veut que ce soit fait directement.
- Elle teste en jeu (2 instances dans l'éditeur) et revient avec des retours de ressenti.
  Les mécaniques sont **volontairement provisoires** : elle les retravaillera quand la
  boucle complète existera. Garder les valeurs dans les `.tres` et `Config`.
- **Un commit par fonctionnalité qui marche** (messages en français, détaillés).
- Elle veut un récap clair à la fin, avec ce qui reste à vérifier en jeu.
- Si le budget de tokens approche ~95 % : faire un récap de ce qui reste à faire et s'arrêter.
- Noms : le jeu doit avoir ses propres noms (pas ceux de The Cycle). Exemples :
  Cœur stellaire, Ambrine, Lumicèpes, Tiques, Rôdeur, Colosse.

## Retours en jeu déjà traités (ne pas refaire)

- **Monstres d'abord trop figés** : la préparation du coup ne les arrête plus, un coup raté
  ne les bloque que 0,3 s, et ils continuent la poursuite pendant leur recharge.
- **Ensuite trop faciles à esquiver** : ils avancent à pleine vitesse pendant la préparation,
  leur portée de coup est ×1,5, le Rôdeur court à 7 m/s, le Colosse prépare son coup en 0,6 s.
- **Ensuite collés au joueur** : pause de 0,6 s (Rôdeur) ou 0,8 s (Colosse) en reculant
  après un coup réussi (`post_hit_pause`).
- Les crédits des monstres vont directement au tueur (rien au sol).
- La régénération du joueur, le bouclier de départ à 25 et la boutique sont décrits dans le DESIGN.

## Pièges techniques rencontrés (important)

1. **L'éditeur Godot réécrit `project.godot`** depuis sa mémoire et a effacé deux fois
   l'action `open_shop`. Les nouvelles touches se déclarent en code dans
   `Config.CODE_KEY_ACTIONS` (`autoload/config.gd`). Éviter de modifier `project.godot`
   ou les `.tscn` quand l'éditeur est ouvert : demander de fermer l'éditeur ou de
   recharger le projet. Si une touche « ne marche pas » : `git diff project.godot`.
2. **`.tscn` / SceneReplicationConfig** : les `properties/N/...` doivent apparaître dans
   l'ordre croissant de N, sinon on obtient l'erreur « Index idx = N is out of bounds ».
   L'erreur a été faite 4 fois en insérant une ligne avec `sed` : vérifier après chaque ajout.
3. **Autorité réseau** : `Player._enter_tree` donne l'autorité du joueur au client, puis
   remet `Health`, `Inventory` et `Score` à 1 (le serveur). Les RPC du serveur vers un nœud
   à autorité client sont en `any_peer` avec la vérification `get_remote_sender_id() == 1`.
4. **Les objets construits en code** (monstres, cristaux, contrats, objets au sol, capsules)
   sont créés via la `spawn_function` d'un `MultiplayerSpawner`, avec un nom stable.
   Le `MultiplayerSynchronizer` est créé dans `setup()`, avant l'entrée dans l'arbre.
5. **Navmesh** : il est généré par le serveur à partir des **collisions** des CSG
   (`MonsterManager._bake_navmesh`), et non de leurs maillages de rendu.
   `NavigationAgent3D.get_next_path_position()` doit être appelé **avant**
   `is_navigation_finished()`, sinon la patrouille ne bouge pas.
6. **Les `@onready` du Player** ne sont prêts qu'après ses enfants : un enfant qui en a
   besoin dans `_ready` doit faire `await player.ready` (voir `shop.gd`).
7. **Python n'est pas installé** sur la machine. Utiliser Bash (sed, awk, heredoc) ou l'outil Edit.

## Comment j'ai testé (scripts hors projet)

- Analyse : `../../../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`
- **Test réseau scripté** : un hôte (`-- --host`, ou un script `-s`) et un client
  `--headless --path . -s mon_test.gd`, avec un script `extends SceneTree` qui charge
  `res://scenes/main/main.tscn` **en différé**, rejoint, puis appelle les RPC comme un joueur
  (`me.interactor.request_hold_start.rpc_id(1, ...)`, etc.).
  - Dans ces scripts, ne pas typer avec les classes du projet ni référencer les autoloads par
    leur nom (erreur « Identifier not found » à la compilation) : utiliser
    `root.get_node("Events")`.
  - Lancer l'hôte et le client avec `timeout`, puis `taskkill //F //IM Godot_v4.7.2-stable_win64_console.exe`.
  - Attendre la libération du port 7777 entre deux tests.
- **Captures d'écran** : lancer sans `--headless`, puis
  `root.get_viewport().get_texture().get_image().save_png(...)`.
- Les messages « BUG: Unreferenced static string » à la fermeture viennent de l'arrêt forcé
  par `timeout` : ce n'est pas un bug du jeu.

## À vérifier en jeu / à faire

- Rien n'a été testé à la main par l'utilisatrice depuis les contrats et les deux types de
  points : attendre ses retours.
- Le paiement de la prime au tueur n'a pas été testé (la logique est simple).
- Les kits de soin et les cellules de bouclier ne s'obtiennent plus (ni caisses ni boutique) :
  touches 3 et 4 inutiles pour l'instant.
- Équilibrage complet à faire : valeurs dans `data/` et `Config`.
- Évac et minuteur de partie : étape 6.
