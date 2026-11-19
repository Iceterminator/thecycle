extends RefCounted
## État serveur de Weapon (c'est lui qui fait foi ; le chargeur est dans Inventory.slot_ammo).

var reload_end_ms: int = 0
var switch_until_ms: int = 0
var tokens: float = 0.0
var last_ms: int = 0
var trigger_ms: int = 0           # début de la charge / du rayon (0 = gâchette relâchée)
var trigger_shots: int = 0        # tirs déjà partis sur cette charge
var self_heal_ready_ms: int = 0   # rayon vital : prochain auto-soin possible
## Projectiles en vol : { id, pos, dir, speed, travelled, max_dist, data }.
var projectiles: Array[Dictionary] = []
var next_projectile_id: int = 0


## Début (pressed = true) ou fin d'une charge / d'un rayon.
func set_trigger(pressed: bool) -> void:
	trigger_ms = Time.get_ticks_msec() if pressed else 0
	trigger_shots = 0
