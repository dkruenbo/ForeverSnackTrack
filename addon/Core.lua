local addonName, ns = ...

local defaults = {
	chatAlerts = true,
	screenAlerts = true,
	remindWhenNoFood = false,
	lowFoodThreshold = 0,
	trackSleepingBagBuff = false,
	remindWhileResting = false,
	repeatReminders = true,
	reminderMinutes = 1,
	buffExpiryWarningMinutes = 5,
	snoozeMinutes = 1,
	screenMessage = "",
	screenDuration = 0,
	screenScale = 1,
	screenIconMode = false,
	selectedFoodItemID = 0,
	alertOffsetX = 0,
	alertOffsetY = 120,
}

local auraTooltipCache = {}
local cachedBuffStatus
local tooltipCacheTime
local lastReminderTime
local reminderState
local dismissedReminderState
local lowStockNotified = false
local snoozeUntil
local scanTicker
local auraScanPending = false
local lastBuffExpiryWarningKey
local buffExpiryScanKey

local snoozeDurations = { 1, 5, 10, 15, 30, 60 }
local uppercaseToLowercase = {
	["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü", ["Á"] = "á", ["É"] = "é",
	["Í"] = "í", ["Ó"] = "ó", ["Ú"] = "ú", ["À"] = "à", ["È"] = "è",
	["Ì"] = "ì", ["Ò"] = "ò", ["Ù"] = "ù", ["Ê"] = "ê", ["Â"] = "â",
	["Î"] = "î", ["Ô"] = "ô", ["Û"] = "û", ["Ç"] = "ç", ["Ñ"] = "ñ",
	["Ё"] = "ё", ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г",
	["Д"] = "д", ["Е"] = "е", ["Ж"] = "ж", ["З"] = "з", ["И"] = "и",
	["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м", ["Н"] = "н",
	["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т",
	["У"] = "у", ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч",
	["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ", ["Ы"] = "ы", ["Ь"] = "ь",
	["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я",
}

local function normalizeTooltipText(text)
	text = text:lower()
	for uppercase, lowercase in pairs(uppercaseToLowercase) do
		text = text:gsub(uppercase, lowercase)
	end
	return text
end
ns.NormalizeTooltipText = normalizeTooltipText

local function containsAny(text, terms)
	for _, term in ipairs(terms) do
		if text:find(term, 1, true) then
			return true
		end
	end
	return false
end
ns.ContainsAny = containsAny

local function hasExperienceKillContext(text)
	return containsAny(text, ForeverSnackTrackL.experienceTerms)
		and containsAny(text, ForeverSnackTrackL.killTerms)
		and containsAny(text, ForeverSnackTrackL.increaseTerms)
end

local function distanceToTerms(text, terms, percentStart, percentEnd)
	local closestDistance = math.huge
	for _, term in ipairs(terms) do
		local searchStart = 1
		while true do
			local termStart, termEnd = text:find(term, searchStart, true)
			if not termStart then
				break
			end

			local distance
			if termEnd < percentStart then
				distance = percentStart - termEnd
			elseif termStart > percentEnd then
				distance = termStart - percentEnd
			else
				distance = 0
			end
			closestDistance = math.min(closestDistance, distance)
			searchStart = termStart + 1
		end
	end
	return closestDistance
end

local function tooltipLineText(line)
	return table.concat({ line.leftText or "", line.rightText or "" }, " ")
end
ns.TooltipLineText = tooltipLineText

local function hasItemUseDescription(tooltipData)
	if type(ITEM_SPELL_TRIGGER_ONUSE) ~= "string" then
		return false
	end
	local prefix = ITEM_SPELL_TRIGGER_ONUSE:match("^(.-)%%") or ITEM_SPELL_TRIGGER_ONUSE
	prefix = normalizeTooltipText(prefix):match("^%s*(.-)%s*$")
	if prefix == "" then
		return false
	end
	for _, line in ipairs(tooltipData and tooltipData.lines or {}) do
		local text = normalizeTooltipText(tooltipLineText(line))
		if text:sub(1, #prefix) == prefix and text:sub(#prefix + 1):match("%S") then
			return true
		end
	end
	return false
end
ns.HasItemUseDescription = hasItemUseDescription

local function hasLoadedSpellDescription(spellID)
	if not spellID or not C_Spell or not C_Spell.GetSpellDescription then
		return false
	end
	local description = C_Spell.GetSpellDescription(spellID)
	return type(description) == "string" and description:match("%S") ~= nil
end

local function hasBuffTooltipDescription(tooltipData, aura)
	local auraName = normalizeTooltipText(aura and aura.name or ""):match("^%s*(.-)%s*$")
	for _, line in ipairs(tooltipData and tooltipData.lines or {}) do
		local rawText = tooltipLineText(line)
		if RETRIEVING_ITEM_INFO and rawText:find(RETRIEVING_ITEM_INFO, 1, true) then
			return false
		end
		local text = normalizeTooltipText(rawText):match("^%s*(.-)%s*$")
		if text ~= "" and text ~= auraName then
			return true
		end
	end
	return false
end

local function debugPrint(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff80d7ffForever SnackTrack debug:|r " .. message)
	end
end
ns.DebugPrint = debugPrint

local function copySettings(source)
	local settings = {}
	if type(source) ~= "table" then
		return settings
	end
	for key, value in pairs(source) do
		settings[key] = value
	end
	if type(settings.screenColor) == "table" then
		local color = settings.screenColor
		settings.screenColor = { r = color.r, g = color.g, b = color.b }
	end
	return settings
end

local function initializeSettings()
	if type(ForeverSnackTrackCharDB) ~= "table" then
		local previousSettings = type(ForeverSnackTrackDB) == "table"
			and ForeverSnackTrackDB or ForeverExpFoodDB
		ForeverSnackTrackCharDB = copySettings(previousSettings)
	end

	for key, value in pairs(defaults) do
		if type(ForeverSnackTrackCharDB[key]) ~= type(value) then
			ForeverSnackTrackCharDB[key] = value
		end
	end

	ForeverSnackTrackCharDB.reminderMinutes = math.max(1,
		math.min(60, math.floor(ForeverSnackTrackCharDB.reminderMinutes)))
	local lowFoodThreshold = ForeverSnackTrackCharDB.lowFoodThreshold
	if type(lowFoodThreshold) ~= "number" or lowFoodThreshold ~= lowFoodThreshold then
		lowFoodThreshold = defaults.lowFoodThreshold
	end
	ForeverSnackTrackCharDB.lowFoodThreshold = math.max(0, math.min(20,
		math.floor(lowFoodThreshold + 0.5)))
	local buffExpiryWarningMinutes = ForeverSnackTrackCharDB.buffExpiryWarningMinutes
	if type(buffExpiryWarningMinutes) ~= "number" or buffExpiryWarningMinutes ~= buffExpiryWarningMinutes then
		buffExpiryWarningMinutes = defaults.buffExpiryWarningMinutes
	end
	ForeverSnackTrackCharDB.buffExpiryWarningMinutes = math.max(0,
		math.min(15, math.floor(buffExpiryWarningMinutes + 0.5)))
	local validSnoozeDuration = false
	for _, minutes in ipairs(snoozeDurations) do
		if ForeverSnackTrackCharDB.snoozeMinutes == minutes then
			validSnoozeDuration = true
			break
		end
	end
	if not validSnoozeDuration then
		ForeverSnackTrackCharDB.snoozeMinutes = defaults.snoozeMinutes
	end
	if ForeverSnackTrackCharDB.screenDuration ~= 0 then
		ForeverSnackTrackCharDB.screenDuration = math.max(1, math.min(20,
			math.floor(ForeverSnackTrackCharDB.screenDuration)))
	end
	ForeverSnackTrackCharDB.screenScale = math.max(0.25,
		math.min(1.5, ForeverSnackTrackCharDB.screenScale))
	local selectedFoodItemID = ForeverSnackTrackCharDB.selectedFoodItemID
	if type(selectedFoodItemID) ~= "number" or selectedFoodItemID <= 0
		or selectedFoodItemID ~= math.floor(selectedFoodItemID) then
		ForeverSnackTrackCharDB.selectedFoodItemID = 0
	end
	if type(ForeverSnackTrackCharDB.screenColor) ~= "table" then
		ForeverSnackTrackCharDB.screenColor = { r = 1, g = 0.82, b = 0 }
	else
		for _, channel in ipairs({ "r", "g", "b" }) do
			local value = ForeverSnackTrackCharDB.screenColor[channel]
			if type(value) ~= "number" or value ~= value then
				ForeverSnackTrackCharDB.screenColor[channel] = channel == "r" and 1 or channel == "g" and 0.82 or 0
			else
				ForeverSnackTrackCharDB.screenColor[channel] = math.max(0, math.min(1, value))
			end
		end
	end
	ns.db = ForeverSnackTrackCharDB
end

local function tooltipExperienceBonusPercent(tooltipData)
	if not tooltipData or type(tooltipData.lines) ~= "table" or #tooltipData.lines == 0 then
		return nil
	end
	for _, line in ipairs(tooltipData.lines) do
		local text = tooltipLineText(line)
		if RETRIEVING_ITEM_INFO and text:find(RETRIEVING_ITEM_INFO, 1, true) then
			return nil
		end
	end

	for _, line in ipairs(tooltipData.lines) do
		local text = normalizeTooltipText(tooltipLineText(line))
		if hasExperienceKillContext(text) then
			local searchStart = 1
			local closestPercent
			local closestDistance = math.huge
			while true do
				local matchStart, matchEnd, percentage = text:find("(%d+)%s*%%", searchStart)
				if not matchStart then
					break
				end

				local previousCharacter = matchStart > 1 and text:sub(matchStart - 1, matchStart - 1)
				if not previousCharacter or not previousCharacter:match("[%d%.,]") then
					local value = tonumber(percentage)
					if value and value > 0 then
						local experienceDistance = distanceToTerms(
							text, ForeverSnackTrackL.experienceTerms, matchStart, matchEnd
						)
						local increaseDistance = distanceToTerms(
							text, ForeverSnackTrackL.increaseTerms, matchStart, matchEnd
						)
						local distance = experienceDistance + increaseDistance * 2
						if distance < closestDistance then
							closestPercent = value
							closestDistance = distance
						end
					end
				end
				searchStart = matchEnd + 1
			end
			if closestPercent then
				return closestPercent
			end
		end
	end
	return false
end
ns.GetExperienceBonusPercent = tooltipExperienceBonusPercent

local function formatDuration(seconds)
	local totalMinutes = math.floor(math.max(0, seconds) / 60)
	local hours = math.floor(totalMinutes / 60)
	local minutes = totalMinutes % 60
	if hours > 0 then
		return minutes > 0 and string.format("%dh %dm", hours, minutes) or string.format("%dh", hours)
	end
	return string.format("%dm", minutes)
end
ns.FormatDuration = formatDuration

function ns.GetLowFoodStatusText()
	local threshold = ns.db and ns.db.lowFoodThreshold or 0
	if threshold <= 0 then
		return nil
	end
	local supply = ns.GetFoodSupply()
	if not supply.complete or supply.count > threshold then
		return nil
	end
	if supply.count == 0 and ns.db.remindWhenNoFood then
		return nil
	end
	local buff = cachedBuffStatus
	if not buff or not buff.complete or (type(buff.bonusPercent) == "number" and buff.bonusPercent > 0) then
		return nil
	end
	return ForeverSnackTrackL.lowFoodTitle
end

function ns.ResetLowStockReminder()
	lowStockNotified = false
end

function ns.GetFoodBuffComparisonText()
	local supply = ns.GetCachedFoodSupply()
	local buff = cachedBuffStatus
	if not supply or not supply.complete then
		return ForeverSnackTrackL.foodBuffComparisonLoading
	end
	if not supply.bestBonusPercent then
		if buff and buff.complete and type(buff.bonusPercent) == "number" then
			return string.format(ForeverSnackTrackL.foodBuffComparisonNoFood, buff.bonusPercent)
		end
		return ForeverSnackTrackL.foodBuffComparisonNoFoodNone
	end
	if not buff or not buff.complete then
		return string.format(ForeverSnackTrackL.foodBuffComparisonUnknown, supply.bestBonusPercent)
	end
	if type(buff.bonusPercent) ~= "number" then
		return string.format(ForeverSnackTrackL.foodBuffComparisonNoActive, supply.bestBonusPercent)
	end
	local expirationTime = buff.expirationTime
	if type(expirationTime) == "number" and expirationTime > GetTime() then
		local minutesLeft = math.ceil((expirationTime - GetTime()) / 60)
		return string.format(ForeverSnackTrackL.foodBuffComparisonTimed,
			supply.bestBonusPercent, buff.bonusPercent, formatDuration(minutesLeft * 60))
	end
	return string.format(ForeverSnackTrackL.foodBuffComparisonActive,
		supply.bestBonusPercent, buff.bonusPercent)
end

local function readPlayerAura(index)
	if C_Secrets and type(C_Secrets.ShouldUnitAuraIndexBeSecret) == "function" then
		local success, restricted = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, "player", index, "HELPFUL")
		if not success or restricted then
			return nil, false
		end
	end
	local success, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
	if not success then
		return nil, false
	end
	if type(issecretvalue) == "function" then
		if issecretvalue(aura) then
			return nil, false
		end
		if aura and (issecretvalue(aura.spellId) or issecretvalue(aura.name)
			or issecretvalue(aura.expirationTime)) then
			return nil, false
		end
	end
	return aura, true
end

local function hasExperienceBuff(requiredBonusPercent)
	if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex
		or not C_TooltipInfo or not C_TooltipInfo.GetUnitBuff then
		return nil
	end

	local index = 1
	local unresolvedTooltip = false
	local bestBonusPercent = 0
	local bestExpirationTime
	local bestSpellID
	while true do
		local aura, accessible = readPlayerAura(index)
		if not accessible then
			local knownBonusPercent = bestBonusPercent > 0 and bestBonusPercent or nil
			if requiredBonusPercent and bestBonusPercent >= requiredBonusPercent then
				return knownBonusPercent, bestExpirationTime, bestSpellID, knownBonusPercent
			end
			return nil, bestExpirationTime, bestSpellID, knownBonusPercent
		end
		if not aura then
			local knownBonusPercent = bestBonusPercent > 0 and bestBonusPercent or nil
			if unresolvedTooltip and not (requiredBonusPercent and bestBonusPercent >= requiredBonusPercent) then
				return nil, bestExpirationTime, bestSpellID, knownBonusPercent
			end
			return knownBonusPercent or false, bestExpirationTime, bestSpellID, knownBonusPercent
		end

		local bonusPercent = aura.spellId and auraTooltipCache[aura.spellId]
		if bonusPercent == nil then
			local tooltipData = C_TooltipInfo.GetUnitBuff("player", index, "HELPFUL")
			if tooltipData and type(tooltipData.lines) == "table" and #tooltipData.lines > 0 then
				bonusPercent = tooltipExperienceBonusPercent(tooltipData)
				if #tooltipData.lines == 1 and aura.name and tooltipData.lines[1].leftText == aura.name then
					bonusPercent = nil
				end
				if bonusPercent == false and not hasLoadedSpellDescription(aura.spellId)
					and not hasBuffTooltipDescription(tooltipData, aura) then
					bonusPercent = nil
				end
				if bonusPercent == nil then
					unresolvedTooltip = true
				elseif aura.spellId then
					auraTooltipCache[aura.spellId] = bonusPercent
				end
			else
				unresolvedTooltip = true
			end
		end
		if type(bonusPercent) == "number" and bonusPercent > bestBonusPercent then
			bestBonusPercent = bonusPercent
			bestExpirationTime = aura.expirationTime
			bestSpellID = aura.spellId
		elseif type(bonusPercent) == "number" and bonusPercent == bestBonusPercent then
			local expirationTime = aura.expirationTime
			if type(expirationTime) ~= "number" or type(bestExpirationTime) ~= "number" then
				bestExpirationTime = nil
				bestSpellID = nil
			elseif expirationTime <= 0 or bestExpirationTime <= 0 then
				bestExpirationTime = 0
				bestSpellID = aura.spellId
			elseif expirationTime > bestExpirationTime then
				bestExpirationTime = expirationTime
				bestSpellID = aura.spellId
			end
		end
		index = index + 1
	end
end

local function isPlayerDead()
	return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false
end

local flightSuppressed = false
local flightTicker

local function isPlayerFlying()
	return IsFlying and IsFlying() or false
end

function ns.IsPlayerMoving()
	if type(GetUnitSpeed) ~= "function" then
		return false
	end
	local success, speed = pcall(GetUnitSpeed, "player")
	if not success or type(speed) ~= "number" then
		return false
	end
	if type(issecretvalue) == "function" then
		local secretCheckSucceeded, isSecret = pcall(issecretvalue, speed)
		if secretCheckSucceeded and isSecret then
			return false
		end
	end
	local comparisonSucceeded, moving = pcall(function()
		return speed > 0
	end)
	return comparisonSucceeded and moving or false
end

local function updateFlightSuppression()
	if not ns.db then
		return
	end
	if ns.IsPlayerMoving() and ns.InterruptSleepingBagRest then
		ns.InterruptSleepingBagRest()
	end
	if isPlayerFlying() then
		flightSuppressed = true
		if ns.InterruptSleepingBagRest then
			ns.InterruptSleepingBagRest()
		elseif ns.HideSleepingBagTimeline then
			ns.HideSleepingBagTimeline()
		end
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
	elseif flightSuppressed then
		flightSuppressed = false
		ns.Scan()
	end
end

local function warnAboutBuffExpiry(bonusPercent, expirationTime, spellID, now)
	local warningMinutes = ns.db.buffExpiryWarningMinutes
	if warningMinutes <= 0 or not ns.db.chatAlerts or not DEFAULT_CHAT_FRAME
		or type(bonusPercent) ~= "number" or type(expirationTime) ~= "number" or expirationTime <= 0 then
		buffExpiryScanKey = nil
		if type(bonusPercent) ~= "number" or type(expirationTime) ~= "number" or expirationTime <= 0 then
			lastBuffExpiryWarningKey = nil
		end
		return
	end
	if snoozeUntil and now < snoozeUntil then
		return
	end
	local remaining = expirationTime - now
	if remaining <= 0 then
		lastBuffExpiryWarningKey = nil
		return
	end
	local expiryKey = tostring(spellID or "unknown") .. ":" .. tostring(expirationTime)
	if remaining > warningMinutes * 60 then
		local scheduledKey = expiryKey .. ":" .. tostring(warningMinutes)
		if C_Timer and C_Timer.After and buffExpiryScanKey ~= scheduledKey then
			buffExpiryScanKey = scheduledKey
			C_Timer.After(remaining - warningMinutes * 60, function()
				if buffExpiryScanKey == scheduledKey then
					buffExpiryScanKey = nil
					ns.Scan()
				end
			end)
		end
		return
	end
	buffExpiryScanKey = nil
	if expiryKey == lastBuffExpiryWarningKey then
		return
	end
	lastBuffExpiryWarningKey = expiryKey
	DEFAULT_CHAT_FRAME:AddMessage("|cff80d7ffForever SnackTrack:|r " .. string.format(
		ForeverSnackTrackL.buffExpiryMessage, bonusPercent, math.ceil(remaining / 60)))
end

local function sendReminder(message, useCustomScreenMessage, lowFoodStatusText, chatMessage,
	showFoodActions, sleepingBagItemName)
	local sent = false
	if ns.db.chatAlerts and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff80d7ffForever SnackTrack:|r " .. (chatMessage or message))
		sent = true
	end
	if ns.db.screenAlerts and ns.ShowScreenAlert
		and not isPlayerDead()
		and not isPlayerFlying()
		and not (ns.alertFrame and ns.alertFrame.isPreview and ns.alertFrame:IsShown()) then
		local screenMessage = useCustomScreenMessage and ns.db.screenMessage ~= "" and ns.db.screenMessage or message
		sent = ns.ShowScreenAlert(screenMessage, false, lowFoodStatusText,
			showFoodActions, sleepingBagItemName) or sent
	end
	return sent
end

function ns.Scan()
	if not ns.db then
		return
	end
	cachedBuffStatus = nil
	local now = GetTime()
	local playerLevel = UnitLevel and UnitLevel("player")
	local sleepingBagEnabled = ns.db.trackSleepingBagBuff and ns.db.screenAlerts
		and not (type(playerLevel) == "number" and playerLevel >= 60)
	local sleepingBagStatus = ns.db.trackSleepingBagBuff and ns.GetSleepingBagStatus()
	if ns.UpdateSleepingBagTimeline then
		ns.UpdateSleepingBagTimeline(sleepingBagStatus, sleepingBagEnabled)
	end
	if type(playerLevel) == "number" and playerLevel >= 60 then
		lastReminderTime = nil
		reminderState = nil
		dismissedReminderState = nil
		snoozeUntil = nil
		if ns.HideScreenAlert then
			ns.HideScreenAlert(true)
		end
		return
	end
	if not ns.db.remindWhileResting and IsResting and IsResting() then
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
		return
	end
	if UnitAffectingCombat and UnitAffectingCombat("player") then
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
		return
	end
	if not ns.db.chatAlerts and not ns.db.screenAlerts then
		lastReminderTime = nil
		reminderState = nil
		dismissedReminderState = nil
		if ns.HideScreenAlert then
			ns.HideScreenAlert(true)
		end
		return
	end

	if not tooltipCacheTime or now - tooltipCacheTime >= 60 then
		ns.ResetFoodCaches()
		auraTooltipCache = {}
		tooltipCacheTime = now
	end

	local hasFood = ns.ScanQualifyingFood()
	local requiredBonusPercent = type(hasFood) == "number" and hasFood or nil
	local sleepingBagReminder = ns.db.trackSleepingBagBuff
		and ns.GetSleepingBagReminder(sleepingBagStatus, now)
	local lowFoodThreshold = ns.db.lowFoodThreshold
	local foodSupply = lowFoodThreshold > 0 and ns.GetFoodSupply() or nil
	if lowFoodThreshold == 0 or (foodSupply and foodSupply.complete and foodSupply.count > lowFoodThreshold) then
		lowStockNotified = false
	end
	local hasBuff, buffExpirationTime, buffSpellID, knownBuffPercent
	if hasFood or ns.db.remindWhenNoFood or lowFoodThreshold > 0 or ns.db.buffExpiryWarningMinutes > 0 then
		hasBuff, buffExpirationTime, buffSpellID, knownBuffPercent = hasExperienceBuff(requiredBonusPercent)
		cachedBuffStatus = {
			complete = hasBuff ~= nil,
			bonusPercent = type(hasBuff) == "number" and hasBuff or nil,
			expirationTime = buffExpirationTime,
		}
	end
	warnAboutBuffExpiry(knownBuffPercent or (type(hasBuff) == "number" and hasBuff),
		buffExpirationTime, buffSpellID, now)
	local lowFoodStatusText = lowFoodThreshold > 0 and ns.GetLowFoodStatusText() or nil
	if ns.SetLowFoodStatusText then
		ns.SetLowFoodStatusText(lowFoodStatusText)
	end
	if hasFood == nil and not sleepingBagReminder then
		return
	end
	local lowStock = foodSupply and foodSupply.complete and foodSupply.count <= lowFoodThreshold
	if lowStock and hasBuff == nil and not sleepingBagReminder then
		return
	end
	local lowStockReminder = lowStock
		and not (foodSupply.count == 0 and ns.db.remindWhenNoFood)
		and not (type(hasBuff) == "number" and hasBuff > 0)
	local lowStockNoticeDue = lowStockReminder and not lowStockNotified

	local state
	local message
	local chatMessage
	local useCustomScreenMessage = false
	if sleepingBagReminder then
		state = "sleeping-bag:" .. sleepingBagReminder
		message = sleepingBagReminder == "refresh"
			and ForeverSnackTrackL.sleepingBagRefreshMessage or ForeverSnackTrackL.sleepingBagBuildMessage
	elseif hasFood == nil then
		return
	elseif hasFood then
		if hasBuff == nil then
			return
		elseif type(hasBuff) == "number" and hasBuff >= hasFood then
			lastReminderTime = nil
			reminderState = nil
			dismissedReminderState = nil
			if ns.HideScreenAlert then
				ns.HideScreenAlert(true)
			end
			return
		end
		state = "missing-buff:" .. hasFood
		message = string.format(ForeverSnackTrackL.chatMessage, hasFood)
		useCustomScreenMessage = true
	elseif ns.db.remindWhenNoFood then
		if hasBuff == nil then
			return
		elseif type(hasBuff) == "number" and hasBuff > 0 then
			lastReminderTime = nil
			reminderState = nil
			dismissedReminderState = nil
			if ns.HideScreenAlert then
				ns.HideScreenAlert(true)
			end
			return
		end
		state = "missing-food"
		message = ForeverSnackTrackL.noFoodMessage
	elseif lowStockReminder then
		state = "low-food-stock"
		message = ForeverSnackTrackL.lowFoodTitle
	else
		lastReminderTime = nil
		reminderState = nil
		dismissedReminderState = nil
		if ns.HideScreenAlert then
			ns.HideScreenAlert(true)
		end
		return
	end
	if lowStockNoticeDue then
		chatMessage = state == "low-food-stock" and lowFoodStatusText
			or message .. "\n" .. lowFoodStatusText
	end

	if reminderState ~= state then
		reminderState = state
		lastReminderTime = nil
	end
	if dismissedReminderState and dismissedReminderState ~= state then
		dismissedReminderState = nil
	end
	if dismissedReminderState == state then
		return
	end

	if snoozeUntil then
		if now < snoozeUntil then
			return
		end
		snoozeUntil = nil
	end
	local intervalElapsed = lastReminderTime
		and now - lastReminderTime >= ns.db.reminderMinutes * 60
	if lowStockNoticeDue or not lastReminderTime
		or (state ~= "low-food-stock" and ns.db.repeatReminders and intervalElapsed) then
		if sendReminder(message, useCustomScreenMessage, lowFoodStatusText, chatMessage,
			not sleepingBagReminder, sleepingBagStatus and sleepingBagStatus.itemName) then
			lastReminderTime = now
			if lowStockNoticeDue then
				lowStockNotified = true
			end
		end
	end
	local frame = ns.alertFrame
	local remaining = lastReminderTime and ns.db.screenDuration > 0
		and lastReminderTime + ns.db.screenDuration - now
	if ns.db.screenAlerts and lastReminderTime and ns.ShowScreenAlert
		and not isPlayerDead()
		and not isPlayerFlying()
		and (ns.db.screenDuration == 0 or remaining > 0)
		and not (frame and frame:IsShown()) then
		local screenMessage = useCustomScreenMessage and ns.db.screenMessage ~= "" and ns.db.screenMessage or message
		ns.ShowScreenAlert(screenMessage, false, lowFoodStatusText, not sleepingBagReminder,
			sleepingBagStatus and sleepingBagStatus.itemName)
		if remaining and ns.alertFrame then
			ns.alertFrame.remaining = remaining
		end
	end
end

local function debugTooltipCandidates(tooltipData)
	local candidates = {}
	for _, line in ipairs(tooltipData and tooltipData.lines or {}) do
		local rawText = tooltipLineText(line)
		local text = normalizeTooltipText(rawText)
		if rawText:find("%", 1, true)
			or containsAny(text, ForeverSnackTrackL.experienceTerms)
			or containsAny(text, ForeverSnackTrackL.killTerms) then
			table.insert(candidates, rawText)
		end
	end
	return candidates
end
ns.DebugTooltipCandidates = debugTooltipCandidates

function ns.DebugStatus()
	if not DEFAULT_CHAT_FRAME then
		return
	end
	if not ns.db then
		debugPrint("Settings have not been initialized.")
		return
	end
	debugPrint(string.format("Chat alerts: %s; screen alerts: %s.",
		tostring(ns.db.chatAlerts), tostring(ns.db.screenAlerts)))
	if not ns.db.chatAlerts and not ns.db.screenAlerts then
		debugPrint("Reminders blocked: both alert channels are disabled.")
	end
	local now = GetTime()
	if snoozeUntil and now < snoozeUntil then
		debugPrint(string.format("Reminders snoozed for %d more second(s).", math.ceil(snoozeUntil - now)))
	end
	if dismissedReminderState then
		debugPrint("Dismissed reminder condition: " .. dismissedReminderState)
	end
	if lastReminderTime then
		if ns.db.repeatReminders then
			debugPrint(string.format("Next repeat eligible in %d second(s).",
				math.max(0, math.ceil(ns.db.reminderMinutes * 60 - (now - lastReminderTime)))))
		else
			debugPrint("A reminder was already sent; repeat reminders are disabled.")
		end
	end
	if UnitAffectingCombat and UnitAffectingCombat("player") then
		debugPrint("Leave combat before running the diagnostic.")
		return
	end
	ns.DebugFoodStatus()

	if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex or not C_TooltipInfo.GetUnitBuff then
		debugPrint("Aura or unit-tooltip API is unavailable.")
		return
	end

	local auraIndex = 1
	local auraCount = 0
	local recognizedBuffs = 0
	local unresolvedBuffs = 0
	local bestBuffPercent = 0
	while true do
		local aura, accessible = readPlayerAura(auraIndex)
		if not accessible then
			debugPrint("Aura data is unavailable or restricted; retry outside combat.")
			return
		end
		if not aura then
			break
		end
		auraCount = auraCount + 1
		local tooltipData = C_TooltipInfo.GetUnitBuff("player", auraIndex, "HELPFUL")
		if not tooltipData or type(tooltipData.lines) ~= "table" or #tooltipData.lines == 0 then
			unresolvedBuffs = unresolvedBuffs + 1
			debugPrint("Buff " .. (aura.name or tostring(aura.spellId)) .. ": tooltip data unavailable.")
		else
			local bonusPercent = tooltipExperienceBonusPercent(tooltipData)
			if #tooltipData.lines == 1 and tooltipData.lines[1].leftText == aura.name then
				bonusPercent = nil
			end
			if bonusPercent == false and not hasLoadedSpellDescription(aura.spellId)
				and not hasBuffTooltipDescription(tooltipData, aura) then
				bonusPercent = nil
			end
			if bonusPercent == nil then
				unresolvedBuffs = unresolvedBuffs + 1
			end
			if aura.spellId then
				if type(bonusPercent) == "number" or bonusPercent == false then
					auraTooltipCache[aura.spellId] = bonusPercent
				else
					auraTooltipCache[aura.spellId] = nil
				end
			end
			if type(bonusPercent) == "number" then
				recognizedBuffs = recognizedBuffs + 1
				bestBuffPercent = math.max(bestBuffPercent, bonusPercent)
				local expiryText = type(aura.expirationTime) == "number" and aura.expirationTime > 0
					and string.format("expires in %d min", math.ceil((aura.expirationTime - now) / 60))
					or "expiry unavailable"
				debugPrint(string.format("Buff: %s (spell %s) -> %d%% kill XP; %s",
					aura.name or "unknown", aura.spellId or "unknown", bonusPercent, expiryText))
			else
				for _, candidate in ipairs(debugTooltipCandidates(tooltipData)) do
					debugPrint(string.format("Buff candidate %s (spell %s): %s", aura.name or "unknown", aura.spellId or "unknown", candidate))
				end
			end
		end
		auraIndex = auraIndex + 1
	end
	if recognizedBuffs == 0 then
		debugPrint(string.format("No XP kill-buff recognized among %d helpful buff(s).", auraCount))
	else
		debugPrint(string.format("Recognized %d XP buff(s); strongest active bonus is %d%%.", recognizedBuffs, bestBuffPercent))
	end
	if unresolvedBuffs > 0 then
		debugPrint(string.format("%d buff tooltip(s) unavailable or incomplete.", unresolvedBuffs))
	end
end

function ns.SnoozeReminders()
	if not ns.db then
		return
	end

	snoozeUntil = GetTime() + ns.db.snoozeMinutes * 60
	lastReminderTime = nil
	if ns.alertFrame then
		ns.HideScreenAlert()
	end
end

function ns.DismissReminder()
	if reminderState then
		dismissedReminderState = reminderState
	end
	lastReminderTime = nil
	if ns.alertFrame then
		ns.HideScreenAlert()
	end
end

local eventFrame = CreateFrame("Frame")

local function scheduleAuraScan()
	local function scanAndRefresh()
		ns.Scan()
		if ns.RefreshFoodSupplyDisplay then ns.RefreshFoodSupplyDisplay() end
	end
	if not C_Timer or not C_Timer.After then
		scanAndRefresh()
		return
	end
	if auraScanPending then
		return
	end
	auraScanPending = true
	C_Timer.After(0.5, function()
		auraScanPending = false
		scanAndRefresh()
	end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_STARTED_MOVING")
eventFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
pcall(eventFrame.RegisterEvent, eventFrame, "BAG_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
if eventFrame.RegisterUnitEvent then
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
	eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
if C_Traits then
	pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_UPDATED")
	pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_LIST_UPDATED")
end
if eventFrame.RegisterUnitEvent then
	eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
else
	eventFrame:RegisterEvent("UNIT_AURA")
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		eventFrame:UnregisterEvent("ADDON_LOADED")
		initializeSettings()
		if ns.InitializeOptions then
			ns.InitializeOptions()
		end
	elseif event == "PLAYER_LOGIN" then
		ns.InvalidateFoodBagScan()
		ns.InvalidateFoodDuration()
		if C_Timer and C_Timer.NewTicker then
			scanTicker = C_Timer.NewTicker(60, ns.Scan)
			flightTicker = C_Timer.NewTicker(0.25, updateFlightSuppression)
		else
			local elapsedSinceScan = 0
			local elapsedSinceFlightCheck = 0
			eventFrame:SetScript("OnUpdate", function(_, elapsed)
				elapsedSinceScan = elapsedSinceScan + elapsed
				elapsedSinceFlightCheck = elapsedSinceFlightCheck + elapsed
				if elapsedSinceFlightCheck >= 0.25 then
					elapsedSinceFlightCheck = elapsedSinceFlightCheck % 0.25
					updateFlightSuppression()
				end
				if elapsedSinceScan >= 60 then
					elapsedSinceScan = elapsedSinceScan % 60
					ns.Scan()
				end
			end)
		end
		ns.Scan()
	elseif event == "BAG_UPDATE_DELAYED" then
		ns.InvalidateFoodBagScan()
		ns.Scan()
		if ns.RefreshSelectedFood then ns.RefreshSelectedFood() end
	elseif event == "BAG_UPDATE_COOLDOWN" then
		ns.Scan()
	elseif event == "PLAYER_ENTERING_WORLD" then
		if ns.ResetSleepingBagTrackingState then ns.ResetSleepingBagTrackingState() end
		ns.InvalidateFoodBagScan()
		ns.InvalidateFoodDuration()
		ns.Scan()
	elseif event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
		ns.InvalidateFoodDuration()
	elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_STOPPED_MOVING" then
		updateFlightSuppression()
	elseif event == "PLAYER_STARTED_MOVING" then
		if ns.InterruptSleepingBagRest then ns.InterruptSleepingBagRest() end
		updateFlightSuppression()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if arg1 == "player" and arg3 == 429961 and ns.RecordSleepingBagPlacement then
			ns.RecordSleepingBagPlacement()
		end
	elseif event == "PLAYER_LEVEL_UP" then
		ns.Scan()
	elseif event == "PLAYER_DEAD" then
		if ns.HideSleepingBagTimeline then
			ns.HideSleepingBagTimeline()
		end
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
	elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
		ns.Scan()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ns.HideSleepingBagTimeline then
			ns.HideSleepingBagTimeline()
		end
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
	elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_UPDATE_RESTING" then
		ns.Scan()
	elseif event == "UNIT_AURA" then
		if arg1 == "player" then
			auraTooltipCache = {}
			cachedBuffStatus = nil
			scheduleAuraScan()
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		ns.InvalidateFoodBagScan(arg1)
		ns.Scan()
		if ns.RefreshSelectedFood then ns.RefreshSelectedFood() end
	end
	if ns.RefreshFoodSupplyDisplay and (event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED"
		or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED"
		or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN") then
		ns.RefreshFoodSupplyDisplay()
	end
end)