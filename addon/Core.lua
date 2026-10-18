local addonName, ns = ...

local defaults = {
	chatAlerts = true,
	screenAlerts = true,
	remindWhenNoFood = false,
	remindWhileResting = false,
	repeatReminders = true,
	reminderMinutes = 1,
	buffExpiryWarningMinutes = 5,
	snoozeMinutes = 1,
	screenMessage = "",
	screenDuration = 0,
	screenScale = 1,
	alertOffsetX = 0,
	alertOffsetY = 120,
}

local foodTooltipCache = {}
local foodStatsCache = {}
local auraTooltipCache = {}
local cachedBagResult
local cachedQualifyingFoods
local tooltipCacheTime
local lastReminderTime
local reminderState
local dismissedReminderState
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

local function containsAny(text, terms)
	for _, term in ipairs(terms) do
		if text:find(term, 1, true) then
			return true
		end
	end
	return false
end

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
	ForeverSnackTrackCharDB.screenScale = math.max(0.75,
		math.min(1.5, ForeverSnackTrackCharDB.screenScale))
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

local function tooltipFoodStats(tooltipData)
	local definitions = {
		{ label = "Str", localized = STAT_STRENGTH, itemMod = ITEM_MOD_STRENGTH_SHORT, fallback = "strength" },
		{ label = "Agi", localized = STAT_AGILITY, itemMod = ITEM_MOD_AGILITY_SHORT, fallback = "agility" },
		{ label = "Int", localized = STAT_INTELLECT, itemMod = ITEM_MOD_INTELLECT_SHORT, fallback = "intellect" },
		{ label = "Sta", localized = STAT_STAMINA, itemMod = ITEM_MOD_STAMINA_SHORT, fallback = "stamina" },
		{ label = "Spi", localized = STAT_SPIRIT, itemMod = ITEM_MOD_SPIRIT_SHORT, fallback = "spirit" },
		{ label = "AP", localized = STAT_ATTACK_POWER, itemMod = ITEM_MOD_ATTACK_POWER_SHORT, fallback = "attack power" },
		{ label = "Spell", localized = STAT_SPELL_DAMAGE, itemMod = ITEM_MOD_SPELL_DAMAGE_DONE_SHORT, fallback = "spell damage" },
		{ label = "Heal", localized = STAT_HEALING_POWER, itemMod = ITEM_MOD_HEALING_DONE_SHORT, fallback = "healing power" },
		{ label = "Armor", localized = STAT_ARMOR, itemMod = ITEM_MOD_ARMOR_SHORT, fallback = "armor" },
		{ label = "Crit", localized = STAT_CRITICAL_STRIKE, itemMod = ITEM_MOD_CRIT_RATING_SHORT,
			fallback = "critical strike chance", aliases = { "crit chance" }, percent = true },
		{ label = "Move", fallback = "movement speed", percent = true },
		{ label = "Fishing", fallback = "fishing" },
		{ label = "Herb", fallback = "herbalism" },
	}
	local normalizedLines = {}
	for _, line in ipairs(tooltipData and tooltipData.lines or {}) do
		table.insert(normalizedLines, normalizeTooltipText(tooltipLineText(line)))
	end
	local bonuses = {}
	for _, definition in ipairs(definitions) do
		local terms = {}
		local function addTerm(candidate)
			if type(candidate) == "string" then
				local term = normalizeTooltipText(candidate):gsub("%%[ds]", "")
				term = term:gsub("[%+%p]", " "):match("^%s*(.-)%s*$")
				if term ~= "" then
					table.insert(terms, term)
				end
			end
		end
		addTerm(definition.localized)
		addTerm(definition.itemMod)
		addTerm(definition.fallback)
		for _, alias in ipairs(definition.aliases or {}) do
			addTerm(alias)
		end
		local found = false
		for _, text in ipairs(normalizedLines) do
			for _, term in ipairs(terms) do
				local first, last = text:find(term, 1, true)
				if first then
					local before = text:sub(1, first - 1)
					local after = text:sub(last + 1)
					local amount = before:match("([%+%-]?%d+%%?)%s*$")
						or after:match("^%s*[:]?%s*([%+%-]?%d+%%?)")
						or after:match("^[^%d]-by%s+([%+%-]?%d+%%?)")
					local numericAmount = amount and amount:gsub("%%", "")
					local value = numericAmount and tonumber(numericAmount)
					if value and value ~= 0 then
						local sign = value > 0 and "+" or ""
						local percent = definition.percent or (amount and amount:find("%%", 1, true))
						local suffix = percent and "%" or ""
						table.insert(bonuses, string.format("%s%d%s %s", sign, value, suffix, definition.label))
						found = true
						break
					end
				end
			end
			if found then
				break
			end
		end
	end
	return bonuses
end

local function foodItemType(itemID)
	local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
	if not getInfo then
		return nil
	end
	local _, _, _, _, _, classID, subclassID = getInfo(itemID)
	if classID == nil or subclassID == nil then
		return nil
	end
	return classID == 0 and subclassID == 5
end

local function hasQualifyingFood()
	if cachedBagResult ~= nil then
		return cachedBagResult
	end
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
		return nil
	end

	local unresolvedTooltip = false
	local bestBonusPercent = 0
	local qualifyingFoods = {}
	local bagCount = NUM_BAG_SLOTS or 0
	for bagID = 0, bagCount do
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slot = 1, slotCount do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
			local itemID = itemInfo and itemInfo.itemID
			if itemID then
				local isFood = foodItemType(itemID)
				local bonusPercent = foodTooltipCache[itemID]
				if isFood == nil then
					unresolvedTooltip = true
					bonusPercent = nil
				elseif not isFood then
					bonusPercent = false
				elseif bonusPercent == nil or (type(bonusPercent) == "number" and foodStatsCache[itemID] == nil) then
					local tooltipData = C_TooltipInfo and C_TooltipInfo.GetBagItem
						and C_TooltipInfo.GetBagItem(bagID, slot)
					if tooltipData and type(tooltipData.lines) == "table" and #tooltipData.lines > 1 then
						bonusPercent = tooltipExperienceBonusPercent(tooltipData)
						if type(bonusPercent) == "number" then
							foodTooltipCache[itemID] = bonusPercent
							foodStatsCache[itemID] = tooltipFoodStats(tooltipData)
						elseif bonusPercent == false and hasItemUseDescription(tooltipData) then
							foodTooltipCache[itemID] = false
						elseif bonusPercent == false then
							bonusPercent = nil
							unresolvedTooltip = true
						elseif bonusPercent == nil then
							unresolvedTooltip = true
						end
					else
						unresolvedTooltip = true
					end
				end
				if type(bonusPercent) == "number" and bonusPercent > bestBonusPercent then
					bestBonusPercent = bonusPercent
				end
				if type(bonusPercent) == "number" and bonusPercent > 0 then
					local matchingFood
					for _, food in ipairs(qualifyingFoods) do
						if food.itemID == itemID then
							matchingFood = food
							break
						end
					end
					local count = itemInfo.stackCount or itemInfo.count or 1
					if type(count) ~= "number" or count < 1 then
						count = 1
					end
					if matchingFood then
						matchingFood.count = matchingFood.count + count
					else
						local itemName = itemInfo.itemName or (GetItemInfo and GetItemInfo(itemID))
						table.insert(qualifyingFoods, {
							itemID = itemID,
							itemName = itemName or ("item " .. itemID),
							bagID = bagID,
							slot = slot,
							bonusPercent = bonusPercent,
							count = count,
							stats = foodStatsCache[itemID] or {},
						})
					end
				end
			end
		end
	end
	table.sort(qualifyingFoods, function(first, second)
		if first.bonusPercent ~= second.bonusPercent then
			return first.bonusPercent > second.bonusPercent
		end
		return first.itemName < second.itemName
	end)
	cachedQualifyingFoods = qualifyingFoods
	if unresolvedTooltip then
		return bestBonusPercent > 0 and bestBonusPercent or nil
	end
	cachedBagResult = bestBonusPercent > 0 and bestBonusPercent or false
	return cachedBagResult
end

local function invalidateBagScan(itemID)
	cachedBagResult = nil
	cachedQualifyingFoods = nil
	if itemID then
		foodTooltipCache[itemID] = nil
		foodStatsCache[itemID] = nil
	end
end

function ns.GetAvailableFoods()
	if cachedQualifyingFoods == nil then
		cachedBagResult = nil
		hasQualifyingFood()
	end
	return cachedQualifyingFoods or {}
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
		local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
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

local function sendReminder(message, useCustomScreenMessage)
	local sent = false
	if ns.db.chatAlerts and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff80d7ffForever SnackTrack:|r " .. message)
		sent = true
	end
	if ns.db.screenAlerts and ns.ShowScreenAlert
		and not isPlayerDead()
		and not (ns.alertFrame and ns.alertFrame.isPreview and ns.alertFrame:IsShown()) then
		local screenMessage = useCustomScreenMessage and ns.db.screenMessage ~= "" and ns.db.screenMessage or message
		sent = ns.ShowScreenAlert(screenMessage) or sent
	end
	return sent
end

function ns.Scan()
	if not ns.db then
		return
	end
	local playerLevel = UnitLevel and UnitLevel("player")
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

	local now = GetTime()
	if not tooltipCacheTime or now - tooltipCacheTime >= 60 then
		foodTooltipCache = {}
		foodStatsCache = {}
		auraTooltipCache = {}
		cachedBagResult = nil
		cachedQualifyingFoods = nil
		tooltipCacheTime = now
	end

	local hasFood = hasQualifyingFood()
	local requiredBonusPercent = type(hasFood) == "number" and hasFood or nil
	local hasBuff, buffExpirationTime, buffSpellID, knownBuffPercent
	if hasFood or ns.db.remindWhenNoFood or ns.db.buffExpiryWarningMinutes > 0 then
		hasBuff, buffExpirationTime, buffSpellID, knownBuffPercent = hasExperienceBuff(requiredBonusPercent)
	end
	warnAboutBuffExpiry(knownBuffPercent or (type(hasBuff) == "number" and hasBuff),
		buffExpirationTime, buffSpellID, now)
	if hasFood == nil then
		return
	end

	local state
	local message
	local useCustomScreenMessage = false
	if hasFood then
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
	else
		lastReminderTime = nil
		reminderState = nil
		dismissedReminderState = nil
		if ns.HideScreenAlert then
			ns.HideScreenAlert(true)
		end
		return
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
	if not lastReminderTime or (ns.db.repeatReminders and intervalElapsed) then
		if sendReminder(message, useCustomScreenMessage) then
			lastReminderTime = now
		end
	end
	local frame = ns.alertFrame
	local remaining = lastReminderTime and ns.db.screenDuration > 0
		and lastReminderTime + ns.db.screenDuration - now
	if ns.db.screenAlerts and lastReminderTime and ns.ShowScreenAlert
		and not isPlayerDead()
		and (ns.db.screenDuration == 0 or remaining > 0)
		and not (frame and frame:IsShown()) then
		local screenMessage = useCustomScreenMessage and ns.db.screenMessage ~= "" and ns.db.screenMessage or message
		ns.ShowScreenAlert(screenMessage)
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
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo
		or not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
		debugPrint("Bag or tooltip API is unavailable.")
		return
	end

	invalidateBagScan()
	local scannedItems = 0
	local unresolvedItems = 0
	local recognizedFoods = 0
	local bestFoodPercent = 0
	local bagCount = NUM_BAG_SLOTS or 0
	debugPrint("Scanning carried bags and helpful buffs...")
	for bagID = 0, bagCount do
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slot = 1, slotCount do
			local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
			local itemID = itemInfo and itemInfo.itemID
			if itemID and foodItemType(itemID) ~= false then
				scannedItems = scannedItems + 1
				local tooltipData = C_TooltipInfo.GetBagItem(bagID, slot)
				if foodItemType(itemID) == nil or not tooltipData
					or type(tooltipData.lines) ~= "table" or #tooltipData.lines <= 1 then
					unresolvedItems = unresolvedItems + 1
					debugPrint("Item " .. itemID .. ": tooltip data unavailable.")
				else
					local bonusPercent = tooltipExperienceBonusPercent(tooltipData)
					if bonusPercent == false and not hasItemUseDescription(tooltipData) then
						bonusPercent = nil
					end
					if bonusPercent == nil then
						unresolvedItems = unresolvedItems + 1
					end
					if type(bonusPercent) == "number" or bonusPercent == false then
						foodTooltipCache[itemID] = bonusPercent
					else
						foodTooltipCache[itemID] = nil
					end
					local itemName = itemInfo.itemName or (GetItemInfo and GetItemInfo(itemID)) or ("item " .. itemID)
					if type(bonusPercent) == "number" then
						recognizedFoods = recognizedFoods + 1
						bestFoodPercent = math.max(bestFoodPercent, bonusPercent)
						debugPrint(string.format("Food: %s (ID %d) -> %d%% kill XP", itemName, itemID, bonusPercent))
					else
						for _, candidate in ipairs(debugTooltipCandidates(tooltipData)) do
							debugPrint(string.format("Item candidate %s (ID %d): %s", itemName, itemID, candidate))
						end
					end
				end
			end
		end
	end

	if unresolvedItems == 0 then
		cachedBagResult = bestFoodPercent > 0 and bestFoodPercent or false
	else
		cachedBagResult = nil
	end
	if unresolvedItems > 0 then
		debugPrint(string.format("%d item tooltip(s) unavailable; known XP food can still trigger reminders.", unresolvedItems))
	end
	if recognizedFoods == 0 then
		debugPrint(string.format("No XP food recognized in %d carried item(s).", scannedItems))
	else
		debugPrint(string.format("Recognized %d XP food item(s); best available bonus is %d%%.", recognizedFoods, bestFoodPercent))
	end

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
		local aura = C_UnitAuras.GetAuraDataByIndex("player", auraIndex, "HELPFUL")
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
	if not C_Timer or not C_Timer.After then
		ns.Scan()
		return
	end
	if auraScanPending then
		return
	end
	auraScanPending = true
	C_Timer.After(0.5, function()
		auraScanPending = false
		ns.Scan()
	end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
if eventFrame.RegisterUnitEvent then
	eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
else
	eventFrame:RegisterEvent("UNIT_AURA")
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
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
		invalidateBagScan()
		if C_Timer and C_Timer.NewTicker then
			scanTicker = C_Timer.NewTicker(60, ns.Scan)
		else
			local elapsedSinceScan = 0
			eventFrame:SetScript("OnUpdate", function(_, elapsed)
				elapsedSinceScan = elapsedSinceScan + elapsed
				if elapsedSinceScan >= 60 then
					elapsedSinceScan = elapsedSinceScan % 60
					ns.Scan()
				end
			end)
		end
		ns.Scan()
	elseif event == "BAG_UPDATE_DELAYED" then
		invalidateBagScan()
		ns.Scan()
	elseif event == "PLAYER_ENTERING_WORLD" then
		invalidateBagScan()
		ns.Scan()
	elseif event == "PLAYER_LEVEL_UP" then
		ns.Scan()
	elseif event == "PLAYER_DEAD" then
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
	elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
		ns.Scan()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ns.HideScreenAlert then
			ns.HideScreenAlert()
		end
	elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_UPDATE_RESTING" then
		ns.Scan()
	elseif event == "UNIT_AURA" then
		if arg1 == "player" then
			auraTooltipCache = {}
			scheduleAuraScan()
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		invalidateBagScan(arg1)
		ns.Scan()
	end
end)