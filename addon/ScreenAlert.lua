local addonName, ns = ...

local function setAlertPosition(frame)
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", ns.db.alertOffsetX / scale, ns.db.alertOffsetY / scale)
end

local function updateAlertAppearance(frame, preservePosition)
	local color = ns.db.screenColor
	local iconMode = ns.db.screenIconMode
	local textHeight = type(frame.messageHeight) == "number" and frame.messageHeight or 64
	local lowFoodText = type(frame.lowFoodStatusText) == "string" and frame.lowFoodStatusText or nil
	frame.lowFoodText:SetText(lowFoodText or "")
	local measuredLowFoodHeight = frame.lowFoodText.GetStringHeight and frame.lowFoodText:GetStringHeight()
	local lowFoodTextHeight = lowFoodText
		and math.max(22, type(measuredLowFoodHeight) == "number" and measuredLowFoodHeight + 4 or 22) or 0
	frame:SetSize(iconMode and 48 or 460, iconMode and 48 or textHeight + 84 + lowFoodTextHeight)
	frame.text:SetShown(not iconMode)
	frame.text:SetHeight(textHeight)
	frame.lowFoodText:SetHeight(math.max(18, lowFoodTextHeight - 4))
	frame.lowFoodText:SetShown(not iconMode and not frame.isPreview and lowFoodText ~= nil)
	frame.lowFoodText:ClearAllPoints()
	if lowFoodText then
		frame.lowFoodText:SetPoint("TOP", frame, "TOP", 0, -(textHeight + 20))
	end
	frame.supplyText:SetShown(not iconMode and not frame.isPreview)
	frame.supplyText:ClearAllPoints()
	frame.supplyText:SetPoint("TOP", frame, "TOP", 0, -(textHeight + 20 + lowFoodTextHeight))
	frame.iconTexture:SetShown(iconMode)
	if iconMode then
		frame.iconGlow:Show()
	else
		frame.iconGlow:Hide()
	end
	frame.eatButton:ClearAllPoints()
	if iconMode then
		frame.eatButton:SetAllPoints(frame)
		frame.eatButton:SetText("")
		frame.snoozeButton:Hide()
		frame.dismissButton:Hide()
		frame.eatDropdownButton:Hide()
		frame.eatButton:Show()
	else
		frame.eatButton:SetSize(96, 24)
		frame.eatButton:SetPoint("RIGHT", frame.snoozeButton, "LEFT", -36, 0)
		frame.eatButton:SetText(ForeverSnackTrackL.eatButton)
		frame.snoozeButton:SetShown(not frame.isPreview)
		frame.dismissButton:SetShown(not frame.isPreview)
		frame.eatButton:SetShown(not frame.isPreview and frame.hasFood)
		frame.eatDropdownButton:SetShown(not frame.isPreview and frame.hasFood)
	end
	frame:SetScale(ns.db.screenScale)
	if not preservePosition then
		setAlertPosition(frame)
	end
	frame.text:SetTextColor(color.r, color.g, color.b)
	frame:SetBackdropBorderColor(color.r, color.g, color.b, 0.9)
end

local function setEatFood(frame, itemID, savePreference)
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	for _, food in ipairs(ns.GetAvailableFoods and ns.GetAvailableFoods() or {}) do
		if food.itemID == itemID then
			local macroText = "/use " .. food.itemName
			frame.eatButton:SetAttribute("type", "macro")
			frame.eatButton:SetAttribute("macrotext", macroText)
			frame.eatButton:SetAttribute("type1", "macro")
			frame.eatButton:SetAttribute("macrotext1", macroText)
			frame.selectedFoodID = food.itemID
			if savePreference and ns.db then
				ns.db.selectedFoodItemID = food.itemID
			end
			return true
		end
	end
	return false
end

function ns.RefreshSelectedFood()
	local frame = ns.alertFrame
	if not frame or not ns.db or not frame:IsShown() or frame.isPreview
		or (InCombatLockdown and InCombatLockdown()) then
		return
	end
	local foods = ns.GetAvailableFoods and ns.GetAvailableFoods() or {}
	local selectedID = ns.db.selectedFoodItemID > 0 and ns.db.selectedFoodItemID or frame.selectedFoodID
	local selectedAvailable = false
	for _, food in ipairs(foods) do
		if food.itemID == selectedID then
			selectedAvailable = true
			break
		end
	end
	if not selectedAvailable then
		selectedID = foods[1] and foods[1].itemID
	end
	frame.hasFood = #foods > 0
	if selectedID then
		setEatFood(frame, selectedID)
	else
		frame.eatButton:SetAttribute("type", nil)
		frame.eatButton:SetAttribute("type1", nil)
		frame.eatButton:SetAttribute("macrotext", nil)
		frame.eatButton:SetAttribute("macrotext1", nil)
	end
	updateAlertAppearance(frame)
end

local function showIconTooltip(frame)
	if not ns.db.screenIconMode or not GameTooltip then
		return
	end
	GameTooltip:SetOwner(frame.eatButton, "ANCHOR_RIGHT")
	GameTooltip:SetText("Forever SnackTrack")
	GameTooltip:AddLine(frame.text:GetText(), 1, 1, 1, true)
	if not frame.isPreview then
		for _, food in ipairs(ns.GetAvailableFoods and ns.GetAvailableFoods() or {}) do
			if food.itemID == frame.selectedFoodID then
				GameTooltip:AddLine(string.format("%s (%d%%) x%d", food.itemName, food.bonusPercent, food.count), 1, 1, 1, true)
				if #food.stats > 0 then
					GameTooltip:AddLine(table.concat(food.stats, ", "), 1, 1, 1, true)
				end
				break
			end
		end
		local summary, rankDetail, durationDetail = ns.GetFoodSupplyText()
		GameTooltip:AddLine(summary, 1, 0.85, 0.3, true)
		GameTooltip:AddLine(rankDetail, 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(durationDetail, 0.8, 0.8, 0.8, true)
		local lowFoodStatusText = ns.GetLowFoodStatusText and ns.GetLowFoodStatusText()
		if lowFoodStatusText then
			GameTooltip:AddLine(lowFoodStatusText, 1, 0.85, 0.3, true)
		end
		GameTooltip:AddLine(ns.GetFoodBuffComparisonText(), 0.8, 0.8, 0.8, true)
	end
	GameTooltip:Show()
end

function ns.RefreshFoodSupplyDisplay()
	local frame = ns.alertFrame
	local panel = ns.optionsPanel
	local alertVisible = frame and frame:IsShown() and not frame.isPreview
	local optionsVisible = panel and panel:IsShown()
	if not alertVisible and not optionsVisible then
		return
	end
	local summary, rankDetail, durationDetail = ns.GetFoodSupplyText()
	if alertVisible then
		frame.supplyText:SetText(summary)
		if GameTooltip and GameTooltip:IsOwned(frame.eatButton) then showIconTooltip(frame) end
	end
	if optionsVisible then
		panel.supplyText:SetText(summary .. "\n" .. rankDetail .. "\n" .. durationDetail)
	end
end

local function createAlertFrame()
	local frame = CreateFrame("Frame", "ForeverSnackTrackAlertFrame", UIParent, "BackdropTemplate")
	frame.glowPhase = 0
	frame.glowAlpha = 1
	frame:SetSize(460, 128)
	frame:SetFrameStrata("LOW")
	frame:SetFrameLevel(1)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.04, 0.05, 0.07, 0.94)

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	frame.text:SetPoint("TOP", frame, "TOP", 0, -16)
	frame.text:SetWidth(420)
	frame.text:SetHeight(64)
	frame.text:SetJustifyH("CENTER")
	frame.text:SetWordWrap(true)
	frame.lowFoodText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.lowFoodText:SetWidth(420)
	frame.lowFoodText:SetHeight(18)
	frame.lowFoodText:SetJustifyH("CENTER")
	frame.supplyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.supplyText:SetPoint("TOP", frame, "TOP", 0, -84)
	frame.supplyText:SetWidth(420)
	frame.supplyText:SetHeight(18)
	frame.supplyText:SetJustifyH("CENTER")

	frame.snoozeButton = CreateFrame("Button", "ForeverSnackTrackAlertSnoozeButton", frame, "UIPanelButtonTemplate")
	frame.snoozeButton:SetSize(120, 24)
	frame.snoozeButton:SetPoint("BOTTOM", frame, "BOTTOM", 4, 12)
	frame.snoozeButton:SetScript("OnClick", function()
		ns.SnoozeReminders()
	end)

	frame.dismissButton = CreateFrame("Button", "ForeverSnackTrackAlertDismissButton", frame, "UIPanelButtonTemplate")
	frame.dismissButton:SetSize(100, 24)
	frame.dismissButton:SetPoint("LEFT", frame.snoozeButton, "RIGHT", 8, 0)
	frame.dismissButton:SetScript("OnClick", function()
		ns.DismissReminder()
	end)

	frame.eatButton = CreateFrame("Button", "ForeverSnackTrackAlertEatButton", frame,
		"UIPanelButtonTemplate,InsecureActionButtonTemplate")
	frame.eatButton:SetSize(96, 24)
	frame.eatButton:SetPoint("RIGHT", frame.snoozeButton, "LEFT", -36, 0)
	frame.eatButton:SetText(ForeverSnackTrackL.eatButton or ForeverSnackTrackLocales.enUS.eatButton)
	frame.eatButton:EnableMouse(true)
	frame.eatButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.eatButton:SetAttribute("useOnKeyDown", false)
	frame.eatButton:SetAttribute("type2", "none")
	frame.iconTexture = frame.eatButton:CreateTexture(nil, "OVERLAY")
	frame.iconTexture:SetPoint("TOPLEFT", frame.eatButton, "TOPLEFT", 4, -4)
	frame.iconTexture:SetPoint("BOTTOMRIGHT", frame.eatButton, "BOTTOMRIGHT", -4, 4)
	frame.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Food_15")
	frame.iconGlow = frame.eatButton:CreateTexture(nil, "OVERLAY", nil, 1)
	frame.iconGlow:SetPoint("TOPLEFT", frame.eatButton, "TOPLEFT", -14, 14)
	frame.iconGlow:SetPoint("BOTTOMRIGHT", frame.eatButton, "BOTTOMRIGHT", 14, -14)
	frame.iconGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	frame.iconGlow:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	frame.iconGlow:SetBlendMode("ADD")
	frame.iconGlow:SetVertexColor(1, 0.85, 0.2, 1)
	frame.iconGlow:Hide()
	frame.eatButton:SetScript("OnEnter", function() showIconTooltip(frame) end)
	frame.eatButton:SetScript("OnLeave", function()
		if GameTooltip and GameTooltip:IsOwned(frame.eatButton) then GameTooltip:Hide() end
	end)
	frame.eatButton:SetScript("PostClick", function(_, mouseButton)
		if mouseButton == "RightButton" and ns.db.screenIconMode and not frame.isPreview
			and ToggleDropDownMenu and UIDropDownMenu_Initialize
			and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
			ToggleDropDownMenu(1, nil, frame.foodDropdown, "ForeverSnackTrackAlertEatButton", 0, 0)
		end
	end)

	frame.eatDropdownButton = CreateFrame("Button", "ForeverSnackTrackAlertEatDropdownButton", frame, "UIPanelButtonTemplate")
	frame.eatDropdownButton:SetSize(24, 24)
	frame.eatDropdownButton:SetPoint("RIGHT", frame.snoozeButton, "LEFT", -8, 0)
	frame.eatDropdownButton:SetText("v")
	frame.eatDropdownButton:SetScript("OnClick", function()
		if ToggleDropDownMenu and UIDropDownMenu_Initialize
			and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
			ToggleDropDownMenu(1, nil, frame.foodDropdown, "ForeverSnackTrackAlertEatDropdownButton", 0, 0)
		end
	end)

	frame.foodDropdown = CreateFrame("Frame", "ForeverSnackTrackAlertFoodDropdown", frame, "UIDropDownMenuTemplate")
	if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
		UIDropDownMenu_Initialize(frame.foodDropdown, function(_, level)
			if level ~= 1 then
				return
			end
			local foods = ns.GetAvailableFoods and ns.GetAvailableFoods() or {}
			for _, item in ipairs(foods) do
				local food = item
				local info = UIDropDownMenu_CreateInfo()
				info.text = string.format("%s (%d%%)", food.itemName, food.bonusPercent)
				if food.count > 1 then
					info.text = info.text .. string.format(" x%d", food.count)
				end
				if #food.stats > 0 then
					info.text = info.text .. " - " .. table.concat(food.stats, ", ")
				end
				info.checked = frame.selectedFoodID == food.itemID
				info.func = function()
					setEatFood(frame, food.itemID, true)
				end
				UIDropDownMenu_AddButton(info, level)
			end
			if ns.db.screenIconMode and not frame.isPreview then
				local snoozeInfo = UIDropDownMenu_CreateInfo()
				snoozeInfo.text = string.format(ForeverSnackTrackL.snoozeButton, ns.db.snoozeMinutes)
				snoozeInfo.notCheckable = true
				snoozeInfo.func = ns.SnoozeReminders
				UIDropDownMenu_AddButton(snoozeInfo, level)
				local dismissInfo = UIDropDownMenu_CreateInfo()
				dismissInfo.text = ForeverSnackTrackL.dismissButton
				dismissInfo.notCheckable = true
				dismissInfo.func = ns.DismissReminder
				UIDropDownMenu_AddButton(dismissInfo, level)
			end
		end)
	end

	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		local centerX, centerY = UIParent:GetCenter()
		local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
		ns.db.alertOffsetX = x * scale - centerX
		ns.db.alertOffsetY = y * scale - centerY
		setAlertPosition(self)
	end)
	frame.eatButton:RegisterForDrag("LeftButton")
	frame.eatButton:SetScript("OnDragStart", function()
		if ns.db.screenIconMode then frame:GetScript("OnDragStart")(frame) end
	end)
	frame.eatButton:SetScript("OnDragStop", function()
		if ns.db.screenIconMode then frame:GetScript("OnDragStop")(frame) end
	end)
	frame:SetScript("OnHide", function()
		if GameTooltip and GameTooltip:IsOwned(frame.eatButton) then GameTooltip:Hide() end
		if CloseDropDownMenus then CloseDropDownMenus() end
	end)
	frame:SetScript("OnUpdate", function(self, elapsed)
		if ns.db.screenIconMode then
			self.glowPhase = (self.glowPhase + elapsed) % 1.2
			self.glowAlpha = 0.25 + 0.75 * (0.5 + 0.5 * math.cos(self.glowPhase * math.pi * 2 / 1.2))
			self.iconGlow:SetAlpha(self.glowAlpha)
		end
		if not self.remaining then
			return
		end

		self.remaining = self.remaining - elapsed
		if self.remaining <= 0 then
			self.remaining = nil
			self:Hide()
		end
	end)

	setAlertPosition(frame)
	updateAlertAppearance(frame)
	return frame
end

function ns.ShowScreenAlert(message, isPreview, lowFoodStatusText)
	if not ns.db then
		return false
	end

	local frame = ns.alertFrame or createAlertFrame()
	ns.alertFrame = frame
	local displayMessage = message
	if not displayMessage or displayMessage == "" then
		displayMessage = ns.db.screenMessage
	end
	if displayMessage == "" then
		displayMessage = string.format(ForeverSnackTrackL.chatMessage, 5)
	end
	frame.text:SetText(displayMessage)
	local measuredTextHeight = frame.text.GetStringHeight and frame.text:GetStringHeight()
	frame.messageHeight = math.max(64, type(measuredTextHeight) == "number" and measuredTextHeight + 12 or 64)
	frame.lowFoodStatusText = type(lowFoodStatusText) == "string" and lowFoodStatusText or nil
	frame.isPreview = not not isPreview
	frame.hasFood = false
	frame.eatButton:SetAttribute("type", nil)
	frame.eatButton:SetAttribute("type1", nil)
	frame.eatButton:SetAttribute("macrotext", nil)
	frame.eatButton:SetAttribute("macrotext1", nil)
	if isPreview then
		frame.snoozeButton:Hide()
		frame.dismissButton:Hide()
		frame.eatButton:Hide()
		frame.eatDropdownButton:Hide()
	else
		frame.snoozeButton:SetText(string.format(ForeverSnackTrackL.snoozeButton, ns.db.snoozeMinutes))
		frame.dismissButton:SetText(ForeverSnackTrackL.dismissButton)
		frame.snoozeButton:Show()
		frame.dismissButton:Show()
		local foods = ns.GetAvailableFoods and ns.GetAvailableFoods() or {}
		if #foods > 0 then
			frame.hasFood = true
			if not frame.selectedFoodID and ns.db.selectedFoodItemID > 0 then
				frame.selectedFoodID = ns.db.selectedFoodItemID
			end
			if not frame.selectedFoodID or not setEatFood(frame, frame.selectedFoodID) then
				setEatFood(frame, foods[1].itemID)
			end
			frame.eatButton:Show()
			frame.eatDropdownButton:Show()
		else
			frame.eatButton:Hide()
			frame.eatDropdownButton:Hide()
		end
	end
	updateAlertAppearance(frame)
	frame.isPreview = not not isPreview
	frame.remaining = ns.db.screenDuration > 0 and ns.db.screenDuration or (isPreview and 5 or nil)
	frame:Show()
	ns.RefreshFoodSupplyDisplay()
	return true
end

function ns.RefreshAlertButtons()
	if not ns.alertFrame or not ns.db then
		return
	end
	ns.alertFrame.snoozeButton:SetText(string.format(ForeverSnackTrackL.snoozeButton, ns.db.snoozeMinutes))
end

function ns.RefreshAlertMode()
	if ns.alertFrame and ns.db then
		updateAlertAppearance(ns.alertFrame)
		if GameTooltip and GameTooltip:IsOwned(ns.alertFrame.eatButton) then GameTooltip:Hide() end
		if CloseDropDownMenus then CloseDropDownMenus() end
	end
end

function ns.SetLowFoodStatusText(text)
	local frame = ns.alertFrame
	if not frame or frame.isPreview then
		return
	end
	frame.lowFoodStatusText = type(text) == "string" and text or nil
	updateAlertAppearance(frame, true)
end

function ns.HideScreenAlert(preservePreview)
	if not ns.alertFrame then
		return
	end
	if preservePreview and ns.alertFrame.isPreview then
		return
	end
	ns.alertFrame.remaining = nil
	ns.alertFrame:Hide()
end

function ns.RefreshScreenAlert()
	if not ns.alertFrame or not ns.db then
		return
	end

	updateAlertAppearance(ns.alertFrame)
	ns.alertFrame.remaining = ns.db.screenDuration > 0 and ns.db.screenDuration
		or (ns.alertFrame.isPreview and 5 or nil)
end

function ns.ResetScreenAlertPosition()
	if not ns.db then
		return
	end

	ns.db.alertOffsetX = 0
	ns.db.alertOffsetY = 120
	if ns.alertFrame then
		setAlertPosition(ns.alertFrame)
	end
end