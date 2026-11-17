# CLAUDE.md — règles pour l'IA sur ce projet

Projet : remake d'un "competitive quest shooter" PvEvP inspiré de The Cycle (2019).
Moteur : **Godot 4.7, GDScript**. Solo dev, l'IA écrit l'essentiel du code.

## À lire en premier
- `docs/DESIGN.md` : toutes les mécaniques et la feuille de route par étapes.
- Demander à l'utilisatrice sur quelle étape on travaille si ce n'est pas précisé.

## Règles
1. **Une étape à la fois.** Ne pas coder les mécaniques des étapes suivantes.
2. **Serveur autoritaire** pour tout ce qui compte : dégâts, mort, loot, Fame, contrats,
   temps de partie. Le client *demande* via `@rpc("any_peer")`, le serveur vérifie
   (`multiplayer.get_remote_sender_id()`) puis applique.
   Exception temporaire : le déplacement du joueur est décidé par son client.
3. **Le serveur crée les objets réseau** (joueurs, monstres, loot) sous un nœud
   surveillé par un `MultiplayerSpawner`. Ne jamais les instancier côté client.
4. **Données hors du code** : armes, contrats, monstres, gadgets = ressources `.tres`
   dans `data/`, avec leur script de type dans `resources/` (voir `WeaponData`).
   Les constantes de partie sont dans `autoload/config.gd`.
5. **Communication entre systèmes** via le bus `Events` (`autoload/events.gd`),
   pas de références directes entre systèmes éloignés.
6. Typage statique GDScript partout (`var x: int`, `-> void`), indentation tabulations.
7. Commentaires et textes du jeu en français.
8. Chaque nouveau système va dans `systems/<nom>/` (script + scène si besoin).
9. Écrire les scènes `.tscn` à la main est OK, mais rester simple ; préférer
   construire les détails en code si la scène devient complexe.
10. Après chaque changement : vérifier que le projet se lance sans erreur
    (`godot --headless --path . --quit` pour l'analyse, puis test à 2 instances).
    Exécutable : `../../../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
    (Godot 4.7.2, pas dans le PATH ; chemin relatif à la racine du projet).

## Arborescence
- `autoload/` singletons : `Config`, `Events`, `Net`, `Items` (registre des objets de `data/items/`)
- `scenes/main/` menu + conteneur du monde (`/root/Main/World`)
- `scenes/world/` carte, points de largage, `PlayerSpawner`
- `scenes/player/` joueur FPS
- `systems/` un dossier par système : `combat/` (santé, arme, réapparition, HUD), `loot/` (objets au sol,
  LootManager), `shop/` (boutique, interface, capsule de largage), `quests/` (cristal + foreuse, QuestManager), `score/` (points de quête),
  `inventory/`, `interaction/` (E, y compris « maintenir E »), `monsters/` (monstre, camps, MonsterManager,
  navmesh), `contracts/` (relais, extracteur, cœur stellaire, collecteurs, station, drones, prime ; base `ContractSite`) ;
  match, tempête, évac… (à venir)
- `resources/` scripts de types de données
- `data/` valeurs d'équilibrage `.tres` : `weapons/`, `items/` (un objet ramassable = un fichier, `price` > 0 = vendu en boutique), `monsters/`, `camps/`, `quests/` (niveaux de cristal + `waves/`), `contracts/` (un .tres par contrat)
- `assets/` modèles, sons, textures

## Tester
- Éditeur : Debug → Customize Run Instances → 2 instances. Héberger dans l'une, Rejoindre dans l'autre.
- Serveur dédié : `godot --headless -- --server` (port 7777 par défaut, `--port=XXXX` pour changer).
