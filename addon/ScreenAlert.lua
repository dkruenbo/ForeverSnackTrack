local addonName, ns = ...

local function setAlertPosition(frame)
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", ns.db.alertOffsetX / scale, ns.db.alertOffsetY / scale)
end

local function updateAlertAppearance(frame)
	local color = ns.db.screenColor
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
	frame.eatButton:RegisterForClicks("LeftButtonUp")
	frame.eatButton:SetAttribute("useOnKeyDown", false)

	frame.eatDropdownButton = CreateFrame("Button", "ForeverSnackTrackAlertEatDropdownButton", frame, "UIPanelButtonTemplate")
	frame.eatDropdownButton:SetSize(24, 24)
	frame.eatDropdownButton:SetPoint("RIGHT", frame.snoozeButton, "LEFT", -8, 0)
	frame.eatDropdownButton:SetText("v")
	frame.eatDropdownButton:SetScript("OnClick", function()
		if ToggleDropDownMenu then
			ToggleDropDownMenu(1, nil, frame.foodDropdown, "ForeverSnackTrackAlertEatDropdownButton", 0, 0)
		end
	end)

	frame.foodDropdown = CreateFrame("Frame", "ForeverSnackTrackAlertFoodDropdown", frame, "UIDropDownMenuTemplate")
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
	end)

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