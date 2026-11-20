# Modélisation Blender — notes de travail

Résumé de ce qui s'est dit et fait sur la modélisation 3D (Blender MCP → Godot), novembre 2026.
À relire seulement sur demande.

## Modèles faits

| Modèle | Fichier | Méthode | État |
| --- | --- | --- | --- |
| Foreuse (quête cristal) | `assets/models/props/foreuse.gltf` | primitives détaillées (pieds télescopiques, vérins, moteur, gyrophares, pupitre, mèche en spirale), fusionnées en 2 maillages (carcasse + `Meche`) | commité, en jeu (descente animée dans `crystal_visual.gd`) |
| Capsule de largage | `assets/models/props/capsule_largage.gltf` | coques de révolution + hublots, intérieur aménagé (harnais, consoles, hologrammes, plafonnier), porte = nœud `Porte` pivotant | commité, en jeu (`drop_pod_visual.gd`) |
| Prospecteur (perso IA importé) | `assets/models/characters/prospecteur.gltf` | modèle IA (.glb 50k tris, 4K) mis à l'échelle, décimé (15k), riggé sur le squelette Superhero (bras en A, os recalés, poids auto) ; animations adaptées par `systems/avatar/avatar_retarget.gd` | apparence au choix dans le lobby ; jugé « horrible in game », à reprendre plus tard ; non commité |
| Pistolet à fléchettes A | `assets/models/weapons/asp_flechette_gun/pistolet_flechettes.glb` | script `tools/blender/pistolet_flechettes.py` : sections super-ellipse, coques séparées SOLIDIFY + BEVEL, liserés dans les joints, ARRAY pour les fléchettes ; contours mesurés sur la photo | 47k tris, pas de textures ; silhouette 0,96 |
| Pistolet B | `…/pistolet_flechettes_b.glb` (+ `_b_sans_cuisson.glb`) | script `tools/blender/pistolet_flechettes_b.py` : contours extraits automatiquement du masque, cages basse résolution + SOLIDIFY + SUBSURF, cuisson complète (BC/ORM/N/E 2048) | cuisson ratée (nez froissé, liserés blancs, canon noir, bug de matériaux) ; la version sans cuisson plaisait |
| Pistolet C | `…/pistolet_flechettes_c.glb` | B corrigé : nez en dôme, joint du panneau lissé (polynôme), cuisson AO seule sur les matériaux d'origine | 18k tris, 1,3 Mo ; candidat retenu, à valider |

Images de référence du pistolet : fond bleu, profil (fournies dans la conversation, non enregistrées dans le projet).

## Pourquoi mes modèles faisaient « pâte à modeler »

- Coque d'un seul bloc lisse (loft de sections) : pas d'arêtes vives ni de vraies pièces.
- Pas de joints entre pièces, lissage partout, matériaux unis sans texture.
- Modélisation « à l'aveugle » (code + quelques captures) → formes faciles à calculer = molles.

Corrections : approche hard-surface (pièces séparées avec épaisseur, chanfreins limités à l'angle, joints creusés où passent les liserés), matériaux avec bruit, textures cuites.

## Ne plus modéliser à l'aveugle (méthode qui marche)

1. Image de référence de **profil sur fond uni** (le fond bleu foncé se détoure presque parfaitement ; le fond clair à pli de studio trompe le détourage).
2. Détourage (masque) → **mesure des contours colonne par colonne**, liserés détectés par leur couleur verte, joints repérés par les creux de luminosité.
3. Caméra orthographique calée sur la photo (même échelle en px) → rendu de la silhouette → **score de recouvrement (IoU)** + carte des écarts (rouge = trop, bleu = manque).
4. Corriger jusqu'au score voulu : A est passé de 0,68 (contours tracés à l'œil, décalés jusqu'à 100 px) à 0,96.
5. Limite : une seule vue → l'épaisseur est devinée. Une vue de dessus / de face améliorerait.

## Skills Blender (installés le 2026-11-19)

- 95 skills de https://github.com/arjun988/blender-skills dans `~/.claude/skills` (Markdown seulement, vérifiés ; `.mcp.json` du dépôt non installé).
- Utiles ici : `blender-director` (point d'entrée, brief + analyse de référence), `hard-surface`, `texture-workflow`, `godot-export`, `asset-optimization`, `lod-pipeline`, `rigging`, `retopology`.
- Ils guident la méthode ; ils ne génèrent pas de modèle à partir d'une image (il faudrait un générateur IA activé dans l'add-on : Meshy, Tripo… clé d'API).

## Leçons techniques

- **Budget** arme vue à la 1re personne : ≤ 20 000 triangles (skill : 10–30k). SOLIDIFY + SUBSURF + BEVEL multiplient vite les triangles : réduire la cage, pas le lissage.
- **Procédural ≠ glTF** : les nœuds de bruit ne s'exportent pas ; il faut cuire en textures (ou accepter des couleurs unies).
- **Cuisson complète** risquée : projection haute→basse (froissements au nez), émission trop forte (vert → blanc), métal pur noir sans reflets d'environnement. La **cuisson AO seule** sur les matériaux d'origine donne le meilleur compromis.
- **Bug corrigé** : en fusionnant des objets via bmesh, conserver les index de matériaux (et ne pas faire `materials.clear()` : ça remet les index à 0 ; remplacer emplacement par emplacement).
- Occlusion exportée en glTF via un groupe de nœuds « glTF Material Output » (entrée `Occlusion`) ; émission > 1 exportée par `KHR_materials_emissive_strength`.
- Cuisson Cycles longue (> 3 min pour 6 cartes 2048) : le MCP coupe à 180 s, Blender continue ; vérifier ensuite.
- Godot : comparer les modèles dans Godot (pas seulement le rendu Blender, plus flatteur) ; ajouter des reflets de ciel pour juger le métal.
- Rigging d'un perso importé : les animations UAL imposent aussi la position des os → adapter les clés de position aux proportions du modèle (avatar_retarget.gd) ; les rotations sont absolues.
- Capsule : visuel `top_level` qui suit la position du joueur mais pas sa rotation.

## Préférences exprimées

- Style futuriste soigné (capsule belle dedans et dehors).
- Comparer plusieurs versions côte à côte avant de choisir ; montrer le rendu face à l'image originale.
- La version B « avant cuisson » plaisait ; la cuisson complète l'a dégradée.

## En suspens

- Choisir la version du pistolet (C proposée), puis la brancher en jeu : scène « tenue en main » avec repères `Poignee` / `Bouche` (`tools/make_held_scenes.gd`), réglage avec `grip_preview`.
- Reprendre le Prospecteur (rendu jugé mauvais en jeu).
- Nettoyer les fichiers d'essai du pistolet non retenus ; commit des modèles et scripts.
