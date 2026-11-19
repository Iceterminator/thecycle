extends RefCounted
## Colonnes de l'écran Tab (MapOverlay) : classement des joueurs et progression des objectifs.
## Remplit les boîtes de l'overlay `o` ; lecture seule de données déjà synchronisées.

const FORAGE_ID := &"forage"  ## objectif du Cristal : toujours visible

## Classement (gauche).
static func refresh_ranking(o: MapOverlay) -> void:
	o._clear(o._ranking_box)
	o._ranking_box.add_child(o._title("CLASSEMENT"))
	var players: Array[Player] = []
	var root := o._world.get_node_or_null("Players") if o._world else null
	if root:
		for node in root.get_children():
			if node is Player:
				players.append(node)
	players.sort_custom(func(a: Player, b: Player) -> bool: return a.score.rank_points > b.score.rank_points)
	var rank := 1
	for p in players:
		var me := p == o._player
		var who := "Vous (%s)" % ProfileManager.name_of(p.get_peer_id()) if me else ProfileManager.name_of(p.get_peer_id())
		var tags: PackedStringArray = []
		if p.is_evacuated:
			tags.append("à bord")
		elif p.health.is_dead:
			tags.append("mort")
		if p.score.beacon != "":
			tags.append(p.score.beacon)
		var line := "%d. %s — %d Fame" % [rank, who, p.score.rank_points]
		if not tags.is_empty():
			line += "\n    " + ", ".join(tags)
		var label := o._label(line, 18 if me else 17)
		label.add_theme_color_override("font_color", Color(1, 0.9, 0.3) if me else Color(1, 1, 1, 0.85))
		o._ranking_box.add_child(label)
		rank += 1

## Quêtes (droite).
static func refresh_quests(o: MapOverlay) -> void:
	o._clear(o._quests_box)
	o._quests_box.add_child(o._title("VOS OBJECTIFS (→ Fame au prochain palier)"))
	var points: Dictionary = o._player.score.objective_points
	var rates: Dictionary = o._player.score.objective_rates
	var quests := o._world.get_node_or_null("QuestManager") as QuestManager
	var active := quests.active_objectives if quests else PackedStringArray()
	for track in o._tracks:
		# Seuls les objectifs des quêtes tirées (le Forage, lui, reste toujours affiché).
		if not active.is_empty() and track.id != FORAGE_ID and not active.has(String(track.id)):
			continue
		var pts: int = points.get(track.resource_path, 0)
		var tier := track.tiers_reached(pts)
		var previous := track.threshold(tier - 1) if tier > 0 else 0
		var next := track.threshold(tier)
		var text := "%s  %d / %d  → +%d" % [track.display_name, pts, next, track.reward(tier)]
		var rate: float = rates.get(track.resource_path, 0.0)
		if rate > 0.0:
			text += "  (+%.1f/s)" % rate
		# Couleur de l'objectif, éclaircie pour rester lisible sur le fond.
		var label := o._label(text, 16)
		label.add_theme_color_override("font_color", track.color.lightened(0.35))
		o._quests_box.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = clampf(float(pts - previous) / maxf(next - previous, 1), 0.0, 1.0)
		var fill := StyleBoxFlat.new()
		fill.bg_color = track.color
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.2)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		o._quests_box.add_child(bar)
