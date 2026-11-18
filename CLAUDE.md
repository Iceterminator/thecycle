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
  `weapons/`, `kits/`, `abilities/`, `items/`, `monsters/`, `camps/`, `quests/`, `contracts/`,
  `factions/`, `weapon_mods/`, `objectives/`, `storm/` ; `reference/` = chiffres du jeu d'origine
- `assets/` : modèles (Quaternius, CC0), polices, icônes ; `tools/` : scripts d'outillage
- `docs/` : design, fiches par mécanique, captures

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
```
Test à 2 instances dans l'éditeur : Debug → Customize Run Instances → 2.
Test réseau scripté : hôte `-- --host` + client `--headless -s mon_test.gd` (script `extends SceneTree`
qui charge `main.tscn` en différé ; autoloads via `root.get_node("Events")`) ; arrêt par `timeout` + `taskkill`.

## Mécanique → fichiers
| Mécanique | Code | Données | Doc |
| --- | --- | --- | --- |
| Joueur, déplacement | `scenes/player/`, `systems/kits/kit_movement.gd` | `data/rules/combat.tres` | DESIGN §1 |
| Combat, armes | `systems/combat/` (`weapon.gd`, `health.gd`, `weapon_model.gd`) | `data/weapons/`, `assets/models/weapons/held/` (repères Poignee / Bouche, réglés avec `tools/grip_preview/grip_preview.tscn`) | DESIGN §2-3 |
| HUD | `systems/combat/hud.gd`, `systems/ui/` | — | — |
| Personnages animés | `systems/avatar/` | `assets/models/characters/` | — |
| Inventaire, boutique | `systems/inventory/`, `systems/shop/`, `systems/loot/` | `data/items/`, `data/rules/economy.tres` | `docs/inventaire.md` |
| Kits | `systems/kits/` | `data/kits/` | DESIGN §12 |
| Capacités, gadgets | `systems/abilities/` | `data/abilities/` | DESIGN §11 |
| Créatures | `systems/monsters/` | `data/monsters/`, `data/camps/` | `docs/creatures.md` |
| Quêtes, contrats | `systems/quests/`, `systems/contracts/` | `data/quests/`, `data/contracts/`, `data/objectives/` | `docs/quetes.md` |
| Fame, score | `systems/score/` | `data/rules/economy.tres` | DESIGN §6 |
| Tempête | `systems/storm/` | `data/storm/` | `docs/tempetes.md` |
| Extraction (évac) | `systems/evac/`, `systems/match/` | `data/rules/match.tres` | `docs/extraction.md` |
| Factions, profils | `systems/profiles/`, `systems/lobby/` | `data/factions/`, `data/weapon_mods/` | `docs/factions.md` |
| Pactes, escouades | `systems/pacts/`, `systems/squads/` | — | DESIGN §10 |
| Carte, décor | `scenes/world/`, `systems/map/`, `systems/decor/` | `assets/models/nature/` | — |
| Menu admin (touche 0) | `systems/admin/` (dont `grip_tuner.gd` : réglage de la prise en jeu) | — | — |
| Crafting | non implémenté | — | `docs/crafting.md` |

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
- Scripts .gd : moins de 150 lignes, une responsabilité, noms en snake_case explicites. Si un fichier dépasse, propose un découpage.
- Données de jeu (stats, loot, prix) dans data/ en .tres ou JSON, jamais en dur dans le code.
- Ne lis pas un .tscn en entier si un grep suffit. Ne lis que les fichiers nécessaires à la tâche.
- Gros scripts (plus de 400 lignes : lobby_ui, hud, weapon, monster…) : grep d'abord, puis lis seulement les lignes utiles (offset / limit), jamais le fichier entier.
- Ne lis pas `data/reference/the_cycle_legacy_data.json` (2 600 lignes) sauf si la tâche porte sur les chiffres d'origine, et alors avec grep.
- Avant d'explorer, consulte la table « mécanique → fichiers » et le docs/ concerné.
- Après tout déplacement ou renommage : mets à jour les références res:// et les UID, puis lance un test en headless.
- Après chaque changement de code : `-s tools/check_scripts.gd` sans échec (avant : `--import` seulement si une class_name ou un asset est nouveau), lancé par le chercheur, qui ne renvoie que les erreurs.
- Changement réseau (RPC, synchro, spawn) : test à 2 instances (hôte + client headless, voir Commandes) avant de dire que c'est fini ; pas pour un changement purement local.
- Changement visuel : une ou deux captures au plus (échelle réduite), puis « À tester en jeu : … » quand c'est le ressenti qui compte. Pas de capture pour du code sans effet visible.
- Pour une tâche de plus de 3 fichiers : propose un plan court et attends mon accord.
- Garde le CLAUDE.md et docs/ à jour quand tu ajoutes ou déplaces un système.
