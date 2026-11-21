# Extraction (navette d'évac)

Code : `systems/evac/evac_ship.gd`, `systems/match/match_manager.gd` · Données : `data/rules/match.tres`, `data/camps/evac_pad.tres`

## Implémenté
- Partie de 20 min (`match_duration`). Annonce de la navette à 16:00, arrivée à 17:00, décollage à 20:00.
- À l'annonce, un camp de monstres occupe la plateforme centrale : « NAVETTE BLOQUÉE — NETTOYER LA
  PLATEFORME ». La navette ne se pose qu'une fois le camp tué ; le tueur du dernier monstre gagne
  `evac_pad_clear_fame`.
- Embarquement : rester `evac_board_time` s dans la soute. Les joueurs embarqués passent en spectateur.
- Fame : bonus au premier embarqué ; pénalité `evac_missed_penalty` si pas à bord au décollage.
- Écran de fin, puis lobby (`match_restart_delay`).
- Largage de début de partie (après la salle de briefing, `systems/briefing/` ; `systems/match/` : `drop_points.gd`, `drop_pod_ride.gd`, `drop_pod_visual.gd`) : voir DESIGN §Déroulé ; réglages `drop_*` dans `data/rules/match.tres`. Reste : choix du point par le joueur.

## Reste à faire
- Classement final : tous les évacués devant les non-évacués, puis par Fame ; supprimer la pénalité.
- Ressenti à vérifier en jeu : difficulté du camp de la plateforme, temps d'embarquement.

## Règles du jeu original : à compléter

## Conception détaillée (déplacé de DESIGN.md)

### 9. Évacuation
- Le vaisseau est annoncé à 16:00 (`Config.match_rules.evac_announce_time`) : un camp de monstres (`data/camps/evac_pad.tres`) apparaît sur la plateforme. Il arrive à 17:00 (`Config.match_rules.evac_landing_time`, 3 min avant la fin) mais ne se pose qu'une fois la plateforme nettoyée (« NAVETTE BLOQUÉE — NETTOYER LA PLATEFORME ») ; le tueur du dernier monstre gagne `Config.economy.evac_pad_clear_fame` (20). Décollage à 20:00.
- Embarquement : rester 5 s dans la zone de la soute. Ensuite le joueur est en sécurité.
- Places illimitées, mais une seule rampe d'accès : c'est le point chaud de la partie.
- *(codé, 17/11/2026)* Une fois à bord : spectateur intouchable (vol libre, Espace / Ctrl), ne tire plus et
  n'interagit plus .
- Classement : le **premier** embarqué gagne +50, les suivants +0 ; au décollage, ceux qui ne sont
  pas à bord perdent **100** points de classement (`Config.economy.evac_*`).
- Après le décollage : écran de fin (classement) pendant 20 s, puis **nouvelle partie sur place** :
  points, crédits, inventaire et bouclier remis à zéro, loot effacé, monstres, cristaux et contrats recréés.
- Le vaisseau : soute surélevée, une porte et une rampe ; on passe sous le plancher accroupi
  Menu admin : « Aller à 14:50 » et « Aller à 19:50 » pour tester.
