# CLAUDE.md — remake de The Cycle (2019)

« Competitive quest shooter » PvEvP multijoueur. Solo dev, l'IA écrit l'essentiel du code.
Avant de coder : `docs/DESIGN.md` (mécaniques, feuille de route) et la fiche `docs/<mécanique>.md`.
Demander à l'utilisatrice sur quelle étape on travaille si ce n'est pas précisé.

## Outils
- **Godot 4.7.2**, GDScript, rendu Forward+.
  Exécutable (hors PATH, chemin relatif à la racine) :
  `../../../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- MCP : **godot-mcp** (lancer / inspecter le projet), **Blender MCP** (modèles 3D).
  Plugins godot-prompter et ponytail désactivés pour ce projet (`.claude/settings.json`).
- Python n'est pas installé : Bash (sed, awk) ou les outils d'édition.

## Règles du projet
1. Une étape de la feuille de route à la fois.
2. **Serveur autoritaire** (dégâts, mort, loot, Fame, contrats, temps) : le client demande
   via `@rpc("any_peer")`, le serveur vérifie `multiplayer.get_remote_sender_id()` puis applique.
   Exception : le déplacement du joueur est décidé par son client.
3. Les objets réseau (joueurs, monstres, loot) sont créés par le serveur sous un
   `MultiplayerSpawner` (`spawn_function`, nom stable). Jamais instanciés côté client.
4. Communication entre systèmes éloignés : bus `Events` (`autoload/events.gd`).
5. Typage statique partout, indentation tabulations, commentaires et textes du jeu en français.
6. Nos propres noms (pas ceux de The Cycle) : Grande Marée, Éclats d'orage, Rôdeur, Colosse…

## Conventions de nommage
- Fichiers et dossiers en `snake_case` ; `class_name` en `PascalCase` ; constantes en `MAJUSCULES`.
- Un système = un dossier `systems/<nom>/` ; un type de données = un script `resources/<nom>_data.gd`.
- Données : un `.tres` par élément dans `data/<type>/` (id = nom du fichier).

## Arborescence
- `autoload/` : `Config` (réglages techniques + accès aux règles), `Events`, `Net`, `Items`
- `scenes/` : `main/` (menu, conteneur du monde), `world/` (carte, points de largage), `player/`
- `systems/<mécanique>/` : un dossier par système (table ci-dessous)
- `resources/` : scripts des types de données (`WeaponData`, `KitData`, `MonsterData`, règles…)
- `data/` : équilibrage en `.tres` — `rules/` (prix, Fame, timings, déplacement, départ),
  `weapons/`, `kits/`, `abilities/`, `kit_mods/`, `items/`, `monsters/`, `camps/`, `quests/`, `contracts/`,
  `factions/`, `weapon_mods/`, `objectives/`, `quest_draws/`, `storm/`, `biomes/` ; `reference/` = chiffres du jeu d'origine
- `assets/` : modèles (Quaternius, CC0), polices, icônes ; `tools/` : scripts d'outillage
- `docs/` : design, fiches par mécanique, captures
- `tests/` : tests réseau automatisés (hôte + client headless), lancés par `tools/run_tests.sh`

## Commandes
```
# Compiler tous les scripts (n'affiche que les échecs)
<godot> --headless --path . -s tools/check_scripts.gd
# Après une nouvelle class_name ou de nouveaux assets
<godot> --headless --path . --import
# Serveur dédié (port 7777, --port=XXXX pour changer)
<godot> --headless --path . -- --server
# Hôte / client en local
<godot> --path . -- --host
<godot> --path . -- --join=127.0.0.1 --name=Test
# Icônes d'armes (avec fenêtre, puis --import, puis -- --assign)
<godot> --path . -s tools/render_weapon_icons.gd
# Scène « tenue en main » (repères Poignee / Bouche) pour un nouveau modèle d'arme
<godot> --headless --path . -s tools/make_held_scenes.gd
# Export Windows (export_presets.cfg ; modèles d'export 4.7.2 installés) -> export/TheCycle/ (+ LISEZMOI.txt à garder)
<godot> --headless --path . --export-release "Windows Desktop" export/TheCycle/TheCycle.exe
```
Archive du wiki The Cycle 2019 (site local `docs/wiki_2019/index.html`, régénéré depuis un `pages.json` téléchargé
par l'API du fandom) : `node tools/wiki_2019/build_site.mjs <pages.json> docs/wiki_2019/index.html`.
Test à 2 instances dans l'éditeur : Debug → Customize Run Instances → 2.
Tests réseau automatisés (18 tests, ~7 min ; port 7777 : un seul lancement à la fois) :
```
bash tools/run_tests.sh            # tous ; OK / ÉCHEC par test, journaux dans .test_logs/
bash tools/run_tests.sh 03 09      # seulement les tests dont le nom contient 03 ou 09
```
Nouveau test : `tests/test_NN_nom.gd`, `extends "res://tests/net_test_aides.gd"`, avec `run_host()` (serveur :
vérité du jeu, prépare la scène) et `run_client()` (agit par les vrais RPC `request_*`). Le même script tourne
des deux côtés via `tests/runner.gd` (un script `-s` est compilé avant les autoloads : la logique est dans un Node).

## Mécanique → fichiers
| Mécanique | Code | Données | Doc |
| --- | --- | --- | --- |
| Joueur, déplacement | `scenes/player/`, `systems/kits/kit_movement.gd` | `data/rules/combat.tres` | DESIGN §1 |
| Combat, armes | `systems/combat/` (`weapon.gd`, `health.gd`, `weapon_model.gd`, effets `weapon_effects_fx.gd` / `weapon_effects_explosion.gd`, maniement : `weapon_spread.gd`) | `data/weapons/` (maniement : `node tools/wiki_2019/make_handling.mjs`), `assets/models/weapons/held/` (repères Poignee / Bouche, réglés avec `tools/grip_preview/grip_preview.tscn`) | DESIGN §2-3 |
| HUD | `systems/combat/hud.gd`, `systems/ui/` | — | — |
| Personnages animés, apparences | `systems/avatar/` (`avatar_retarget.gd` : animations adaptées aux proportions de chaque modèle), choix dans `systems/lobby/lobby_ui_appearance.gd` | `assets/models/characters/` (même squelette que les Superhero), `data/appearances/` | — |
| Inventaire, boutique | `systems/inventory/`, `systems/shop/`, `systems/loot/` | `data/items/`, `data/rules/economy.tres` | `docs/inventaire.md` |
| Kits | `systems/kits/` (`kit_combat_effects.gd` : effets de combat des mods) | `data/kits/` (cœurs de kit), `data/kit_mods/` (mods de niveau 1 à 3, `KitModData`) | DESIGN §12, `docs/factions.md` |
| Capacités, gadgets | `systems/abilities/` | `data/abilities/` | DESIGN §11 |
| Créatures | `systems/monsters/` (boss Alpha : `alpha_boss.gd`) | `data/monsters/`, `data/camps/` | `docs/creatures.md` |
| Quêtes, contrats (tirage), tableau de contrats (4 proposés, 2 actifs, touche J), Prime | `systems/quests/`, `systems/contracts/` (`contract_board.gd`, `contract_ui.gd` ; drones : `drone_site*.gd` ; station centrale : `central_station.gd`, `central_power.gd`) (relais tournant `uplink.gd`, bouches d'Ambrine `extractor.gd`, éclats portés `storm_shards.gd`, surtension `surge_crystals.gd`) | `data/quests/`, `data/contracts/`, `data/objectives/`, `data/quest_draws/` | `docs/quetes.md` |
| Fame, score | `systems/score/` | `data/rules/economy.tres` | DESIGN §6 |
| Tempête | `systems/storm/` (éclairs, rafales : `storm_effets.gd`) | `data/storm/` | `docs/tempetes.md` |
| Extraction (évac), largage de début | `systems/evac/`, `systems/match/` (`drop_*` : points, capsule) | `data/rules/match.tres` | `docs/extraction.md` |
| Niveaux (ce qui est construit : briefing seul au lobby, carte en partie, salle de test), salle de test (armurerie, monstres figés, galerie) | `systems/niveaux/niveaux.gd`, `systems/salle_test/`, boutons PRÊT / SALLE DE TEST de l'onglet Décollage `systems/lobby/lobby_ui_launch.gd` | — | `docs/salle_test.md` |
| Salle de briefing (entre lobby et largage, vote de départ) | `systems/briefing/` (salle, hologramme, tableau), `systems/match/match_briefing.gd` (phase `BRIEFING`, serveur) | `data/rules/match.tres` (`briefing_time`) | `docs/briefing.md` |
| Factions, profils | `systems/profiles/`, `systems/lobby/` | `data/factions/`, `data/weapon_mods/` (générés par `tools/wiki_2019/make_weapon_mods.mjs`) | `docs/factions.md` |
| Pactes, escouades | `systems/pacts/`, `systems/squads/` | — | DESIGN §10 |
| Carte (300 m, relief `map_terrain.gd` / `MapTerrain.height_at`), 4 biomes (`map_biomes.gd`, eau `map_water.gd`), décor | `scenes/world/` (`world_test.tscn` = ancienne carte plate), `systems/map/` (construction asynchrone : `map_terrain_build.gd`, `map_thread.gd` ; orchestration `systems/niveaux/niveaux_carte.gd`), `systems/decor/` (`map_decor_plan.gd` : où poser quoi, en thread ; `map_decor_pick.gd` : modèle selon le biome) | `data/biomes/`, `assets/models/nature/` (+ `plaine/`, `desert/`, `neige/`, `marais/`) ; packs bruts dans `packs_telecharges/` (non versionné) | `docs/carte_biomes.md` |
| Rendu (environnement, post-traitement, qualité Bas / Moyen / Haut, particules d'ambiance) | `systems/rendu/` (`qualite_graphique.gd`, `post_traitement.gd`, `ambiance_particules.gd`, ciel `ciel.gdshader` / `ciel.tres`), environnement dans `scenes/world/world.tscn`, onglet `systems/settings/pause_menu_graphics.gd` | — | `docs/a_faire_graphismes.md` |
| Menu Échap (touches, blocs du HUD) | `systems/settings/` (`settings_store.gd` : `user://reglages.cfg`, appliqué par `Config`) ; blocs marqués par `HudWidgets.tag_block` | — | — |
| Menu admin (touche 0) | `systems/admin/` (dont `grip_tuner.gd` : réglage de la prise en jeu ; `admin_fly.gd` : vol rapide ; bouton « Carte complète » = `MapView.full_map`) | — | — |
| Crafting | non implémenté | — | `docs/crafting.md` |
| Tests réseau | `tests/` (`net_test.gd`, `net_test_aides.gd`, `runner.gd`, `test_NN_*.gd`), `tools/run_tests.sh` | — | ci-dessus (Commandes) |

## Pièges connus
- L'éditeur Godot réécrit `project.godot` : nouvelles touches dans `Config.CODE_KEY_ACTIONS`.
- `.tscn` / SceneReplicationConfig : `properties/N/...` en ordre croissant de N.
- Nouvelle `class_name` : lancer `--import` avant l'analyse.
- Textures des `.gltf` Quaternius : versionnées (exception dans `.gitignore`).

## Sous-agents
- Recherche, exploration, logs, runs headless → agent chercheur (Haiku)
- Écriture et modification de code → agent codeur (Sonnet)
- Décisions d'architecture → session principale, pas de sous-agent

## Règles de travail
- Réponses courtes : pas de récap au-delà de 5 lignes, pas d'explication si on ne la demande pas.
- Scripts .gd : moins de 150 lignes (180 toléré), une responsabilité, noms en snake_case explicites. Si un fichier dépasse, propose un découpage.
  Découpage d'un gros script : helpers `<script>_<rôle>.gd` à côté (RefCounted ou statiques, chargés par `preload`) ;
  les `@rpc`, propriétés synchronisées et l'API publique restent sur le nœud d'origine.
- Données de jeu (stats, loot, prix) dans data/ en .tres ou JSON, jamais en dur dans le code.
- Ne lis pas un .tscn en entier si un grep suffit. Ne lis que les fichiers nécessaires à la tâche.
- Gros scripts découpés en helpers `<script>_<rôle>.gd` (ex. `weapon.gd` + `weapon_damage.gd`…) : grep le dossier pour trouver le bon helper. `tools/import_legacy_data.gd` (445 lignes) : grep puis offset / limit.
- Ne lis pas `data/reference/the_cycle_legacy_data.json` (2 600 lignes) sauf si la tâche porte sur les chiffres d'origine, et alors avec grep.
- Avant d'explorer, consulte la table « mécanique → fichiers » et le docs/ concerné.
- Après tout déplacement ou renommage : mets à jour les références res:// et les UID, puis lance un test en headless.
- Après chaque changement de code : `-s tools/check_scripts.gd` sans échec (avant : `--import` seulement si une class_name ou un asset est nouveau), lancé par le chercheur, qui ne renvoie que les erreurs.
- Changement réseau (RPC, synchro, spawn) : `bash tools/run_tests.sh` (au moins les tests concernés) avant de dire que c'est fini ; pas pour un changement purement local.
- Changement visuel : une ou deux captures au plus (échelle réduite), puis « À tester en jeu : … » quand c'est le ressenti qui compte. Pas de capture pour du code sans effet visible.
- Pour une tâche de plus de 3 fichiers : propose un plan court et attends mon accord.
- Garde le CLAUDE.md et docs/ à jour quand tu ajoutes ou déplaces un système.
