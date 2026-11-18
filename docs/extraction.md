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

## Reste à faire
- Classement final : tous les évacués devant les non-évacués, puis par Fame ; supprimer la pénalité.
- Ressenti à vérifier en jeu : difficulté du camp de la plateforme, temps d'embarquement.

## Règles du jeu original : à compléter
