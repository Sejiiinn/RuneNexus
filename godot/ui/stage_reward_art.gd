extends RefCounted
## Reuse existing artwork, including the approved research flask for the extra slot.
const PATHS := {
	"material:ef3a": "ui/hud/turrets_3d/sniper.png",
	"material:eedd": "ui/hud/turrets_3d/lightning.png",
	"material:f499": "stage_rewards/reward_research.png",
}

static func for_reward(original: String) -> String:
	return PATHS.get(original,original)
