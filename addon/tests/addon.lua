local addonPath = (arg[0]:match("^(.*[/\\])") or "") .. "../"

local function setup(settings)
	local state = {
		now = 100,
		level = 59,
		chats = 0,
		food = "Increases experience from kills by 5%",
		classID = 0,
		subclassID = 5,
		items = { { bagID = 0, slot = 1, itemID = 1, stackCount = 1 } },
		itemTypes = {},
		itemNames = {},
		foodsByItem = {},
		statLinesByItem = {},
		usedItems = {},
		menuEntries = {},
		dropdownAnchor = nil,
	}
	local methods = {}
	local function object()
		return setmetatable({ scripts = {}, shown = false }, { __index = function(_, key)
			return methods[key] or function() end
		end })
	end
	function methods:SetScript(event, callback) self.scripts[event] = callback end
	function methods:SetSize(width, height) self.size = { width, height } end
	function methods:CreateFontString() return object() end
	function methods:CreateTexture() return object() end
	function methods:SetText(text) self.textValue = text end
	function methods:GetText() return rawget(self, "textValue") or "" end
	function methods:SetChecked(value) self.checked = value end
	function methods:GetChecked() return self.checked end
	function methods:SetValue(value)
		if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
	end
	function methods:Show() self.shown = true end
	function methods:Hide() self.shown = false end
	function methods:IsShown() return self.shown end
	function methods:SetScale(scale) self.scale = scale end
	function methods:SetFrameLevel(level) self.frameLevel = level end
	function methods:GetFrameLevel() return rawget(self, "frameLevel") or 0 end
	function methods:GetEffectiveScale() return rawget(self, "scale") or 1 end
	function methods:GetCenter() return rawget(self, "centerX") or 0, rawget(self, "centerY") or 0 end
	function methods:SetPoint(...) self.point = { ... } end
	function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
	function methods:RegisterForClicks(...) self.registeredClicks = { ... } end
	function methods:SetAttribute(key, value)
		local attributes = rawget(self, "attributes") or {}
		rawset(self, "attributes", attributes)
		attributes[key] = value
	end
	function methods:GetAttribute(key)
		local attributes = rawget(self, "attributes")
		return attributes and attributes[key]
	end
	function CreateFrame(_, name, parent, template)
		local frame = object()
		frame.template = template
		if name then _G[name .. "Text"] = object() else state.eventFrame = frame end
		return frame
	end
	UIParent = object()
	SlashCmdList = {}
	UIDropDownMenu_SetSelectedValue = function() end
	UIDropDownMenu_SetWidth = function() end
	UIDropDownMenu_Initialize = function(dropdown, initialize) dropdown.initialize = initialize end
	UIDropDownMenu_CreateInfo = function() return {} end
	UIDropDownMenu_AddButton = function(info) table.insert(state.menuEntries, info) end
	ToggleDropDownMenu = function(_, _, dropdown, anchorName)
		state.dropdownAnchor = anchorName
		state.menuEntries = {}
		dropdown.initialize(dropdown, 1)
	end
	Settings, InterfaceOptions_AddCategory = nil, nil
	function GetTime() return state.now end
	function UnitLevel(unit)
		assert(unit == "player")
		return state.level
	end
	function GetLocale() return "enUS" end
	function IsResting() return state.resting end
	function UnitAffectingCombat() return state.combat end
	function GetItemInfo(itemID) return state.itemNames[itemID] end
	STAT_STRENGTH, STAT_AGILITY, STAT_INTELLECT = "Strength", "Agility", "Intellect"
	STAT_STAMINA, STAT_SPIRIT = "Stamina", "Spirit"
	NUM_BAG_SLOTS = 0
	RETRIEVING_ITEM_INFO = "Retrieving item information"
	C_Item = { GetItemInfoInstant = function(itemID)
		local itemType = state.itemTypes[itemID]
		return itemID, nil, nil, nil, nil,
			itemType and itemType[1] or state.classID,
			itemType and itemType[2] or state.subclassID
	end }
	C_Container = {
		GetContainerNumSlots = function(bagID)
			if state.empty then return 0 end
			local slotCount = 0
			for _, item in ipairs(state.items) do
				if item.bagID == bagID then slotCount = math.max(slotCount, item.slot) end
			end
			return slotCount
		end,
		GetContainerItemInfo = function(bagID, slot)
			for _, item in ipairs(state.items) do
				if item.bagID == bagID and item.slot == slot then
					return {
						itemID = item.itemID,
						itemName = state.itemNames[item.itemID],
						stackCount = item.stackCount,
					}
				end
			end
		end,
		UseContainerItem = function(bagID, slot)
			for _, item in ipairs(state.items) do
				if item.bagID == bagID and item.slot == slot then
					table.insert(state.usedItems, { bagID = bagID, slot = slot, itemID = item.itemID })
					return
				end
			end
		end,
	}
	C_TooltipInfo = {
		GetBagItem = function(bagID, slot)
			if state.partial then return { lines = { { leftText = "Food" } } } end
			local itemID = 1
			for _, item in ipairs(state.items) do
				if item.bagID == bagID and item.slot == slot then itemID = item.itemID end
			end
			local lines = { { leftText = "Food" }, { leftText = state.foodsByItem[itemID] or state.food } }
			for _, text in ipairs(state.statLinesByItem[itemID] or {}) do
				table.insert(lines, { leftText = text })
			end
			return { lines = lines }
		end,
		GetUnitBuff = function() return { lines = { { leftText = state.buff } } } end,
	}
	C_UnitAuras = { GetAuraDataByIndex = function(_, index)
		if index == 1 and state.buff then return { spellId = 1, name = "Well Fed" } end
	end }
	DEFAULT_CHAT_FRAME = { AddMessage = function() state.chats = state.chats + 1 end }
	ForeverSnackTrackDB, ForeverExpFoodDB = settings or {}, nil
	local ns = {}
	assert(loadfile(addonPath .. "Locale.lua"))()
	for _, path in ipairs({ "ScreenAlert.lua", "Core.lua", "Options.lua" }) do
		assert(loadfile(addonPath .. path))("ForeverSnackTrack", ns)
	end
	function state:event(event, arg)
		self.eventFrame.scripts.OnEvent(self.eventFrame, event, arg)
	end
	state:event("ADDON_LOADED", "ForeverSnackTrack")
	return ns, state
end

for _, repeatReminders in ipairs({ false, true }) do
	local ns, state = setup({ repeatReminders = repeatReminders })
	ns.Scan()
	local checkbox = ns.optionsPanel.screenCheckbox
	checkbox:SetChecked(false)
	checkbox.scripts.OnClick(checkbox)
	checkbox:SetChecked(true)
	checkbox.scripts.OnClick(checkbox)
	assert(ns.alertFrame:IsShown() and state.chats == 1)
	ns.optionsPanel.previewButton.scripts.OnClick()
	ns.Scan()
	assert(ns.alertFrame.isPreview and ns.alertFrame:IsShown())
	assert(not ns.alertFrame.eatButton:IsShown() and not ns.alertFrame.eatDropdownButton:IsShown())
	ns.optionsPanel.scripts.OnHide()
	assert(ns.alertFrame:IsShown() and not ns.alertFrame.isPreview and state.chats == 1)
	state.combat = true
	state:event("PLAYER_REGEN_DISABLED")
	assert(not ns.alertFrame:IsShown())
	state.combat = false
	state:event("PLAYER_REGEN_ENABLED")
	assert(ns.alertFrame:IsShown() and state.chats == 1)
	state.resting = true
	state:event("PLAYER_UPDATE_RESTING")
	assert(not ns.alertFrame:IsShown())
	state.resting = false
	state:event("PLAYER_UPDATE_RESTING")
	assert(ns.alertFrame:IsShown() and state.chats == 1)
	ns.SnoozeReminders()
	state:event("PLAYER_REGEN_ENABLED")
	assert(not ns.alertFrame:IsShown())
	state.now = 160
	ns.Scan()
	assert(ns.alertFrame:IsShown())
	ns.DismissReminder()
	state:event("PLAYER_REGEN_ENABLED")
	state:event("PLAYER_UPDATE_RESTING")
	assert(not ns.alertFrame:IsShown())
end

local capNs, capState = setup()
capNs.Scan()
assert(capState.chats == 1 and capNs.alertFrame:IsShown())
capState.level = 60
capState:event("PLAYER_LEVEL_UP")
assert(capState.chats == 1 and not capNs.alertFrame:IsShown())
capNs.optionsPanel.previewButton.scripts.OnClick()
capNs.Scan()
assert(capNs.alertFrame.isPreview and capNs.alertFrame:IsShown())
capState.level = nil
local unknownLevelNs, unknownLevelState = setup()
unknownLevelState.level = nil
unknownLevelNs.Scan()
assert(unknownLevelState.chats == 1 and unknownLevelNs.alertFrame:IsShown())

local eatNs, eatState = setup()
eatState.items = {
	{ bagID = 0, slot = 1, itemID = 1, stackCount = 2 },
	{ bagID = 0, slot = 2, itemID = 2, stackCount = 1 },
	{ bagID = 0, slot = 3, itemID = 3, stackCount = 1 },
}
eatState.itemNames = { [1] = "Roasted Fish", [2] = "Spiced Meat", [3] = "XP Trinket" }
eatState.foodsByItem = {
	[1] = "Increases experience from kills by 5%",
	[2] = "Increases experience from kills by 10%",
	[3] = "Increases experience from kills by 50%",
}
eatState.statLinesByItem = {
	[1] = {
		"Increases your Agility by 12",
		"Increases your Strength by 8",
		"+3 Stamina",
		"Increases your Spirit by 2",
		"Use: Restores 59 health and 145 mana over 18 sec and grants 2 Attack Power for 15 min",
		"+1 Spell Damage",
		"+2 Healing Power",
		"+150 Armor",
		"+1% Critical Strike Chance",
		"+15% Movement Speed",
		"+3 Fishing",
		"+15 Herbalism",
		"Requires level 30",
	},
	[2] = { "+5 Intellect", "Lasts 1 hour" },
	[3] = { "Increases your Strength by 99" },
}
eatState.itemTypes[3] = { 4, 1 }
eatNs.Scan()
assert(eatNs.alertFrame.eatButton:IsShown() and eatNs.alertFrame.eatDropdownButton:IsShown())
assert(eatNs.alertFrame.eatButton.template == "UIPanelButtonTemplate,InsecureActionButtonTemplate")
assert(eatNs.alertFrame.eatButton.size[1] == 96 and eatNs.alertFrame.eatButton.size[2] == 24)
assert(eatNs.alertFrame.eatButton.mouseEnabled == true)
assert(eatNs.alertFrame.eatButton.registeredClicks[1] == "LeftButtonUp")
assert(eatNs.alertFrame.eatButton:GetAttribute("useOnKeyDown") == false)
assert(eatNs.alertFrame.eatButton:GetAttribute("type1") == "macro")
assert(eatNs.alertFrame.eatButton:GetAttribute("macrotext1") == "/use Spiced Meat")
assert(#eatState.usedItems == 0)
eatNs.alertFrame.eatDropdownButton.scripts.OnClick()
assert(eatState.dropdownAnchor == "ForeverSnackTrackAlertEatDropdownButton")
assert(#eatState.menuEntries == 2)
assert(eatState.menuEntries[1].text == "Spiced Meat (10%) - +5 Int")
assert(eatState.menuEntries[2].text == "Roasted Fish (5%) x2 - +8 Str, +12 Agi, +3 Sta, +2 Spi, +2 AP, +1 Spell, +2 Heal, +150 Armor, +1% Crit, +15% Move, +3 Fishing, +15 Herb")
eatState.items = {
	{ bagID = 0, slot = 2, itemID = 2, stackCount = 1 },
	{ bagID = 0, slot = 3, itemID = 3, stackCount = 1 },
	{ bagID = 0, slot = 4, itemID = 1, stackCount = 2 },
}
eatState.menuEntries[2].func()
assert(eatNs.alertFrame.eatButton:GetAttribute("macrotext1") == "/use Roasted Fish")
assert(eatNs.alertFrame.selectedFoodID == 1 and #eatState.usedItems == 0)
eatState.items = { { bagID = 0, slot = 2, itemID = 2, stackCount = 1 } }
eatState.menuEntries[2].func()
assert(eatNs.alertFrame.eatButton:GetAttribute("macrotext1") == "/use Roasted Fish"
	and #eatState.usedItems == 0)

local debugNs, debugState = setup()
debugState.statLinesByItem[1] = { "Increases your Strength by 6" }
debugNs.DebugStatus()
local debugFoods = debugNs.GetAvailableFoods()
assert(#debugFoods == 1 and debugFoods[1].stats[1] == "+6 Str")

local ns
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
	ns = setup({ screenScale = scale })
	ns.Scan()
	UIParent.centerX, UIParent.centerY = 960, 540
	ns.alertFrame.centerX, ns.alertFrame.centerY = 1160 / scale, 640 / scale
	ns.alertFrame.scripts.OnDragStop(ns.alertFrame)
	assert(math.abs(ns.db.alertOffsetX - 200) < 0.001)
	assert(math.abs(ns.db.alertOffsetY - 100) < 0.001)
	ns.db.screenScale = 1.25
	ns.RefreshScreenAlert()
	assert(ns.alertFrame.point[4] == 160 and ns.alertFrame.point[5] == 80)
end

local state
ns, state = setup({ screenDuration = 5, repeatReminders = false })
ns.Scan()
state.now = 102
ns.HideScreenAlert()
ns.Scan()
assert(ns.alertFrame.remaining == 3 and state.chats == 1)
state.now = 106
ns.alertFrame.scripts.OnUpdate(ns.alertFrame, 4)
ns.Scan()
assert(not ns.alertFrame:IsShown() and state.chats == 1)

ns, state = setup()
state.partial = true
ns.Scan()
assert(state.chats == 0)
state.partial = false
state:event("BAG_UPDATE_DELAYED")
assert(state.chats == 1)
state.buff = "Well Fed"
state:event("UNIT_AURA", "player")
state.buff = "Increases experience from kills by 5%"
state:event("UNIT_AURA", "player")
assert(not ns.alertFrame:IsShown())

for _, classification in ipairs({ { 4, 1 }, { 0, 1 } }) do
	ns, state = setup()
	state.classID, state.subclassID = classification[1], classification[2]
	ns.Scan()
	assert(state.chats == 0)
end

ns, state = setup({ remindWhenNoFood = true })
state.food = RETRIEVING_ITEM_INFO
ns.Scan()
assert(state.chats == 0)
state.classID, state.subclassID = nil, nil
ns.Scan()
assert(state.chats == 0)
state.classID, state.subclassID = 0, 5
state.food = "Increases experience from kills by 5%"
state:event("GET_ITEM_INFO_RECEIVED", 1)
assert(state.chats == 1)
state.empty, state.buff = true, "Increases experience from kills by 5%"
state:event("BAG_UPDATE_DELAYED")
assert(not ns.alertFrame:IsShown())
ns.optionsPanel.previewButton.scripts.OnClick()
ns.Scan()
assert(ns.alertFrame:IsShown() and ns.alertFrame.isPreview)
ns.optionsPanel.scripts.OnHide()
assert(not ns.alertFrame:IsShown())

ns, state = setup({ remindWhenNoFood = true })
state.empty = true
ns.Scan()
assert(ns.alertFrame:IsShown())
assert(not ns.alertFrame.eatButton:IsShown() and not ns.alertFrame.eatDropdownButton:IsShown())
print("PASS: addon alert state, food actions, finite expiry, suppression, scaled positioning, classification and tooltip retries")