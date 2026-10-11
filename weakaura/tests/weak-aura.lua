local imported = assert(load("return " .. io.read("*a")))()
local trigger, customText = imported.trigger, imported.text
local state
local function reset()
	state = { now = 100, slots = 1, bagReads = 0, auraReads = 0, chats = 0, classID = 0, subclassID = 5 }
	state.tooltip = { lines = { { leftText = "Food" }, { leftText = "Increases experience from kills by 5%" } } }
	aura_env = { config = {
		chatAlerts = true, screenAlerts = true, repeatReminders = true,
		reminderMinutes = 1, screenDuration = 0, remindWhenNoFood = true,
		experienceTerms = "experience", killTerms = "kill", increaseTerms = "increas",
	} }
	function IsResting() return state.resting end
	function UnitAffectingCombat() return state.combat end
	function GetTime() return state.now end
	function print() state.chats = state.chats + 1 end
	NUM_BAG_SLOTS = 0
	RETRIEVING_ITEM_INFO = "Retrieving item information"
	C_Item = { GetItemInfoInstant = function() return 1, nil, nil, nil, nil, state.classID, state.subclassID end }
	C_Container = {
		GetContainerNumSlots = function() return state.slots end,
		GetContainerItemInfo = function() return { itemID = 1, itemName = "Food" } end,
	}
	C_TooltipInfo = {
		GetBagItem = function() state.bagReads = state.bagReads + 1; return state.tooltip end,
		GetUnitBuff = function()
			return state.buffTooltip or { lines = { { leftText = "Increases experience from kills by 5%" } } }
		end,
	}
	C_UnitAuras = { GetAuraDataByIndex = function(_, index)
		state.auraReads = state.auraReads + 1
		if state.hasBuff and index == 1 then return { spellId = 1, name = "Well Fed" } end
	end }
end

reset()
state.slots, state.hasBuff = 0, true
assert(trigger("BAG_UPDATE_DELAYED") == false and state.chats == 0 and state.auraReads > 0)
state.hasBuff = false
assert(trigger("UNIT_AURA") == true and state.chats == 1)

for _, tooltip in ipairs({ { lines = {} }, { lines = { { leftText = "Food" } } },
	{ lines = { { leftText = "Food" }, { leftText = "Retrieving item information" } } } }) do
	reset()
	state.tooltip = tooltip
	assert(trigger("BAG_UPDATE_DELAYED") == false and state.chats == 0)
	state.tooltip = { lines = { { leftText = "Food" }, { leftText = "Increases experience from kills by 5%" } } }
	assert(trigger("GET_ITEM_INFO_RECEIVED") == true and state.chats == 1)
end

reset()
state.slots = 100
assert(trigger("PLAYER_ENTERING_WORLD") == true)
for tick = 1, 59 do
	state.now = 100 + tick / 60
	assert(trigger("FRAME_UPDATE") == true)
end
assert(state.bagReads == 100)
state.now = 101
assert(trigger("FRAME_UPDATE") == true and state.bagReads == 200)
state.hasBuff = true
assert(trigger("UNIT_AURA") == false and state.bagReads == 300)

reset()
state.tooltip.lines[2].leftText = "Restores 50% health and increases experience from kills by 5%"
assert(trigger("BAG_UPDATE_DELAYED") == true and aura_env.fefState.reminderPercent == 5)
reset()
state.tooltip.lines[2].leftText = "Increases experience from kills by 2.5%"
aura_env.config.remindWhenNoFood = false
assert(trigger("BAG_UPDATE_DELAYED") == false and state.chats == 0)

for _, suppression in ipairs({ "combat", "resting" }) do
	reset()
	aura_env.config.repeatReminders = false
	assert(trigger("PLAYER_ENTERING_WORLD") == true and state.chats == 1)
	state[suppression] = true
	assert(trigger("FRAME_UPDATE") == false)
	state[suppression] = false
	assert(trigger("PLAYER_REGEN_ENABLED") == true and state.chats == 1)
end

reset()
aura_env.config.repeatReminders, aura_env.config.screenDuration = false, 5
assert(trigger("PLAYER_ENTERING_WORLD") == true)
state.now, state.resting = 102, true
assert(trigger("PLAYER_UPDATE_RESTING") == false)
state.resting = false
assert(trigger("PLAYER_UPDATE_RESTING") == true and state.chats == 1)
state.now = 106
assert(trigger("FRAME_UPDATE") == false and state.chats == 1)

reset()
state.hasBuff = true
state.buffTooltip = { lines = { { leftText = "Well Fed" } } }
assert(trigger("UNIT_AURA") == false and state.chats == 0)
state.buffTooltip = nil
assert(trigger("UNIT_AURA") == false and state.chats == 0)

reset()
state.classID, state.subclassID = 4, 1
aura_env.config.remindWhenNoFood = false
assert(trigger("BAG_UPDATE_DELAYED") == false and state.bagReads == 0)
reset()
state.classID, state.subclassID = nil, nil
assert(trigger("BAG_UPDATE_DELAYED") == false and state.chats == 0)

reset()
local before = state.bagReads
assert(trigger("OPTIONS") == false and state.bagReads == before and state.chats == 0)
local region = { point = { 300, 200 } }
function region:SetScale() end
function region:ClearAllPoints() error("Saved position was cleared") end
function region:SetPoint() error("Saved position was overwritten") end
aura_env.region = region
assert(type(customText()) == "string")
assert(region.point[1] == 300 and region.point[2] == 200)
io.write("PASS: WeakAura throttling, restock suppression, tooltip retries, percentage parsing, expiry, classification and positioning\n")