local addonPath = (arg[0]:match("^(.*[/\\])") or "") .. "../"

local function setup(settings)
	local state = { now = 100, chats = 0, food = "Increases experience from kills by 5%", classID = 0, subclassID = 5 }
	local methods = {}
	local function object()
		return setmetatable({ scripts = {}, shown = false }, { __index = function(_, key)
			return methods[key] or function() end
		end })
	end
	function methods:SetScript(event, callback) self.scripts[event] = callback end
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
	function methods:GetEffectiveScale() return rawget(self, "scale") or 1 end
	function methods:GetCenter() return rawget(self, "centerX") or 0, rawget(self, "centerY") or 0 end
	function methods:SetPoint(...) self.point = { ... } end
	function CreateFrame(_, name)
		local frame = object()
		if name then _G[name .. "Text"] = object() else state.eventFrame = frame end
		return frame
	end
	UIParent = object()
	SlashCmdList = {}
	UIDropDownMenu_SetSelectedValue = function() end
	UIDropDownMenu_SetWidth = function() end
	UIDropDownMenu_Initialize = function() end
	Settings, InterfaceOptions_AddCategory = nil, nil
	function GetTime() return state.now end
	function GetLocale() return "enUS" end
	function IsResting() return state.resting end
	function UnitAffectingCombat() return state.combat end
	NUM_BAG_SLOTS = 0
	RETRIEVING_ITEM_INFO = "Retrieving item information"
	C_Item = { GetItemInfoInstant = function() return 1, nil, nil, nil, nil, state.classID, state.subclassID end }
	C_Container = {
		GetContainerNumSlots = function() return state.empty and 0 or 1 end,
		GetContainerItemInfo = function() return { itemID = 1 } end,
	}
	C_TooltipInfo = {
		GetBagItem = function()
			if state.partial then return { lines = { { leftText = "Food" } } } end
			return { lines = { { leftText = "Food" }, { leftText = state.food } } }
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

for _, scale in ipairs({ 0.75, 1, 1.5 }) do
	local ns = setup({ screenScale = scale })
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

local ns, state = setup({ screenDuration = 5, repeatReminders = false })
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
print("PASS: addon alert state, finite expiry, suppression, scaled positioning, classification and tooltip retries")