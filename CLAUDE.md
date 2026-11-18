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
- `systems/` un dossier par système : `combat/` (santé, arme, réapparition, `WeaponModel` = arme 3D en main d'après `WeaponData.model` (+ rotation, longueur, décalage ; modèles dans `assets/models/weapons/<id>/`), HUD : minimap ronde + rang + objectifs en haut à gauche, horloge en haut, classement en haut à droite, escouade / kit / crédits en bas à gauche, Q / F + barres en segments en bas au centre, armes en bas à droite), `loot/` (objets au sol,
  LootManager), `shop/` (boutique configurée dans le lobby : 4 armes + 4 gadgets / capacités ; arme possédée = boost ; interface, capsule de largage), `quests/` (cristal + foreuse, QuestManager), `score/` (Fame = `rank_points` + points d'objectif à paliers ; FameManager : +50 par joueur tué),
  `kits/` (KitController : kit, niveau, XP ; KitMovement : capacités de mouvement ; menu Équipement K),
  `pacts/` (PactManager : pactes, alliés ; menu P),
  `abilities/` (AbilityController : capacités Q / F ; BuffController : bonus / malus ; AbilityManager + AbilityObject :
  grenades, sphères, tourelle, murs, frappes, portail, balise, créés par le serveur via `Events.ability_object_requested`),
  `inventory/`, `interaction/` (E, y compris « maintenir E »), `monsters/` (monstre, camps, MonsterManager,
  navmesh), `contracts/` (relais, extracteur, cœur stellaire, collecteurs, station, drones, prime ; base `ContractSite`),
  `admin/` (menu de test, touche 0 : armes, crédits, cristaux, avance du temps → `Events.time_skip_requested` ;
  désactivable via `Config.ADMIN_MENU_ENABLED`) ;
  `match/` (minuteur de partie, fin, lobby entre les parties : `MatchManager`, créé par World),
  `profiles/` (ProfileManager : pseudo, réputation, équipement, JSON `user://profiles/`), `squads/` (SquadManager :
  escouades du lobby ; `Allies` : qui est allié), `lobby/` (écran du lobby : barre d'onglets Décollage / Équipement / Arsenal / Factions / Escouade ; Équipement = `LoadoutPage` : vue d'ensemble (départ + boutique, cases avec ⇄) → fiche de l'objet → sélecteur « Choisissez votre … » → ÉQUIPER ; Arsenal = catégories, filtres, cartes débloquées puis verrouillées par niveau, fiche détaillée avec actions ; `UiCard` = carte cliquable avec icône et cadenas), `ui/` (`UiStyle` = DA « Nuit polaire » : palette bleu nuit / acier / cuivre, coins coupés, thème des boutons et listes, police Barlow Condensed dans `assets/fonts/` (OFL) ; éléments d'interface dessinés en code : `WeaponIcon` (armes, gadgets), `AbilityIcon` (capacités, par catégorie), `KitIcon` (kits, selon PV et mouvement) = visuels dessinés d'après les données, liseré de faction ; `ItemVisual.make(id)` choisit le bon ; champ `hud_icon` (armes, capacités, kits) = vraie image facultative, `SegmentBar` = barre PV / bouclier en segments, `LockIcon` = cadenas), `evac/` (vaisseau, soute,
  embarquement : `EvacShip`, créé par World) ; `storm/` (tempête en zone qui se referme : `StormManager`, phases dans `data/storm/`) ;
  `map/` (écran Tab : carte, quêtes, classement ; `MapView` sert aussi à la minimap du HUD ; un objet apparaît sur la carte s'il est dans le groupe
  `map_marker` et a `map_info() -> { text, color, kind, [position], [radius] }`). Nouvelle partie : `Events.match_reset_requested`,
  chaque système de carte se remet à zéro lui-même
- `resources/` scripts de types de données
- `data/reference/the_cycle_legacy_data.json` : chiffres des armes, kits, capacités et gadgets du jeu d'origine (référence) ;
  `tools/import_legacy_data.gd` en génère `data/weapons/` (avec la fiche « detailed » et le ressenti visuel) et `data/kits/`
- `data/` valeurs d'équilibrage `.tres` : `weapons/`, `kits/` (bonus de niveau chiffrés dans `level_perk_effects`), `abilities/` (21 capacités, générées), `items/` (un objet ramassable = un fichier, `price` > 0 = vendu en boutique), `monsters/`, `camps/`, `quests/` (niveaux de cristal + `waves/`), `contracts/` (un .tres par contrat), `factions/` (3 factions : vrai nom + notre nom), `weapon_mods/` (mods d'arme), `objectives/` (paliers d'objectif -> classement ; le HUD montre le prochain palier et le gain/s)
- `tools/render_weapon_icons.gd` : icônes des armes qui ont un modèle 3D (rendu de profil → `assets/icons/weapons/<id>.png`, branché dans `hud_icon`) ; avec fenêtre, puis `--import`, puis `-- --assign`
- `assets/` modèles, sons, textures ; `assets/ui/lobby_background.webp` = fond du lobby (sous un voile bleu nuit, `UiStyle.make_lobby_background`)

## Tester
- Éditeur : Debug → Customize Run Instances → 2 instances. Héberger dans l'une, Rejoindre dans l'autre.
- Serveur dédié : `godot --headless -- --server` (port 7777 par défaut, `--port=XXXX` pour changer).

## Règle de délégation
- Collecte (chercher, lire, extraire) → sous-agent "chercheur" (Haiku)
- Synthèse de plusieurs sources → sous-agent "analyste" (Sonnet)
- Réfléchir, décider, écrire le code final → toi (Opus)
Délègue systématiquement la collecte, ne lis pas toi-même des dizaines de fichiers.
