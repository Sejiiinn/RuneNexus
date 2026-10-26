extends RefCounted
## Shared combat state, small queries, effect records and stockpile timing.
const Teleports = preload("res://combat/teleport_pairs.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Kinds = preload("res://combat/combat_kinds.gd")
const Capabilities = preload("res://combat/attack_capabilities.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Wave = preload("res://combat/native_wave_state.gd")
const Defense = preload("res://combat/native_core_defense_state.gd")
const CoreSkill = preload("res://combat/native_core_skill_state.gd")
const Attack = preload("res://combat/attack_calculation.gd")
const EffectFormat = preload("res://combat/effect_presentation.gd")
const FrameRows = preload("res://presentation/frame_rows.gd")
# Match the authored 1.1-second cannon impact; generic hits last only 0.28s.
const BLAST_DURATION: float = 1.1
## Matches effects/sniper_energy_blast.gd DURATION.
const SNIPER_BLAST_DURATION: float = 0.6
## 독액 착탄 연출(튄 방울·안개)의 최소 길이. 웅덩이는 독 장판 유지 시간만큼 이어진다.
const VENOM_SPLASH_DURATION: float = 1.1
## 독 장판: 착탄 지점에 착탄 반경만큼 남아, 포탑별 주기마다 안에 있는 적에게 독 1중첩을 준다.
## 같은 포탑의 웅덩이 여러 개를 밟아도 주기당 1중첩. stackShare는 중첩 하나의 총 피해(치명타 없는 기본 피해 대비).
## 독 중첩 하나 = 기준 피해의 hitShare(공통 규칙 30%)를 stackSeconds에 나눠 준다.
## 착탄은 맞은 피해(100%)가 기준이고, 웅덩이는 포탑 피해 × puddleBase(절반)가 기준이다.
const POISON_PUDDLE := {"duration": 1.0, "tick": 0.5, "maxCount": 3, "hitShare": 0.3, "puddleBase": 0.5, "stackSeconds": 5.0}
## 1차 특성 독액 웅덩이: 웅덩이 3초.
const VENOM_POOL_PUDDLE := {"duration": 3.0}
## 2차 특성 부식 독소: 이 포탑 독 3중첩 이상인 동안 물리 저항 -15%p. 조건이 끊긴 뒤 잠깐만 남는다.
const CORROSION := {"stacks": 3, "bonus": 0.15, "linger": 0.25}
const PROJECTILE_RADII: Dictionary = {"arrow":3.5, "cannon":7.0, "magic":4.0, "poison":4.0}
## Turret-type presentation tables, shared instead of rebuilt per shot or hit.
const IMPACT_STYLES := {"arrow":"spark", "magic":"flame", "cannon":"blast", "lightning":"lightning", "poison":"venom"}
const VISUAL_COLORS := {"arrow":0xffffdf9e, "cannon":0xffffb066, "magic":0xffff713d, "frost":0xff94e6ff, "sniper":0xffffeec4, "lightning":0xffc7d8ff, "poison":0xffa6ff3a}
# Extend fired shots without changing turret or chain target acquisition ranges.
const PROJECTILE_TRAVEL_MULTIPLIER: float = 3.0
# Game seconds, independent of render cadence and playback speed. Keep the
# existing 60 Hz integrators (including their cooldown/waypoint overshoot rules).
const FIXED_STEP: float = 1.0 / 60.0
## Canvas artwork is authored for 48-pixel tiles (bars, glyphs, line widths).
const LOGICAL_CANVAS_TILE := 48.0
const MAX_STEPS_PER_FRAME: int = 64
const STEP_EPSILON: float = 1.0e-10
const STOCKPILE_MAX_CHARGES: int = 2
const STOCKPILE_SPEED_MULTIPLIER: float = 1.5
# Emitted only after a complete step. Application events/commands may be settled
# synchronously here, before another step consumes debt in this render frame.
signal step_completed
# Host wall-clock boundaries accrue at the old controls without advancing the
# simulation. Bootstrap, stale packets and duplicate ACKs never emit these.
signal clock_control_changing
signal clock_control_changed
var epoch: int = -1
var active: bool = false
var running: bool = true
var elapsed: float:
	get: return clock
var sequence: int = -1
var enemies: Dictionary = {}
var turrets: Dictionary = {}
var projectiles: Array = []
var delayed: Array = []
var events: Array = []
# ACK retires gameplay records before render. Keep only immutable death display
# data until the next presentation observation; never include it in saves.
var _presentation_deaths: Array = []
var visual_effects: Array = []
var puddles: Array = []
## 부식 독소 중첩이 붙은 적 id. 중첩이 모두 사라지면 빠진다.
var corroding: Dictionary = {}
var poison_puddle: Dictionary = POISON_PUDDLE.duplicate()
var venom_pool_puddle: Dictionary = VENOM_POOL_PUDDLE.duplicate()
# Canonical static payloads are immutable; raw journal units stay compatible
# with public frames, 3D impacts and development sessions.
var _prepared_effects: Dictionary = {}
# Internal presentation frames reuse one row object per actor id; rows are
# rewritten in full each frame. Public snapshots always receive fresh rows.
var _frame_row_pool := {"enemies": {}, "turrets": {}, "projectiles": {}, "impacts": {}, "labels": {}}
# Step-local target candidates: [enemy, position, target radius, progress, id].
# Valid only from the end of movement until spawns, while positions and
# membership are fixed; alive state and durability are still read live.
var _target_candidates: Array = []
var _target_candidates_ready := false
# [min x, min y, max x, max y, max target radius] of the shared candidates.
var _target_bounds: Array = []
# Core sync changes only when its actual multipliers change. New/replaced
# turrets still receive the current sync in _turret, independent of this cache.
var _sync_stats_ready := false
var _sync_stats_damage := 1.0
var _sync_stats_rate := 1.0
# Account growth is read at each hit/tick; it is never checkpoint state.
var _boss_damage_bonus_rate := 0.0
var _direct_damage_training_bonus_rate := 0.0
var _splash_damage_training_bonus_rate := 0.0
var _damage_over_time_training_bonus_rate := 0.0
var visual_id: int = 1000000000
var damage_number_index: int = 0
var event_id: int = 0
var projectile_id: int = 0
var clock: float = 0.0
var simulation_tick: int = 0
var simulation_debt: float = 0.0
var clock_control_revision: int = 0
var _advancing_session: bool = false
var path: Array = []
var teleport_pairs: Array = []
var routes: Dictionary = {}
var spawn_portal_id := ""
var _path_revision := 0
var origin := Vector2.ZERO
var tile_size: float = 1.0
var board_scale: float = 1.0
var rng := RandomNumberGenerator.new()
var wave = Wave.new()
var core = CoreSkill.new()
var defense = Defense.new()
var wave_configured: bool = false
var terminal: bool = false
var pending_steps: Array = []
# Only the session clock may advance production combat. Legacy step packets are
# retained for deterministic regression fixtures, never mixed with this clock.
var session: Dictionary = {}
var state_revision: int = 0
var wall_elapsed: float = 0.0
var effect_time: float = 0.0
var effect_squared: float = 0.0
var destruction_elapsed: float = 0.0
var nexus_alert: float = 0.0
var portal_alert: float = 0.0

func native_session() -> bool:
	return session.get("clock", "") == "godot"

func _training_rate(value: Variant) -> float:
	var rate := float(value)
	return clampf(rate, 0.0, 0.4) if is_finite(rate) else 0.0

func _target_damage_multiplier(e: Dictionary) -> float:
	return 1.0 + _boss_damage_bonus_rate if _boss_damage_bonus_rate > 0.0 and _boss(e) else 1.0

func _boss(e: Dictionary) -> bool:
	return Enemy.is_boss(e)

# Larger score means nearer the core. Subtracting each route's own length
# preserves every same-path ordering/tie while comparing unequal routes fairly.
func _progress_score(enemy: Dictionary) -> float:
	return float(enemy.get("distanceTravelled",0.0)) - float(enemy.get("_total",0.0))

func _core_visual(kind: String, targets: Array, color: int) -> void:
	if targets.is_empty(): return
	visual_id += 1
	var start := (_vec(path[-1]) - origin)/tile_size if not path.is_empty() else Vector2.ZERO
	var points: Array = [[start.x,start.y]] if kind == "coreBeam" else []
	var ids: Array = []
	for target in targets:
		var p := (_pos(target)-origin)/tile_size
		points.append([p.x,p.y])
		ids.append(target.id)
	_append_visual({"id":visual_id,"kind":kind,"born":clock,"duration":0.14 if kind == "coreBeam" else 0.42,"x":start.x,"y":start.y,"tileSize":tile_size,"scale":board_scale,"color":color,"points":points,"targetIds":ids,"screenOffset":[0,0]})

func _core_damage_number(target: Dictionary, damage: float) -> void:
	var at := _pos(target)
	var source := _vec(path[-1]) if not path.is_empty() else origin
	var direction := source-at
	if direction.length_squared()>0.001:
		direction = direction.normalized()
		at += Vector2(direction.x*14.0,direction.y*6.0-10.0)*board_scale
	else:
		at.y -= 10.0*board_scale
	var angle := -PI*0.82+float(damage_number_index%7)*PI*0.27
	damage_number_index += 1
	at += Vector2.from_angle(angle)*8.0*board_scale
	at = (at-origin)/tile_size
	visual_id += 1
	_append_visual({"id":visual_id,"kind":"damage","born":clock,"duration":0.75,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,"color":0xff8ee6ff,"text":str(roundi(damage)),"feedback":"neutral","motion":"rise","arcDirection":1,"points":[],"screenOffset":[0,0]})

## 화상·독 틱을 적 상태가 모아 둔 주기(화상 0.28초, 독 0.5초)마다 아래로 떨어지는 숫자로 보인다.
## 색은 이전 앱의 지속피해 숫자와 같다(화상 주황, 독 연두).
const DOT_NUMBER_COLORS := {"burn": 0xffff8a2a, "poison": 0xff9dff4a}
func _dot_damage_number(raw: Dictionary) -> void:
	var damage := float(raw.get("damage", 0.0))
	var e: Dictionary = enemies.get(str(raw.get("enemyId", "")), {})
	if damage < 0.5 or e.is_empty() or not DOT_NUMBER_COLORS.has(raw.get("kind")): return
	var at := (_pos(e) - origin) / tile_size
	visual_id += 1
	damage_number_index += 1
	_append_visual({"id":visual_id,"kind":"damage","born":clock,"duration":0.75,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,"color":DOT_NUMBER_COLORS[raw.kind],"text":str(roundi(damage)),"feedback":"neutral","motion":"fallArc","arcDirection":1 if damage_number_index % 2 == 0 else -1,"points":[],"screenOffset":[0,0]})

func _nexus_health_number(change: float) -> void:
	visual_id += 1
	var at := (_vec(path[-1])-origin)/tile_size if not path.is_empty() else Vector2.ZERO
	var value := ("+" if change>0 else "-")+String.num(absf(change),1)
	_append_visual({"id":visual_id,"kind":"damage","born":clock,"duration":0.75,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,"color":0xff72e0a2 if change>0 else 0xffff7043,"text":value,"feedback":"neutral","motion":"rise","arcDirection":1,"points":[],"screenOffset":[0,0]})

func _normal_aim_duration(t: Dictionary) -> float:
	if t.statInput.definition.type == "lightning": return 0.3
	return float(t.stats.aimDuration) if t.statInput.definition.instantHit else 0.0

func _stockpile_aim_multiplier(t: Dictionary) -> float:
	return maxf(1.0, float(t.statInput.get("coreEffects", {}).get("stockpileAimSpeedMultiplier", STOCKPILE_SPEED_MULTIPLIER)))

func _stockpile_cooldown_multiplier(t: Dictionary) -> float:
	return maxf(1.0, float(t.statInput.get("coreEffects", {}).get("stockpileCooldownRecoveryMultiplier", STOCKPILE_SPEED_MULTIPLIER)))

func _normal_attack_rate(t: Dictionary) -> float:
	return maxf(0.001, t.stats.attackRate / (1.4 if t.statInput.chainCleanupActive else 1.0) * (1.4 if t.cleanup > 0 else 1.0))

func _charge_stockpile(t: Dictionary, ready_dt: float) -> void:
	if ready_dt <= 0.0 or t.stockpileCharges >= STOCKPILE_MAX_CHARGES: return
	var aim := _normal_aim_duration(t)
	var interval := 1.0 / _normal_attack_rate(t) + aim
	t.stockpileIdleElapsed += ready_dt
	while t.stockpileIdleElapsed + STEP_EPSILON >= interval and t.stockpileCharges < STOCKPILE_MAX_CHARGES:
		t.stockpileIdleElapsed = maxf(0.0, t.stockpileIdleElapsed - interval)
		t.stockpileCharges += 1
	# Never bank overflow past the two-charge cap.
	if t.stockpileCharges >= STOCKPILE_MAX_CHARGES: t.stockpileIdleElapsed = 0.0

func _add_core_bonus_damage(damage: float) -> void:
	if core.configured and damage > 0: core.bonus_damage_dealt += damage

func _emit(event: Dictionary) -> void:
	event_id += 1
	event.id = event_id
	events.append(event)

func _retain_death_presentation(event: Dictionary) -> void:
	var enemy: Dictionary = enemies.get(str(event.enemyId), {})
	if enemy.is_empty(): return
	var display := event.duplicate(true)
	display.enemyPresentation = {
		"type":enemy.get("type", "normal"), "facingAngle":enemy.get("facingAngle", 0.0),
		"presentationScale":enemy.get("presentationScale", 0.48 if enemy.get("type") == "fast" else 0.55),
		"teleportSerial":enemy.get("teleportSerial", 0), "routeId":enemy.get("routeId", ""), "spawnPortalId":enemy.get("spawnPortalId", ""),
	}
	display.visualOffset = _visual_enemy_offset(enemy)
	_presentation_deaths.append(display)

func take_death_presentations() -> Array:
	var pending := _presentation_deaths
	_presentation_deaths = []
	return pending

func _diamond_reward_visual(enemy: Dictionary) -> void:
	var amount := maxi(0, int(enemy.get("diamondReward", 0)))
	if amount == 0 or bool(enemy.get("isDebug", false)): return
	var at := (_pos(enemy) + _visual_enemy_offset(enemy) - origin) / tile_size
	visual_id += 1
	_append_visual({"id":visual_id,"kind":"diamond","born":clock,"bornSquared":effect_squared,
		"duration":1.05,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,
		"text":"+%d" % amount,"hasImage":true,"points":[],"screenOffset":[0,0]})

func _visual(kind: String, at: Vector2, t: Dictionary, extra: Dictionary = {}) -> void:
	visual_id += 1
	var pos := (at - origin) / tile_size
	var v := {"id":visual_id, "kind":kind, "born":clock, "duration":0.28, "x":pos.x, "y":pos.y, "tileSize":tile_size, "scale":board_scale, "color":VISUAL_COLORS.get(t.statInput.definition.type, 0xffffffff), "points":[], "screenOffset":[0,0], "feedback":"neutral", "motion":"rise", "arcDirection":1}
	if t.statInput.definition.type == "lightning":
		v["turretType"] = "lightning"
		v["ownerId"] = int(t.id)
	v.merge(extra, true)
	if kind == "blast" and not extra.has("duration"):
		v.duration = BLAST_DURATION
	var points: Array = []
	for point in v.points:
		var p := (_vec(point) - origin) / tile_size
		points.append([p.x,p.y])
	v.points = points
	_append_visual(v)

func _append_visual(effect: Dictionary) -> void:
	visual_effects.append(effect)
	_prepared_effects[int(effect.id)] = {"source":effect,"payload":EffectFormat.prepare(effect)}

func _effect_frame(effect: Dictionary, reuse_static: bool, canonical: bool) -> Dictionary:
	if not canonical: return effect.duplicate(not reuse_static)
	var prepared: Dictionary = _prepared_effects.get(int(effect.id), {})
	if not prepared.is_empty() and is_same(prepared.source, effect):
		return prepared.payload.duplicate(not reuse_static)
	# Directly supplied fixture/legacy entries preserve their current values.
	var item := effect.duplicate(true)
	EffectFormat.normalize(item)
	return item

func _visual_enemy_offset(e: Dictionary) -> Vector2:
	var lane: float = e.get("laneOffsetRatio", 0.0)
	if lane == 0 or e.path.size() < 2: return Vector2.ZERO
	var distance: float = e.distanceTravelled
	var sample := 48.0 * board_scale * 0.4
	var before := Enemy.point_at_distance(e, distance - sample)
	var after := Enemy.point_at_distance(e, distance + sample)
	var tangent := after - before
	if tangent.length_squared() <= 0.001: return Vector2.ZERO
	var total: float = e._total
	var fade := clampf(minf(distance,total-distance)/(48.0*board_scale*0.55),0,1)
	return Vector2(-tangent.y,tangent.x).normalized()*lane*48.0*board_scale*fade

func _alive(e: Dictionary) -> bool:
	return float(e.get("hp", 0)) > 0 and not e.get("arrived", false) and not e.get("isDead", false)

func _target_radius(e: Dictionary) -> float:
	return float(e.get("targetingRadius", float(e.get("presentationSize", [_radius(e)*2])[0])*0.5))

func _radius(e: Dictionary) -> float:
	return float(e.get("collisionRadius", e.get("radius", 8.0)))

func _durability(e: Dictionary) -> float:
	return float(e.get("hp", 0)) + maxf(0, e.get("armor", 0)) + maxf(0, e.get("shield", 0))

func _pos(e: Dictionary) -> Vector2:
	return Vector2(float(e.get("x", 0)), float(e.get("y", 0)))

func _vec(raw) -> Vector2:
	if raw is Vector2:
		return raw
	if raw is Array:
		return Vector2(float(raw[0]), float(raw[1])) if raw.size() >= 2 else Vector2.ZERO
	return Vector2(float(raw.get("x", 0)), float(raw.get("y", 0)))
