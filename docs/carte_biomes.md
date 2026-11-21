# Carte : les 4 biomes

La carte (300 × 300 m) est découpée en 4 biomes. Tout est calculé de façon déterministe
(bruit à graine fixe) : chaque peer obtient le même relief, les mêmes couleurs et le même décor,
rien ne passe par le réseau.

| Biome | Où | Ambiance | Fiche |
| --- | --- | --- | --- |
| **Prairies d'Ambre** | sud + centre (évac) | relief de base, forêts, fleurs, bouleaux | `data/biomes/plaine.tres` |
| **Dunes de Sel** | est | sable, dunes douces (relief × 0,55 + ondulations), palmiers, cactus, arbres morts, rochers ocre, végétation rare | `data/biomes/desert.tres` |
| **Cimes Blanches** | nord | neige, collines plus hautes (× 1,25, +1,5 m), sapins et arbres enneigés, rochers, souches, tas de neige | `data/biomes/neige.tres` |
| **Marais des Brumes** | ouest | terrain bas (× 0,3, −2,6 m), lac peu profond, saules, quenouilles, nénuphars, galets moussus | `data/biomes/marais.tres` |

Captures : `docs/captures/biomes/` (`carte_relief.png` = carte Tab / minimap, puis une vue par biome).

## Répartition (`systems/map/map_biomes.gd`, `MapBiomes`)
- 4 secteurs de 90° autour du centre ; frontières tordues par du bruit (`WARP`) et fondues
  (`BLEND`) : `weights_at(x, z)` renvoie le poids de chaque biome (somme 1).
- Le centre (rayon 32 m, fondu sur 28 m) est entièrement Prairies : l'évac ne change pas.
- La forêt hors carte suit le biome voisin.

## Ce que les biomes changent
- **Relief** (`MapTerrain._raw_height` → `MapBiomes.shape_height`) : `height_scale`, `height_offset`,
  `dunes`, mélangés selon les poids. Zones plates des points d'intérêt et de l'évac inchangées.
- **Sol** (`MapTerrainMesh._color`) : couleurs herbe / terre / roche / sommet du biome ; vase sous l'eau.
- **Carte et minimap** (`MapRelief`) : `map_color` du biome, mares en bleu.
- **Eau** (`systems/map/map_water.gd`) : surface à `MapBiomes.WATER_LEVEL` (−2,2 m) sur les cases
  de 4 m du marais dont le sol passe dessous. Pas de collision : on marche au fond (≈ 1 m au plus profond).
- **Décor** (`MapDecorPlan` + `map_decor_pick.gd`) : à chaque tirage, un biome est choisi selon les poids
  (les frontières mélangent les décors), puis la densité du biome décide si quelque chose pousse,
  puis un modèle au hasard dans sa liste. Rien ne pousse dans l'eau, sauf les plantes d'eau
  (`water_plants`, posées à la surface). Nombres totaux inchangés (`TREE_COUNT`…).

## Construction asynchrone (aucune image longue)
La carte se construit au début du briefing, sur chaque peer (`Niveaux` -> `NiveauxCarte`, `systems/niveaux/`),
en coroutine : les calculs purs tournent dans le `WorkerThreadPool` (attendus image par image, `systems/map/map_thread.gd`),
les nœuds sont créés par tranches de `Config.MAP_BUILD_BUDGET_MS` (8 ms) par image.
- Relief (`map_terrain_build.gd`) : grille de hauteurs (une tâche par ligne), puis `MapTerrain.appliquer_relief`
  (collision) ; rendu : lignes du maillage (`MapTerrainMesh.calculer_ligne`) et vertices de l'eau
  (`MapWater.calculer`) en thread, nœuds posés ensuite. Pas de rendu en serveur dédié.
- Décor (`map_decor.gd` + `map_decor_plan.gd`) : le plan (quoi, où, échelle, rotation ; mêmes tirages, même ordre
  qu'avant, graine fixe `MapDecorPlan.SEED`, donc identique chez tous les peers) est calculé en thread ;
  les modèles sont préchargés en arrière-plan (`DecorModels.precharger`), puis instanciés par tranches.
- Le changement de niveau (retour au lobby) annule une construction en cours : `NiveauxCarte.annuler()`,
  les threads en cours sont simplement jetés.
- Journal : `[Carte] prête en X ms, image max Y ms`.

## Réglages (`resources/biome_data.gd`, `BiomeData`)
Couleurs, relief, densités (`tree_density`…) et listes de modèles `chemin res:// → échelle`
(les packs n'ont pas la même taille : les modèles Quaternius « Ultimate » font environ la moitié
du MegaKit, d'où des échelles autour de 2).

## Modèles (tous CC0, licences copiées dans chaque dossier)
- `assets/models/nature/` : Stylized Nature MegaKit (Quaternius), base des Prairies.
- `assets/models/nature/plaine/`, `desert/`, `neige/`, `marais/` : Ultimate Nature Pack (Quaternius, FBX).
- `desert/Rock_Desert_*.gltf` : rochers du MegaKit avec sa texture `Rocks_Desert_Diffuse.png`
  (même `.bin`, seul le chemin de texture change).
- `neige/snow-pile.glb` : Holiday Kit (Kenney).
- `marais/Meshes/` : Pond Kit (Asset Quest). Ses FBX ne retrouvent pas leurs textures : les matériaux
  sont remplacés à l'import (`_subresources` des `.fbx.import`) par `marais/pond_plantes.tres`
  (atlas, transparence découpée) et `marais/pond_props.tres`.
- Packs bruts complets : `packs_telecharges/` (non versionné, ignoré par Godot).

## Décisions
- Marais à l'ouest près des Prairies (couleurs proches), neige au nord, désert à l'est.
- Un seul grand lac dans le marais (le relief de base y est surtout positif) ; pour plus de mares,
  baisser `height_offset` du marais (chaque −0,2 m agrandit nettement l'eau).
- Pas de nage ni de ralentissement dans l'eau (à faire plus tard si besoin).
