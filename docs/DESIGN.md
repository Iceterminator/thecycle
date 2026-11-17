# Remake The Cycle — Document de design

> Copie de travail pour l'IA. Version de référence : https://claude.ai/artifact/Y4hUX91sDpkGe6SfBuXALD
> Mettre à jour les deux si une mécanique change. Les deux versions datent du 17/11/2026.

## Vision et périmètre

On refait la boucle de The Cycle (Yager, 2019) : un FPS « competitive quest shooter » PvEvP où le gagnant est celui qui marque le plus de points (Fame) avec des contrats **et** qui monte dans le vaisseau d'évacuation, pas celui qui tue le plus. Moteur : **Godot 4 + GDScript**, multijoueur serveur autoritaire, codé en grande partie par une IA.

**Ce qu'on garde de l'original**

- Jusqu'à 20 joueurs par partie, en solo ou en escouade (jusqu'à 4).
- Partie d'environ 20 minutes sur une planète hostile (Fortuna III dans l'original).
- Contrats de factions à réaliser pendant la partie, événements en cours de route.
- Monstres qui deviennent plus forts au fil de la partie.
- Tempête (la « Cycle ») qui ravage la carte.
- Vaisseau d'évac au centre : seuls ceux qui montent à bord gardent leur score.
- Pactes entre joueurs, gadgets (tourelles, bulles de bouclier), largages de ravitaillement.
- Factions (Korolev, ICA, Osiris dans l'original) et personnalisation des armes et gadgets entre les parties.

**Ce qu'on change**

- Noms, logos, personnages, sons et modèles originaux : tout est refait ou remplacé (propriété de Yager). Le jeu a son propre nom ; « The Cycle » est un nom de code.
- Style graphique stylisé low-poly, faisable en solo.
- Les valeurs chiffrées de ce doc (dégâts, timings, points) sont des **valeurs de départ à équilibrer**, pas celles de l'original.

**Règles de travail avec l'IA**

1. Ce doc est la référence : l'IA le relit au début de chaque session.
2. Une étape de la feuille de route à la fois, testée en jeu avant la suivante.
3. Le réseau dès l'étape 1 : tout ce qui compte (dégâts, loot, score) est décidé par le serveur.
4. Les données (armes, contrats, monstres) vivent dans des fichiers `.tres`, pas dans le code : on équilibre sans toucher aux scripts.
5. Un commit Git par fonctionnalité qui marche, pour pouvoir revenir en arrière si l'IA casse quelque chose.

## Boucle d'une partie

Une partie dure 20 minutes et se gagne au score de Fame, à condition d'être à bord de l'évac au départ. Timings de départ, à ajuster :

1. **Lobby et loadout (hors partie).** Le joueur choisit arme, gadgets et faction de prédilection, puis rejoint une file.
2. **0:00 – Largage.** Chaque joueur tombe en capsule à un point de son choix sur la carte. 4 contrats sont proposés ; il en accepte jusqu'à 2 à la fois.
3. **0:00 – 15:00 – Prospection.** Contrats, loot, monstres, gains de crédits en partie. Le joueur améliore boucliers et armes en cours de partie (terminal d'achat ou largage de ravitaillement).
4. **~5:00 et ~10:00 – Événements.** Contrats spéciaux pour tous (roi de la colline, boss, zone de ressources). Les monstres montent d'un palier de difficulté.
5. **Tempête.** Elle arrive par vagues : un avertissement, puis elle balaie une partie de la carte (dégâts, visibilité réduite).
6. **15:00 – Le vaisseau d'évac se pose** au centre. Annonce à tous les joueurs ; c'est le moment des embuscades.
7. **20:00 – Décollage.** Les joueurs à bord gardent leur Fame. Les autres finissent à 0 pour le classement.
8. **Écran de fin.** Classement, récompenses de faction, retour au lobby.

**Mort pendant la partie** : le joueur n'est pas éliminé. Il perd une partie de sa Fame (qui va à son tueur si c'est un joueur), puis réapparaît en capsule après quelques secondes, avec son équipement de base. En escouade : état « à terre » d'abord, relevable par un coéquipier.

## Mécaniques

### 1. Joueur (déplacement)
- Vue FPS, marche 5 m/s, sprint 7,5 m/s, accroupi, saut.
- Glissade depuis le sprint, escalade de rebords bas (mantle).
- Pas d'endurance : le sprint est illimité.

### 2. Combat et armes
- Tir hitscan pour fusils et pistolets, projectile pour lance-grenades et armes lourdes.
- Recul, dispersion, visée (ADS), rechargement, multiplicateur tête ×1,5.
- Rareté : commun → peu commun → rare → épique → légendaire. Chaque palier = +10 % dégâts et une meilleure stabilité.
- Deux emplacements d'arme + un emplacement de gadget + consommables (soins, recharges de bouclier).

| Famille | Rôle | Exemple de valeurs |
| --- | --- | --- |
| Fusil d'assaut | Polyvalent | 18 dégâts, 600 coups/min |
| SMG | Courte portée | 12 dégâts, 900 coups/min |
| Fusil à pompe | Très courte portée | 8 × 12 plombs |
| Fusil de précision | Longue portée | 90 dégâts, 40 coups/min |
| Pistolet | Secours | 25 dégâts, semi-auto |
| Arme lourde | Contre monstres | Projectile explosif |

### 3. Santé et boucliers
- 100 PV + bouclier par palier : 25 au départ (palier 0), puis 50, 100, 150 (paliers 1 à 3), achetés en boutique. Le palier acheté est gardé à la mort.
- Le bouclier absorbe d'abord. Il se recharge seul après 10 s sans dégâts, de 1/20 de son maximum par seconde. La santé remonte seule de 1 PV/s après 20 s sans dégâts, et plus vite avec des soins. *(valeurs du 17/11/2026, provisoires)*
- Le niveau de bouclier s'améliore **pendant la partie** avec les crédits gagnés.

### 4. Loot et crédits en partie
- Caisses, monstres tués et joueurs tués lâchent armes, munitions, soins, gadgets et ressources.
- Les crédits gagnés pendant la partie servent aux améliorations sur place : terminaux d'achat ou **largage de ravitaillement** que le joueur appelle (arrive en 30 s, visible par tous).
- Ressources récoltables (minerais, plantes) : à rapporter pour certains contrats.

> **Boutique et largages (17/11/2026) — remplace les caisses.** Les caisses de loot sont supprimées.
> Au largage, le joueur a seulement un **pistolet** et **25 de bouclier**. Avec **T**, il ouvre la
> **boutique** : armes (SMG 150, fusil d'assaut 250) et améliorations de bouclier (50 → 100 cr.,
> 100 → 200 cr., 150 → 350 cr.), payées en crédits. L'achat fait tomber une **capsule de largage**
> à 3 m devant le joueur, qui atterrit au bout de 3 s ; l'objet est dedans, au sol, et **n'importe quel
> joueur peut le ramasser**. Prix dans `data/items/*.tres` (`price`), délais dans `Config`.
> Soins et recharges de bouclier ne sont plus vendus ni trouvés pour l'instant (la vie et le bouclier
> se régénèrent seuls).

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
- **Extracteur d'Ambrine** : maintenir E 4 s pour l'installer ou le reprendre (le stock est volé avec). Le stock monte de plus en plus vite (+1 pt/s, +1,5 pt/s par minute tenue) ; le propriétaire le récolte (E 1,5 s). Annoncé aux joueurs, pas aux monstres.
- **Cœur stellaire** : objet unique au centre ; son porteur gagne +4 pts/s et sa position est visible par tous (balise). Il tombe au sol à sa mort.
- **Chasse à la biomasse** : Rôdeurs (1) et Colosses (3) lâchent de la biomasse (20 max portés) ; dépôt au collecteur = 15 pts l'unité.
- **Lumicèpes** : champignons qui repoussent sur 8 spots ; les porter attire des **Tiques**, de plus en plus souvent (24 s ÷ nombre porté) ; dépôt = 40 pts l'unité (10 max).
- **Station de recherche** : 3 nœuds couverts de biomasse ; chaque activation (E 3 s) fait venir une vague qui attaque l'activateur ; puis l'ordinateur central = 300 pts.
- **Drones en panne** : protéger 3 drones pendant 45 s contre 2 vagues, puis envoyer chaque survivant (E 1,5 s) = 120 pts × PV restants.
- **Prime** : toutes les 90 s, prime sur le joueur qui a le plus de points (150 + 25 % de ses points), position visible ; son tueur la gagne, s'il survit 120 s il en touche la moitié.
- **Évac** : pas encore codé, il dépend du minuteur de partie et du vaisseau (étape 6).
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

### 6. Fame et score
- Sources : contrats (principal), monstres (peu), joueurs (vole un % de la Fame de la victime).
- Mourir = perte de 20 % de sa Fame, récupérée par le tueur s'il s'agit d'un joueur.
- Classement en direct visible dans l'interface. Le score ne compte que si le joueur est à bord de l'évac.

### 7. Monstres (PvE)
- 3 types de départ : petit rapide (meute), moyen à distance, gros tank. Plus tard, un boss pour les événements.
- Patrouille par zones, IA simple : patrouille → poursuite → attaque → retour.
- Un palier de difficulté toutes les 5 min (+PV, +dégâts, nouvelles espèces).
- **Camps (meutes)** : les monstres vivent en camps de 2 niveaux. Niveau 1 = 1 Colosse (tank) + 3 à 5 Rôdeurs (petits rapides). Niveau 2 = 2 à 3 Colosses + 7 à 10 Rôdeurs. Quand un monstre repère ou se fait attaquer par un joueur, toute la meute réagit.
- **Récompenses** : pour l'instant, un monstre tué donne seulement des crédits, versés directement au tueur. À terme, **vider un camp rapportera des points de quête** (`Events.camp_cleared` est déjà émis). Il faudra aussi les autres types (à distance, boss).
- Pour les tests, un camp vidé réapparaît après 60 s (`Config.CAMP_RESPAWN_DELAY`).

### 8. Tempête
- Par vagues, avec un avertissement 60 s avant.
- Pendant une vague : dégâts légers continus hors abri, brouillard, éclairs. Une partie de la carte, ou toute la carte en fin de partie.
- Monstres plus agressifs pendant la tempête.

### 9. Évacuation
- Le vaisseau se pose au centre à 15:00 et décolle à 20:00.
- Embarquement : rester 5 s dans la zone de la soute. Ensuite le joueur est en sécurité.
- Places illimitées, mais une seule rampe d'accès : c'est le point chaud de la partie.

### 10. Pactes
- Deux joueurs (solos ou escouades) peuvent proposer un pacte : Fame des contrats partagée, pas de dégâts entre eux.
- Rupture possible à tout moment (trahison) : l'autre est averti.

### 11. Gadgets
- 1 gadget équipé, avec un temps de recharge.
- Exemples : tourelle (90 s de vie), bulle de bouclier, grenade, balise de scan, grappin ou propulseur.
- Chaque faction débloque ses propres gadgets.

### 12. Factions et progression (hors partie)
- 3 factions inventées (équivalents de Korolev, ICA, Osiris) : puissance lourde, équilibre, technologie.
- Les contrats donnent de la réputation, qui débloque niveau par niveau des armes et gadgets.
- Entre les parties : mods d'armes et gadgets (feu, électricité, poison, chargeurs étendus…).
- Sauvegarde côté serveur (JSON par joueur au début, base de données plus tard).

## Feuille de route

Onze étapes (0 à 10). La boucle complète est jouable à la fin de l'étape 6. Chaque étape se termine par un test en jeu à 2 joueurs ou plus.

- [x] **Étape 0 – Projet de base** — un serveur et un client se connectent en local.
- [x] **Étape 1 – Joueurs en réseau** — déplacement FPS répliqué, apparition au point de largage. Fini quand : 2 joueurs se voient bouger sans saccade *(à vérifier en jeu)*.
- [x] **Étape 2 – Combat** — une arme hitscan, santé, bouclier, mort et réapparition. Fini quand : on peut s'entretuer, et le serveur valide les touches *(validé par test automatisé ; à vérifier en jeu)*.
- [x] **Étape 3 – Loot et inventaire** — caisses, armes au sol, 2 emplacements, soins, crédits. *(validé par test automatisé ; à vérifier en jeu. Mécaniques de base, à revoir avec la boucle complète. Les caisses ont ensuite été remplacées par la boutique et les capsules de largage, voir §4.)*
- [x] **Étape 4 – Monstres** — un type de monstre (patrouille, poursuite, attaque), géré par le serveur. *(fait : 2 types en camps de niveau 1 et 2 ; validé par test automatisé, à vérifier en jeu)*
- [ ] **Étape 5 – Contrats et Fame** — livraison, chasse, contrôle de zone, Fame, classement en direct.
- [ ] **Étape 6 – Partie complète** — minuteur 20 min, évac à 15:00, embarquement, écran de fin. **Jalon « jouable ».**
- [ ] **Étape 7 – Tempête et événements** — vagues, paliers de monstres, événements à 5 et 10 min, largages.
- [ ] **Étape 8 – Profondeur du combat** — familles d'armes, raretés, boucliers en partie, gadgets, pactes, escouades, état « à terre ».
- [ ] **Étape 9 – Méta et lobby** — factions, réputation, déblocages, mods, sauvegarde, menu, matchmaking simple.
- [ ] **Étape 10 – En ligne** — serveur dédié hébergé (VPS), tests à 10-20 joueurs, optimisation réseau.

## Architecture Godot

Voir `CLAUDE.md` pour l'arborescence et les règles. Résumé réseau :

| Brique Godot | Utilisation |
| --- | --- |
| `ENetMultiplayerPeer` | Connexion UDP, port 7777 par défaut |
| `MultiplayerSpawner` | Le serveur crée joueurs, monstres et loot ; ils apparaissent chez tous les clients |
| `MultiplayerSynchronizer` | Position, rotation, PV, bouclier envoyés en continu |
| RPC `@rpc` | Actions ponctuelles : tirer, ramasser, valider un contrat. Le client demande, le serveur vérifie puis applique |
| `--server` | Serveur dédié sans joueur ni fenêtre |

## Questions ouvertes
- Nom du jeu et nom de la planète.
- Noms et styles des 3 factions.
- Taille de la carte : ~500 m × 500 m pour 8-12 joueurs au début ?
- Score à la mort : remis à zéro ou réduit de 20 % ?
- Hébergement du serveur dédié (VPS ou chez soi avec ouverture de port).
