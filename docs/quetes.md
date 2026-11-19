# Quêtes et contrats

Code : `systems/quests/` (cristal, foreuse, `QuestManager`), `systems/contracts/` (base `ContractSite`) · Données : `data/quests/`, `data/contracts/`, `data/objectives/`, `data/rules/match.tres`

## Implémenté
- Cristal + foreuse (3 difficultés) : lancer la foreuse, défendre contre des vagues, extraire.
  Les cristaux non commencés montent d'un niveau à 10:00.
- Contrats sur la carte, ouverts à tous : relais satellite, extracteur d'Ambrine, Cœur stellaire,
  collecteurs (biomasse, Lumicèpes + Tiques), station de recherche, drones en panne, prime,
  collecteur d'Éclats d'orage (pendant la Grande Marée), nettoyage de la plateforme d'évac.
- Points d'objectif à paliers ; chaque palier donne de la Fame (`data/objectives/`).
- **Tirage par partie (19/11/2026)** : le Cristal est toujours présent ; 5 autres types sont tirés (`drawn_quest_types`), chacun en N exemplaires (min-max dans `data/quest_draws/`), placés sur les `QuestSpots` (40). Niveau du cristal pondéré (`variant_weights` : 50 % / 35 % / 15 %). Deux quêtes non-cristal sont à au moins `quest_min_spacing` (60 m) ; les cristaux (`ignores_spacing`) ignorent la règle ; **Répartition** (`QuestPlacement`, poids `quest_spread_*` dans match.tres) : chaque exemplaire est placé par score (éloigné des exemplaires du même type, quart de carte sans ce type, quart opposé au 1er, malus des quarts chargés), tirage parmi les 3 meilleurs ; plus de spot libre = avertissement et exemplaire sauté. 5 points de Lumicèpes par collecteur de Lumicèpes tiré. **Apparition différée** (`QuestDelayed`) : `spawn_delay` (Cœur stellaire : 300 s, avec annonce) ou `spawns_with_storm` (collecteur d'éclats d'orage : début de la Grande Marée, avec les éclats) ; un type tiré mais pas encore apparu reste dans la liste Tab ; une nouvelle partie annule les apparitions en attente. Code : `quest_draw.gd`, `quest_delayed.gd`, `quest_factory.gd`, `lumicep_ticks.gd`.

## Reste à faire
- Tableau de contrats : 4 proposés, 2 actifs (`contracts_offered`, `max_active_contracts` existent déjà).
- Contrats qui arrivent au fil de la partie (`unlock_time`), annonce « Nouveau contrat ».
- Relais qui change de place toutes les N s.

## Règles du jeu original : à compléter

## Conception détaillée (déplacé de DESIGN.md)

### 4 bis. Quête « cristal + foreuse » (17/11/2026, première quête codée)
- Des **cristaux** sont posés sur la carte, en 3 difficultés : **facile** (1 vague de Rôdeurs, +100 pts de quête), **moyen** (2 vagues, la 2e avec un Colosse, +250 pts), **difficile** (2 vagues plus grosses, monstres +40 % PV et +30 % dégâts, +500 pts).
- **Maintenir E 3 s** sur un cristal déploie une **foreuse**. Des vagues de monstres apparaissent à 16-22 m et attaquent la foreuse (elle a des PV). Ils ripostent si on leur tire dessus, puis retournent sur la foreuse.
- Il faut **tuer tous les monstres de toutes les vagues**. Si la foreuse est détruite, la quête échoue et le cristal redevient utilisable 15 s plus tard.
- Une fois les vagues finies, **maintenir E 5 s** sur la foreuse donne les **points de quête** à celui qui extrait (un autre joueur peut voler l'extraction).
- Un cristal extrait est épuisé ; pour les tests, il réapparaît après 120 s. Valeurs dans `data/quests/*.tres` et `Config`.
- Les points de quête sont affichés en haut à droite. Ils préparent la Fame et le classement de l'étape 5.

### 4 ter. Contrats sur la carte (17/11/2026, codés, ouverts à tous sans tableau de contrats)
Inspirés des contrats du jeu d'origine, avec nos propres noms. Réglages dans `data/contracts/*.tres` et `Config`.
- **Forage de cristal** : voir §4 bis.
- **Relais satellite** : maintenir E 5 s pour le capturer ; +3 pts/s au propriétaire jusqu'à ce qu'un autre le reprenne. Capture annoncée à tous.
- **Extracteur d'Ambrine** : maintenir E 4 s pour l'installer ou le reprendre. Son propriétaire reçoit directement des points d'objectif, sans y retourner, de plus en plus vite (+1 pt/s, +1,5 pt/s par minute tenue, remis à zéro quand il change de mains). Annoncé aux joueurs, pas aux monstres.
- **Cœur stellaire** : objet unique au centre ; son porteur gagne +4 pts/s et sa position est visible par tous (balise). Il tombe au sol à sa mort.
- **Chasse à la biomasse** : Rôdeurs (1) et Colosses (3) lâchent de la biomasse (20 max portés) ; dépôt au collecteur = 15 pts l'unité.
- **Lumicèpes** : champignons qui repoussent sur 8 spots ; les porter attire des **Tiques**, de plus en plus souvent (24 s ÷ nombre porté) ; dépôt = 40 pts l'unité (10 max).
- **Station de recherche** : 3 nœuds couverts de biomasse ; chaque activation (E 3 s) fait venir une vague qui attaque l'activateur ; puis l'ordinateur central = 300 pts.
- **Drones en panne** : protéger 3 drones pendant 45 s contre 2 vagues, puis envoyer chaque survivant (E 1,5 s) = 120 pts × PV restants.
- **Prime** : toutes les 90 s, prime sur le joueur qui a le plus de points (150 + 25 % de ses points), position visible ; son tueur la gagne, s'il survit 120 s il en touche la moitié.
- **Évac** : codé à l'étape 6, voir §9.
- Pas encore de tableau « 4 contrats proposés, 2 actifs » : tous les contrats sont ouverts à tous.
> **Deux types de points (17/11/2026).** Les **points de classement** forment le score général. Les objectifs Forage, Relais, Ambrine, Cœur stellaire, Biomasse et Lumicèpes rapportent des **points d'objectif** propres à chacun ; chaque **palier** atteint donne des points de classement (par défaut +10, +15, +20, +25, puis +25 par palier supplémentaire). Paliers dans `data/objectives/*.tres`. La station (+40), les drones (+15 par drone × PV restants) et la prime (20 + 10 % du classement de la cible) donnent directement des points de classement. Les chiffres en « pts » des lignes ci-dessus sont des points d'objectif, sauf pour ces trois contrats.

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
| Prime | Tuer un joueur désigné | 250 |
