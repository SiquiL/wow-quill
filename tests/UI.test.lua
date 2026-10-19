-- Regression tests with deterministic font metrics; visual validation still requires WoW.
local objects, named = {}, {}
local Methods = {}
local function Object(kind, parent, template)
	local object = setmetatable({
		kind = kind, parent = parent, template = template,
		shown = true, scripts = {}, hooks = {}, text = "",
	}, { __index = Methods })
	objects[#objects + 1] = object
	return object
end

for _, method in ipairs({
	"SetFrameStrata", "SetClampedToScreen", "SetResizable", "SetMovable", "EnableMouse",
	"RegisterForDrag", "SetAutoFocus", "SetMaxLetters", "SetCursorPosition", "SetScrollChild",
	"SetHighlightTexture", "SetNormalTexture", "SetPushedTexture", "SetFrameLevel", "SetAllPoints",
	"SetColorTexture", "SetTexCoord", "SetTexture", "SetVertexColor", "SetTextColor",
	"SetJustifyH", "SetJustifyV", "SetWordWrap", "SetNonSpaceWrap", "SetEnabled",
	"SetVerticalScroll", "UpdateScrollChildRect", "ClearFocus", "SetFocus", "Enable", "Disable",
	"RegisterEvent", "UnregisterEvent", "RegisterForClicks", "HighlightText",
	"SetOwner", "SetHyperlink", "AddLine", "SetAlpha", "SetDesaturated", "Raise",
}) do
	Methods[method] = function(self, ...)
		self[method .. "Args"] = { ... }
	end
	function Methods:SetFocus() self.focused = true end
	function Methods:ClearFocus() self.focused = false end
	function Methods:HasFocus() return self.focused end
	function Methods:Insert(text) self:SetText(self:GetText() .. text) end
	function Methods:SetChecked(checked) self.checked = checked end
	function Methods:GetChecked() return self.checked end
end
function Methods:SetScript(event, fn) self.scripts[event] = fn end
function Methods:HookScript(event, fn) self.hooks[event] = fn end
function Methods:SetPoint(...) self.point = { ... } end
function Methods:ClearAllPoints() self.point = nil end
function Methods:GetPoint() return unpack(self.point) end
function Methods:SetResizeBounds(...) self.bounds = { ... } end
function Methods:SetSize(width, height)
	if self.bounds then
		width = math.max(self.bounds[1], math.min(self.bounds[3], width))
		height = math.max(self.bounds[2], math.min(self.bounds[4], height))
	end
	self.width, self.height = width, height
	if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, width, height) end
end
function Methods:GetSize() return self.width, self.height end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:SetWidth(width) self.width = width end
function Methods:SetHeight(height) self.height = height end
function Methods:GetFrameLevel() return 1 end
function Methods:StartMoving() self.moving = true end
function Methods:StartSizing(point) self.sizing = point end
function Methods:StopMovingOrSizing() self.moving, self.sizing = nil, nil end
function Methods:Hide()
	self.shown = false
	if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:Show() self.shown = true end
function Methods:IsShown() return self.shown end
function Methods:SetShown(shown) self.shown = shown end
function Methods:SetText(text)
	self.text = text
	if self.hooks.OnTextChanged then self.hooks.OnTextChanged(self, false) end
end
function Methods:GetText() return self.text end
function Methods:EnableMouse(enabled) self.mouse = enabled end
function Methods:GetCursorPosition() return self.SetCursorPositionArgs and self.SetCursorPositionArgs[1] or 0 end
function Methods:GetScript(event) return self.scripts[event] end
function Methods:GetParent() return self.parent end
function Methods:SetFontObject()
	self.font, self.fontSize = "Fonts\\FRIZQT__.TTF", 12
end
function Methods:SetFont(path, size, flags)
	self.font, self.fontSize, self.flags = path, size, flags
	return true
end
function Methods:GetFont() return self.font, self.fontSize, self.flags end
function Methods:GetStringWidth()
	local text = self.text:gsub("||", "|"):gsub("%s+$", "")
	local _, characters = text:gsub("[^\128-\191]", "")
	return characters * self.fontSize * (self.font:find("Bold", 1, true) and 0.55 or 0.5)
end
function Methods:GetStringHeight()
	return math.max(1, math.ceil(self:GetStringWidth() / self.width)) * self.fontSize * 1.35
end
function Methods:CreateFontString() return Object("FontString", self) end
function Methods:CreateTexture(_, layer)
	local texture = Object("Texture", self)
	texture.layer = layer
	return texture
end
function Methods:GetObjectType() return self.kind end
function Methods:GetDrawLayer() return self.layer end
function Methods:GetRegions()
	local regions = {}
	for _, object in ipairs(objects) do
		if object.parent == self and (object.kind == "Texture" or object.kind == "FontString") then
			regions[#regions + 1] = object
		end
	end
	return unpack(regions)
end

_G.UIParent = Object("Frame")
_G.UISpecialFrames = {}
_G.CreateFrame = function(kind, name, parent, template)
	local object = Object(kind, parent, template)
	if name then named[name] = object end
	if template == "BasicFrameTemplateWithInset" then
		object.Bg = object:CreateTexture(nil, "BACKGROUND")
		object.InsetBg = object:CreateTexture(nil, "BACKGROUND")
		object.unnamedBackground = object:CreateTexture(nil, "BACKGROUND")
		object.TitleBg = object:CreateTexture(nil, "BACKGROUND")
		object.TopTileStreaks = object:CreateTexture(nil, "BACKGROUND")
		object.border = object:CreateTexture(nil, "BORDER")
		object.Inset = Object("Frame", object)
		object.Inset.Bg = object.Inset:CreateTexture(nil, "BACKGROUND")
	end
	if template == "InputScrollFrameTemplate" then
		object.EditBox = Object("EditBox", object)
		object.EditBox.Instructions = Object("FontString", object.EditBox)
	elseif template == "InputBoxInstructionsTemplate" then
		object.Instructions = Object("FontString", object)
	end
	return object
end
_G.FauxScrollFrame_Update = function(frame, total, visible, rowHeight)
	frame.total, frame.visible, frame.rowHeight = total, visible, rowHeight
end
_G.FauxScrollFrame_GetOffset = function() return 0 end
_G.FauxScrollFrame_OnVerticalScroll = function(_, _, _, refresh) refresh() end
_G.YES, _G.NO = "Yes", "No"
_G.UnitGUID = function() return "Player-A" end
_G.time = function() return 12345 end
_G.SlashCmdList, _G.StaticPopupDialogs = {}, {}
_G.GameTooltip = Object("Tooltip")
local hooks, clickedLink = {}, nil
_G.hooksecurefunc = function(target, name, callback)
	if type(target) == "string" then name, callback = target, name end
	hooks[name] = callback
end
_G.ChatFrameUtil = { InsertLink = function() end }
_G.SetItemRef = function(link) clickedLink = link end
_G.InCombatLockdown = function() return false end
local now, controlDown, shiftDown, popup = 100, false, false, nil
_G.GetTime = function() return now end
_G.IsControlKeyDown = function() return controlDown end
_G.IsShiftKeyDown = function() return shiftDown end
_G.StaticPopup_Show = function(_, text, _, onAccept) popup = { text = text, accept = onAccept } end

local text = table.concat({
	"# H1", "## H2", "### H3", "#### H4", "##### H5", "###### H6", "",
	"plain **bold** *italic* **bolditalic *both* end** ~~gone~~", "",
	"|| Left || Center || Right ||", "|| :--- || :---: || ---: ||", "|| **cell** || centered || value ||", "",
	"```", "**literal**", "```", "",
	string.rep("wrapword ", 16) .. "lastword",
	"", "|cffa335ee|Hitem:123:0|h[Test Item]|h|r |Hquest:456:10|h[Quest]|h",
}, "\n")
_G.QuillDB = { notes = {}, settings = { mode = "read" } }
for id = 1, 60 do
	QuillDB.notes[id] = { title = "Note " .. id, text = id == 1 and text or "" }
end
local ns = {
	L = setmetatable({}, { __index = function(_, key) return key end }),
}
assert(loadfile("Core.lua"))("Quill", ns)
local eventFrame = objects[#objects]
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "Quill")
assert(loadfile("Markdown.lua"))("Quill", ns)
assert(loadfile("Metadata.lua"))("Quill", ns)
assert(loadfile("Wiki.lua"))("Quill", ns)
assert(loadfile("Appearance.lua"))("Quill", ns)
assert(loadfile("TextLayout.lua"))("Quill", ns)
assert(loadfile("NotebookUI.lua"))("Quill", ns)
assert(loadfile("UI.lua"))("Quill", ns)
assert(loadfile("Popout.lua"))("Quill", ns)
assert(loadfile("Trash.lua"))("Quill", ns)
ns.OpenNote(1)

local count = 0
local function Check(name, condition)
	count = count + 1
	assert(condition, name)
end
local function Near(actual, expected) return math.abs(actual - expected) < 0.0001 end
local function FindText(value)
	for index = #objects, 1, -1 do
		local object = objects[index]
		if object.kind == "FontString" and object.shown and object.text == value
			and object.parent.parent and object.parent.parent.template == "UIPanelScrollFrameTemplate" then
			return object
		end
	end
	error("Rendered text not found: " .. value)
end
local function VisibleRows()
	local countRows = 0
	for _, object in ipairs(objects) do
		if object.entry and object.parent == named.QuillWindow and object.shown then countRows = countRows + 1 end
	end
	return countRows
end

for word, face in pairs({ plain = "Regular", bold = "Bold", italic = "Italic", both = "BoldItalic" }) do
	local object = FindText(word)
	Check(word .. " uses real font face", object.font == "Interface\\AddOns\\Quill\\fonts\\Lato-" .. face .. ".ttf")
	Check(word .. " uses readable body size", object.fontSize == 13)
end
Check("space between styled words is measured",
	FindText("bold").point[2] > FindText("plain").point[2] + FindText("plain"):GetStringWidth())
for level, size in ipairs({ 22, 19, 17, 15, 14, 13 }) do
	Check("heading " .. level .. " has distinct size", FindText("H" .. level).fontSize == size)
end
local gone, strike = FindText("gone"), false
for _, object in ipairs(objects) do
	if object.kind == "Texture" and object.shown and object.height == 1
		and Near(object.width, gone:GetStringWidth()) and object.point
		and Near(object.point[2], gone.point[2]) then strike = true end
end
Check("strikethrough draws a line", strike)
Check("table header is bold", FindText("Left").font:find("Bold", 1, true))
Check("table cell has inline bold", FindText("cell").font:find("Bold", 1, true))
local reader = FindText("value").parent
Check("table right alignment", Near(FindText("value").point[2] + FindText("value"):GetStringWidth(), reader.width - 6))
Check("table center alignment", Near(FindText("centered").point[2] + FindText("centered"):GetStringWidth() / 2, reader.width / 2))
local function CheckTableBounds()
	local rightEdge = false
	for _, object in ipairs(objects) do
		if object.parent == reader and object.kind == "Texture" and object.shown and object.point then
			local x = object.point[2]
			Check("rendered texture stays within reader width", x + object.width <= reader.width + 0.001)
			if object.width == 1 and Near(x, reader.width - 1) then rightEdge = true end
		end
	end
	Check("table right border is inside visible content", rightEdge)
end
CheckTableBounds()
Check("code preserves markers", FindText("**literal**").fontSize == 12)

local window = named.QuillWindow
window:SetSize(1100, 720)
local wideY = FindText("lastword").point[3]
Check("resize updates table width", Near(FindText("value").point[2] + FindText("value"):GetStringWidth(), reader.width - 6))
CheckTableBounds()
Check("tall window adds tree rows", VisibleRows() == 29)
window:SetSize(700, 360)
Check("narrow view reflows text", FindText("lastword").point[3] < wideY)
CheckTableBounds()
Check("short window hides extra rows", VisibleRows() == 11)

local handle
for _, object in ipairs(objects) do
	if object.SetNormalTextureArgs then handle = object end
end
handle.scripts.OnMouseDown(handle, "LeftButton")
Check("handle starts bottom-right sizing", window.sizing == "BOTTOMRIGHT")
window:SetSize(1000, 700)
handle.scripts.OnMouseUp(handle, "LeftButton")
Check("handle stops sizing", window.sizing == nil)
Check("resized dimensions saved", QuillDB.settings.window.width == 1000 and QuillDB.settings.window.height == 700)

local questButton
for _, object in ipairs(objects) do
	if object.link == "quest:456:10" and object.shown then questButton = object end
end
Check("native link has click target", questButton ~= nil)
questButton.scripts.OnClick(questButton, "LeftButton")
Check("native link uses game click handler", clickedLink == "quest:456:10")
questButton.scripts.OnEnter(questButton)
Check("quest link shows tooltip", GameTooltip.SetHyperlinkArgs[1] == "quest:456:10")
ns.OpenNote(1, "edit")
local editBox
for _, object in ipairs(objects) do
	if object.template == "InputScrollFrameTemplate" then editBox = object.EditBox end
end
local chatLink = "|Hitem:789|h[Inserted]|h"
Check("chat insertion requires editor focus", not ns.InsertChatLink(chatLink))
editBox:SetFocus()
hooks.InsertLink(chatLink)
Check("shift-click hook inserts and saves raw hyperlink", ns.GetNote(1).text:sub(-#chatLink) == chatLink)
ns.OpenNote(1, "read")
Check("chat hook does not edit read mode", not ns.InsertChatLink(chatLink))
window:Hide()
Check("chat hook does not edit hidden window", not ns.InsertChatLink(chatLink))
ns.OpenNote(1)

ns.ShowNotebookManager()
local manager = named.QuillNotebookManager
manager.name:SetText("Dungeon")
manager.scope:SetChecked(true)
local function FindButton(parent, label)
	for _, object in ipairs(objects) do
		if object.parent == parent and object.text == label and object.kind == "Button" then return object end
	end
	error("Button not found: " .. label)
end
FindButton(manager, "Save").scripts.OnClick()
local created = ns.ActiveNotebook()
Check("notebook dialog creates character notebook", ns.GetNotebook(created).title == "Dungeon" and ns.GetNotebook(created).owner == "Player-A")
ns.ShowNotebookManager(created)
manager.name:SetText("Dungeon renamed")
manager.parentButton.scripts.OnClick()
local parentChooser = named.QuillNotebookChooser
Check("parent picker replaces manager", parentChooser:IsShown() and not manager:IsShown())
parentChooser:Hide()
Check("canceling picker restores manager and draft", manager:IsShown() and manager.name:GetText() == "Dungeon renamed")
manager.parentButton.scripts.OnClick()
parentChooser.rows[1].scripts.OnClick(parentChooser.rows[1])
Check("choosing top level restores manager", manager:IsShown() and not parentChooser:IsShown() and manager.parentId == nil)
Check("parent picker preserves visibility draft", manager.scope:GetChecked())
manager.parentButton.scripts.OnClick()
parentChooser.rows[2].scripts.OnClick(parentChooser.rows[2])
Check("parent picker applies notebook selection", manager.parentId == QuillDB.defaultNotebook)
FindButton(manager, "Save").scripts.OnClick()
Check("notebook dialog renames notebook", ns.GetNotebook(created).title == "Dungeon renamed")
local chosen
ns.ChooseNotebook("Choose", function(id) chosen = id end, created, true)
local chooser = named.QuillNotebookChooser
Check("parent picker contains root choice", chooser.entries[1].path == "Top level")
chooser.rows[1].scripts.OnClick(chooser.rows[1])
Check("root choice clears parent", chosen == nil)
ns.OpenNote(1)
local move = FindButton(window, "Move note")
move.scripts.OnClick()
local destination
for _, row in ipairs(chooser.rows) do
	if row.entry and row.entry.id == created then destination = row end
end
Check("move dialog lists nested notebook", destination ~= nil)
destination.scripts.OnClick(destination)
Check("move dialog moves note into selected notebook", ns.GetNote(1).notebook == created and ns.ActiveNotebook() == created)
Check("opening moved note expands its ancestors", VisibleRows() > 1)
local rootEntry
for _, object in ipairs(objects) do
	if object.parent == window and object.entry and object.entry.kind == "notebook" and object.entry.id == QuillDB.defaultNotebook then
		rootEntry = object
		break
	end
end
rootEntry.scripts.OnClick(rootEntry)
Check("tree click selects and collapses notebook", ns.ActiveNotebook() == QuillDB.defaultNotebook and VisibleRows() == 1)
rootEntry.scripts.OnClick(rootEntry)
Check("second tree click expands notebook", VisibleRows() > 1)
ns.OpenNote(1)

ns.ResetWindow()
Check("reset restores size and position", window.width == 780 and window.height == 520
	and window.point[1] == "CENTER" and window.point[4] == 0 and window.point[5] == 0)
Check("reset keeps notebooks and notes", ns.GetNotebook(created) ~= nil and ns.GetNote(1) ~= nil)
window:SetSize(1000, 700)
handle.scripts.OnMouseUp(handle, "LeftButton")

assert(loadfile("UI.lua"))("Quill", ns)
ns.OpenNote(1)
Check("saved dimensions restored", named.QuillWindow.width == 1000 and named.QuillWindow.height == 700)
QuillDB.settings.window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
assert(loadfile("UI.lua"))("Quill", ns)
ns.OpenNote(1)
Check("old settings retain default size", named.QuillWindow.width == 780 and named.QuillWindow.height == 520)

-- Before a client restart the bundled font files are missing and SetFont leaves no font
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local SetFont = Methods.SetFont
function Methods:SetFont(path, size, flags)
	if path:find("Lato", 1, true) then
		self.font = nil
		return false
	end
	return SetFont(self, path, size, flags)
end
assert(loadfile("UI.lua"))("Quill", ns)
ns.OpenNote(1)
local fallback
for index = #objects, 1, -1 do
	if objects[index].kind == "FontString" and objects[index].text == "bold" then
		fallback = objects[index]
		break
	end
end
Check("missing font falls back to game font", fallback.font == STANDARD_TEXT_FONT and fallback.flags == "")
Methods.SetFont = SetFont

local opened
local initializers = {}
local themeSetting, themeOptions
local registered, sliders = {}, {}
_G.CreateSettingsButtonInitializer = function(label, buttonText, callback, tooltip, standard)
	return { label = label, buttonText = buttonText, callback = callback, tooltip = tooltip, standard = standard }
end
_G.CreateSettingsListSectionHeaderInitializer = function(label) return { header = label } end
_G.CreateFromMixins = function(source)
	local result = {}
	for key, value in pairs(source) do result[key] = value end
	return result
end
_G.SettingsListElementMixin = {
	OnLoad = function() end,
	Init = function(self, initializer) self.data = initializer.data end,
}
_G.C_Timer = { After = function(_, callback) callback() end }
_G.Settings = {
	RegisterAddOnSetting = function(_, _, key, settings, _, _, default)
		if settings[key] == nil then settings[key] = default end
		local setting = {
			SetValueChangedCallback = function(self, callback) self.callback = callback end,
			GetValue = function() return settings[key] end,
			SetValue = function(self, value)
				settings[key] = value
				if self.callback then self.callback(self, value) end
			end,
		}
		registered[key] = setting
		if key == "theme" then themeSetting = setting end
		return setting
	end,
	CreateDropdown = function(_, _, options) themeOptions = options end,
	CreateSliderOptions = function(min, max, step) return { min = min, max = max, step = step } end,
	CreateSlider = function(_, setting, options) sliders[#sliders + 1] = { setting = setting, options = options } end,
	CreateControlTextContainer = function()
		local data = {}
		return {
			Add = function(_, key, label) data[#data + 1] = { key = key, label = label } end,
			GetData = function() return data end,
		}
	end,
	RegisterVerticalLayoutCategory = function(name)
		Check("settings category name", name == "Quill")
		return { GetID = function() return 42 end }, {
			AddInitializer = function(_, initializer) initializers[#initializers + 1] = initializer end,
		}
	end,
	CreateElementInitializer = function(template, data)
		return { template = template, data = data, AddSearchTags = function(self, tag) self.tag = tag end }
	end,
	RegisterAddOnCategory = function(category) opened = category end,
	OpenToCategory = function(id) opened = id end,
}
assert(loadfile("Settings.lua"))("Quill", ns)
eventFrame = objects[#objects]
eventFrame.scripts.OnEvent(eventFrame)
Check("settings lists every theme", #themeOptions() == 2)
Check("settings uses native button rows", initializers[2].standard and initializers[3].standard)
Check("settings reset row", initializers[2].label == "Reset window size and position")
initializers[2].callback()
Check("settings reset clears saved dimensions", QuillDB.settings.window == nil)
Check("settings links section", initializers[4].header == "Links")
Check("settings uses registered link template", initializers[5].template == "QuillSettingsLinkTemplate")
local linkRow = Object("Frame")
QuillSettingsLinkMixin.OnLoad(linkRow)
QuillSettingsLinkMixin.Init(linkRow, initializers[5])
local urlBox = linkRow.Link
Check("settings links to Quill GitHub repository", urlBox.text == "https://github.com/SiquiL/wow-quill")
urlBox.text = "edited"
urlBox.scripts.OnTextChanged(urlBox, true)
Check("repository field remains copy-only", urlBox.text == "https://github.com/SiquiL/wow-quill")
local linkButton
for _, object in ipairs(objects) do
	if object.parent == linkRow and object.kind == "Button" then linkButton = object end
end
linkButton.scripts.OnMouseDown()
Check("GitHub icon focuses URL", urlBox.focused)
urlBox.scripts.OnMouseUp(urlBox, "LeftButton")
Check("URL mouse selection ignores button argument", #urlBox.HighlightTextArgs == 0)
linkRow.hooks.OnHide()
Check("hiding settings row releases URL focus", not urlBox.focused)
QuillSettingsLinkMixin.Init(linkRow, { data = { url = "https://example.org" } })
urlBox.text = "edited again"
urlBox.scripts.OnTextChanged(urlBox, true)
Check("recycled link row uses current URL", urlBox.text == "https://example.org")
ns.OpenOptions()
Check("options opens Quill category", opened == 42)
local optionsButton
for _, object in ipairs(objects) do
	if object.SetTextureArgs and object.SetTextureArgs[1] == "Interface\\Icons\\Trade_Engineering"
		and object.parent.parent == named.QuillWindow then
		optionsButton = object.parent
	end
end
Check("window has Tally-style options icon", optionsButton and optionsButton.width == 22)
Check("options icon sits at the right end of the toolbar", optionsButton.point[1] == "TOPRIGHT"
	and optionsButton.point[4] == -12 and optionsButton.point[5] == -30)
opened = nil
optionsButton.scripts.OnClick()
Check("window options button opens Quill category", opened == 42)
optionsButton.scripts.OnEnter(optionsButton)
Check("options icon has localized tooltip", GameTooltip:GetText() == "Options" and GameTooltip:IsShown())
optionsButton.scripts.OnLeave()
Check("options icon hides tooltip on leave", not GameTooltip:IsShown())
opened = nil
SlashCmdList.QUILL("options")
Check("slash command opens options", opened == 42)
Check("Quill uses its canonical slash command", SLASH_QUILL1 == "/quill")
opened = nil
Quill_OnAddonCompartmentClick(nil, "RightButton")
Check("addon compartment opens options on right click", opened == 42)
_G.InCombatLockdown = function() return true end
opened = nil
ns.OpenOptions()
Check("options blocked in combat", opened == nil)
optionsButton.scripts.OnClick()
Check("window options button respects combat restriction", opened == nil)
optionsButton.scripts.OnEnter(optionsButton)
Check("options tooltip explains combat restriction",
	GameTooltip.AddLineArgs[1] == "The options cannot be opened in combat.")
optionsButton.scripts.OnLeave()

local inTitleBar = false
for _, object in ipairs(objects) do
	if object.parent == window and object.template == "UIMenuButtonStretchTemplate" then inTitleBar = true end
end
Check("window title bar has no report button", not inTitleBar)
Check("settings report row", initializers[3].label == "Report a bug")
initializers[3].callback()
local report = named.QuillBugReport
Check("report button opens bug dialog", report ~= nil and report:IsShown())
local issueBox
for _, object in ipairs(objects) do
	if object.parent == report and object.kind == "EditBox" then issueBox = object end
end
Check("bug dialog shows issue URL", issueBox.text == "https://github.com/SiquiL/wow-quill/issues/new")
Check("bug dialog focuses URL for copying", issueBox.focused)
issueBox.text = "edited"
issueBox.scripts.OnTextChanged(issueBox, true)
Check("issue URL remains copy-only", issueBox.text == "https://github.com/SiquiL/wow-quill/issues/new")
FindButton(report, "Close").scripts.OnClick()
Check("bug dialog closes", not report:IsShown() and not issueBox.focused)

ns.UpdateNote(1, "text", '<font color="#9d9d9d">**Poor**</font> <font color="white">Common</font>\n\n'
	.. '| Quality |\n| --- |\n| <font color="orange">Legendary</font> |')
ns.OpenNote(1, "read")
local poor, common, legendary = FindText("Poor"), FindText("Common"), FindText("Legendary")
Check("HTML hex color reaches rendered text", poor.SetTextColorArgs[1] == 157 / 255
	and poor.SetTextColorArgs[2] == 157 / 255 and poor.SetTextColorArgs[3] == 157 / 255)
Check("HTML named color reaches rendered text", common.SetTextColorArgs[1] == 1
	and common.SetTextColorArgs[2] == 1 and common.SetTextColorArgs[3] == 1)
Check("HTML color renders in table cell", legendary.SetTextColorArgs[1] == 1
	and legendary.SetTextColorArgs[2] == 165 / 255 and legendary.SetTextColorArgs[3] == 0)

ns.UpdateNote(1, "text", "---\nstatus: open\ntags: [raid]\n---\n[[Note 2||Other note]] #raid/tank")
ns.OpenNote(1, "read")
local wikiButton, tagButton, propertyToggle
for _, object in ipairs(objects) do
	if object.kind == "Button" and object:IsShown() then
		if object.wiki == "Note 2" then wikiButton = object end
		if object.tag == "raid/tank" then tagButton = object end
		if object.properties then propertyToggle = object end
	end
end
Check("wiki alias is rendered", FindText("Other").text == "Other")
Check("wiki link creates click target", wikiButton ~= nil)
wikiButton.scripts.OnClick(wikiButton)
Check("wiki click opens linked note", QuillDB.settings.selected == 2)
ns.OpenNote(1, "read")
tagButton.scripts.OnClick(tagButton)
local searchBox
for _, object in ipairs(objects) do
	if object.parent == named.QuillWindow and object.template == "SearchBoxTemplate" then searchBox = object end
end
Check("tag click activates filter", searchBox:GetText() == "tag:raid/tank")
Check("tag filter retains matching note", #ns.SortedNotes(searchBox:GetText()) == 1)
propertyToggle.scripts.OnClick(propertyToggle)
Check("properties expand in read view", FindText("status:").text == "status:")
searchBox:SetText("")

local menuRoot
local function MenuRoot()
	local root = { entries = {} }
	function root:CreateButton(label, callback) self.entries[#self.entries + 1] = { label = label, callback = callback } end
	function root:CreateTitle(label) self.entries[#self.entries + 1] = { label = label, title = true } end
	function root:CreateRadio(label, isSelected, callback)
		self.entries[#self.entries + 1] = { label = label, selected = isSelected, callback = callback }
	end
	return root
end
_G.MenuUtil = { CreateContextMenu = function(owner, generator) menuRoot = MenuRoot(); generator(owner, menuRoot) end }
Check("tag list collects property and inline tags", table.concat(ns.AllTags(), ",") == "raid,raid/tank")
FindButton(named.QuillWindow, "#").scripts.OnClick(FindButton(named.QuillWindow, "#"))
Check("tag menu lists all tags", #menuRoot.entries == 3 and menuRoot.entries[3].label == "#raid/tank")
menuRoot.entries[3].callback()
Check("tag menu applies filter", searchBox:GetText() == "tag:raid/tank" and menuRoot.entries[3].selected())
menuRoot.entries[1].callback()
Check("tag menu can clear filter", searchBox:GetText() == "")
_G.MenuUtil = nil

local titleInput
for _, object in ipairs(objects) do
	if object.parent == named.QuillWindow and object.template == "InputBoxInstructionsTemplate" then titleInput = object end
end
local windowWidth, windowHeight = named.QuillWindow:GetSize()
Check("title field leaves room for toolbar buttons", titleInput:GetWidth() == windowWidth - 534)
named.QuillWindow:SetSize(windowWidth + 100, windowHeight)
Check("resized title field stays clear of toolbar buttons", titleInput:GetWidth() == windowWidth + 100 - 534)
named.QuillWindow:SetSize(windowWidth, windowHeight)
local sibling = assert(ns.CreateNote("Sibling", "", ns.GetNote(1).notebook))
ns.OpenNote(1, "edit")
titleInput.text = "sibling"
titleInput.hooks.OnTextChanged(titleInput, true)
Check("duplicate title is not saved", ns.GetNote(1).title == "Note 1" and titleInput.SetTextColorArgs[2] < 0.5)
titleInput.hooks.OnEditFocusLost(titleInput)
Check("duplicate title reverts on focus loss", titleInput:GetText() == "Note 1" and titleInput.SetTextColorArgs[2] == 1)
ns.DeleteNote(sibling)
ns.OpenNote(1, "read")

local picker
_G.ColorPickerFrame = {
	SetupColorPickerAndShow = function(_, info) picker = info end,
	GetColorRGB = function() return 0.9, 0.8, 0.7 end,
}
ns.ShowNotebookManager(created)
FindButton(manager, "Custom color").scripts.OnClick()
picker.swatchFunc()
Check("notebook color picker changes only draft", manager.color[1] == 0.9 and ns.GetNotebook(created).color == nil)
picker.cancelFunc()
Check("color picker cancel restores draft", manager.color[1] == 1)
FindButton(manager, "Cancel").scripts.OnClick()
ns.ShowNotebookManager(created)
FindButton(manager, "Custom color").scripts.OnClick()
picker.swatchFunc()
FindButton(manager, "Save").scripts.OnClick()
Check("notebook color is persisted on save", ns.GetNotebook(created).color[2] == 0.8)
searchBox:SetText("tag:no-such-tag")
local markerFound = false
for _, object in ipairs(objects) do
	if object.entry and object.entry.id == created and object.entry.kind == "notebook" and object.shown then
		markerFound = object.label.SetTextColorArgs[2] == 0.8
	end
end
Check("notebook name uses its color in tree", markerFound)
searchBox:SetText("")

local themeLabels = {}
for _, option in ipairs(themeOptions()) do themeLabels[#themeLabels + 1] = option.key .. "=" .. option.label end
Check("theme choices are Standard and Custom color", table.concat(themeLabels, ",") == "standard=Standard,solid=Custom color")
themeSetting.callback(nil, "parchment")
Check("removed themes are rejected", QuillDB.settings.theme ~= "parchment")
initializers[1].callback()
picker.swatchFunc()
themeSetting.callback(nil, "solid")
Check("solid theme saves chosen color", QuillDB.settings.backgroundColor[1] == 0.9)
Check("solid theme adjusts text contrast", select(1, ns.ThemeColor("body")) < 0.2)
local solidFound = false
for _, object in ipairs(objects) do
	if object.parent == named.QuillWindow and object.shown and object.SetColorTextureArgs
		and object.SetColorTextureArgs[1] == 0.9 and object.SetColorTextureArgs[2] == 0.8 then
		solidFound = true
	end
end
Check("custom color applied to main window", solidFound)
themeSetting.callback(nil, "standard")
Check("standard theme restores light text", select(1, ns.ThemeColor("body")) == 1)
local windowBg = named.QuillWindow.Bg
Check("standard theme starts opaque", windowBg.SetAlphaArgs[1] == 1 and named.QuillWindow.Inset.Bg.SetAlphaArgs[1] == 1)
Check("settings has opacity slider", #sliders == 1 and sliders[1].setting == registered.backgroundOpacity
	and sliders[1].options.min == 0 and sliders[1].options.max == 1)
registered.backgroundOpacity:SetValue(0.4)
Check("opacity applies to standard theme", windowBg.SetAlphaArgs[1] == 0.4 and named.QuillWindow.Inset.Bg.SetAlphaArgs[1] == 0.4)
Check("standard inset background uses opacity", named.QuillWindow.InsetBg.SetAlphaArgs[1] == 0.4)
Check("opacity is accountwide setting", QuillDB.settings.backgroundOpacity == 0.4)
Check("opacity does not fade text", select(1, ns.ThemeColor("body")) == 1)
_G.ColorPickerFrame.GetColorAlpha = function() return 0.7 end
initializers[1].callback()
Check("custom color picker offers opacity", picker.hasOpacity and picker.opacity == 0.4)
picker.opacityFunc()
Check("picker opacity syncs slider setting", QuillDB.settings.backgroundOpacity == 0.7)
themeSetting.callback(nil, "solid")
local solidAlpha
for _, object in ipairs(objects) do
	if object.parent == named.QuillWindow and object.shown and object.SetColorTextureArgs
		and object.SetColorTextureArgs[1] == 0.9 then
		solidAlpha = object.SetColorTextureArgs[4]
	end
end
Check("custom color uses opacity", solidAlpha == 0.7)
Check("custom color hides template backgrounds", windowBg.SetAlphaArgs[1] == 0)
Check("custom color hides native inset background", named.QuillWindow.InsetBg.SetAlphaArgs[1] == 0)
Check("custom color hides unnamed template backgrounds", named.QuillWindow.unnamedBackground.SetAlphaArgs[1] == 0)
Check("custom color keeps borders opaque", named.QuillWindow.border.SetAlphaArgs == nil)
Check("custom color keeps title bar opaque", named.QuillWindow.TitleBg.SetAlphaArgs == nil
	and named.QuillWindow.TopTileStreaks.SetAlphaArgs == nil)
registered.backgroundOpacity:SetValue(0)
Check("fully transparent custom background has no default background underneath",
	named.QuillWindow.InsetBg.SetAlphaArgs[1] == 0 and windowBg.SetAlphaArgs[1] == 0)
picker.cancelFunc()
Check("picker cancel restores opacity", QuillDB.settings.backgroundOpacity == 0.4)
registered.backgroundOpacity:SetValue(1)
themeSetting.callback(nil, "standard")
ns.OpenNote(1, "read")
Check("themes preserve note contents", ns.GetNote(1).text:find("#raid/tank", 1, true))

for _, source in ipairs({
	"---\ntags: #test\n---\n",
	"---\ntags: [test]\n---\n",
}) do
	ns.UpdateNote(1, "text", source)
	ns.OpenNote(1, "read")
	local labels, tagCount, propertyRow, tagRow = {}, 0
	for _, object in ipairs(objects) do
		local ancestor = object.parent
		while ancestor and ancestor ~= named.QuillWindow do ancestor = ancestor.parent end
		if ancestor == named.QuillWindow and object.kind == "FontString" and object.shown and object.parent.parent
			and object.parent.parent.template == "UIPanelScrollFrameTemplate" then
			labels[#labels + 1] = object.text
			if object.text == "tags:" then propertyRow = object.point[3] end
			if object.text == "#test" then tagRow = object.point[3] end
		elseif ancestor == named.QuillWindow and object.kind == "Button" and object.shown and object.tag == "test" then
			tagCount = tagCount + 1
		end
	end
	Check("tags render without YAML brackets or quotes: " .. table.concat(labels, " "),
		table.concat(labels, " ") == "Properties [-] tags: #test")
	Check("tags render on property line", propertyRow ~= nil and propertyRow == tagRow)
	Check("property tag is clickable exactly once", tagCount == 1)
end

-- Undo and redo
local editorBox
for index = #objects, 1, -1 do
	local object = objects[index]
	if object.kind == "EditBox" and object.parent.template == "InputScrollFrameTemplate" then
		editorBox = object
		break
	end
end
ns.UpdateNote(1, "text", "start")
ns.OpenNote(1, "edit")
local function Type(value)
	editorBox.text = value
	editorBox.hooks.OnTextChanged(editorBox, true)
end
local function Key(key, ctrl, shift)
	controlDown, shiftDown = ctrl, shift
	editorBox.hooks.OnKeyDown(editorBox, key)
	controlDown, shiftDown = false, false
end
Type("start a")
now = now + 0.2
Type("start ab")
now = now + 5
Type("start ab c")
Key("Z", true)
Check("undo reverts the latest typing step", ns.GetNote(1).text == "start ab" and editorBox:GetText() == "start ab")
Key("Z", true)
Check("quick typing is one undo step", ns.GetNote(1).text == "start")
Key("Z", true)
Check("undo stops at the opened text", ns.GetNote(1).text == "start")
Key("Y", true)
Check("ctrl+y redoes", ns.GetNote(1).text == "start ab")
Key("Z", true, true)
Check("ctrl+shift+z redoes", ns.GetNote(1).text == "start ab c")
Key("Z", false)
Check("z without ctrl does not undo", ns.GetNote(1).text == "start ab c")
Key("Z", true)
now = now + 5
Type("start ab x")
Key("Y", true)
Check("typing clears redo", ns.GetNote(1).text == "start ab x")
now = now + 5
editorBox.scripts.OnTabPressed(editorBox)
Key("Z", true)
Check("tab insert is undoable", ns.GetNote(1).text == "start ab x")
ns.UpdateNote(1, "text", "changed elsewhere")
ns.OpenNote(1, "edit")
Key("Z", true)
Check("outside changes start a new history", ns.GetNote(1).text == "changed elsewhere")

-- Favorites
ns.OpenNote(1, "read")
local function IconButtonFor(texture)
	for _, object in ipairs(objects) do
		if object.parent == named.QuillWindow and object.icon and object.icon.SetTextureArgs[1] == texture then return object end
	end
	error("Icon button not found: " .. texture)
end
local function TreeRows()
	local result = {}
	for _, object in ipairs(objects) do
		if object.entry and object.parent == named.QuillWindow and object.shown then result[#result + 1] = object end
	end
	return result
end
local function FindRow(match)
	for _, row in ipairs(TreeRows()) do
		if match(row.entry) then return row end
	end
end
local star = IconButtonFor("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
Check("unpinned star is desaturated", star.icon.SetDesaturatedArgs[1] == true)
star.scripts.OnClick(star)
Check("star pins the note", ns.GetNote(1).pinned == true and star.icon.SetDesaturatedArgs[1] == false)
local favoritesRow = FindRow(function(entry) return entry.kind == "favorites" end)
Check("favorites section heads the tree", favoritesRow ~= nil and TreeRows()[1] == favoritesRow
	and favoritesRow.label.text == "- Favorites")
Check("favorites section lists pinned note", FindRow(function(entry) return entry.favorite and entry.id == 1 end) ~= nil)
favoritesRow.scripts.OnClick(favoritesRow, "LeftButton")
Check("favorites section collapses", favoritesRow.label.text == "+ Favorites"
	and FindRow(function(entry) return entry.favorite end) == nil)
favoritesRow.scripts.OnClick(favoritesRow, "LeftButton")
Check("favorites section expands", FindRow(function(entry) return entry.favorite end) ~= nil)

_G.MenuUtil = { CreateContextMenu = function(owner, generator) menuRoot = MenuRoot(); generator(owner, menuRoot) end }
local otherRow = FindRow(function(entry) return entry.kind == "note" and not entry.favorite and entry.id ~= 1 end)
local otherId = otherRow.entry.id
otherRow.scripts.OnClick(otherRow, "RightButton")
Check("right-click opens note menu without selecting", QuillDB.settings.selected == 1 and #menuRoot.entries == 4
	and menuRoot.entries[2].label == "Add to favorites" and menuRoot.entries[3].label == "Open in small window")
menuRoot.entries[2].callback()
Check("context menu pins note", ns.GetNote(otherId).pinned == true)
otherRow = FindRow(function(entry) return entry.kind == "note" and entry.id == otherId end)
otherRow.scripts.OnClick(otherRow, "RightButton")
Check("context menu offers unpinning", menuRoot.entries[2].label == "Remove from favorites")
menuRoot.entries[2].callback()
Check("context menu unpins note", ns.GetNote(otherId).pinned == nil)
_G.MenuUtil = nil

-- Small note windows
ns.UpdateNote(1, "text", "# Boss\nfirst #phase")
ns.OpenNote(1, "read")
IconButtonFor("Interface\\Icons\\INV_Misc_NoteBlank1B").scripts.OnClick()
local popout = named.QuillNoteWindow1
local function PopoutText(frame, value)
	for _, object in ipairs(objects) do
		if object.kind == "FontString" and object.parent == frame.content and object.shown and object.text == value then
			return object
		end
	end
end
local function PopoutButtons(frame)
	local buttons = {}
	for _, object in ipairs(objects) do
		if object.kind == "Button" and object.parent == frame.content and object.shown then buttons[#buttons + 1] = object end
	end
	return buttons
end
Check("toolbar opens small window", popout ~= nil and popout.shown and popout.heading.text == "Note 1")
Check("small window renders note", PopoutText(popout, "first") ~= nil and PopoutText(popout, "Boss") ~= nil)
Check("small window survives escape", not table.concat(UISpecialFrames, ","):find("QuillNoteWindow", 1, true))
Check("small window uses its own width", popout.content.width == 320 - 20 - 22)
local mainText
for _, object in ipairs(objects) do
	if object.kind == "FontString" and object.shown and object.text == "first" and object.parent ~= popout.content then
		mainText = object
	end
end
Check("main window keeps its own render", mainText ~= nil and mainText.parent.width ~= popout.content.width)
popout:SetSize(400, 300)
Check("resizing small window reflows note", popout.content.width == 400 - 20 - 22)
popout.scripts.OnDragStart(popout)
Check("unlocked small window moves", popout.moving)
popout.scripts.OnDragStop(popout)
Check("small window position is saved", QuillDB.settings.popouts[1].width == 400 and QuillDB.settings.popouts[1].point == "TOPLEFT")
Check("small window links are clickable while unlocked", #PopoutButtons(popout) > 0 and PopoutButtons(popout)[1].mouse == true)
popout.lock.scripts.OnClick(popout.lock)
Check("locked small window lets clicks through", popout.mouse == false and not popout.resize.shown
	and PopoutButtons(popout)[1].mouse == false and QuillDB.settings.popouts[1].locked == true)
Check("locked small window hides text size buttons", not popout.textSize.shown)
Check("locked small window moves text up", popout.scroll.point[3] == -30)
popout.scripts.OnDragStart(popout)
Check("locked small window does not move", not popout.moving)
popout.lock.scripts.OnClick(popout.lock)
Check("unlocked small window leaves room for text size buttons", popout.scroll.point[3] == -56)
Check("unlocked small window takes clicks again", popout.mouse == true and popout.resize.shown
	and PopoutButtons(popout)[1].mouse == true and QuillDB.settings.popouts[1].locked == nil)
ns.UpdateNote(1, "text", "second")
Check("small window follows edits", PopoutText(popout, "second") ~= nil)
ns.OpenNoteWindow(otherId)
local popoutOther = named.QuillNoteWindow2
Check("each note gets its own small window", popoutOther ~= nil and popoutOther.shown and popout.shown)
ns.OpenNoteWindow(1)
Check("reopening reuses the window", named.QuillNoteWindow3 == nil)
ns.DeleteNote(otherId)
Check("deleting a note closes its small window", not popoutOther.shown and popout.shown)
ns.RestoreNote(otherId)

do
	local openButton = IconButtonFor("Interface\\Icons\\INV_Misc_NoteBlank1B")
	Check("popout button sits immediately right of favorite", openButton.point[1] == "LEFT"
		and openButton.point[2] == star and openButton.point[3] == "RIGHT" and openButton.point[4] == 4)
	Check("title starts after both left toolbar icons", titleInput.point[2] == 234 + 2 * 22 + 14)
	Check("lock icon is enlarged", popout.lock.width == 24 and popout.lock.height == 24)
	local mainControls
	for _, object in ipairs(objects) do
		if object.parent == named.QuillWindow and object.increase and object.decrease then
			mainControls = object
		end
	end
	Check("main window has text size controls", mainControls ~= nil)
	ns.OpenNote(1, "read")
	local mainBody
	for _, object in ipairs(objects) do
		if object.kind == "FontString" and object.shown and object.text == "second" then
			local ancestor = object.parent
			while ancestor and ancestor ~= named.QuillWindow do ancestor = ancestor.parent end
			if ancestor then mainBody = object end
		end
	end
	local defaultEditorSize = editorBox.fontSize
	mainControls.increase.scripts.OnClick()
	Check("main text size is saved", QuillDB.settings.textScale == 1.25)
	Check("main editor font grows", editorBox.fontSize == defaultEditorSize * 1.25)
	Check("main read font grows", mainBody.fontSize == 13 * 1.25)
	Check("main zoom does not affect popout", PopoutText(popout, "second").fontSize == 13)
	ns.OpenNote(1, "edit")
	Check("editor keeps zoom when switching modes", editorBox.fontSize == defaultEditorSize * 1.25)
	ns.OpenNote(1, "read")

	ns.UpdateNote(1, "text", "# Boss\nfirst #phase\n\n```\ncode\n```\n\n| A | B |\n| --- | --- |\n| left | right |")
	popout.textSize.increase.scripts.OnClick()
	Check("popout size is saved per note", QuillDB.settings.popouts[1].textScale == 1.25)
	Check("popout body text grows", PopoutText(popout, "first").fontSize == 13 * 1.25)
	Check("popout heading grows", PopoutText(popout, "Boss").fontSize == 22 * 1.25)
	Check("popout code grows", PopoutText(popout, "code").fontSize == 12 * 1.25)
	Check("popout table text grows", PopoutText(popout, "left").fontSize == 13 * 1.25)
	Check("popout link hitbox grows", PopoutButtons(popout)[1].height == math.ceil(13 * 1.25 * 1.35))
	Check("popout zoom is independent of other windows", QuillDB.settings.textScale == 1.25
		and ns.TextScale(QuillDB.settings.popouts[otherId]) == 1)
	for _ = 1, 10 do popout.textSize.increase.scripts.OnClick() end
	Check("text zoom is capped at 200 percent", popout.target.scale == 2
		and popout.textSize.increase.SetEnabledArgs[1] == false)
	for _ = 1, 10 do popout.textSize.decrease.scripts.OnClick() end
	Check("text zoom stops at 75 percent", popout.target.scale == 0.75
		and popout.textSize.decrease.SetEnabledArgs[1] == false)
	Check("reduced text preserves heading hierarchy", PopoutText(popout, "Boss").fontSize == 22 * 0.75
		and PopoutText(popout, "first").fontSize == 13 * 0.75)
	for _, object in ipairs(objects) do
		if object.parent == popout.content and object.kind == "Texture" and object.shown then
			Check("zoomed table fits window", object.point[2] + object.width <= popout.content.width + 0.001)
		end
	end
	popout:Hide()
	ns.OpenNoteWindow(1)
	Check("reopened window preserves text size", popout.target.scale == 0.75)
	popout:Hide()
	popoutOther:Hide()
	assert(loadfile("Popout.lua"))("Quill", ns)
	Check("loading popouts does not reopen windows", not popout.shown and not popoutOther.shown)
	ns.OpenNoteWindow(1)
	local restored = ns.NoteWindow(1)
	Check("recreated window restores saved text size", restored ~= popout and restored.target.scale == 0.75
		and PopoutText(restored, "Boss").fontSize == 22 * 0.75)
	mainControls.decrease.scripts.OnClick()
	Check("main text size returns to default", QuillDB.settings.textScale == 1
		and editorBox.fontSize == defaultEditorSize)
	Check("invalid saved text scale is sanitized", ns.TextScale({ textScale = "invalid" }) == 1
		and ns.TextScale({ textScale = 100 }) == 2 and ns.TextScale({ textScale = -1 }) == 0.75)
end

-- Trash
local trashId = assert(ns.CreateNote("Trash me", "", ns.GetNote(1).notebook))
ns.OpenNote(trashId, "read")
FindButton(named.QuillWindow, "Delete").scripts.OnClick()
Check("delete asks to move to trash", popup.text == "Move the note \"Trash me\" to the trash?")
popup.accept()
Check("deleted note goes to trash", ns.GetNote(trashId) == nil and ns.GetNote(trashId, true).deleted == 12345)
IconButtonFor("Interface\\Icons\\INV_Misc_Basket_05").scripts.OnClick()
local trash = named.QuillTrash
local function TrashRow(id)
	for _, row in ipairs(trash.rows) do
		if row.shown and row.entry and row.entry.id == id then return row end
	end
end
Check("trash lists deleted note", trash.shown and TrashRow(trashId) ~= nil
	and TrashRow(trashId).info.text == "Note · 7 days left")
TrashRow(trashId).restore.scripts.OnClick(TrashRow(trashId).restore)
Check("trash restores note", ns.GetNote(trashId) ~= nil and TrashRow(trashId) == nil)
ns.DeleteNote(trashId)
Check("open trash follows deletions", TrashRow(trashId) ~= nil)
TrashRow(trashId).purge.scripts.OnClick(TrashRow(trashId).purge)
popup.accept()
Check("trash deletes permanently", QuillDB.notes[trashId] == nil and TrashRow(trashId) == nil)
ns.DeleteNotebook(created)
Check("trash lists deleted notebook", TrashRow(created) ~= nil and TrashRow(created).info.text == "Notebook · 7 days left")
TrashRow(created).restore.scripts.OnClick(TrashRow(created).restore)
Check("trash restores notebook", ns.GetNotebook(created) ~= nil)
local emptyId = assert(ns.CreateNote("Empty me", "", ns.GetNote(1).notebook))
ns.DeleteNote(emptyId)
FindButton(trash, "Empty trash").scripts.OnClick()
popup.accept()
Check("empty trash removes everything", QuillDB.notes[emptyId] == nil and #ns.TrashEntries() == 0
	and trash.empty.shown and trash.emptyButton.SetEnabledArgs[1] == false)

print(("%d UI tests passed"):format(count))
