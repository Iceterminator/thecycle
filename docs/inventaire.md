# Inventaire, boutique et loot

Code : `systems/inventory/inventory.gd`, `systems/shop/`, `systems/loot/` · Données : `data/items/` (un objet = un fichier, `price` > 0 = vendu), `data/weapons/`, `data/rules/economy.tres`, `data/rules/start_loadout.tres`

## Implémenté
- 2 emplacements d'arme ; arme de départ au choix parmi les secondaires débloquées, jamais perdue.
- Q / F vides au départ : capacité ou gadget acheté puis assigné ; racheté = amélioration / recharge ;
  perdu à la mort.
- Boutique configurée dans le lobby (4 armes + 4 gadgets / capacités) ; arme déjà portée = palier de boost
  (+10 % dégâts, portée, cadence ; `weapon_boost_prices`).
- Achats livrés par capsule de largage. Crédits : monstres (directement au tueur), mort = perte d'une part.
- Objets au sol (`LootManager`), ramassage avec E.

## Reste à faire
- 3 emplacements d'arme.
- Soins et recharges de bouclier : plus obtenables (touches 3 et 4 inutiles).
- Boutique en 3 colonnes, lâcher des crédits au sol.

## Règles du jeu original : à compléter
