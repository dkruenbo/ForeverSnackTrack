local addonName, ns = ...

local sleepingBagItemID = 211527
local sleepingBagUnrollSpellID = 429961
local wellRestedSpellID = 429959
local lastResting
local sleepingBagRestActive = false
local sleepingBagRestInterrupted = false
local sleepingBagRestPosition
local placedBagPosition

local function playerPosition()
	if type(UnitPosition) ~= "function" then
		return nil
	end
	local success, x, y, _, mapID = pcall(UnitPosition, "player")
	if not success or type(x) ~= "number" or type(y) ~= "number" or type(mapID) ~= "number" then
		return nil
	end
	return { x = x, y = y, mapID = mapID }
end

local function saveRestPosition()
	sleepingBagRestPosition = playerPosition()
	sleepingBagRestInterrupted = false
	sleepingBagRestActive = true
end

function ns.RecordSleepingBagPlacement()
	local position = playerPosition()
	local resting = IsResting and IsResting() or false
	placedBagPosition = position and {
		x = position.x,
		y = position.y,
		mapID = position.mapID,
		placedAt = GetTime(),
		restingAtPlacement = resting,
	} or nil
	ns.DebugPrint(placedBagPosition and "Sleeping Bag placement location recorded."
		or "Sleeping Bag cast seen, but UnitPosition is unavailable; using stack tracking.")
end

local function isAtRestPosition(position)
	if not position or not sleepingBagRestPosition or position.mapID ~= sleepingBagRestPosition.mapID then
		return false
	end
	local deltaX = position.x - sleepingBagRestPosition.x
	local deltaY = position.y - sleepingBagRestPosition.y
	return deltaX * deltaX + deltaY * deltaY <= 64
end

local function isAtPlacedBag(position)
	if not position or not placedBagPosition or placedBagPosition.restingAtPlacement
		or GetTime() - placedBagPosition.placedAt > 20 * 60
		or position.mapID ~= placedBagPosition.mapID then
		return false
	end
	local deltaX = position.x - placedBagPosition.x
	local deltaY = position.y - placedBagPosition.y
	return deltaX * deltaX + deltaY * deltaY <= 144
end

function ns.GetSleepingBagIcon()
	if C_Item and C_Item.GetItemIconByID then
		local icon = C_Item.GetItemIconByID(sleepingBagItemID)
		if icon then
			return icon
		end
	end
	if GetItemIcon then
		local icon = GetItemIcon(sleepingBagItemID)
		if icon then
			return icon
		end
	end
	local _, _, _, _, _, _, _, _, _, icon = GetItemInfo and GetItemInfo(sleepingBagItemID)
	return icon or "Interface\\Icons\\INV_Misc_Bag_10"
end

local function findSleepingBag()
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
		return nil, nil, nil
	end
	for bagID = 0, NUM_BAG_SLOTS or 0 do
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slot = 1, slotCount do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
			if itemInfo and itemInfo.itemID == sleepingBagItemID then
				return bagID, slot, itemInfo
			end
		end
	end
	return nil, nil, nil
end

local function getSleepingBagCooldown(bagID, slot)
	local itemCooldownAPI = C_Item and C_Item.GetItemCooldown
	if type(itemCooldownAPI) == "function" then
		local success, startTime, duration, enabled = pcall(itemCooldownAPI, sleepingBagItemID)
		if not success or type(startTime) ~= "number" or type(duration) ~= "number" then
			return nil
		end
		if enabled == false or enabled == 0 or duration <= 0 then
			return true, 0
		end
		local remaining = math.max(0, startTime + duration - GetTime())
		return remaining <= 0, remaining
	end

	local containerCooldownAPI = C_Container and C_Container.GetContainerItemCooldown or GetContainerItemCooldown
	if type(containerCooldownAPI) ~= "function" then
		return nil
	end
	local success, startTime, duration, enabled = pcall(containerCooldownAPI, bagID, slot)
	if not success or type(startTime) ~= "number" or type(duration) ~= "number" then
		return nil
	end
	if enabled == false or enabled == 0 or duration <= 0 then
		return true, 0
	end
	local remaining = math.max(0, startTime + duration - GetTime())
	return remaining <= 0, remaining
end

local function getWellRestedAura()
	local getAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if type(getAuraBySpellID) ~= "function" then
		return nil, false
	end
	local success, aura = pcall(function()
		local auraData = getAuraBySpellID(wellRestedSpellID)
		if type(issecretvalue) == "function" and issecretvalue(auraData) then
			error("Well-Rested aura data is restricted")
		end
		if not auraData then
			return nil
		end
		if type(issecretvalue) == "function" then
			for _, field in ipairs({ "spellId", "name", "applications", "charges", "duration", "expirationTime" }) do
				if issecretvalue(auraData[field]) then
					error("Well-Rested aura field is restricted")
				end
			end
		end
		return {
			spellId = auraData.spellId,
			name = auraData.name,
			applications = auraData.applications,
			charges = auraData.charges,
			duration = auraData.duration,
			expirationTime = auraData.expirationTime,
		}
	end)
	if not success then
		return nil, false
	end
	return aura, true
end

function ns.GetSleepingBagStatus()
	local bagID, slot, itemInfo = findSleepingBag()
	local cooldownReady, cooldownRemaining = getSleepingBagCooldown(bagID, slot)
	local aura, auraDataComplete = getWellRestedAura()
	local stacks = aura and (aura.applications or aura.charges) or 0
	if type(stacks) ~= "number" then
		stacks = nil
	end
	local resting = IsResting and IsResting() or false
	local indoors = IsIndoors and IsIndoors() or false
	local sitting = UnitIsSitting and UnitIsSitting("player") or false
	local position = playerPosition()
	local becameResting = resting and not lastResting
	lastResting = resting
	if becameResting and isAtPlacedBag(position)
		and not (UnitAffectingCombat and UnitAffectingCombat("player"))
		and not (ns.IsPlayerMoving and ns.IsPlayerMoving()) then
		saveRestPosition()
	end
	if not sleepingBagRestActive and sleepingBagRestInterrupted and resting
		and isAtRestPosition(position) then
		sleepingBagRestActive = true
		sleepingBagRestInterrupted = false
	end
	return {
		complete = cooldownReady ~= nil and auraDataComplete and type(stacks) == "number",
		auraComplete = auraDataComplete and type(stacks) == "number",
		auraPresent = aura ~= nil,
		bagPresent = bagID ~= nil,
		itemName = itemInfo and (itemInfo.itemName
			or (GetItemInfo and GetItemInfo(sleepingBagItemID))) or nil,
		cooldownReady = cooldownReady,
		cooldownRemaining = cooldownRemaining,
		stacks = stacks,
		expirationTime = aura and aura.expirationTime,
		auraDuration = aura and aura.duration,
		resting = resting,
		indoors = indoors,
		sitting = sitting,
		restSessionActive = sleepingBagRestActive,
		atPreviousRestPosition = isAtRestPosition(position),
		positionAPIAvailable = type(UnitPosition) == "function",
	}
end

function ns.GetSleepingBagReminder(status, now)
	if not ns.db or not ns.db.trackSleepingBagBuff or not status or not status.complete
		or not status.bagPresent or not status.cooldownReady then
		return nil
	end
	if status.stacks < 3 then
		return "build-stacks"
	end
	local expirationTime = status.expirationTime
	if type(expirationTime) == "number" and expirationTime > now and expirationTime - now <= 10 * 60 then
		return "refresh"
	end
	return nil
end

local timelineFrame
local timelineState

local function formatTimelineTime(seconds)
	local totalSeconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(totalSeconds / 60), totalSeconds % 60)
end

local function renderTimeline()
	if not timelineFrame or not timelineFrame:IsShown() or not timelineState then
		return
	end
	local elapsed = math.max(0, GetTime() - timelineState.startedAt)
	local stacks = timelineState.stacks
	local progress
	local remaining
	local text
	if stacks < 3 then
		local totalDuration = (3 - stacks) * 60
		progress = math.min(3, stacks + elapsed / 60)
		remaining = math.max(0, totalDuration - elapsed)
		local nextStack = math.min(60, remaining)
		text = string.format("Well-Rested %d/3  |  Next stack %s  |  3/3 in %s",
			stacks, formatTimelineTime(nextStack), formatTimelineTime(remaining))
	else
		remaining = math.max(0, 60 - elapsed)
		progress = 3
		text = string.format("Well-Rested 3/3  |  Refresh in %s", formatTimelineTime(remaining))
	end
	timelineFrame.progress:SetValue(progress)
	timelineFrame.label:SetText(text)
end

local function createTimelineFrame()
	local frame = CreateFrame("Frame", "ForeverSnackTrackSleepingBagTimeline", UIParent, "BackdropTemplate")
	frame:SetSize(440, 62)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.04, 0.05, 0.07, 0.88)
	frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.label:SetPoint("TOP", frame, "TOP", 0, -7)
	frame.label:SetWidth(420)
	frame.label:SetJustifyH("CENTER")
	frame.progress = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
	frame.progress:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -28)
	frame.progress:SetSize(404, 12)
	frame.progress:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	frame.progress:SetStatusBarColor(0.12, 0.75, 0.62, 1)
	frame.progress:SetMinMaxValues(0, 3)
	frame.progress:SetValue(0)
	frame.progress:SetBackdrop({ bgFile = "Interface/TargetingFrame/UI-StatusBar" })
	frame.progress:SetBackdropColor(0.08, 0.1, 0.12, 1)
	frame.milestones = {}
	for milestone = 1, 3 do
		local marker = frame.progress:CreateTexture(nil, "OVERLAY")
		marker:SetColorTexture(1, 0.85, 0.2, 1)
		marker:SetSize(2, 16)
		marker:SetPoint("CENTER", frame.progress, "LEFT", frame.progress:GetWidth() * milestone / 3, 0)
		frame.milestones[milestone] = marker
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOP", marker, "BOTTOM", 0, -1)
		label:SetText(tostring(milestone))
		frame.milestones[milestone] = { marker = marker, label = label }
	end
	frame:SetPoint("TOP", UIParent, "TOP", 0, -145)
	frame:SetScript("OnUpdate", renderTimeline)
	frame:Hide()
	ns.sleepingBagTimeline = frame
	return frame
end

function ns.UpdateSleepingBagTimeline(status, enabled)
	if not enabled or not status or not status.auraComplete or not status.restSessionActive or not status.resting
		or (UnitAffectingCombat and UnitAffectingCombat("player"))
		or (IsFlying and IsFlying())
		or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
		if timelineFrame then
			timelineFrame:Hide()
		end
		timelineState = nil
		return
	end
	if not timelineFrame then
		timelineFrame = createTimelineFrame()
	end
	if not timelineState or timelineState.stacks ~= status.stacks
		or timelineState.expirationTime ~= status.expirationTime then
		timelineState = {
			stacks = status.stacks,
			expirationTime = status.expirationTime,
			startedAt = GetTime(),
		}
	end
	timelineFrame:Show()
	renderTimeline()
end

function ns.InterruptSleepingBagRest()
	if sleepingBagRestActive and sleepingBagRestPosition then
		sleepingBagRestInterrupted = true
	end
	sleepingBagRestActive = false
	ns.HideSleepingBagTimeline()
end

function ns.ResetSleepingBagTrackingState()
	lastResting = nil
	sleepingBagRestActive = false
	sleepingBagRestInterrupted = false
	sleepingBagRestPosition = nil
	placedBagPosition = nil
	ns.HideSleepingBagTimeline()
end

function ns.ToggleSleepingBagTimeline()
	if sleepingBagRestActive then
		sleepingBagRestActive = false
		sleepingBagRestInterrupted = false
		sleepingBagRestPosition = nil
		ns.HideSleepingBagTimeline()
		ns.DebugPrint("Sleeping Bag timeline stopped.")
		return
	end
	if not ns.db or not ns.db.trackSleepingBagBuff then
		ns.DebugPrint("Enable Sleeping Bag tracking in options before starting the timeline.")
		return
	end
	if not IsResting or not IsResting() then
		ns.DebugPrint("Start the timeline while resting in a Sleeping Bag.")
		return
	end
	if (UnitAffectingCombat and UnitAffectingCombat("player"))
		or (IsFlying and IsFlying())
		or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
		ns.DebugPrint("Leave combat, flight, or death before starting the Sleeping Bag timeline.")
		return
	end
	local status = ns.GetSleepingBagStatus()
	if not status or not status.auraComplete then
		ns.DebugPrint("Sleeping Bag aura data is unavailable; timeline was not started.")
		return
	end
	sleepingBagRestActive = true
	sleepingBagRestInterrupted = false
	sleepingBagRestPosition = playerPosition()
	status.restSessionActive = true
	local enabled = ns.db.screenAlerts
		and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
		and not (IsFlying and IsFlying())
		and not (UnitAffectingCombat and UnitAffectingCombat("player"))
	ns.UpdateSleepingBagTimeline(status, enabled)
	ns.DebugPrint(string.format("Sleeping Bag timeline started at %d/3.", status.stacks))
end

function ns.HideSleepingBagTimeline()
	if timelineFrame then
		timelineFrame:Hide()
	end
	timelineState = nil
end

function ns.DebugSleepingBagStatus()
	if not ns.db then
		ns.DebugPrint("Settings have not been initialized.")
		return
	end
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
		ns.DebugPrint("Bag API is unavailable.")
		return
	end
	local status = ns.GetSleepingBagStatus()
	local playerLevel = UnitLevel and UnitLevel("player")
	local timelineEnabled = ns.db.trackSleepingBagBuff and ns.db.screenAlerts
		and not (type(playerLevel) == "number" and playerLevel >= 60)
	if status and status.complete then
		ns.DebugPrint(string.format("Sleeping Bag 211527: tracking=%s screenAlerts=%s timelineEnabled=%s level=%s; bag=%s; cooldown %s%s; Well-Rested 429959 stacks=%d; expiry=%s; IsResting=%s indoors=%s sitting=%s session=%s nearPreviousBag=%s UnitPositionAPI=%s.",
			tostring(ns.db.trackSleepingBagBuff), tostring(ns.db.screenAlerts), tostring(timelineEnabled),
			tostring(playerLevel or "unknown"),
			tostring(status.bagPresent),
			status.cooldownReady and "ready" or "remaining ",
			status.cooldownReady and "" or ns.FormatDuration(status.cooldownRemaining or 0),
			status.stacks,
			type(status.expirationTime) == "number" and string.format("%d sec", math.max(0, status.expirationTime - GetTime()))
				or "unavailable",
			tostring(status.resting), tostring(status.indoors), tostring(status.sitting),
			tostring(status.restSessionActive), tostring(status.atPreviousRestPosition),
			tostring(status.positionAPIAvailable)))
		if not status.auraPresent then
			ns.DebugPrint("No Well-Rested aura yet; while in a party bag, use /fst bag to start the timeline manually.")
		end
	else
		ns.DebugPrint(string.format("Sleeping Bag status unresolved; tracking=%s screenAlerts=%s timelineEnabled=%s level=%s.",
			tostring(ns.db.trackSleepingBagBuff), tostring(ns.db.screenAlerts), tostring(timelineEnabled),
			tostring(playerLevel or "unknown")))
	end
	local itemCooldownAPI = C_Item and C_Item.GetItemCooldown
	local containerCooldownAPI = C_Container.GetContainerItemCooldown or GetContainerItemCooldown
	ns.DebugPrint(string.format("Sleeping-bag cooldown APIs: item=%s, container=%s.",
		tostring(type(itemCooldownAPI) == "function"), tostring(type(containerCooldownAPI) == "function")))
	local candidateCount = 0
	for bagID = 0, NUM_BAG_SLOTS or 0 do
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slot = 1, slotCount do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
			local itemID = itemInfo and itemInfo.itemID
			if itemID == sleepingBagItemID then
				local itemName = itemInfo.itemName or (GetItemInfo and GetItemInfo(itemID)) or ""
				candidateCount = candidateCount + 1
				ns.DebugPrint(string.format("Bag: %s (item %d; bag %d, slot %d).",
					itemName ~= "" and itemName or "unknown name", itemID, bagID, slot))
				if type(itemCooldownAPI) == "function" then
					local success, startTime, duration, enabled, modRate = pcall(itemCooldownAPI, itemID)
					if success then
						ns.DebugPrint(string.format("C_Item.GetItemCooldown: start=%s duration=%s enabled=%s rate=%s.",
							tostring(startTime), tostring(duration), tostring(enabled), tostring(modRate)))
					else
						ns.DebugPrint("C_Item.GetItemCooldown call failed for this item.")
					end
				end
				if type(containerCooldownAPI) == "function" then
					local success, startTime, duration, enabled = pcall(containerCooldownAPI, bagID, slot)
					if success then
						ns.DebugPrint(string.format("Container cooldown: start=%s duration=%s enabled=%s.",
							tostring(startTime), tostring(duration), tostring(enabled)))
					else
						ns.DebugPrint("Container cooldown call failed for this slot.")
					end
				end
			end
		end
	end
	if candidateCount == 0 then
		ns.DebugPrint("No bag item matched sleep/rest/bag terms; include the item name and tooltip if the bag is present.")
	end
	if not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function" then
		ns.DebugPrint("Player aura-by-spell API is unavailable.")
		return
	end
	local aura, auraDataComplete = getWellRestedAura()
	if not auraDataComplete then
		ns.DebugPrint("Well-Rested aura data is unavailable or restricted.")
	elseif aura then
		local expirationText = type(aura.expirationTime) == "number" and aura.expirationTime > 0
			and string.format("expires in %d sec", math.max(0, math.ceil(aura.expirationTime - GetTime())))
			or "expiry unavailable"
		ns.DebugPrint(string.format("Well-Rested aura: %s (spell %s), stacks=%s, duration=%s, %s.",
			aura.name or "unknown", aura.spellId, tostring(aura.applications or aura.charges or 0),
			tostring(aura.duration), expirationText))
	else
		ns.DebugPrint("Well-Rested aura not found.")
	end
end
