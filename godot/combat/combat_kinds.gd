extends RefCounted
## Wire values shared by combat producers and session/presentation consumers.
## Fixtures, journals and protocol checks use these exact strings; never rename.

# Journal events the runtime emits for the run domain and presentation.
const KILL := "kill"
const ARRIVAL := "arrival"
const CORE_DEFEATED := "coreDefeated"
const CORE_DAMAGE := "coreDamage"
const CORE_RECOVERED := "coreRecovered"
const WAVE_STARTED := "waveStarted"
const WAVE_COMPLETED := "waveCompleted"
## Removing these only after the run domain ACKs them keeps rewards readable.
const ACK_REMOVES_ENEMY := [KILL, ARRIVAL]

# Enemy-state step results; the runtime settles or renames them into events.
const ENEMY_KILLED := "killed"
const ENEMY_CORE_ARRIVAL := "coreArrival"
const ENEMY_DAMAGE := "damage"
const ENEMY_DAMAGE_NUMBER := "damageNumber"
const ENEMY_TELEPORT := "teleport"

# Batch commands the session sends to the runtime.
const COMMAND_COMBAT_CONFIG := "combatConfig"
const COMMAND_WAVE_START := "waveStart"
const COMMAND_WAVE_CANCEL := "waveCancel"
const COMMAND_CORE_CONFIG := "coreConfig"
const COMMAND_RESET_CORE_CYCLE := "resetCoreCycle"
const COMMAND_EMERGENCY_CHARGE := "emergencyCharge"
const COMMAND_DEFENSE_CONFIG := "defenseConfig"
const COMMAND_DEFENSE_RESTORE := "defenseRestore"
const COMMAND_LAYOUT := "layout"
const COMMAND_SPAWN := "spawn"
const COMMAND_TURRET := "turret"
const COMMAND_RESET_TRAIT_STATE := "resetTraitState"
const COMMAND_REMOVE_TURRET := "removeTurret"
const COMMAND_RIFT_MARK := "riftMark"
const COMMAND_CORE_DAMAGE := "coreDamage"
