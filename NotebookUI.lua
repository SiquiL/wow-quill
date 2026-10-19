local _, ns = ...
local L = ns.L

local chooser, manager

local function Dialog(name, title, width, height)
	local frame = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(width, height)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	ns.StyleFrame(frame)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOP", 0, -5)
	heading:SetText(title)
	frame.heading = heading
	table.insert(UISpecialFrames, name)
	frame:Hide()
	return frame
end
ns.Dialog = Dialog

local function Button(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function ScopeText(id)
	local notebook = ns.GetNotebook(id)
	return notebook and notebook.owner and L["Character only"] or L["Global"]
end
ns.NotebookScopeText = ScopeText

function ns.ChooseNotebook(title, onSelect, exclude, allowRoot, returnTo, noteIds)
	if not chooser then
		chooser = Dialog("QuillNotebookChooser", "", 450, 390)
		chooser:SetScript("OnHide", function(self)
			local previous = self.returnTo
			self.returnTo = nil
			if previous then previous:Show() end
		end)
		local scroll = CreateFrame("ScrollFrame", nil, chooser, "FauxScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 12, -34)
		scroll:SetSize(402, 14 * 24)
		chooser.scroll, chooser.rows = scroll, {}
		local function Refresh()
			FauxScrollFrame_Update(scroll, #chooser.entries, 14, 24)
			local offset = FauxScrollFrame_GetOffset(scroll)
			for index, row in ipairs(chooser.rows) do
				local entry = chooser.entries[offset + index]
				row.entry = entry
				row:SetShown(entry ~= nil)
				if entry then
					row.label:SetText(entry.path .. (entry.id and not entry.note and (" [" .. ScopeText(entry.id) .. "]") or ""))
					local color = entry.id and not entry.note and ns.GetNotebook(entry.id).color
					if color then
						row.label:SetTextColor(unpack(color))
					else
						row.label:SetTextColor(ns.ThemeColor("body"))
					end
				end
			end
		end
		chooser.refresh = Refresh
		scroll:SetScript("OnVerticalScroll", function(self, offset)
			FauxScrollFrame_OnVerticalScroll(self, offset, 24, Refresh)
		end)
		for index = 1, 14 do
			local row = CreateFrame("Button", nil, chooser)
			row:SetSize(402, 24)
			row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(index - 1) * 24)
			row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
			row.label:SetPoint("LEFT", 4, 0)
			row.label:SetPoint("RIGHT", -4, 0)
			row.label:SetWordWrap(false)
			ns.StyleText(row.label)
			row:SetScript("OnClick", function(self)
				chooser:Hide()
				chooser.onSelect(self.entry.id or nil)
			end)
			row:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(self.entry.path)
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
			chooser.rows[index] = row
		end
	end
	chooser.entries = ns.NotebookList(exclude)
	if noteIds then
		chooser.entries = {}
		for _, id in ipairs(noteIds) do
			if ns.GetNote(id) then chooser.entries[#chooser.entries + 1] = { id = id, path = ns.NotePath(id), note = true } end
		end
	end
	if allowRoot then
		table.insert(chooser.entries, 1, { path = L["Top level"] })
	end

	chooser.onSelect = onSelect
	chooser.returnTo = returnTo
	chooser.heading:SetText(title)
	FauxScrollFrame_OnVerticalScroll(chooser.scroll, 0, 24, chooser.refresh)
	chooser:Show()
end

function ns.ChooseNote(title, ids, onSelect)
	ns.ChooseNotebook(title, onSelect, nil, false, nil, ids)
end

function ns.ShowNotebookManager(id)
	if not manager then
		manager = Dialog("QuillNotebookManager", "", 460, 430)
		local label = manager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOPLEFT", 18, -40)
		label:SetText(L["Notebook name"])
		ns.StyleText(label, "heading")
		local name = CreateFrame("EditBox", nil, manager, "InputBoxTemplate")
		name:SetPoint("TOPLEFT", 22, -62)
		name:SetSize(412, 24)
		name:SetAutoFocus(false)
		name:SetMaxLetters(100)
		name:SetScript("OnEscapePressed", name.ClearFocus)
		manager.name = name

		local function UpdateParent()
			local parent = ns.GetNotebook(manager.parentId)
			local isDefault = manager.id == QuillDB.defaultNotebook
			manager.parentButton:SetText(parent and ns.NotebookPath(manager.parentId) or L["Top level"])
			manager.parentButton:SetEnabled(not isDefault)
			if parent and parent.owner then
				manager.scope:SetChecked(true)
			end
			manager.scope:SetEnabled(not isDefault and not (parent and parent.owner))
		end
		manager.updateParent = UpdateParent
		local parentLabel = manager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		parentLabel:SetPoint("TOPLEFT", 18, -100)
		parentLabel:SetText(L["Parent notebook"])
		ns.StyleText(parentLabel, "heading")
		manager.parentButton = Button(manager, "", 418, function()
			manager:Hide()
			ns.ChooseNotebook(L["Parent notebook"], function(parent)
				manager.parentId = parent
				UpdateParent()
			end, manager.id, true, manager)
		end)
		manager.parentButton:SetPoint("TOPLEFT", 18, -122)
		manager.scope = CreateFrame("CheckButton", nil, manager, "UICheckButtonTemplate")
		manager.scope:SetSize(26, 26)
		manager.scope:SetPoint("TOPLEFT", 14, -158)
		local scopeLabel = manager.scope:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		scopeLabel:SetPoint("LEFT", manager.scope, "RIGHT", 2, 0)
		scopeLabel:SetText(L["Only available to this character"])
		ns.StyleText(scopeLabel)
		local hint = manager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", 18, -196)
		hint:SetWidth(420)
		hint:SetJustifyH("LEFT")
		hint:SetText(L["Changing visibility also changes all notes and subnotebooks. Character notebooks cannot contain global notebooks."])
		ns.StyleText(hint)

		local colorLabel = manager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		colorLabel:SetPoint("TOPLEFT", 18, -250)
		colorLabel:SetText(L["Notebook color"])
		ns.StyleText(colorLabel, "heading")
		local function SelectColor(color)
			manager.color = color and { unpack(color) } or nil
			manager.swatch:SetColorTexture(unpack(color or { 1, 0.82, 0 }))
		end
		local palette = {
			{ 0.9, 0.25, 0.25 }, { 1, 0.55, 0.15 }, { 1, 0.82, 0 },
			{ 0.3, 0.8, 0.35 }, { 0.25, 0.65, 1 }, { 0.65, 0.4, 0.9 }, { 1, 0.45, 0.7 },
		}
		for index, color in ipairs(palette) do
			local swatch = Button(manager, "", 26, function() SelectColor(color) end)
			swatch:SetPoint("TOPLEFT", 18 + (index - 1) * 30, -276)
			local fill = swatch:CreateTexture(nil, "ARTWORK")
			fill:SetPoint("TOPLEFT", 5, -5)
			fill:SetPoint("BOTTOMRIGHT", -5, 5)
			fill:SetColorTexture(unpack(color))
		end
		local custom = Button(manager, L["Custom color"], 140, function()
			local session = manager.colorSession
			ns.PickColor(manager.color or { 1, 0.82, 0 }, function(color)
				if manager:IsShown() and manager.colorSession == session then SelectColor(color) end
			end)
		end)
		custom:SetPoint("TOPLEFT", 18, -312)
		manager.swatch = custom:CreateTexture(nil, "ARTWORK")
		manager.swatch:SetSize(10, 10)
		manager.swatch:SetPoint("RIGHT", -6, 0)
		local resetColor = Button(manager, L["Default color"], 140, function() SelectColor(nil) end)
		resetColor:SetPoint("LEFT", custom, "RIGHT", 8, 0)

		local save = Button(manager, L["Save"], 100, function()
			local result, err
			if manager.id then
				result, err = ns.UpdateNotebook(manager.id, name:GetText(), manager.parentId, manager.scope:GetChecked())
			else
				result, err = ns.CreateNotebook(name:GetText(), manager.parentId, manager.scope:GetChecked())
			end
			if not result then
				ns.Say(err)
				return
			end
			local ok, colorError = ns.SetNotebookColor(result, manager.color)
			if not ok then ns.Say(colorError); return end
			manager:Hide()
			ns.SelectNotebook(result)
		end)
		save:SetPoint("BOTTOMRIGHT", -16, 16)
		local cancel = Button(manager, L["Cancel"], 100, function() manager:Hide() end)
		cancel:SetPoint("RIGHT", save, "LEFT", -6, 0)
		manager.delete = Button(manager, L["Delete"], 100, function()
			local notebookId = manager.id
			local notebook = ns.GetNotebook(notebookId)
			if not notebook then return end
			ns.Confirm(L["Move notebook \"%s\" with all notes and subnotebooks to the trash?"]:format(notebook.title), function()
				local ok, err = ns.DeleteNotebook(notebookId)
				if not ok then
					ns.Say(err)
					return
				end
				manager:Hide()
				ns.SelectNotebook(QuillDB.defaultNotebook)
			end)
		end)
		manager.delete:SetPoint("BOTTOMLEFT", 16, 16)
		manager:SetScript("OnHide", function()
			name:ClearFocus()
			if chooser then chooser:Hide() end
		end)
	end
	local notebook = ns.GetNotebook(id)
	manager.id = notebook and id or nil
	manager.colorSession = {}
	manager.parentId = notebook and notebook.parent or (not id and ns.ActiveNotebook() or nil)
	manager.heading:SetText(notebook and L["Manage notebook"] or L["New notebook"])
	manager.name:SetText(notebook and notebook.title or "")
	manager.scope:SetChecked(notebook and notebook.owner ~= nil or false)
	manager.color = notebook and notebook.color and { unpack(notebook.color) } or nil
	manager.swatch:SetColorTexture(unpack(manager.color or { 1, 0.82, 0 }))
	manager.delete:SetEnabled(notebook ~= nil and id ~= QuillDB.defaultNotebook)
	manager.updateParent()
	manager:Show()
	manager.name:SetFocus()
end
