# The Cycle Remake (nom de code)

Remake PvEvP en Godot 4.7 inspiré de The Cycle (2019). Toutes les mécaniques et la
feuille de route sont dans `docs/DESIGN.md`. Les règles pour l'IA sont dans `CLAUDE.md`.

## Démarrer
1. Installer [Godot 4.7](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot → Importer → choisir `project.godot`.
3. Debug → Customize Run Instances → activer 2 instances → lancer (F5).
4. Fenêtre 1 : **Héberger**. Fenêtre 2 : **Rejoindre** (laisser l'adresse vide = 127.0.0.1).

## Contrôles
Touches physiques (ZQSD sur AZERTY, WASD sur QWERTY) · Espace : sauter ·
Maj : sprint · Ctrl : s'accroupir · Clic gauche : tirer · Clic droit : viser ·
R : recharger · E : ramasser (maintenir E sur un cristal) · T : boutique · 1 / 2 / molette : changer d'arme ·
3 : kit de soin · 4 : cellule de bouclier · Échap : libérer la souris.

## État
Étapes 0 à 4 de la feuille de route : connexion réseau, joueurs FPS répliqués, combat
(fusil d'assaut, SMG, pistolet, PV + bouclier, mort et réapparition), loot et inventaire
(boutique avec capsules de largage, objets au sol, 2 emplacements, crédits), monstres (Rôdeurs et Colosses
en camps de niveau 1 et 2, IA côté serveur), première quête : cristaux à défendre avec une foreuse
(3 difficultés, points de quête).
Prochaine étape : **Étape 5 – Contrats et Fame**.
