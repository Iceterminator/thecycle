# À faire — pour que le jeu soit beau

But : quitter l'aspect « Roblox » pour une science-fiction réaliste et colorée (planète extraterrestre
luxuriante, lumière chaude et brumeuse, matériaux usés, technologie industrielle massive).
Liste à cocher au fur et à mesure (`- [x]`). Établie le 20/11/2026.

## Lumière et rendu (gain rapide)
- [x] Activer SSAO + SSIL
- [ ] Éclairage global : SDFGI essayé puis retiré (7 FPS sur GPU intégré) — à revoir (VoxelGI, lumière cuite)
- [x] Tonemap AgX (exposition auto retirée : image blanche)
- [ ] Étalonnage des couleurs (LUT) — contraste / saturation faits, LUT pas encore
- [x] Brouillard volumétrique (+ tempête)
- [x] Ombres douces, 4 cascades sur 150 m
- [x] Vrai ciel (`systems/rendu/ciel.gdshader` + `ciel.tres`) : nuages qui défilent, planète géante à anneaux, 2 lunes ; la tempête couvre et assombrit le ciel
- [x] Post-traitement : flou de profondeur, aberration chromatique, vignette, grain (`systems/rendu/`)

## Matériaux et textures
- [x] Textures du sol (Poly Haven, `assets/textures/sol/`) : herbe, roche, sable, neige, boue, terre — normal maps coupées en Bas
- [x] Shader de terrain (`systems/map/terrain_sol.gdshader`) : mélange par biome, terre, vase, roche selon la pente — reste : casser la répétition des textures
- [ ] Decals : saleté, rouille, mousse

## À retoucher (avis du 20/11/2026)
- [ ] Arbres : jugés moches (« textures 2D partout ») — fait : plaques 3× plus nombreuses et plus petites, orientées au hasard, normales sphériques, fondu de profil (`herbe_vent.gdshader` : `normale_haut`, `fondu_profil`). Si insuffisant : vraies feuilles 3D de près (LOD)
- [ ] Sols : trop répétitifs — fait : variante tournée par zones, seconde échelle, taches de couleur (`terrain_sol.gdshader`). À juger en jeu

## Modèles
- [ ] Remplacer les modèles Quaternius low-poly par des modèles détaillés (Poly Haven, CC0, ou Blender)
  - [x] Rochers (Poly Haven, `assets/models/nature/rochers/`) — neige : manque un shader de neige sur le dessus
  - [x] Herbe (touffes Poly Haven, `assets/models/nature/herbe/`) — clairsemée : à compléter par une texture d'herbe sur le terrain
  - [x] Buissons (Poly Haven, `assets/models/nature/plantes/`) : fougères, anthuriums, rooibos, branches sèches — reste : souches / rondins Quaternius, petites plantes (`small`), plantes extraterrestres
  - [x] Arbres (Poly Haven, `assets/models/nature/arbres/`) : feuillus, arbres d'île, sapin, arbres carquois — 3 000 à 5 000 triangles (écorce allégée + plaques de feuillage). Reste : plus de variantes de sapin, pins
- [ ] Personnages réalistes : combinaisons de prospecteur, casques, équipement — fait : Prospecteur = astronaute Tripo (apparence du lobby) ; reste : d'autres tenues, remplacer Homme / Femme (Superhero)
- [ ] Armes détaillées et texturées
- [ ] Végétation dense : herbe en MultiMesh, buissons, plantes extraterrestres
- [x] Shader de vent sur la végétation (`systems/decor/herbe_vent.gdshader`) : herbe, plantes, feuillage des arbres
- [ ] LOD pour garder les performances

## Ambiance et interface
- [x] Particules : ambiance par biome (`systems/rendu/ambiance_particules.gd` : pollen, poussière, flocons, lucioles), tempête (`systems/storm/storm_effets.gd` : éclairs visibles, rafales ; pluie poussée par le vent)
- [x] Traînées de balles, fumée des grenades (`systems/combat/weapon_effects_fx.gd`, `weapon_effects_explosion.gd` : traçants lumineux, flash, étincelles, poussière d'impact, explosion avec fumée qui reste)
- [x] HUD sobre : blanc + cuivre (+ rouge pour le danger), fonds semi-transparents sans bordure, lignes fines (`hud.gd`, `hud_widgets.gd`) — reste : police plus fine (Barlow Condensed Light/Regular non installées)
- [ ] Direction artistique par biome : palette et lumière propres à chacun
