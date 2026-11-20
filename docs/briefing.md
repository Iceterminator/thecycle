# Salle de briefing

Phase `BRIEFING` du `MatchManager`, entre le lobby et le largage.

## Déroulé (serveur : `systems/match/match_briefing.gd`)
1. **Lobby** : équipement, escouades. Le **premier** joueur qui clique « PRÊT » ouvre la salle :
   la carte est remise à zéro (tirage des quêtes, monstres) et un compte à rebours démarre
   (`briefing_time` dans `data/rules/match.tres`, 60 s).
2. Chaque joueur prêt reçoit l'équipement de son profil, est remis à zéro et **téléporté dans la
   salle** (`BriefingRoom.spawn_point`). Une fois dans la salle, on ne peut plus annuler.
   Les joueurs encore au lobby voient toujours le lobby et peuvent se mettre prêts jusqu'au départ.
   Un joueur qui se connecte pendant le briefing arrive au lobby.
3. **Vote** (touche E dans la salle, `request_briefing_vote`) : départ dès qu'une **majorité stricte**
   des joueurs de la salle a voté (1/1, 2/2, 2/3, 3/4…). E de nouveau : annuler son vote.
4. **Départ** (fin du compte à rebours ou vote) : points de largage pour les joueurs de la salle,
   chute en capsule. Les joueurs restés au lobby perdent leur joueur et voient l'écran d'attente
   jusqu'au lobby suivant. Salle vide à la fin du compte à rebours : retour au lobby.
5. Pendant le briefing, `Player.is_dropping()` est vrai : ni tir, ni capacité, ni dégâts ; on marche.

## La salle (`systems/briefing/`, construite en local sur chaque peer par `World`)
- `briefing_room.gd` (`BriefingRoom`) : vaisseau en orbite basse au nord, hors des murs de la carte
  (`ORIGIN`), baie vitrée tournée vers la carte ; gère la touche E (vote du joueur local).
- `briefing_room_build.gd` : coque, baie vitrée (avec collision), bandes lumineuses, plafonniers, réacteurs.
- `briefing_hologram.gd` : socle, relief de la carte en miniature (couleurs des biomes, mares),
  anneau animé, repères des quêtes (groupe `map_marker` : cristaux, contrats, relique, évac).
- `briefing_board.gd` : tableau des quêtes tirées (`QuestManager.drawn_list`), temps et votes.
- Brume réduite pendant le briefing (`StormManager.BRIEFING_FOG`) pour voir la carte par la vitre.
- HUD : compte à rebours et votes (`hud_clock.gd`, `update_briefing`).

Captures : `docs/captures/briefing/`. Tests : `test_10_briefing_vote`, `test_11_briefing_exclu`.

## À faire plus tard
- Modèle Blender de la salle (la v1 est faite de boîtes).
- Points de largage affichés sur l'hologramme (aujourd'hui tirés au départ seulement).
