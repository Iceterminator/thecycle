# Audit de bugs (lecture seule) — 19/11/2026

Base : commit `435954c`. Les numéros de ligne sont ceux d'avant le découpage des scripts de plus de
150 lignes (fait en parallèle sur une autre branche) : chercher le nom de la fonction s'ils ont bougé.
Classement du plus grave au moins grave. « À confirmer » = lu dans le code, pas reproduit.

Remarque générale : presque toutes les RPC `any_peer` vérifient bien `get_remote_sender_id()`
(propriétaire, ou 1 pour les RPC serveur → client) et l'état mort / à terre / embarqué / largage.
Les failles ci-dessous demandent pour la plupart un client modifié (triche), sauf mention contraire.

---

## Critique

### C1. Menu admin ouvert à tous les clients
- **Fichier** : `autoload/config.gd:81` (`ADMIN_MENU_ENABLED := true`), `systems/admin/admin.gd:160` (`_server_allowed`).
- **Scénario** : n'importe quel client appuie sur 0 → 100 000 crédits au sol, temps de partie avancé
  à 19:59 pour tout le monde, partie lancée sans attendre les autres, kit ou capacité verrouillés
  par la faction équipés directement.
- **Correctif** : réserver l'admin à l'hôte / à une liste de pseudos côté serveur (ou `false` par
  défaut et `--admin` en ligne de commande) avant l'étape 10.

### C2. `request_register` rappelable en pleine partie : soin complet, changement de kit, vol de profil
- **Fichier** : `systems/profiles/profile_manager.gd:166-190` (pas de garde « déjà enregistré » ni de phase),
  `systems/kits/kit_controller.gd:171-180` (`server_set_kit` → `_server_apply_stats(true)` = tout plein).
- **Scénario** : en partie, un client renvoie `request_register("AutrePseudo")` dont le profil a un
  autre kit → `server_apply_loadout` change le kit et remet PV + bouclier au maximum, à volonté
  (deux pseudos en alternance). Même chose pour charger le profil d'un joueur hors ligne (pas de mot
  de passe) : sa réputation et son équipement sont pris puis réécrits. Les gains de réputation non
  encore sauvegardés de l'ancien profil (sauvegarde toutes les 10 s) sont perdus.
- **Correctif** : refuser si `_profiles.has(peer)` (un seul enregistrement par connexion) ; plus
  tard, un jeton secret par profil stocké côté client.

---

## Moyen

### M1. Partie qui tourne 20 min avec 0 joueur ; les arrivants attendent dans le vide
- **Fichier** : `systems/match/match_manager.gd:64-81` (aucune vérification du nombre de joueurs hors lobby),
  `scenes/world/world.gd:66-70` (nouveau venu mis en attente si pas lobby).
- **Scénario** : 2 joueurs lancent une partie puis quittent tous les deux à 1:00. Un 3e se connecte :
  il voit l'écran d'attente jusqu'à 20:00 + 20 s d'écran de fin (≈ 19 min), pendant que le serveur
  simule monstres, tempête et vagues pour personne.
- **Correctif** : dans `_physics_process`, si `world.players.get_child_count() == 0` hors LOBBY,
  appeler `_enter_lobby()` directement.

### M2. Esquive blindée sans limite (réduction de dégâts permanente)
- **Fichier** : `systems/kits/kit_movement.gd:397-404` (`request_dodge_guard`).
- **Scénario** : Furet avec l'effet `dodge_damage_reduction` ; un client modifié envoie
  `request_dodge_guard(0.5)` toutes les 0,5 s sans esquiver → le buff « Esquive » reste actif en
  permanence (jusqu'à −90 % de dégâts). Le serveur ne vérifie ni charge d'énergie (gérée côté client)
  ni recharge.
- **Correctif** : délai minimal côté serveur entre deux demandes (durée d'esquive + recharge du
  kit) et/ou compteur de charges serveur.

### M3. Tir à travers un mur fin (origine du tir non vérifiée par ligne de vue)
- **Fichier** : `systems/combat/weapon.gd:380` ; même contrôle dans `systems/abilities/ability_controller.gd:233`.
- **Scénario** : collé à un mur de moins de 2 m d'épaisseur, un client modifié envoie une `origin`
  de l'autre côté du mur (à moins de `SHOT_ORIGIN_TOLERANCE` = 2 m des yeux) → il touche des
  joueurs sans être exposé ; idem pour poser une tourelle / une frappe derrière un mur.
- **Correctif** : raycast monde (couche 1) de `camera.global_position` à `origin` ; refuser si touché.

### M4. Plongée (Martinet) déclenchable sans plonger, et à travers les murs
- **Fichier** : `systems/kits/kit_movement.gd:323-339` (`request_dive_impact`).
- **Scénario** : un client modifié envoie `request_dive_impact(sa_position)` à chaque fin de recharge,
  au sol, sans carburant ni plongée → explosion de zone gratuite ; elle touche aussi derrière un mur
  (pas de test de ligne de vue, contrairement à `_server_explode`).
- **Correctif** : mémoriser côté serveur le début de plongée (RPC de départ, ou vitesse verticale
  observée) et ajouter le raycast mur comme dans `weapon.gd::_server_explode`.

### M5. Tourelle bloquée sur un allié (escouade / pacte)
- **Fichier** : `systems/abilities/ability_object.gd:155-165` (`_targets_in` n'exclut que le propriétaire), `:197-210`.
- **Scénario** : en escouade, je pose une tourelle ; mon coéquipier est à 3 m d'elle, un ennemi à
  10 m. La tourelle choisit la cible la plus proche (le coéquipier), ses dégâts sont annulés par
  `Health.apply_damage` (alliés) → elle ne tire jamais sur l'ennemi. Idem pour la balise de scan
  (`_server_ward`) qui signale les alliés comme ennemis.
- **Correctif** : dans `_targets_in` et `_server_ward`, ignorer les joueurs `Allies.allied(owner_id, peer)`.

### M6. Relique perdue sous la carte si son porteur tombe dans le vide
- **Fichier** : `systems/contracts/relic.gd:110-119` (`_drop` pose la relique à la position du porteur).
- **Scénario** : le porteur du Cœur saute hors de la carte ; il meurt à y < −15 (`health.gd:232`),
  `_drop` place la relique à y ≈ −16 : plus personne ne peut la ramasser jusqu'à la partie suivante.
- **Correctif** : dans `_drop`, reposer au sol (raycast comme `LootManager._ground`) et, si y < `KILL_Y`,
  la remettre à son point d'apparition.

### M7. Fame finale contraire au design (pénalité au lieu de « 0 / derrière les évacués »)
- **Fichier** : `systems/match/match_manager.gd:183-192`, `data/rules/economy.tres` (`evac_missed_penalty = 100`).
- **Scénario** : A a 600 Fame et rate l'évac (→ 500), B a 80 Fame et embarque (→ 130). A finit
  premier du classement alors que DESIGN §Boucle 7 dit « les autres finissent à 0 ». La Fame peut
  aussi devenir négative (30 − 100 = −70). Déjà noté comme TODO dans `docs/extraction.md:16`.
- **Correctif** : trier d'abord par `evacuated` puis par Fame, et supprimer la pénalité (ou la borner à 0).

### M8. Soigner un joueur à terre (Rayon vital)
- **Fichier** : `systems/combat/weapon.gd:870-881` (`request_gadget_alt` sans test `is_downed`),
  `weapon.gd:839` (soin d'un allié à terre accepté), `systems/combat/health.gd:201` (`heal` ne bloque que les morts).
- **Scénario** : à terre, je fais clic droit avec le Rayon vital → mes PV d'agonie remontent bien
  au-dessus de `downed_health` ; un allié peut aussi me « soigner » au rayon. L'ennemi doit tirer
  bien plus pour m'achever, sans que je sois relevé.
- **Correctif** : `heal()` ne fait rien si `is_downed` (ou tester `is_downed` dans les deux appels).

---

## Mineur

### m1. Actions et gains pendant l'écran de fin (phase ENDED)
- **Fichiers** : `systems/combat/health.gd:155` (dégâts bloqués seulement au lobby),
  `systems/score/score.gd:119` (Fame de contrat bloquée seulement au lobby), `systems/shop/shop.gd:140-151`.
- **Scénario** : pendant les 20 s de l'écran de fin, on peut encore s'entretuer, finir un contrat
  et gagner de la **réputation de faction** (sauvegardée dans le profil) après le classement, et
  acheter en boutique (crédits perdus à la remise à zéro).
- **Correctif** : traiter ENDED comme le lobby dans `apply_damage`, `add_contract_fame` et `_state_refusal`.

### m2. Prime posée dans le lobby
- **Fichier** : `systems/contracts/bounty_manager.gd:29-56` (aucun test de phase).
- **Scénario** : au lobby, après 90 s à 2 joueurs, « Prime de 20 Fame sur X ! » est annoncée et la
  balise s'affiche ; elle ne peut rien rapporter. La doc dit « plus de points de quête » mais le code
  prend `rank_points` (Fame).
- **Correctif** : ne compter le temps qu'en phase PLAYING/EVAC ; aligner le commentaire.

### m3. Coup de poing chargé : recul appliqué aux alliés et aux invulnérables
- **Fichier** : `systems/kits/kit_movement.gd:371-373`.
- **Scénario** : un Bastion frappe un coéquipier (ou n'importe qui au lobby) : les dégâts sont
  annulés mais `apply_knockback` est envoyé quand même → on peut pousser ses alliés hors d'une falaise.
  Après le délai `PUNCH_HIT_DELAY`, seul `is_dead` est revérifié (pas à terre / embarqué).
- **Correctif** : n'appliquer le recul que si la cible n'est pas alliée et si le coup a été accepté.

### m4. Monstre tombé hors carte : peut mourir deux fois
- **Fichier** : `systems/monsters/monster.gd:175-177`, `:464-484` (`_die` ne met pas `health` à 0).
- **Scénario** : un monstre passe sous y = −15 et reçoit une balle dans la même image avant le
  `queue_free` → `server_receive_hit` le tue une 2e fois : crédits au tireur, biomasse au sol,
  `camp.cleared` émis deux fois (le camp est repeuplé deux fois). Rare.
- **Correctif** : `health = 0.0` au début de `_die`.

### m5. Réapparition plus rapide après une remise à zéro
- **Fichier** : `systems/combat/respawn_manager.gd:19-35`.
- **Scénario** : je meurs à 19:58 ; nouvelle partie (je suis remis sur pied) ; je meurs à nouveau
  2 s plus tard : la 1re attente de 5 s se termine et me fait réapparaître après ~2 s seulement.
- **Correctif** : garder un compteur de morts par joueur et l'ignorer si le compteur a changé.

### m6. Pactes possibles au lobby, pendant le largage, une fois mort ou embarqué
- **Fichier** : `systems/pacts/pact_manager.gd:81-114`.
- **Scénario** : au lobby, deux joueurs concluent un pacte ; il est effacé sans prévenir au début
  de la partie (`match_reset_requested`). Aucune limite au nombre de propositions (spam de notifications).
- **Correctif** : refuser hors PLAYING/EVAC ; petit délai entre deux propositions d'un même joueur.

### m7. Maintien de E vérifié seulement au début
- **Fichiers** : `systems/interaction/interactor.gd:107-133`, `systems/inventory/weapon_pickup.gd:90-118`.
- **Scénario** : client modifié : `request_hold_start`, s'éloigner, revenir 3 s plus tard et
  envoyer `request_interact` → relève / activation de cristal sans être resté sur place (seule la
  distance finale est contrôlée).
- **Correctif** : vérifier la distance aussi au début du maintien et annuler si le joueur meurt / est mis à terre entre-temps.

### m8. Balise de scan : RPC vers un propriétaire déconnecté
- **Fichier** : `systems/abilities/ability_object.gd:295`.
- **Scénario** : je pose une balise et je quitte : chaque intervalle de scan, le serveur appelle
  `_scan_ping.rpc_id` vers un peer inexistant (erreurs dans la console jusqu'à la fin de la balise).
- **Correctif** : `queue_free()` des objets dont le propriétaire part (`Events.player_left`), ou tester `owner_id in multiplayer.get_peers()`.

### m9. Brûlure / poison : cumul sur les monstres, pas sur les joueurs
- **Fichiers** : `systems/monsters/monster.gd:724-739` (chaque tir ajoute un DoT), `systems/abilities/buff_controller.gd:181-188` (max, pas de cumul).
- **Scénario** : même SMG avec mod de feu : les dégâts de brûlure totaux sur un monstre sont
  N fois ceux subis par un joueur après N balles.
- **Correctif** : choisir une règle commune (cumul ou max) — à décider.

### m10. Valeurs de jeu en dur dans le code (règle du projet)
- `autoload/config.gd` : `PICKUP_LIFETIME`, `DROP_POD_FALL_TIME` (3 s, à ne pas confondre avec
  `match.tres: drop_pod_fall_time` = 10 s), `SQUAD_MAX`, `BOUNTY_FACTION`, `SHOT_ORIGIN_TOLERANCE`…
- `systems/kits/kit_movement.gd:328` (6 m de tolérance de plongée), `:404` (durée d'esquive 0,1–0,5 s).
- `systems/abilities/ability_object.gd` : `lerpf(1.0, 0.4, …)` des explosions, `MISSILE_RADIUS`, `PORTAL_RADIUS`.
- `systems/monsters/monster_lod.gd` : `FAR_DISTANCE` ; `systems/contracts/relic.gd` / `monster_manager.gd:186` (rayon 8 m du camp d'évac).
- `autoload/config.gd:50-51` : `SHIELD_PER_TIER`, `STARTING_SHIELD_TIER` inutilisés.
- **Correctif** : passer les réglages d'équilibrage dans `data/rules/*.tres` ; supprimer les constantes mortes.

### m11. Commentaires de timing faux
- **Fichier** : `systems/match/match_manager.gd:4` (« annonce 16:10, évac 19:10 ») alors que
  `match.tres` donne 16:00 (960 s) et 17:00 (1020 s).
- **Correctif** : citer les noms des réglages plutôt que des heures.

### m12. Nom de profil réservé sous Windows
- **Fichier** : `systems/profiles/profile_manager.gd:138-163`.
- **Scénario** : pseudo `CON`, `NUL`, `AUX`, `COM1`… → `FileAccess.open` échoue : le profil n'est jamais sauvegardé, sans message.
- **Correctif** : préfixer le nom de fichier (`p_con.json`) ou refuser ces noms.

---

## À confirmer

- **Double fin de partie (admin)** — `match_manager.gd:110` + `:175` : si l'évac est annoncée et que
  le camp de plateforme est vide/absent, `evac_pad_cleared` est émis pendant `_advance`, qui rappelle
  `_advance` ; si l'admin a sauté directement à 20:00, `_end_match` peut s'exécuter deux fois (pénalité
  d'évac appliquée deux fois, `match_ended` émis deux fois). Seulement avec `EVAC_PAD_CAMP` vide.
- **Monstres coincés dans le décor** — `systems/monsters/monster_lod.gd:27-31` : loin des joueurs,
  le monstre avance sans collision et est posé sur `MapTerrain.height_at` (relief seul) ; il peut
  finir dans un rocher / un bâtiment et rester bloqué quand la physique revient.
- **Quête bloquée en défense** — `systems/quests/crystal.gd:145-155` : la vague suivante n'arrive que
  quand tous les monstres de la vague sont morts. Un monstre de vague coincé (voir ci-dessus) ou une
  vague dont `roll()` renvoie 0 monstre bloque la foreuse en DÉFENSE jusqu'à la fin de la partie.
  Correctif possible : délai maximum par vague.
- **Téléportation par le portail** — `ability_object.gd:259-279` : les joueurs embarqués (spectateurs)
  ou morts proches de l'entrée sont aussi téléportés.
