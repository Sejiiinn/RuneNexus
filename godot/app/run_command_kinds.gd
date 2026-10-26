extends RefCounted
## Player run-command kinds sent by the HUD and debug controls to RunCommands.
## Tests and fixtures send these exact strings; never rename.

const BUILD := "build"
const BUILD_SUPPORT_CORE := "buildSupportCore"
const SELL_SUPPORT_CORE := "sellSupportCore"
const RUN_UPGRADE := "runUpgrade"
const LEVEL := "level"
const LINK := "link"
const SELL := "sell"
const EQUIP_GEM := "equipGem"
const REMOVE_GEM := "removeGem"
const PRIMARY_TRAIT := "primaryTrait"
const SECONDARY_TRAIT := "secondaryTrait"
const TARGET_PRIORITY := "targetPriority"
const CHOOSE_REWARD_GEM := "chooseRewardGem"
const CHOOSE_REWARD_SHARDS := "chooseRewardShards"
const CHOOSE_REWARD_GEM_EQUIP := "chooseRewardGemEquip"
const PURCHASE_GEM_CHOICE := "purchaseGemChoice"
const REROLL_REWARD_FREE := "rerollRewardFree"
const REWARD_CHOICES := [CHOOSE_REWARD_GEM, CHOOSE_REWARD_SHARDS, CHOOSE_REWARD_GEM_EQUIP]
