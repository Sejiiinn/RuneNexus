extends "res://combat/combat_runtime_simulation.gd"
## Per-render presentation frame built from the authoritative state.

func decorate_frame(base: Dictionary, reuse_static: bool = false, canonical_effects: bool = false) -> Dictionary:
	if not active:
		return base
	# Internal presentation (reuse_static) reads static map/selection read-only and
	# reuses row/label objects until the next internal call; consume it at once.
	# Public snapshots (the default) stay fully isolated for existing callers.
	var frame := base.duplicate(not reuse_static)
	# Canonical (internal) frames carry Canvas sizes in 48-pixel tile units, as
	# app_presentation.normalize produces for public snapshots.
	var canvas_tile := maxf(0.001, tile_size)
	var canvas_ratio := LOGICAL_CANVAS_TILE / canvas_tile
	var canvas_scaled: bool = canonical_effects and base.has("presentation") and not is_equal_approx(canvas_tile, LOGICAL_CANVAS_TILE)
	if reuse_static and base.get("presentation") is Dictionary:
		frame.presentation = base.presentation.duplicate()
		for group in ["effects", "selection", "labels"]:
			if frame.presentation.get(group) is Dictionary:
				frame.presentation[group] = frame.presentation[group].duplicate()
	if native_session():
		frame.time = effect_time
		frame.nexusHit = nexus_alert/0.65
		frame.portalAlert = portal_alert/0.55
		if frame.get("presentation") is Dictionary:
			for group in ["effects", "selection"]:
				if frame.presentation.get(group) is Dictionary:
					frame.presentation[group].clock = effect_time
					frame.presentation[group].time = effect_time
			if frame.presentation.get("selection") is Dictionary and not frame.presentation.selection.get("state", frame.presentation.selection).get("preserveLegacyOrnaments", false):
				var aims: Array = []
				for t in turrets.values():
					var target: Dictionary = enemies.get(str(t.aimTargetId), {})
					if not target.is_empty():
						var point := (_pos(target)-origin)/tile_size
						aims.append([t.id,point.x,point.y,t.aimProgress])
				frame.presentation.selection.aim = aims
			if frame.presentation.get("effects") is Dictionary:
				# Dart's last sampled shake must never become a permanent offset.
				var shake := sin(destruction_elapsed*78)*(1.0-destruction_elapsed/3.2)*3.4*board_scale if destruction_elapsed>0 else 0.0
				# World shake is consumed as canonical screen pixels.
				frame.presentation.effects.shake = [shake*canvas_ratio,-shake*0.45*canvas_ratio] if canvas_scaled else [shake,-shake*0.45]
				frame.presentation.effects.squaredSteps = effect_squared
	if defense.configured:
		frame.nexusHpRatio = defense.hp/maxf(0.000001,defense.max_hp)
	var rows: Array = []
	var labels: Array = []
	var enemy_rows := {}
	var enemy_pool: Dictionary = _frame_row_pool.enemies
	var label_rows := {}
	var label_pool: Dictionary = _frame_row_pool.labels
	for e in enemies.values():
		if not _alive(e): continue
		# Dictionary.get evaluates its fallback first; avoid it for authored sizes.
		var logical := (_pos(e) - origin) / tile_size
		var p := logical + _visual_enemy_offset(e) / tile_size
		var burning: bool = not e.burnInstances.is_empty()
		var slowed: bool = not e.slowInstances.is_empty()
		var poisoned: bool = not e.poisonInstances.is_empty()
		var diamond: bool = int(e.get("diamondReward", 0)) > 0
		var row: FrameRows.Enemy = enemy_pool.get(e.id) if reuse_static else null
		if row == null: row = FrameRows.Enemy.new()
		if reuse_static: enemy_rows[e.id] = row
		# Typed row fields convert the runtime's numeric values on assignment.
		row.id = e.id; row.x = p.x; row.y = p.y
		row.facing = e.facingAngle; row.phase = e.visualPhase
		row.scale = e.presentationScale if e.has("presentationScale") else _radius(e)*2.0/tile_size; row.has_scale = true
		row.hit_flash = e.hitFlashTimer; row.type = e.get("type","normal")
		row.burning = burning; row.slowed = slowed; row.poisoned = poisoned; row.diamond = diamond
		row.has_logical = true; row.logical_x = logical.x; row.logical_y = logical.y
		row.teleport_serial = e.get("teleportSerial",0) if not e.get("teleportPairs", []).is_empty() else -1
		row.has_shield = row.type == "shielded"
		row.shield = e.shield if row.has_shield else 0.0
		row.max_shield = e.maxShield if row.has_shield else 0.0
		row.rarity = e.rarity if e.has("rarity") else ""
		rows.append(row)
		var size: Array = e.presentationSize if e.has("presentationSize") else [_radius(e)*2,_radius(e)*2]
		if canvas_scaled: size = [float(size[0])*canvas_ratio,float(size[1])*canvas_ratio]
		# Dictionary.get evaluates its fallback eagerly; look up without one.
		var label = label_pool.get(e.id) if reuse_static else null
		if label == null: label = {}
		if reuse_static: label_rows[e.id] = label
		label.id = e.id; label.position = [p.x,p.y]; label.size = size
		label.hp = e.hp; label.maxHp = e.maxHp; label.armor = e.armor; label.maxArmor = e.maxArmor
		label.shield = e.shield; label.maxShield = e.maxShield; label.effectTime = e.statusEffectTime
		label.enemyCount = enemies.size(); label.burning = burning; label.slowed = slowed; label.poisoned = poisoned
		label.riftMarked = e.riftMarkRemaining>0; label.diamondCarrier = diamond
		label.rarity = e.rarity if e.has("rarity") else ""
		labels.append(label)
	frame.enemies = rows
	frame.turrets = []
	var turret_rows := {}
	var turret_pool: Dictionary = _frame_row_pool.turrets
	for t in turrets.values():
		var p := (_vec(t.position)-origin)/tile_size
		var row: FrameRows.Turret = turret_pool.get(t.id) if reuse_static else null
		if row == null: row = FrameRows.Turret.new()
		if reuse_static: turret_rows[t.id] = row
		row.id = t.id; row.x = p.x; row.y = p.y; row.aim_angle = t.aimAngle
		row.shot_sequence = t.shotSequence; row.fire_feedback = t.fireFeedback/0.18
		row.type = t.statInput.definition.type; row.level = t.statInput.level
		row.extension = FrameRows.NO_EXTENSION
		if t.statInput.definition.type == "sniper":
			# Optional visual state only; damage, targeting and saved state stay native.
			var target: Dictionary=enemies.get(str(t.aimTargetId),{})
			var aiming: bool=running and session.get("phase","")=="wave" and float(t.aimProgress)>0 and float(t.cooldown)<=0
			aiming=aiming and not target.is_empty() and _alive(target) and _vec(t.position).distance_to(_pos(target))<=float(t.stats.range)+_target_radius(target)
			var ratio := clampf(float(t.aimProgress)/maxf(.000001,float(t.stats.aimDuration)),0.0,1.0) if aiming else 0.0
			row.extension = {"aimActive":aiming,"aimTargetId":int(t.aimTargetId),"aimProgress":float(t.aimProgress),"aimRatio":ratio}
		if t.statInput.definition.type == "frost":
			# Presentation extension only.
			# Saves retain remaining cooldown but not lastBaseCooldown; derive a safe
			# denominator from current attack speed without changing saved state.
			var duration := float(t.get("lastBaseCooldown", 0.0))
			if duration <= 0.0:
				duration = maxf(float(t.cooldown), 1.0 / maxf(.001, float(t.stats.attackRate)))
			row.extension = {"cooldown":t.cooldown, "duration":duration, "radius":float(t.stats.centeredAreaRadius)/tile_size}
		if t.statInput.definition.type == "poison" and t.statInput.get("primaryTrait") == "venomPool":
			# Presentation extension only: the heavier glob is drawn larger.
			row.extension = {"venomPool": true}
		if t.stockpileEnabled:
			if is_same(row.extension, FrameRows.NO_EXTENSION): row.extension = {}
			row.extension.merge({"stockpileEnabled":true,"stockpileCharges":int(t.stockpileCharges),"stockpileIdleElapsed":float(t.stockpileIdleElapsed),"stockpileChargeInterval":1.0 / _normal_attack_rate(t) + _normal_aim_duration(t)}, true)
		frame.turrets.append(row)
	if frame.has("presentation"):
		if not frame.presentation.has("labels"): frame.presentation.labels = {}
		frame.presentation.labels.enemies = labels
		frame.presentation.labels.logicalTileSize = LOGICAL_CANVAS_TILE if canvas_scaled else tile_size
		if native_session():
			frame.presentation.labels.core = null
			if session.get("phase") == "wave" and core.configured and core.skill != null and not path.is_empty():
				var center := (_vec(path[-1])-origin)/tile_size
				var progress := 1.0 if core.guardian_beam_active_remaining>0 else clampf(1.0-core.cooldown/maxf(0.000001,core.interval()),0,1)
				frame.presentation.labels.core = {"position":[center.x,center.y],"progress":progress,"accent":0xffcfa7ff if core.skill == "riftMark" else 0xff8ee6ff,"active":core.guardian_beam_active_remaining>0}
	frame.projectiles = []
	frame.impacts = []
	var impact_rows := {}
	var projectile_rows := {}
	for v in visual_effects:
		if v.kind == "blast":
			var impact: FrameRows.Impact = _frame_row_pool.impacts.get(v.id) if reuse_static else null
			if impact == null: impact = FrameRows.Impact.new()
			if reuse_static: impact_rows[v.id] = impact
			impact.id = v.id; impact.x = v.x; impact.y = v.y
			impact.radius = float(v.radius)/tile_size; impact.progress = clampf((clock-float(v.born))/float(v.duration),0,1)
			impact.variant = str(v.get("variant", ""))
			impact.duration = float(v.duration)
			frame.impacts.append(impact)
	for p in projectiles:
		var at: Vector2 = (p.position - origin) / tile_size
		var start: Vector2 = (p.origin - origin) / tile_size
		var row: FrameRows.Projectile = _frame_row_pool.projectiles.get(p.id) if reuse_static else null
		if row == null: row = FrameRows.Projectile.new()
		if reuse_static: projectile_rows[p.id] = row
		row.id = p.id; row.x = at.x; row.y = at.y
		row.direction_x = p.direction.x; row.direction_y = p.direction.y; row.type = p.attack.definition.type
		row.has_launch = true; row.start_x = start.x; row.start_y = start.y
		row.has_owner = true; row.owner_id = int(p.owner); row.shot = p.shot; row.chained = p.chained
		row.finished_at = -1.0; row.has_end = false
		if p.has("landing"):
			# In-flight lob: the end fields carry the current landing point for the arc.
			var landing: Vector2 = (p.landing - origin) / tile_size
			row.has_end = true; row.end_x = landing.x; row.end_y = landing.y
		frame.projectiles.append(row)
	if reuse_static:
		_frame_row_pool = {"enemies": enemy_rows, "turrets": turret_rows, "projectiles": projectile_rows, "impacts": impact_rows, "labels": label_rows}
	if frame.has("presentation") and frame.presentation.has("effects"):
		var effects: Dictionary = frame.presentation.effects
		var items: Array = effects.get("items", []).duplicate(true)
		var presentation_events: Array = effects.get("events", []).duplicate(true)
		effects.erase("_canonicalNativeEffects")
		if canonical_effects:
			# Mixed base/legacy entries are owned copies, never cached or skipped.
			for legacy in items + presentation_events: EffectFormat.normalize(legacy)
			effects._canonicalNativeEffects = true
		for v in visual_effects:
			if v.kind == "diamond":
				# The receiver owns receipt display time after first delivery, even
				# when the source's short combat-time journal has already expired.
				presentation_events.append(_effect_frame(v, reuse_static, canonical_effects))
				continue
			var item: Dictionary = _effect_frame(v, reuse_static, canonical_effects)
			item.age = clock - float(v.born)
			if item.kind == "damage":
				item.screenOffset = [0,-34.0*float(item.age)]
			elif item.kind == "chain":
				item.points = v.points.duplicate(not reuse_static)
				var linked: Dictionary = enemies.get(str(item.targetIds[-1]),{})
				if not linked.is_empty() and _alive(linked):
					var end := (_pos(linked)-origin)/tile_size
					item.points[-1] = [end.x,end.y]
					v.points[-1] = [end.x,end.y]
			elif item.kind == "coreBeam":
				item.points = v.points.duplicate(not reuse_static)
				var linked: Dictionary = enemies.get(str(item.targetIds[0]),{})
				if not linked.is_empty() and _alive(linked):
					var end := (_pos(linked)-origin)/tile_size
					item.points[1] = [end.x,end.y]
					v.points[1] = [end.x,end.y]
			elif item.kind == "rift":
				item.points = []
				for id in item.targetIds:
					var linked: Dictionary = enemies.get(str(id),{})
					if not linked.is_empty() and _alive(linked):
						var end := (_pos(linked)-origin)/tile_size
						item.points.append([end.x,end.y])
			items.append(item)
		effects.items = items
		effects.events = presentation_events
	return frame
