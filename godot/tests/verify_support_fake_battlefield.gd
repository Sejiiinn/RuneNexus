extends Node3D
## Inert stand-in for main.gd's public battlefield API, for session/app checks
## that do not need rendering. Subclasses override only what they observe.
const Runtime = preload("res://combat/native_combat_runtime.gd")
var combat_runtime = Runtime.new()
var combat_base_frame: Dictionary = {}
var session_controller: Node
var options := {"camera": "angled", "zoom": 1.0}

func apply_frame(_frame: Dictionary) -> void: pass
func request_native_frame() -> void:
	if not combat_base_frame.is_empty(): apply_frame(combat_base_frame)
func apply_options() -> void: pass
func confirm_turret_placement(_id: int, _type: String, _x: int, _y: int) -> void: pass
func cancel_turret_placement(_id: int) -> void: pass
func play_gem_equip_burst(_id: int, _gem: String) -> void: pass
func begin_deferred_battle_presentation() -> void: pass
func set_battle_visible(_active: bool) -> void: pass
func prepare_stage_resources(_catalog, _index: int, _derived: Dictionary, _restored_state: Dictionary = {}) -> bool: return true
func request_stage_preparation_cancel() -> void: pass
func cancel_stage_preparation() -> void: pass
func realize_battle_presentation() -> bool: return true
func battle_preparation_pending() -> bool: return false
