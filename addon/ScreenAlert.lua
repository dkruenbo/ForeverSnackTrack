local addonName, ns = ...

local function setAlertPosition(frame)
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", ns.db.alertOffsetX / scale, ns.db.alertOffsetY / scale)
end

local function updateAlertAppearance(frame)
	local color = ns.db.screenColor
	local iconMode = ns.db.screenIconMode
	frame:SetSize(iconMode and 48 or 460, iconMode and 48 or 128)
	frame.text:SetShown(not iconMode)
	frame.iconTexture:SetShown(iconMode)
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
	setAlertPosition(frame)
	frame.text:SetTextColor(color.r, color.g, color.b)
	frame:SetBackdropBorderColor(color.r, color.g, color.b, 0.9)
end

local function setEatFood(frame, itemID)
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
			return true
		end
	end
	return false
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
	end
	GameTooltip:Show()
end

local function createAlertFrame()
	local frame = CreateFrame("Frame", "ForeverSnackTrackAlertFrame", UIParent, "BackdropTemplate")
	frame:SetSize(460, 128)
	frame:SetFrameStrata("HIGH")
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
					setEatFood(frame, food.itemID)
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

function ns.ShowScreenAlert(message, isPreview)
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