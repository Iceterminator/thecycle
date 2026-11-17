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
Maj : sprint · Ctrl : s'accroupir · Échap : libérer la souris.

## État
Étapes 0 et 1 de la feuille de route : connexion réseau et joueurs FPS répliqués.
Prochaine étape : **Étape 2 – Combat**.
