# Quêtes et contrats

Code : `systems/quests/` (cristal, foreuse, `QuestManager`), `systems/contracts/` (base `ContractSite`) · Données : `data/quests/`, `data/contracts/`, `data/objectives/`, `data/rules/match.tres`

## Implémenté
- Cristal + foreuse (3 difficultés) : lancer la foreuse, défendre contre des vagues, extraire.
  Les cristaux non commencés montent d'un niveau à 10:00.
- Contrats sur la carte, ouverts à tous : relais satellite, extracteur d'Ambrine,
  collecteur de Lumicèpes + Tiques, station de recherche, drones en panne, Prime (contrat),
  éclats d'orage portés (pendant la Grande Marée), nettoyage de la plateforme d'évac.
- Points d'objectif à paliers ; chaque palier donne Fame + crédits + XP de kit (`data/objectives/`, valeurs du jeu d'origine, voir « Alignement sur les contrats d'origine »).
- **Tirage par partie (19/11/2026)** : le Cristal est toujours présent ; 5 autres types sont tirés (`drawn_quest_types`), chacun en N exemplaires (min-max dans `data/quest_draws/`), placés sur les `QuestSpots` (40). Niveau du cristal pondéré (`variant_weights` : 50 % / 35 % / 15 %). Deux quêtes non-cristal sont à au moins `quest_min_spacing` (60 m) ; les cristaux (`ignores_spacing`) ignorent la règle ; **Répartition** (`QuestPlacement`, poids `quest_spread_*` dans match.tres) : chaque exemplaire est placé par score (éloigné des exemplaires du même type, quart de carte sans ce type, quart opposé au 1er, malus des quarts chargés), tirage parmi les 3 meilleurs ; plus de spot libre = avertissement et exemplaire sauté. 5 points de Lumicèpes par collecteur de Lumicèpes tiré. **Apparition différée** (`QuestDelayed`) : `spawn_delay` (aucune quête pour l'instant) ; un type tiré mais pas encore apparu reste dans la liste Tab ; une nouvelle partie annule les apparitions en attente. Code : `quest_draw.gd`, `quest_delayed.gd`, `quest_factory.gd`, `lumicep_ticks.gd`.

## Reste à faire

- Contrats qui arrivent au fil de la partie (`unlock_time`), annonce « Nouveau contrat ».

## Règles du jeu original : à compléter

## Conception détaillée (déplacé de DESIGN.md)

### 4 bis. Quête « cristal + foreuse » (17/11/2026, première quête codée)
- Des **cristaux** sont posés sur la carte, en 3 difficultés : **facile** (2 vagues, +200 pts d'objectif), **moyen** (4 vagues, +400 pts), **difficile** (6 vagues, monstres +40 % PV et +30 % dégâts, +600 pts) : une vague par tranche de 100 points. Les vagues (`data/quests/waves/forage_1` à `forage_6`) grossissent : Rôdeurs de plus en plus nombreux, Colosses à partir de la 2e vague.
- **Maintenir E 3 s** sur un cristal déploie une **foreuse**. Des vagues de monstres apparaissent à 16-22 m et attaquent la foreuse (elle a des PV). Ils ripostent si on leur tire dessus, puis retournent sur la foreuse.
- Il faut **tuer tous les monstres de toutes les vagues**. Si la foreuse est détruite, la quête échoue et le cristal redevient utilisable 15 s plus tard.
- Une fois les vagues finies, **maintenir E 5 s** sur la foreuse donne les **points de quête** à celui qui extrait (un autre joueur peut voler l'extraction).
- Un cristal extrait est épuisé ; pour les tests, il réapparaît après 120 s. Valeurs dans `data/quests/*.tres` et `Config`.
- Les points de quête sont affichés en haut à droite. Ils préparent la Fame et le classement de l'étape 5.

### 4 ter. Contrats sur la carte (17/11/2026, codés, ouverts à tous sans tableau de contrats)
Inspirés des contrats du jeu d'origine, avec nos propres noms. Réglages dans `data/contracts/*.tres` et `Config`.
- **Forage de cristal** : voir §4 bis.
- **Relais satellite (tournant, 21/11/2026)** : `uplink_count` = 3 relais tirés dès le départ (`data/quest_draws/uplink.tres`, min = max = 3, éloignés par la répartition), **un seul actif à la fois** : le 1er s'active à `uplink_first_time` (114 s : 18:06 restantes sur 20 min dans l'original, soit 114 / 1200 x `match_duration`), reste actif `uplink_active_time` (362 s), puis le suivant (114 + 3 x 362 = 1200 s). Rang d'activation = ordre de création (`Uplink._rank`), état calculé sur le temps de partie (clients compris). Capture : maintenir E 10 s ; +3 pts/s au propriétaire même loin, jusqu'à ce qu'un rival le reprenne ou que le relais s'éteigne (alors il ne rapporte plus et ne se capture plus). Annonce « Nouveau relais actif » à chaque activation ; seul le relais actif est visible partout sur la carte (les éteints : gris, de près).
- **Extracteur d'Ambrine (bouches, 21/11/2026)** : **4 filons** de 3 à 4 bouches groupées (`data/quest_draws/extractor.tres` : min = max = 4 filons, `cluster_min` / `cluster_max` = 3 / 4 bouches, dans `cluster_radius` 9 m (le décor est dégagé sur 13 m autour des emplacements, marge pour les gros rochers), au moins `cluster_gap` 1 m entre deux bouches, hors de l’eau et des pentes de plus de `cluster_max_slope` (≈ 27°), 5 cm au-dessus du relief ; `QuestDraw._cluster`), comme dans le jeu d’origine (gisements de Letium regroupés depuis le Weekly Playtest 1), visibles sur la carte pour tous. Maintenir E 4 s sur une bouche libre pose un extracteur ; un joueur peut en posséder plusieurs, chacun monte de niveau seul (`level_rates` / `level_times` : 0,2 pt/s, 0,4 après 60 s, 1 pt/s après 120 s ; le débit affiché est la somme). **Piratage** : un rival maintient E `hack_time` (6 s) sur un extracteur adverse ; dès le début du maintien le propriétaire reçoit « Votre extracteur est piraté ! » (`server_hold_started`, appelé par `Interactor`) ; s'il est pris, le niveau repart à zéro.
- **Cœur stellaire** : supprimé (21/11/2026) ; le Convoi du jeu d'origine le remplacera (`docs/a_faire_gameplay.md`).
- **Chasse à la biomasse** : plus de collecteur. Les monstres lâchent des échantillons au sol ; les ramasser donne directement leurs points (75 / 150 / 300 selon la créature et la rareté, voir `docs/creatures.md`). Objectif toujours actif (`always_objectives`).
- **Éclats d'orage portés (Zeal Shard, 21/11/2026)** : plus de collecteur. Ils tombent avec la Grande Marée (`StormShards`, `shard_count`), chacun rouge avec `red_chance` (0,15). Ramasser un éclat (E) : on le porte et on gagne `carry_points_per_second` (5 pts/s, estimé) d'objectif tant qu'on le porte ; un seul à la fois. Le moindre dégât (joueur ou monstre) le fait tomber aux pieds ; à la mort aussi (`InventoryDeath`). Éclat rouge (`storm_shard_red.tres`) : mêmes points, +`red_evac_fame` (40 Fame, estimé) si on embarque dans l'évac avec. Éclats au sol et porteurs visibles de tous sur la carte (`map_view_shards.gd`). Données : `data/items/storm_shard*.tres`.
- **Lumicèpes** : champignons qui repoussent sur 8 spots ; les porter attire des **Tiques**, de plus en plus souvent (24 s ÷ nombre porté) ; dépôt = 40 pts l'unité (portés sans limite).
- **Station de recherche** : 3 nœuds couverts de biomasse ; chaque activation (E 3 s) fait venir une vague qui attaque l'activateur ; puis l'ordinateur central = 1 point d'objectif (paliers 1, 3, 6, 10… stations).
- **Station centrale (Central Power, 21/11/2026)** : son emplacement est tiré au début (`QuestDraw` : un point libre de plus, seulement si des stations de recherche sont tirées ; `central_spot`). Quand `central_unlock_count` stations ont été réactivées dans la partie (`Events.facility_reactivated`, compté par `CentralPower`, une seule ouverture par partie), elle s'ouvre : annonce à tous, visible sur la carte (`always`). Zone de `zone_radius` : chaque joueur vivant dedans gagne `points_per_second` points de l'objectif « station centrale » (`data/objectives/station_centrale.tres`, 80 / 160 / 240, 40 Fame). Ouverte `active_time` s ; un Gardien (`gardien_1` ou `gardien_2`) apparaît toutes les `guard_interval` s tant qu'un joueur est dans la zone (`guard_max` vivants au plus) et l'attaque ; elle s'éteint avec annonce, puis disparaît. Code : `central_station.gd`, `central_power.gd` ; données : `data/contracts/central.tres`.
- **Drones en panne (Drone Salvage, 21/11/2026)** : un porteur au centre, 3 drones en panne autour. Le 1er joueur qui passe à moins de `trigger_radius` (60 m) fait apparaître la meute (`drones_meute.tres` : Rôdeurs + 1 Cracheur) qui attaque les drones (choix : au déclenchement et pas dès le départ, pour que les drones ne meurent pas avant l'arrivée de quiconque). Maintenir E 1,5 s sur un drone le relance (il s'envole vers le porteur) : 100 pts si PV > 80 %, 70 si > 40 %, sinon 40 (`condition_*`). Celui qui relance le dernier drone utilisable déclenche le décollage (`launch_time` 60 s) : les vagues (`waves`) attaquent le porteur (`carrier_health` PV) ; tous les autres joueurs reçoivent « Empêchez le décollage ! » et peuvent tirer dessus (le déclencheur ne peut pas). Il tient : +`launch_fame` (3) Fame au déclencheur (et son partenaire de pacte, `add_contract_fame`) ; détruit : rien. Tous les drones détruits avant : échec. Code : `drone_site.gd` + helpers `drone_site_visual / _waves / _launch`.
- **Prime (Bounty, 21/11/2026)** : contrat d'origine, plus de prime sur le meneur. Objectif `data/objectives/prime.tres` (sans paliers, toujours dans la partie : `always_objectives`), faction ICA (choix : déjà celle de la Prime dans nos docs, l'original ne la donne pas). Chaque joueur ÉLIMINÉ (mort, pas à terre) par un tueur qui a la Prime ACTIVE lui rapporte `bounty_kill_fame` (5, `economy.tres`) de Fame + la réputation de la faction ; `player_kill_fame` reste en plus. Code : `ContractBoard._on_player_died`.
- **Surtension (Surge Crystals, 21/11/2026)** : `surge_lead` (120 s) avant le début de la Grande Marée, annonce « Surtension détectée » puis `surge_count` (3) cristaux sur des emplacements de quête libres (`QuestFreeSpots` : aucune quête à moins de 4 m, loin des joueurs d'abord, `surge_min_player_distance` 60 m), visibles de tous sur la carte (`map_view_evenements.gd`), pendant `surge_lifetime` (90 s). Ramasser (E) = `surge_points` (400) points de l'objectif `surtension` (1 palier : 1000 points = 20 Fame, 40 crédits, XP 1000 ; faction Osiris). Objets au sol `data/items/surge_crystal.tres`. Code : `systems/contracts/surge_crystals.gd`. Test : `test_18_surtension.gd`.
- **Boss Alpha (Warden Alpha, 21/11/2026)** : apparaît à `alpha_time` (720 s) sur un emplacement libre, annonce, visible de tous sur la carte. Fame : `alpha_step_fame` (25) à chaque tranche de 1 / `alpha_steps` (25 %) des PV max qu'un joueur lui a infligés (4 tranches au plus) + `alpha_kill_fame` (25) pour qui l'achève (125 max). Choix : Fame donnée directement par `AlphaBoss` (`add_contract_fame`), sans paliers de points ; `data/objectives/alpha.tres` (faction Korolev) ne sert qu'à proposer le contrat au tableau : la réputation n'est donnée que s'il est actif. Code : `systems/monsters/alpha_boss.gd`. Test : `test_17_alpha.gd`.
- **Évac** : codé à l'étape 6, voir §9.
- **Tableau de contrats (21/11/2026)** : voir ci-dessous. Les contrats sur la carte restent ouverts à tous (points d'objectif, Fame, crédits, XP) ; seule la réputation de faction dépend des contrats actifs.
> **Deux types de points (17/11/2026).** Les **points de classement** forment le score général. Les objectifs Forage, Relais, Ambrine, Biomasse, Lumicèpes, Éclats, Station et Drones rapportent des **points d'objectif** propres à chacun ; chaque **palier** atteint donne des points de classement, des crédits et de l'XP de kit. Paliers dans `data/objectives/*.tres`. La station et les drones sont aussi des objectifs à paliers ; Les chiffres en « pts » des lignes ci-dessus sont des points d'objectif.


### Tableau de contrats (21/11/2026)
Code : `systems/contracts/contract_board.gd` (serveur : tirage, vérifications ; nœud `World/ContractBoard`), `contract_ui.gd` (panneau du joueur local, touche **J**, s'ouvre au largage) · Règles : `contracts_offered` (4), `max_active_contracts` (2) dans `match.tres`.
- Au tirage des quêtes (`Events.objectives_drawn`), chaque joueur reçoit 4 contrats tirés parmi les objectifs de la partie (quêtes tirées, `always_objectives` dont la Prime), sans doublon, différents d'un joueur à l'autre. Un contrat = un objectif (`data/objectives/`) et sa faction.
- RPC `request_activate` / `request_abandon` (any_peer, vérifiées par le serveur : contrat proposé, 2 actifs au plus). Abandonner libère une place ; le contrat reste proposé (réactivable). État renvoyé au seul joueur concerné.
- Effet : points d'objectif, Fame, crédits, XP : pour tous, comme avant. La **réputation** n'est donnée que si l'objectif du palier (ou du bonus de lancement des drones, d'éclat rouge) est un contrat ACTIF du joueur (`Score.add_contract_fame(..., with_rep)`). Avec un pacte, la règle suit le joueur qui gagne la Fame.
- HUD : les contrats actifs sont marqués « ◆ » dans la liste de quêtes (la Prime y apparaît quand elle est active). Test : `tests/test_16_contrats.gd`.
- Reste : contrats qui arrivent au fil de la partie.

### 5. Contrats
- 4 contrats proposés au largage, 2 actifs au maximum. On en reprend de nouveaux à chaque fin.
- Chaque contrat appartient à une faction et rapporte de la Fame + des crédits + des points de réputation.

| Type | Objectif | Fame de départ |
| --- | --- | --- |
| Livraison | Aller du point A au point B avec un objet | 100 |
| Récolte | Ramasser X ressources et les déposer | 150 |
| Chasse | Tuer X monstres d'un type | 150 |
| Contrôle | Tenir une zone pendant 60 s (roi de la colline) | 200 |
| Données | Pirater un terminal (interaction longue, vulnérable) | 150 |
| Prime | Tuer des joueurs tant que le contrat est actif | 5 par kill |

### Alignement sur les contrats d'origine (21/11/2026)
Paliers (`thresholds` = `total`, `rewards` = `vp`, `credit_rewards`, `xp_rewards`) repris de `contracts[].tiers` de `data/reference/the_cycle_legacy_data.json`. Au-delà du dernier palier listé : même écart et même récompense que le dernier. Un palier atteint (serveur, `Score.add_objective_points`) donne : points de classement (puis Fame / réputation), crédits, XP de kit = `roundi(xp × economy.kit_xp_contract_scale)` (0,05). `kit_xp_per_objective_point` est à 0 (l'XP vient des paliers) ; l'XP par Fame reste.

| Objectif | Contrat d'origine | Gain de points d'objectif |
| --- | --- | --- |
| relais | Uplink | 3 pts/s (30 / 10 s), capture en 10 s |
| forage | Veltecite Minerals | une vague par tranche de 100 points : cristal facile / moyen / difficile = 200 / 400 / 600 pts = 2 / 4 / 6 vagues (`data/quests/waves/forage_N.tres`, de plus en plus fortes, Colosses dès la 2e ; difficile : monstres renforcés) |
| biomasse | Hunt | 75 / 150 / 300 par échantillon ramassé au sol (valeur selon la créature et la rareté) |
| lumicepes | Brightcaps | 100 par Lumicèpe (estimé) |
| eclats_orage | Zeal Shard | 5 pts/s tant qu'un éclat est porté (estimé) |
| ambrine | Letium Gas | par extracteur, niveaux 0,2 / 0,4 / 1 pt/s (0, 60, 120 s) |
| station | Power Facilities | 1 par station réactivée (paliers 1, 3, 6, 10… stations) |
| station_centrale | Central Power | 2 pts/s (estimé) par joueur dans la zone ; paliers 80 / 160 / 240, 40 Fame chacun (duo à 30 ignoré) |
| drones | Drone Salvage | par drone relancé : 100 (intact, PV > 80 %) / 70 (bon, > 40 %) / 40 (endommagé) ; paliers 200 / 600 / 1200 |

Bounty : 5 VP par élimination (`bounty_kill_fame`), voir « Prime » plus haut.

**Valeurs estimées** (notées en commentaire dans chaque `.tres`) : surtension : `surge_lead`, `surge_count`, `surge_lifetime`, `surge_points` (400), `surge_min_player_distance`, crédits 2 × vp et XP 50 × vp, icône ; Alpha : `alpha_time` (720 s), faction Korolev, tout `alpha.tres` sauf les 8000 PV ; seuils d'état (80 % / 40 %), PV des drones et du porteur, `launch_time` (60 s), `trigger_radius`, compositions de la meute et des vagues des drones ; station centrale : `central_unlock_count` (2), `zone_radius` (10 m), `points_per_second` (2), `active_time` (300 s), `guard_interval` (30 s), `guard_max` (6), crédits 2 × vp et XP 50 × vp ; crédits = 2 × vp et XP = 50 × vp quand l'original n'en donne pas (Veltecite, Mag-Train, Letium Gas, Drone Salvage) ; VP 10 / 15 / 20 pour Letium Gas et Drone Salvage (1 / 2 / 3 d'origine jugés douteux) ; palier 3 des drones (total 1200) ; gains par unité de biomasse, Lumicèpe et éclat. Valeurs d'origine gardées bien que douteuses : Zeal Shard palier 4 = 20 crédits ; VP élevés de Power Facilities.
