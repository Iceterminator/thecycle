# Quêtes et contrats

Code : `systems/quests/` (cristal, foreuse, `QuestManager`), `systems/contracts/` (base `ContractSite`) · Données : `data/quests/`, `data/contracts/`, `data/objectives/`, `data/rules/match.tres`

## Implémenté
- Cristal + foreuse (3 difficultés) : lancer la foreuse, défendre contre des vagues, extraire.
  Les cristaux non commencés montent d'un niveau à 10:00.
- Contrats sur la carte, ouverts à tous : relais satellite, extracteur d'Ambrine, Cœur stellaire,
  collecteurs (biomasse, Lumicèpes + Tiques), station de recherche, drones en panne, prime,
  collecteur d'Éclats d'orage (pendant la Grande Marée), nettoyage de la plateforme d'évac.
- Points d'objectif à paliers ; chaque palier donne de la Fame (`data/objectives/`).

## Reste à faire
- Tableau de contrats : 4 proposés, 2 actifs (`contracts_offered`, `max_active_contracts` existent déjà).
- Contrats qui arrivent au fil de la partie (`unlock_time`), annonce « Nouveau contrat ».
- Relais qui change de place toutes les N s.

## Règles du jeu original : à compléter
