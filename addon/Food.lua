local addonName, ns = ...

local foodTooltipCache = {}
local foodStatsCache = {}
local cachedBagResult
local cachedQualifyingFoods
local cachedFoodScanComplete = false
local cachedFoodSupply
local gourmandScanComplete = false
local cachedGourmandRank

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
		table.insert(normalizedLines, ns.NormalizeTooltipText(ns.TooltipLineText(line)))
	end
	local bonuses = {}
	for _, definition in ipairs(definitions) do
		local terms = {}
		local function addTerm(candidate)
			if type(candidate) == "string" then
				local term = ns.NormalizeTooltipText(candidate):gsub("%%[ds]", "")
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
	cachedFoodSupply = nil
	cachedFoodScanComplete = false
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
						bonusPercent = ns.GetExperienceBonusPercent(tooltipData)
						if type(bonusPercent) == "number" then
							foodTooltipCache[itemID] = bonusPercent
							foodStatsCache[itemID] = tooltipFoodStats(tooltipData)
						elseif bonusPercent == false and ns.HasItemUseDescription(tooltipData) then
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
	cachedFoodScanComplete = not unresolvedTooltip
	if unresolvedTooltip then
		return bestBonusPercent > 0 and bestBonusPercent or nil
	end
	cachedBagResult = bestBonusPercent > 0 and bestBonusPercent or false
	return cachedBagResult
end

function ns.InvalidateFoodBagScan(itemID)
	cachedBagResult = nil
	cachedQualifyingFoods = nil
	cachedFoodSupply = nil
	cachedFoodScanComplete = false
	if itemID then
		foodTooltipCache[itemID] = nil
		foodStatsCache[itemID] = nil
	end
end

function ns.ResetFoodCaches()
	foodTooltipCache = {}
	foodStatsCache = {}
	cachedBagResult = nil
	cachedQualifyingFoods = nil
	cachedFoodSupply = nil
	cachedFoodScanComplete = false
end

function ns.InvalidateFoodDuration()
	gourmandScanComplete = false
	cachedGourmandRank = nil
	cachedFoodSupply = nil
end

function ns.ScanQualifyingFood()
	return hasQualifyingFood()
end

function ns.GetAvailableFoods()
	if cachedQualifyingFoods == nil then
		cachedBagResult = nil
		hasQualifyingFood()
	end
	return cachedQualifyingFoods or {}
end

local function traitValue(api, ...)
	if type(api) ~= "function" then
		return nil
	end
	local success, value = pcall(api, ...)
	if success then
		return value
	end
end

local function gourmandRank()
	if gourmandScanComplete then
		return cachedGourmandRank
	end
	gourmandScanComplete = true
	if not C_Traits then
		return nil
	end
	local configs = {}
	local seen = {}
	local function addConfig(configID, priority)
		if type(configID) ~= "number" then
			return
		end
		if seen[configID] then
			seen[configID].priority = math.max(seen[configID].priority, priority)
		else
			local config = { id = configID, priority = priority }
			seen[configID] = config
			table.insert(configs, config)
		end
	end
	for name, configType in pairs(Enum and Enum.TraitConfigType or {}) do
		local configIDs = traitValue(C_Traits.GetConfigsByType, configType)
		if type(configIDs) == "table" then
			local priority = tostring(name):lower():find("legacy", 1, true) and 2 or 1
			for _, configID in ipairs(configIDs) do
				addConfig(configID, priority)
			end
		end
	end
	addConfig(traitValue(C_ClassTalents and C_ClassTalents.GetActiveConfigID), 0)
	table.sort(configs, function(first, second) return first.priority > second.priority end)
	for _, config in ipairs(configs) do
		local info = traitValue(C_Traits.GetConfigInfo, config.id)
		for _, treeID in ipairs(type(info) == "table" and info.treeIDs or {}) do
			local nodeIDs = traitValue(C_Traits.GetTreeNodes, treeID)
			for _, nodeID in ipairs(type(nodeIDs) == "table" and nodeIDs or {}) do
				local node = traitValue(C_Traits.GetNodeInfo, config.id, nodeID)
				if type(node) == "table" then
					local matches = nodeID == 1225499
					for _, entryID in ipairs(node.entryIDs or {}) do
						local entry = traitValue(C_Traits.GetEntryInfo, config.id, entryID)
						local definitionID = type(entry) == "table" and entry.definitionID
						local definition = definitionID and traitValue(C_Traits.GetDefinitionInfo, definitionID)
						if entryID == 1225499 or definitionID == 1225499
							or (type(definition) == "table" and definition.spellID == 1225499) then
							matches = true
						end
					end
					if matches then
						local rank = node.ranksPurchased
						if rank == nil and type(node.activeEntry) == "table" then rank = node.activeEntry.rank end
						if rank == nil then rank = node.currentRank or node.activeRank end
						if type(rank) == "number" and rank >= 0 and rank <= 3 and rank == math.floor(rank) then
							cachedGourmandRank = rank
							return rank
						end
					end
				end
			end
		end
	end
end

function ns.GetFoodSupply()
	if cachedFoodSupply then
		return cachedFoodSupply
	end
	local count = 0
	local bestBonusPercent = 0
	for _, food in ipairs(ns.GetAvailableFoods()) do
		count = count + food.count
		bestBonusPercent = math.max(bestBonusPercent, food.bonusPercent)
	end
	local rank = gourmandRank()
	local duration = (15 + (rank or 0) * 5) * 60
	cachedFoodSupply = {
		count = count,
		seconds = count * duration,
		perServingSeconds = duration,
		complete = cachedFoodScanComplete,
		isFallback = rank == nil,
		gourmandRank = rank,
		bestBonusPercent = bestBonusPercent > 0 and bestBonusPercent or nil,
	}
	return cachedFoodSupply
end

function ns.GetCachedFoodSupply()
	return cachedFoodSupply
end

function ns.GetFoodSupplyText()
	local supply = ns.GetFoodSupply()
	local template = supply.complete and ForeverSnackTrackL.foodSupply or ForeverSnackTrackL.foodSupplyPartial
	if supply.count == 1 then
		template = supply.complete and ForeverSnackTrackL.foodSupplySingle or ForeverSnackTrackL.foodSupplyPartialSingle
	end
	local message = string.format(template, supply.count, ns.FormatDuration(supply.seconds))
	if not supply.complete and supply.count == 0 then
		message = ForeverSnackTrackL.foodSupplyLoading
	end
	local rankDetail = supply.isFallback and ForeverSnackTrackL.foodSupplyFallback
		or string.format(ForeverSnackTrackL.foodSupplyGourmand, supply.gourmandRank)
	local durationDetail = supply.isFallback and ForeverSnackTrackL.foodSupplyFallbackDuration
		or string.format(ForeverSnackTrackL.foodSupplyDuration, supply.perServingSeconds / 60)
	return message, rankDetail, durationDetail
end

function ns.DebugFoodStatus()
	if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo
		or not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
		ns.DebugPrint("Bag or tooltip API is unavailable.")
		return
	end
	ns.InvalidateFoodBagScan()
	local scannedItems = 0
	local unresolvedItems = 0
	local recognizedFoods = 0
	local bestFoodPercent = 0
	local bagCount = NUM_BAG_SLOTS or 0
	ns.DebugPrint("Scanning carried bags...")
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
					ns.DebugPrint("Item " .. itemID .. ": tooltip data unavailable.")
				else
					local bonusPercent = ns.GetExperienceBonusPercent(tooltipData)
					if bonusPercent == false and not ns.HasItemUseDescription(tooltipData) then
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
						ns.DebugPrint(string.format("Food: %s (ID %d) -> %d%% kill XP", itemName, itemID, bonusPercent))
					else
						for _, candidate in ipairs(ns.DebugTooltipCandidates(tooltipData)) do
							ns.DebugPrint(string.format("Item candidate %s (ID %d): %s", itemName, itemID, candidate))
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
		ns.DebugPrint(string.format("%d item tooltip(s) unavailable; known XP food can still trigger reminders.", unresolvedItems))
	end
	local supply = ns.GetFoodSupply()
	local threshold = ns.db.lowFoodThreshold == 0 and "disabled" or tostring(ns.db.lowFoodThreshold)
	ns.DebugPrint(string.format("Low-stock threshold: %s; qualifying food count: %d (%s).",
		threshold, supply.count, supply.complete and "complete" or "partial"))
	if recognizedFoods == 0 then
		ns.DebugPrint(string.format("No XP food recognized in %d carried item(s).", scannedItems))
	else
		ns.DebugPrint(string.format("Recognized %d XP food item(s); best available bonus is %d%%.", recognizedFoods, bestFoodPercent))
	end
end
