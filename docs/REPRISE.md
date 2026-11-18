# Reprise de session — notes pour la prochaine IA

> À lire après `CLAUDE.md`, seulement si besoin : ce qui n'est écrit nulle part ailleurs
> (façon de travailler de l'utilisatrice, retours déjà traités, pièges, tests scriptés).
> État du projet : `docs/DESIGN.md` (feuille de route) et les fiches `docs/<mécanique>.md`.

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

## Pièges techniques (en plus de ceux du CLAUDE.md)

1. **Autorité réseau** : `Player._enter_tree` donne l'autorité du joueur au client, puis
   remet `Health`, `Inventory` et `Score` à 1 (le serveur). Les RPC du serveur vers un nœud
   à autorité client sont en `any_peer` avec la vérification `get_remote_sender_id() == 1`.
2. **Les objets construits en code** (monstres, cristaux, contrats, objets au sol, capsules)
   sont créés via la `spawn_function` d'un `MultiplayerSpawner`, avec un nom stable.
   Le `MultiplayerSynchronizer` est créé dans `setup()`, avant l'entrée dans l'arbre.
3. **Navmesh** : généré par le serveur à partir des **collisions** des CSG
   (`MonsterManager._bake_navmesh`). `NavigationAgent3D.get_next_path_position()` doit être
   appelé **avant** `is_navigation_finished()`.
4. **Les `@onready` du Player** ne sont prêts qu'après ses enfants : un enfant qui en a
   besoin dans `_ready` doit faire `await player.ready`.
5. **Données envoyées au client juste après l'apparition du joueur** : attendre un peu
   (voir 1e65326, fenêtre de kit envoyée 1 s après), sinon le nœud n'existe pas encore chez lui.

## Tests réseau scriptés et captures (scripts hors projet)

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
