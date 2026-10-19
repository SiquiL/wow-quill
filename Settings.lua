local _, ns = ...
local L = ns.L
local category, bugReport
local GITHUB_URL = "https://github.com/SiquiL/wow-quill"
local ISSUES_URL = GITHUB_URL .. "/issues/new"

-- Read-only field: the game cannot open a browser, so the URL is selected for Ctrl+C
local function LinkBox(parent, url, width)
	local link = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	link:SetSize(width, 24)
	link:SetAutoFocus(false)
	link:SetFontObject("GameFontHighlightSmall")
	link:SetText(url)
	link:SetCursorPosition(0)
	link:SetScript("OnEscapePressed", link.ClearFocus)
	link:SetScript("OnEnterPressed", link.ClearFocus)
	link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	link:SetScript("OnMouseUp", function(self) self:HighlightText() end)
	link:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(url)
			self:HighlightText()
		end
	end)
	return link
end

function ns.ShowBugReport()
	if not bugReport then
		bugReport = ns.Dialog("QuillBugReport", L["Report a bug"], 440, 190)
		local text = bugReport:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", 18, -36)
		text:SetWidth(404)
		text:SetJustifyH("LEFT")
		text:SetText(L["Found a bug or have an idea? Please open an issue on GitHub and describe what happened."])
		ns.StyleText(text)
		local link = LinkBox(bugReport, ISSUES_URL, 396)
		link:SetPoint("TOPLEFT", 24, -86)
		bugReport.link = link
		local hint = bugReport:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", 18, -118)
		hint:SetWidth(404)
		hint:SetJustifyH("LEFT")
		hint:SetText(L["Click the address and press Ctrl+C to copy it. The game cannot open a browser by itself."])
		ns.StyleText(hint)
		local close = CreateFrame("Button", nil, bugReport, "UIPanelButtonTemplate")
		close:SetSize(100, 24)
		close:SetPoint("BOTTOM", 0, 12)
		close:SetText(CLOSE or L["Close"])
		close:SetScript("OnClick", function() bugReport:Hide() end)
		bugReport:SetScript("OnHide", function() link:ClearFocus() end)
	end
	bugReport:Show()
	bugReport.link:SetFocus()
end

function ns.OpenOptions()
	if not category then
		ns.Say(L["The options panel is not available in this client."])
	elseif InCombatLockdown() then
		ns.Say(L["The options cannot be opened in combat."])
	else
		Settings.OpenToCategory(category:GetID())
	end
end

local function PrepareLinkTemplate()
	local mixin = CreateFromMixins(SettingsListElementMixin)
	function mixin:OnLoad()
		SettingsListElementMixin.OnLoad(self)
		local link = LinkBox(self, "", 300)
		self:HookScript("OnHide", function() link:ClearFocus() end)
		link:SetPoint("LEFT", self, "CENTER", -175, 0)
		link:SetScript("OnTextChanged", function(box, userInput)
			if userInput then
				box:SetText(self.url)
				box:HighlightText()
			end
		end)
		local function ShowTooltip(owner)
			GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
			GameTooltip:SetText("GitHub")
			GameTooltip:AddLine(L["Click the address and press Ctrl+C to copy it. The game cannot open a browser by itself."], 1, 1, 1, true)
			GameTooltip:Show()
		end
		link:SetScript("OnEnter", ShowTooltip)
		link:SetScript("OnLeave", function() GameTooltip:Hide() end)
		local button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
		button:SetSize(28, 28)
		button:SetPoint("RIGHT", link, "LEFT", -8, 0)
		button:SetFrameLevel(self:GetFrameLevel() + 10)
		button:RegisterForClicks("LeftButtonUp")
		button:SetScript("OnMouseDown", function()
			C_Timer.After(0, function()
				link:SetFocus()
				link:HighlightText()
			end)
		end)
		button:SetScript("OnEnter", ShowTooltip)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		local logo = button:CreateTexture(nil, "ARTWORK")
		logo:SetPoint("TOPLEFT", 5, -5)
		logo:SetPoint("BOTTOMRIGHT", -5, 5)
		logo:SetTexture("Interface\\AddOns\\Quill\\textures\\GitHubMark")
		self.Link = link
	end
	function mixin:Init(initializer)
		SettingsListElementMixin.Init(self, initializer)
		self.url = self.data.url
		self.Link:SetText(self.url)
		self.Link:SetCursorPosition(0)
	end
	QuillSettingsLinkMixin = mixin
end

local function Register()
	if not (Settings and Settings.RegisterVerticalLayoutCategory
		and CreateSettingsButtonInitializer and CreateSettingsListSectionHeaderInitializer
		and SettingsListElementMixin and Settings.CreateElementInitializer
		and Settings.RegisterAddOnSetting and Settings.CreateDropdown and Settings.CreateControlTextContainer) then
		ns.Say(L["The options panel is not available in this client."])
		return
	end
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory("Quill")
	local theme = Settings.RegisterAddOnSetting(category, "Quill_Theme", "theme", QuillDB.settings,
		"string", L["Theme"], "standard")
	theme:SetValueChangedCallback(function(_, value) ns.SetTheme(value) end)
	Settings.CreateDropdown(category, theme, function()
		local options = Settings.CreateControlTextContainer()
		for _, entry in ipairs(ns.THEMES) do options:Add(entry.id, L[entry.label]) end
		return options:GetData()
	end, L["Changes Quill and its dialogs for all characters."])
	local opacity
	layout:AddInitializer(CreateSettingsButtonInitializer(L["Background color"], L["Choose color"], function()
		ns.PickColor(QuillDB.settings.backgroundColor or { 0.08, 0.08, 0.08 }, function(color, alpha)
			QuillDB.settings.backgroundColor = color
			if opacity and alpha ~= ns.BackgroundOpacity() then
				opacity:SetValue(alpha)
			else
				ns.SetBackgroundOpacity(alpha)
			end
			ns.RefreshAppearance()
		end, ns.BackgroundOpacity())
	end, L["Used by the Custom color theme. Text contrast adjusts automatically. The opacity applies to every theme."], true))
	if Settings.CreateSlider and Settings.CreateSliderOptions then
		opacity = Settings.RegisterAddOnSetting(category, "Quill_BackgroundOpacity", "backgroundOpacity",
			QuillDB.settings, "number", L["Background opacity"], 1)
		opacity:SetValueChangedCallback(function(_, value) ns.SetBackgroundOpacity(value) end)
		local options = Settings.CreateSliderOptions(0, 1, 0.05)
		if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
				return ("%d%%"):format(math.floor(value * 100 + 0.5))
			end)
		end
		Settings.CreateSlider(category, opacity, options,
			L["Transparency of the Quill window and its dialogs in every theme. Text and borders stay opaque."])
	end
	local resetLabel = L["Reset window size and position"]
	layout:AddInitializer(CreateSettingsButtonInitializer(resetLabel, resetLabel, ns.ResetWindow,
		L["Restore the default window size and center it on the screen. Notes and notebooks are not changed."], true))
	local reportLabel = L["Report a bug"]
	layout:AddInitializer(CreateSettingsButtonInitializer(reportLabel, reportLabel, ns.ShowBugReport,
		L["Found a bug or have an idea? Please open an issue on GitHub and describe what happened."], true))
	PrepareLinkTemplate()
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Links"]))
	local link = Settings.CreateElementInitializer("QuillSettingsLinkTemplate", { name = "", title = "GitHub", url = GITHUB_URL })
	link:AddSearchTags("GitHub")
	layout:AddInitializer(link)
	Settings.RegisterAddOnCategory(category)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	Register()
end)
