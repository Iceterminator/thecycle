# Checklist — rapprocher le jeu de la vidéo de référence

> Source : `docs/REFERENCE_VIDEO.md` (écarts listés le 18/11/2026).
> Ce fichier est fait pour être traité **par une loop, un point à la fois**.

## Protocole de la loop (à suivre à chaque tour)

1. Lire ce fichier. Prendre le **premier point `[ ]`** dont les décisions (`Dx`) sont tranchées.
   Si toutes les décisions nécessaires d'un point sont encore « à trancher » : passer au suivant.
   S'il ne reste que des points bloqués : **s'arrêter** et lister les décisions à demander.
2. Coder **ce point seulement** (règles de `CLAUDE.md` : données dans `data/` et `Config`,
   serveur autoritaire, `Events`, typage statique, textes en français, nos propres noms).
3. Vérifier avec **tous** les critères du point :
   - `[analyse]` : `../../../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit` sans erreur ni nouvel avertissement de script ;
   - `[test]` : test réseau scripté hôte + client (méthode dans `docs/REPRISE.md`), qui affiche `OK` ;
   - `[capture]` : capture d'écran (méthode dans `docs/REPRISE.md`), enregistrée dans `docs/captures/<id>.png`, et comparée aux attentes écrites ;
   - `[code]` : la valeur ou la structure décrite existe dans le code.
4. Si un critère échoue : corriger et revérifier, **3 essais au maximum**. Ensuite, marquer le point
   `[!]` avec une ligne `Bloqué :` qui explique pourquoi, et passer au suivant.
5. Si tout passe : un commit en français (`Réf. Ax : …`), `git push`, cocher `[x]` et ajouter
   `À tester en jeu : …` quand le ressenti compte.
6. Après chaque **bloc** terminé (A, B, C ou D) : **s'arrêter** pour que l'utilisatrice teste en jeu.
7. Ne jamais modifier `project.godot` si l'éditeur est ouvert (les touches vont dans `Config.CODE_KEY_ACTIONS`).

États : `[ ]` à faire · `[x]` fait et vérifié · `[!]` bloqué · `[-]` abandonné (décision).

---

## Décisions à trancher par l'utilisatrice (avant la loop)

| # | Question | Proposition par défaut | Réponse |
| --- | --- | --- | --- |
| D1 | Rendu : garder le low-poly stylisé ou viser un rendu riche (textures peintes, végétation dense) ? | Garder le low-poly, mais reprendre la palette, la brume et la lumière de la vidéo | Par défaut (validé le 18/11/2026) |
| D2 | Touches : passer à G (boutique), A / E (capacités), L (kit), T maintenu (pacte) ? E sert déjà à interagir. | Garder Q / F et E ; boutique T → G ; kit K → L | Par défaut (validé le 18/11/2026) |
| D3 | Noms propres au jeu pour : la tempête (« pic du Cycle »), les cristaux d'orage, l'uplink | « Grande Marée », « Éclats d'orage », garder « Relais » | Par défaut (validé le 18/11/2026) |
| D4 | Carte : agrandir (île entourée d'eau, biomes) ? Quelle taille ? | 400 × 400 m, 3 biomes (canyon ocre, prairie, zone industrielle) | Par défaut (validé le 18/11/2026) |
| D5 | Fame d'un kill de joueur | 10 (au lieu de 50) | Par défaut (validé le 18/11/2026) |
| D6 | Véhicule (moto volante) | Abandonner pour l'instant | Par défaut (validé le 18/11/2026) |
| D7 | Défis personnels en partie | Abandonner pour l'instant | Par défaut (validé le 18/11/2026) |

---

## Bloc A — Boucle de partie

- [x] **A1. Tempête globale au lieu d'une zone.** Décisions : D3.
  Ce qu'il faut : plus de cercle ni de dégâts hors zone ; une annonce environ 60 s avant
  (bandeau vert) ; à environ 10:00 de partie, la tempête couvre toute la carte : ciel sombre, pluie, éclairs violets.
  Les phases restent dans `data/storm/`.
  - `[code]` `StormManager.is_in_storm()` n'utilise plus de rayon ; aucun cercle dans `map_info()`.
  - `[test]` avancer le temps à 10:30 (via `Events.time_skip_requested`) : la tempête est active, et aucun joueur ne prend de dégâts de tempête.
  - `[capture]` `A1.png` à 10:30 : ciel sombre, pluie visible, bandeau ou indicateur de tempête.
  - Fait le 18/11/2026 : test réseau OK (10:30, coin (90, 90) : tempête active, 0 PV perdu), capture `docs/captures/A1.png`.
    À tester en jeu : ressenti de la pluie et des éclairs, lisibilité dans la tempête. Note : erreur « Kit » au moment où un client rejoint (RPC reçu avant l'apparition du joueur), sans lien avec A1, à regarder à part.
- [x] **A2. Ressource d'orage pendant la tempête.** Décisions : D3. Dépend de A1.
  Ce qu'il faut : quand la tempête démarre, le serveur fait apparaître des cristaux d'orage (via le `MultiplayerSpawner`) et un contrat de collecte associé (`.tres` dans `data/contracts/`).
  - `[test]` à 10:30, au moins N cristaux d'orage existent (N lu dans les données) ; en récolter un augmente le contrat.
  - Fait le 18/11/2026 : test réseau OK (12 éclats + 1 collecteur créés à 10:00 et vus par le client ; ramasser puis déposer un éclat : objectif 0 → 30). Erreur « Kit » à la connexion corrigée au passage.
    À tester en jeu : nombre d'éclats et place du collecteur (30, 0, 30).
- [ ] **A3. Calendrier de l'évac.**
  Ce qu'il faut : annonce à 16:10 (bandeau rouge « La navette arrivera dans … »), atterrissage à 19:10, décollage à 20:00.
  - `[code]` `Config.EVAC_LANDING_TIME == 19 * 60 + 10`, avec une constante pour l'annonce à 16:10.
  - `[test]` à 16:15, l'annonce a été émise ; à 19:15, la navette est posée.
- [ ] **A4. Plateforme d'évac bloquée par des monstres.** Dépend de A3.
  Ce qu'il faut : à l'annonce, un camp de monstres apparaît sur la plateforme (réutiliser `data/camps/`) ;
  le message « NAVETTE BLOQUÉE — NETTOYER LA PLATEFORME » s'affiche ; le contrat « Nettoyer la plateforme » est actif.
  La navette ne se pose qu'une fois la plateforme vide (et pas avant 19:10).
  - `[test]` plateforme non nettoyée à 19:15 : navette pas posée ; tuer les monstres du camp : la navette se pose.
- [ ] **A5. Classement final : les évacués d'abord.**
  Ce qu'il faut : le tri final met tous les évacués devant tous les non-évacués, puis trie par Fame.
  Supprimer `EVAC_MISSED_PENALTY`.
  - `[test]` joueur A (évacué, 10 Fame) et joueur B (non évacué, 200 Fame) : A est 1er dans les résultats.
- [ ] **A6. Contrats qui arrivent au fil de la partie.**
  Ce qu'il faut : chaque `.tres` de `data/contracts/` reçoit `unlock_time` (s) ; le HUD n'affiche que les contrats débloqués ;
  annonce « Nouveau contrat : … » ; 5 à 7 lignes visibles au maximum.
  - `[test]` à 00:30, seuls les contrats avec `unlock_time <= 30` sont actifs ; à 08:00, au moins un nouveau contrat est apparu.
  - `[capture]` `A6.png` : liste des contrats à gauche, 7 lignes au maximum.
- [ ] **A7. Le Relais change de place.**
  Ce qu'il faut : toutes les N s (valeur dans le `.tres`), le Relais se déplace vers un autre point prévu ;
  bandeau « Changement de relais dans X s » 20 s avant.
  - `[test]` la position du Relais change après N s ; l'annonce est émise 20 s avant.

## Bloc B — Armes, touches, systèmes

- [ ] **B1. 3 emplacements d'arme.**
  Ce qu'il faut : `Inventory.WEAPON_SLOTS := 3` ; les gadgets passent aux emplacements 3 et 4 ; touche 3 = arme 3
  (les soins et recharges qui étaient sur 3 / 4 sont déplacés ou retirés, voir `REPRISE.md`) ; HUD en bas à droite avec 3 silhouettes.
  - `[code]` `grep -n "WEAPON_SLOTS" systems/` : aucun `2` codé en dur restant dans les calculs d'emplacement.
  - `[test]` ramasser 3 armes : les 3 sont portées, et changer d'arme avec 1 / 2 / 3 marche.
- [ ] **B2. Touches.** Décisions : D2.
  - `[code]` `Config.CODE_KEY_ACTIONS` correspond à D2 ; tous les textes du HUD qui citent une touche sont à jour (`grep -rn "\[T\]\|\[K\]" systems/`).
- [ ] **B3. Kit de Niv. 0 à 6, avec annonce de niveau.**
  Ce qu'il faut : niveau de départ 0 ; à chaque niveau, une grande annonce au centre « NIVEAU N — <bonus> »
  (texte tiré de `level_perk_effects`) et un rayon vertical rose sur le joueur.
  - `[test]` donner l'XP d'un niveau : le niveau passe de 0 à 1 et l'annonce est émise avec le texte du bonus.
- [ ] **B4. Boutique en 3 colonnes + lâcher des crédits.**
  Ce qu'il faut : colonnes Armes / Compétences / Divers ; prix en rouge si pas assez de crédits ;
  « Niv. 2 — Améliorer : X ₵ » ; champ + bouton « LÂCHER (min. 25) » qui crée un objet crédits au sol (serveur).
  - `[test]` lâcher 30 crédits : le solde baisse de 30, et un objet crédits de 30 apparaît au sol ; lâcher 10 est refusé.
  - `[capture]` `B4.png` : boutique ouverte, 3 colonnes.
- [ ] **B5. Fame d'un kill de joueur.** Décisions : D5.
  - `[code]` `Config.PLAYER_KILL_FAME` correspond à D5.
- [-] **B6. Véhicule.** Décisions : D6 (par défaut `[-]`).
- [-] **B7. Défis personnels.** Décisions : D7 (par défaut `[-]`).

## Bloc C — Graphismes

- [ ] **C1. Ambiance de jour.** Décisions : D1.
  Ce qu'il faut : ciel clair `#dae8de` à l'horizon ; soleil chaud et ombres marquées ; brume forte au loin
  (couleur du ciel, densité telle que le relief à 150 m soit à moitié effacé) ; sol ocre `#cfa35b` ; herbe olive `#887b1a` / `#23320c`.
  - `[capture]` `C1.png` à 02:00, vue vers l'horizon : ciel presque blanc, relief lointain délavé par la brume, couleurs chaudes.
- [ ] **C2. Jour → tempête → nuit.** Dépend de A1.
  Ce qu'il faut : l'`Environment` passe en douceur (tween) du jour à la tempête (bleu-gris `#343b44`, lumière froide, éclairs violets en flash),
  puis à la nuit après 16:00 (lucioles dorées en particules près des arbres).
  - `[capture]` `C2_jour.png` (05:00), `C2_tempete.png` (11:00), `C2_nuit.png` (17:00) : trois ambiances clairement différentes.
- [ ] **C3. Cristaux et extraction en magenta.**
  Ce qu'il faut : cristaux en `#e019d2`, émissifs ; barre d'extraction rose `#f55074` « Prêt à être récupéré » ;
  petite foreuse sur pieds à côté du cristal.
  - `[capture]` `C3.png` : un cristal en cours d'extraction, avec la barre rose visible.
- [ ] **C4. Effets lumineux.**
  Ce qu'il faut : glow réglé pour que les explosions, le flash d'embarquement et les rayons montent jusqu'au blanc ; flash blanc plein écran à l'embarquement.
  - `[capture]` `C4.png` : une explosion de grenade.
- [ ] **C5. Nouvelle carte (île).** Décisions : D1, D4. **Gros chantier : le découper en sous-points avant de le coder.**
  Ce qu'il faut : terrain en relief, eau tout autour, biomes de D4, lieux nommés (nos propres noms), plateforme d'évac au centre ;
  le navmesh se génère toujours à partir des collisions.
  - `[test]` le navmesh se génère, et un monstre de chaque camp atteint un point à 30 m.
  - `[capture]` `C5.png` : vue de haut (carte Tab) qui montre l'île et ses biomes.

## Bloc D — HUD et interface

- [ ] **D-1. Palette du HUD en partie.**
  Ce qu'il faut : en partie, texte blanc et cyan (`#61d4f5` pour le bouclier) presque sans fond ;
  jaune `#f1dc33` seulement pour les gains et objectifs ; rouge seulement pour les menaces.
  Les menus du lobby gardent « Nuit polaire ».
  - `[capture]` `D1.png` : HUD en partie, sans panneau bleu plein derrière les éléments.
- [ ] **D-2. Boussole en haut au centre.**
  - `[capture]` `D2.png` : graduations en degrés + lettres cardinales qui défilent avec la caméra (2 captures à 90° d'écart).
- [ ] **D-3. Bandeaux d'événement à rayures.**
  Ce qu'il faut : sous le classement en haut à droite, des bandeaux à rayures diagonales avec barre de progression :
  vert (tempête), rouge (évac), jaune (relais). Ils réutilisent `Events.announcement` ou un nouveau signal.
  - `[capture]` `D3.png` : au moins un bandeau avec sa barre de progression.
- [ ] **D-4. Fil d'actualité + grandes annonces.**
  Ce qu'il faut : panneau doré « X a rempli <contrat> (+N) » ; grandes annonces au centre (« Contrat rempli », « Niveau N »).
  - `[test]` remplir un contrat : l'événement du fil est émis chez l'autre client.
- [ ] **D-5. Touches en pavé blanc + rappel de rechargement.**
  Ce qu'il faut : un helper `UiStyle.key_badge("G")` (pavé blanc, texte noir) utilisé partout dans le HUD ;
  « [R] POUR RECHARGER » en jaune quand le chargeur est vide.
  - `[code]` plus aucune touche écrite en texte brut `[X]` dans `hud.gd`.
- [ ] **D-6. Lunette et flou de sprint.**
  Ce qu'il faut : les fusils de précision en visée assombrissent tout l'écran sauf un cercle ; léger flou ou vignette en sprint.
  - `[capture]` `D6.png` : visée avec un fusil de précision.
- [ ] **D-7. Écran de résultats.**
  Ce qu'il faut : classement (évacués cochés, les autres avec une tête de mort) ; histogramme des points par type de contrat ;
  réputation gagnée selon la position et l'évac.
  - `[test]` en fin de partie, les résultats contiennent les points par type de contrat pour chaque joueur.
  - `[capture]` `D7.png` : l'écran de résultats.
