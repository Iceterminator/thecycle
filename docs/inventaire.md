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

## Conception détaillée (déplacé de DESIGN.md)

### 4. Loot et crédits en partie
- Caisses, monstres tués et joueurs tués lâchent armes, munitions, soins, gadgets et ressources.
- Les crédits gagnés pendant la partie servent aux améliorations sur place : terminaux d'achat ou **largage de ravitaillement** que le joueur appelle (arrive en 30 s, visible par tous).
- Ressources récoltables (minerais, plantes) : à rapporter pour certains contrats.

> **Boutique et largages (17/11/2026) — remplace les caisses.** Les caisses de loot sont supprimées.
> Au largage, le joueur a seulement le pistolet **Dard** (K-28 de la référence) et **25 de bouclier**. Avec **T**, il ouvre la
> **boutique** : armes (Guêpe 200, Trident 500, Faucon 500) et améliorations de bouclier (50 → 100 cr.,
> 100 → 200 cr., 150 → 350 cr.), payées en crédits. L'achat fait tomber une **capsule de largage**
> à 3 m devant le joueur, qui atterrit au bout de 3 s ; l'objet est dedans, au sol, et **n'importe quel
> joueur peut le ramasser**. Prix dans `data/items/*.tres` (`price`), délais dans `Config`.
> Soins et recharges de bouclier ne sont plus vendus ni trouvés pour l'instant (la vie et le bouclier
> se régénèrent seuls).
