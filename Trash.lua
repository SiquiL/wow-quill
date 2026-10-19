local _, ns = ...
local L = ns.L

local ROWS = 12
local ROW_HEIGHT = 26
local WIDTH = 560
local LIST_WIDTH = WIDTH - 46

local dialog

local function DaysLeft(entry)
	return math.max(0, math.ceil((entry.expires - time()) / 86400))
end

local function Button(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function Refresh()
	dialog.entries = ns.TrashEntries()
	local entries = dialog.entries
	FauxScrollFrame_Update(dialog.scroll, #entries, ROWS, ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(dialog.scroll)
	for index, row in ipairs(dialog.rows) do
		local entry = entries[offset + index]
		row.entry = entry
		row:SetShown(entry ~= nil)
		if entry then
			local kind = entry.kind == "notebook" and L["Notebook"] or L["Note"]
			row.label:SetText(entry.title)
			row.label:SetTextColor(ns.ThemeColor(entry.kind == "notebook" and "heading" or "body"))
			row.info:SetText(kind .. " · " .. L["%d days left"]:format(DaysLeft(entry)))
		end
	end
	dialog.empty:SetShown(#entries == 0)
	dialog.emptyButton:SetEnabled(#entries > 0)
end

local function Report(ok, err)
	if not ok then ns.Say(err) end
	ns.RefreshWindow()
	Refresh()
end

local function Build()
	dialog = ns.Dialog("QuillTrash", L["Trash"], WIDTH, 34 + ROWS * ROW_HEIGHT + 50)

	local scroll = CreateFrame("ScrollFrame", nil, dialog, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -34)
	scroll:SetSize(LIST_WIDTH, ROWS * ROW_HEIGHT)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Refresh)
	end)
	dialog.scroll, dialog.rows = scroll, {}

	for index = 1, ROWS do
		local row = CreateFrame("Frame", nil, dialog)
		row:SetSize(LIST_WIDTH, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

		row.purge = Button(row, L["Delete permanently"], 130, function(self)
			local entry = self:GetParent().entry
			ns.Confirm(L["Permanently delete \"%s\"? This cannot be undone."]:format(entry.title), function()
				Report(ns.PurgeTrashEntry(entry.kind, entry.id))
			end)
		end)
		row.purge:SetPoint("RIGHT", 0, 0)
		row.restore = Button(row, L["Restore"], 90, function(self)
			local entry = self:GetParent().entry
			local restore = entry.kind == "notebook" and ns.RestoreNotebook or ns.RestoreNote
			Report(restore(entry.id))
		end)
		row.restore:SetPoint("RIGHT", row.purge, "LEFT", -4, 0)

		row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.info:SetPoint("RIGHT", row.restore, "LEFT", -8, 0)
		row.info:SetJustifyH("RIGHT")
		ns.StyleText(row.info, "muted")

		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
		row.label:SetPoint("LEFT", 4, 0)
		row.label:SetPoint("RIGHT", row.info, "LEFT", -8, 0)
		row.label:SetWordWrap(false)
		dialog.rows[index] = row
	end

	dialog.empty = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	dialog.empty:SetPoint("CENTER", scroll, "CENTER")
	dialog.empty:SetText(L["The trash is empty."])
	ns.StyleText(dialog.empty, "muted")

	local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("BOTTOMLEFT", 14, 18)
	hint:SetText(L["Entries are deleted permanently after %d days."]:format(ns.TRASH_DAYS))
	ns.StyleText(hint, "muted")

	dialog.emptyButton = Button(dialog, L["Empty trash"], 120, function()
		ns.Confirm(L["Permanently delete everything in the trash? This cannot be undone."], function()
			ns.EmptyTrash()
			ns.RefreshWindow()
			Refresh()
		end)
	end)
	dialog.emptyButton:SetPoint("BOTTOMRIGHT", -12, 12)
end

function ns.ShowTrash()
	if not dialog then Build() end
	FauxScrollFrame_OnVerticalScroll(dialog.scroll, 0, ROW_HEIGHT, Refresh)
	dialog:Show()
end

-- Keeps the dialog current when something is deleted while it is open.
function ns.RefreshTrash()
	if dialog and dialog:IsShown() then Refresh() end
end
