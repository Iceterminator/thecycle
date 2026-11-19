extends RefCounted
## Serveur : projectiles simulés (création, avancée par image, impact ou fin de portée).
## La liste des projectiles en vol est dans Weapon (_srv_projectiles).

var _w: Weapon


func _init(weapon: Weapon) -> void:
	_w = weapon


func launch(origin: Vector3, dir: Vector3) -> void:
	var data := _w.data
	_w._srv_next_projectile_id += 1
	_w._srv_projectiles.append({
		"id": _w._srv_next_projectile_id,
		"pos": origin,
		"dir": dir,
		"speed": data.projectile_speed_mps,
		"travelled": 0.0,
		"max_dist": data.get_max_range() * _w._boost("range"),
		"range_mult": _w._boost("range"),
		"dmg_mult": _w._boost("damage"),
		"data": data,  # l'arme peut changer pendant le vol
	})
	_w._show_projectile.rpc(_w._srv_next_projectile_id, origin, dir, data.projectile_speed_mps, data.get_max_range() * _w._boost("range"))


## Fait avancer les projectiles (serveur uniquement) : un raycast par image sur le
## segment parcouru, en ligne droite (pas de chute pour l'instant).
func update(delta: float) -> void:
	var projectiles := _w._srv_projectiles
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		var step := minf(p["speed"] * delta, p["max_dist"] - p["travelled"])
		var from: Vector3 = p["pos"]
		var to: Vector3 = from + p["dir"] * step
		var ray := _w._damage.raycast(from, to)
		if not ray.is_empty():
			var point: Vector3 = ray["position"]
			var distance: float = p["travelled"] + from.distance_to(point)
			var wdata: WeaponData = p["data"]
			var collider := ray["collider"] as Node
			var kind := _w._damage.hit(collider, point, distance / float(p.get("range_mult", 1.0)), wdata, float(p.get("dmg_mult", 1.0)))
			if wdata.is_explosive():
				_w._damage.explode(point, wdata, collider, float(p.get("dmg_mult", 1.0)))
			_w._show_projectile_end.rpc(p["id"], point, kind)
			projectiles.remove_at(i)
			continue
		p["pos"] = to
		p["travelled"] += step
		if p["travelled"] >= p["max_dist"]:
			_w._show_projectile_end.rpc(p["id"], to, Weapon.HitKind.NONE)
			projectiles.remove_at(i)
