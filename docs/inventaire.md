# Inventaire, boutique et loot

Code : `systems/inventory/inventory.gd`, `systems/shop/`, `systems/loot/` · Données : `data/items/` (un objet = un fichier, `price` > 0 = vendu), `data/weapons/`, `data/rules/economy.tres`, `data/rules/start_loadout.tres`

## Implémenté
- 2 emplacements d'arme ; arme de départ au choix parmi les secondaires débloquées, jamais perdue.
- Q / F vides au départ : capacité ou gadget acheté puis assigné ; racheté = amélioration / recharge ;
  perdu à la mort.
- Plus de soins ni de recharges de bouclier (la vie et le bouclier se régénèrent seuls).
- Ramasser une arme au sol (`systems/inventory/weapon_pickup.gd`) : en visant l'arme, touche 1 / 2 =
  emplacement vide : prise immédiate et arme équipée ; emplacement occupé : maintenir
  `weapon_replace_hold_time` (2 s, `economy.tres`) pour remplacer (appui court = changer d'arme).
  E = emplacement en main ; s'il est occupé et l'autre libre, l'autre ; sinon maintien de E pour remplacer.
  L'ancienne arme tombe au sol avec son palier et ses munitions. Le serveur vérifie cible, portée et maintien.
  Les autres objets (ressources, crédits, gadgets) se ramassent avec E comme avant.
- Boutique configurée dans le lobby (4 armes + 4 gadgets / capacités), en 3 colonnes : gadgets, armes, palier
  d'amélioration suivant de chaque arme. Achat d'arme = capsule de largage.
- Améliorations d'arme par type (`systems/shop/weapon_upgrades.gd`, `Inventory.weapon_upgrades`) : palier
  acheté (+10 % dégâts, portée, cadence ; `weapon_boost_prices`) gardé jusqu'à la mort / nouvelle partie
  (comme les paliers d'emplacement), appliqué à l'exemplaire équipé et aux exemplaires achetés ensuite
  (livrés boostés). Une arme ramassée garde ses propres paliers.
- Crédits : monstres (directement au tueur) ; à la mort la part perdue (`death_credits_loss`) va au tueur
  joueur, sinon tombe au sol.
- Objets au sol (`LootManager`), ramassage avec E.

## Reste à faire
- Lâcher des crédits au sol (hors mort).

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
> Soins et recharges de bouclier : supprimés (la vie et le bouclier
> se régénèrent seuls).
