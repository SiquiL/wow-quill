local addonName, ns = ...
local L = ns.L
local Markdown = ns.Markdown
local TextLayout = ns.TextLayout

local WIDTH, HEIGHT = 780, 520
local MIN_WIDTH, MIN_HEIGHT = 700, 360
local MAX_WIDTH, MAX_HEIGHT = 1600, 1200
local MARGIN = 12
local TOP = -30
local BUTTON_HEIGHT = 22
local BUTTON_WIDTH = 80
local SCROLLBAR_WIDTH = 22

local LIST_WIDTH = 210
local ROW_HEIGHT = 20
local SEARCH_TOP = TOP - 56
local LIST_TOP = SEARCH_TOP - 26
local VISIBLE_ROWS = math.floor((HEIGHT + LIST_TOP - MARGIN) / ROW_HEIGHT)

local PANE_LEFT = MARGIN + LIST_WIDTH + 12
local PANE_TOP = TOP - 56
local PANE_WIDTH = WIDTH - PANE_LEFT - MARGIN
local PANE_PADDING = 8
local CONTENT_WIDTH = PANE_WIDTH - 2 * PANE_PADDING - SCROLLBAR_WIDTH
-- InputScrollFrameTemplate draws its scroll bar inside the frame and insets the edit box by 18
local EDITOR_RIGHT = PANE_PADDING + 12
local EDITOR_WIDTH = PANE_WIDTH - PANE_PADDING - EDITOR_RIGHT - 18
-- Star, popout, edit, delete, trash and options buttons share the title row
local TITLE_RESERVED = 288
local HISTORY_LIMIT = 100
local HISTORY_PAUSE = 1
local STAR_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local POPOUT_ICON = "Interface\\Icons\\INV_Misc_NoteBlank1B"
local TRASH_ICON = "Interface\\Icons\\INV_Misc_Basket_05"

local CODE_FONT = "GameFontHighlightSmall"
local BODY_SIZE, CODE_SIZE = 13, 12
local FONT_BASE = "Interface\\AddOns\\" .. addonName .. "\\fonts\\Lato-"
local BODY_STYLE = { size = BODY_SIZE }
local MUTED_STYLE = { size = BODY_SIZE, color = { 0.6, 0.6, 0.6 } }
local QUOTE_STYLE = { size = BODY_SIZE, color = { 0.75, 0.75, 0.75 } }
local GOLD = { 1, 0.82, 0 }
local HEADING_STYLES = {}
for level, size in ipairs({ 22, 19, 17, 15, 14, 13 }) do
	HEADING_STYLES[level] = { size = size, bold = true, color = GOLD }
end
local TABLE_HEADER_STYLE = { size = BODY_SIZE, bold = true, color = GOLD }
local TABLE_PADDING = 6
local INDENT = 18
local MARKER_WIDTH = 20
local QUOTE_INDENT = 12
local CODE_PADDING = 6
local CHECKBOX_SIZE = 18
local CHECKBOX_UP = "Interface\\Buttons\\UI-CheckBox-Up"
local CHECKBOX_CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local VALID_POINTS = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

local window
local search
local searchError
local list
local rows = {}
local filtered = {}
local titleBox
local modeButton
local deleteButton
local moveButton
local scopeCheck
local notebookLabel
local editorScroll
local editor
local readerScroll
local reader
local main
local starButton
local popoutButton
local placeholder
local histories = {}
local selected
local mode
local collapsed = {}
local propertiesExpanded = false

-- Window ---------------------------------------------------------------------

local function SavePosition()
	local point, _, relativePoint, x, y = window:GetPoint(1)
	QuillDB.settings.window = {
		point = VALID_POINTS[point] and point or "CENTER",
		relativePoint = VALID_POINTS[relativePoint] and relativePoint or "CENTER",
		x = x or 0,
		y = y or 0,
		width = window:GetWidth(),
		height = window:GetHeight(),
	}
end

local function RestorePosition()
	local state = QuillDB.settings.window or {}
	local point = VALID_POINTS[state.point] and state.point or "CENTER"
	local relativePoint = VALID_POINTS[state.relativePoint] and state.relativePoint or point
	local width = math.min(MAX_WIDTH, math.max(MIN_WIDTH, tonumber(state.width) or WIDTH))
	local height = math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, tonumber(state.height) or HEIGHT))
	window:SetSize(width, height)
	window:ClearAllPoints()
	window:SetPoint(point, UIParent, relativePoint, tonumber(state.x) or 0, tonumber(state.y) or 0)
end

local function Button(text, width, onClick)
	local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	button:SetSize(width, BUTTON_HEIGHT)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function Tooltip(owner, title, line)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title)
	if line then GameTooltip:AddLine(line, 1, 0.3, 0.3, true) end
	GameTooltip:Show()
end

-- A square button showing an icon instead of text
local function IconButton(texture, tooltip, onClick)
	local button = Button("", BUTTON_HEIGHT, onClick)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", 4, -4)
	button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
	button.icon:SetTexture(texture)
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button:SetScript("OnEnter", function(self)
		Tooltip(self, type(tooltip) == "function" and tooltip() or tooltip)
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return button
end

local function TogglePinned(id)
	local note = ns.GetNote(id)
	if not note then return end
	ns.SetNotePinned(id, not note.pinned)
	ns.RefreshWindow()
end

local function DeleteNote(id)
	local note = ns.GetNote(id)
	if not note then
		return
	end
	ns.Confirm(L["Move the note \"%s\" to the trash?"]:format(ns.NoteTitle(note)), function()
		if id ~= selected then
			ns.DeleteNote(id)
			ns.RefreshWindow()
			return
		end
		local position = 1
		local remaining = ns.SortedNotes(search:GetText(), ns.ActiveNotebook())
		for index, other in ipairs(remaining) do
			if other == id then
				position = index
			end
		end
		ns.DeleteNote(id)
		remaining = ns.SortedNotes(search:GetText(), ns.ActiveNotebook())
		ns.OpenNote(remaining[math.min(position, #remaining)])
	end)
end

local function NoteMenu(owner, id)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		local note = ns.GetNote(id)
		if not note then return end
		root:CreateTitle(ns.NoteTitle(note))
		root:CreateButton(note.pinned and L["Remove from favorites"] or L["Add to favorites"], function() TogglePinned(id) end)
		root:CreateButton(L["Open in small window"], function() ns.OpenNoteWindow(id) end)
		root:CreateButton(L["Delete"], function() DeleteNote(id) end)
	end)
end

-- Note list ------------------------------------------------------------------

local function RefreshList()
	local err
	filtered, err = ns.TreeEntries(search:GetText(), collapsed)
	if searchError then
		searchError:SetText(err or "")
		searchError:SetShown(err ~= nil)
	end
	FauxScrollFrame_Update(list, #filtered, VISIBLE_ROWS, ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(list)
	for index, row in ipairs(rows) do
		local entry = filtered[offset + index]
		if index > VISIBLE_ROWS then
			entry = nil
		end
		row.entry = entry
		if entry then
			local isNotebook = entry.kind == "notebook"
			local isFavorites = entry.kind == "favorites"
			local title
			if isFavorites then
				title = (collapsed.favorites and "+ " or "- ") .. L["Favorites"]
			elseif isNotebook then
				title = (collapsed[entry.id] and "+ " or "- ") .. ns.GetNotebook(entry.id).title
			else
				title = ns.NoteTitle(ns.GetNote(entry.id))
			end
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", 6 + math.min(entry.depth * 12, 96), 0)
			row.label:SetPoint("RIGHT", -4, 0)
			row.label:SetText(title)
			local color = isNotebook and ns.GetNotebook(entry.id).color
			if color then
				row.label:SetTextColor(unpack(color))
			else
				row.label:SetTextColor(ns.ThemeColor((isNotebook or isFavorites) and "heading" or "body"))
			end
			row.selection:SetShown(isNotebook and entry.id == ns.ActiveNotebook() or (entry.kind == "note" and entry.id == selected))
			row:Show()
		else
			row:Hide()
		end
	end
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, window)
	row:SetSize(LIST_WIDTH - SCROLLBAR_WIDTH, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

	row.selection = row:CreateTexture(nil, "BACKGROUND")
	row.selection:SetAllPoints()
	row.selection:SetColorTexture(1, 0.82, 0, 0.2)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
	row.label:SetPoint("LEFT", 6, 0)
	row.label:SetPoint("RIGHT", -4, 0)
	row.label:SetWordWrap(false)

	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(self, button)
		if self.entry.kind == "favorites" then
			collapsed.favorites = not collapsed.favorites
			RefreshList()
		elseif self.entry.kind == "notebook" then
			collapsed[self.entry.id] = not collapsed[self.entry.id]
			ns.SelectNotebook(self.entry.id)
		elseif button == "RightButton" then
			NoteMenu(self, self.entry.id)
		else
			ns.OpenNote(self.entry.id)
		end
	end)
	row:SetScript("OnEnter", function(self)
		if self.entry.kind == "favorites" then
			return
		elseif self.entry.kind == "notebook" then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(ns.NotebookPath(self.entry.id))
			GameTooltip:AddLine(ns.NotebookScopeText(self.entry.id), 1, 1, 1)
			GameTooltip:Show()
			return
		end
		local note = ns.GetNote(self.entry.id)
		if not note then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(ns.NoteTitle(note))
		GameTooltip:AddLine(L["Last changed: %s"]:format(date("%Y-%m-%d %H:%M", note.modified or 0)), 1, 1, 1)
		GameTooltip:AddLine(ns.IsNoteCharacterOnly(self.entry.id) and L["Character only"] or L["Global"], 1, 1, 1)
		GameTooltip:AddLine(L["Right-click for more actions"], 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return row
end

-- Read mode ------------------------------------------------------------------

-- A render target owns its frame, object pools and content width, so several windows can show notes.
local target
local function NewTarget(frame, scroll)
	return {
		frame = frame, scroll = scroll, width = 1,
		pools = { FontString = {}, Texture = {}, Button = {} },
		used = { FontString = 0, Texture = 0, Button = 0 },
	}
end
local TOOLTIP_LINKS = { item = true, quest = true, spell = true, achievement = true, currency = true, battlepet = true, enchant = true }
local measureText
-- Word widths by font face, size and text; resizing re-renders the note on every frame
local widths = {}

local function Acquire(kind)
	local used, pool = target.used, target.pools[kind]
	used[kind] = used[kind] + 1
	local object = pool[used[kind]]
	if not object then
		local frame = target.frame
		if kind == "FontString" then
			object = frame:CreateFontString(nil, "OVERLAY")
			object:SetJustifyH("LEFT")
			object:SetJustifyV("TOP")
			object:SetWordWrap(true)
			object:SetNonSpaceWrap(true)
		elseif kind == "Button" then
			object = CreateFrame("Button", nil, frame)
			object:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			object:SetScript("OnClick", function(self, button)
				if self.wiki then
					ns.FollowWikiLink(self.wiki)
				elseif self.tag then
					ns.FilterTag(self.tag)
				elseif self.properties then
					propertiesExpanded = not propertiesExpanded
					ns.RefreshWindow()
					ns.RefreshNoteWindows()
				else
					SetItemRef(self.link, self.label, button, self)
				end
			end)
			object:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
				if self.wiki then
					GameTooltip:SetText(self.wiki)
					if #ns.ResolveWikiLink(self.wiki) == 0 then
						GameTooltip:AddLine(L["Click to create this note."], 1, 1, 1)
					end
				elseif self.tag then
					GameTooltip:SetText(L["Filter by tag: %s"]:format(self.tag))
				elseif self.properties then
					GameTooltip:SetText(L["Show or hide properties"])
				elseif TOOLTIP_LINKS[self.link:match("^([^:]+):")] then
					GameTooltip:SetHyperlink(self.link)
				else
					GameTooltip:SetText(self.label)
				end
				GameTooltip:Show()
			end)
			object:SetScript("OnLeave", function() GameTooltip:Hide() end)
		else
			object = frame:CreateTexture(nil, "ARTWORK")
		end
		pool[used[kind]] = object
	end
	object:ClearAllPoints()
	if kind == "Button" then
		object.link, object.wiki, object.tag, object.properties = nil, nil, nil, nil
		-- Locked windows let clicks through to the game world.
		object:EnableMouse(not target.locked)
	end
	object:Show()
	return object
end

local function CodeText(x, y, width, text)
	local fontString = Acquire("FontString")
	fontString:SetFontObject(CODE_FONT)
	local path, _, flags = fontString:GetFont()
	fontString:SetFont(path, CODE_SIZE * (target.scale or 1), flags)
	fontString:SetWordWrap(true)
	fontString:SetNonSpaceWrap(true)
	fontString:SetHeight(0)
	fontString:SetTextColor(ns.ThemeColor("code"))
	fontString:SetPoint("TOPLEFT", x, -y)
	fontString:SetWidth(width)
	fontString:SetText(Markdown.Escape(text))
	return fontString:GetStringHeight()
end

local function Box(x, y, width, height, r, g, b, a)
	local texture = Acquire("Texture")
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetColorTexture(r, g, b, a)
	texture:SetPoint("TOPLEFT", x, -y)
	texture:SetSize(width, height)
end

local function Icon(path, x, y, size)
	local texture = Acquire("Texture")
	texture:SetTexture(path)
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetVertexColor(1, 1, 1, 1)
	texture:SetPoint("TOPLEFT", x, -y)
	texture:SetSize(size, size)
end

-- New font files are only found after a client restart; until then the game font is used
local function SetTextFont(fontString, span, style)
	local bold = span.bold or style.bold
	local italic = span.italic or style.italic
	local face = bold and (italic and "BoldItalic" or "Bold") or (italic and "Italic" or "Regular")
	local size = style.size * (target.scale or 1)
	fontString:SetFont(FONT_BASE .. face .. ".ttf", size, "")
	if not fontString:GetFont() then
		fontString:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	return face
end

local function TextColor(span, style)
	if span.code then
		return ns.ThemeColor("code")
	elseif span.color then
		local color = span.color
		return tonumber(color:sub(3, 4), 16) / 255, tonumber(color:sub(5, 6), 16) / 255, tonumber(color:sub(7, 8), 16) / 255
	elseif span.hyperlink then
		return 0.31, 0.72, 1
	elseif span.wiki then
		return ns.ThemeColor(#ns.ResolveWikiLink(span.wiki) == 0 and "error" or "link")
	elseif span.link or span.tag then
		return ns.ThemeColor("link")
	elseif span.strike then
		return ns.ThemeColor("muted")
	end
	return ns.ThemeColor(style.color == GOLD and "heading" or (style == MUTED_STYLE or style == QUOTE_STYLE) and "muted" or "body")
end

local function Text(source, x, y, width, style, alignment)
	style = style or BODY_STYLE
	local size = style.size * (target.scale or 1)
	if not measureText then
		measureText = target.frame:CreateFontString(nil, "OVERLAY")
		measureText:SetWordWrap(false)
		measureText:Hide()
	end
	local lines = TextLayout.Wrap(Markdown.Spans(source), math.max(1, width), function(text, span)
		local face = SetTextFont(measureText, span, style)
		local key = face .. size .. "\0" .. text
		local cached = widths[key]
		if cached then
			return cached
		end
		local measured
		-- Surround whitespace so font metrics include it even when trailing spaces are trimmed.
		if text:match("^%s+$") then
			measureText:SetText("x" .. text .. "x")
			local paddedWidth = measureText:GetStringWidth()
			measureText:SetText("xx")
			measured = paddedWidth - measureText:GetStringWidth()
		else
			measureText:SetText((text:gsub("|", "||")))
			measured = measureText:GetStringWidth()
		end
		widths[key] = measured
		return measured
	end)
	local lineHeight = math.ceil(size * 1.35)
	for index, line in ipairs(lines) do
		local alignOffset = alignment == "right" and (width - line.width)
			or alignment == "center" and (width - line.width) / 2 or 0
		local lineY = y + (index - 1) * lineHeight
		for _, run in ipairs(line.runs) do
			local r, g, b = TextColor(run.span, style)
			if run.text:match("%S") then
				local fontString = Acquire("FontString")
				SetTextFont(fontString, run.span, style)
				fontString:SetWordWrap(false)
				fontString:SetNonSpaceWrap(false)
				fontString:SetTextColor(r, g, b)
				fontString:SetPoint("TOPLEFT", x + alignOffset + run.x, -lineY)
				fontString:SetSize(run.width + size * 0.25, lineHeight)
				fontString:SetText((run.text:gsub("|", "||")))
				if run.span.hyperlink or run.span.wiki or run.span.tag then
					local button = Acquire("Button")
					button.link, button.label = run.span.hyperlink, run.span.text
					button.wiki, button.tag = run.span.wiki, run.span.tag
					button:SetPoint("TOPLEFT", x + alignOffset + run.x, -lineY)
					button:SetSize(run.width, lineHeight)
				end
			end
			if run.span.strike then
				Box(x + alignOffset + run.x, lineY + size * 0.55, run.width, 1, r, g, b, 1)
			end
		end
	end
	return #lines * lineHeight
end

local function RenderTable(block, y)
	local startY = y
	local columnWidth = target.width / #block.header
	local lineR, lineG, lineB = ns.ThemeColor("muted")
	local function Row(cells, header, rowIndex)
		local height = 0
		for column, cell in ipairs(cells) do
			height = math.max(height, Text(cell, (column - 1) * columnWidth + TABLE_PADDING, y + TABLE_PADDING,
				columnWidth - 2 * TABLE_PADDING, header and TABLE_HEADER_STYLE or BODY_STYLE, block.alignment[column]))
		end
		height = height + 2 * TABLE_PADDING
		if header then
			local r, g, b = ns.ThemeColor("heading")
			Box(0, y, target.width, height, r, g, b, 0.12)
		elseif rowIndex % 2 == 0 then
			local r, g, b = ns.ThemeColor("body")
			Box(0, y, target.width, height, r, g, b, 0.04)
		end
		y = y + height
		Box(0, y, target.width, 1, lineR, lineG, lineB, 0.5)
	end
	Box(0, y, target.width, 1, lineR, lineG, lineB, 0.5)
	Row(block.header, true)
	for index, cells in ipairs(block.rows) do
		Row(cells, false, index)
	end
	for column = 0, #block.header do
		Box(math.min(column * columnWidth, target.width - 1), startY, 1, y - startY, lineR, lineG, lineB, 0.5)
	end
	return y - startY + 1
end

local function Gap(previous, block)
	if not previous then
		return 0
	elseif previous.type == "item" and block.type == "item" and not block.afterBlank then
		return 4
	elseif block.type == "heading" then
		return 16
	end
	return 10
end

local function RenderItem(block, y)
	local x = block.depth * INDENT
	local textX = x + MARKER_WIDTH

	if block.task ~= nil then
		Icon(CHECKBOX_UP, x - 3, y - 3, CHECKBOX_SIZE)
		if block.task then
			Icon(CHECKBOX_CHECK, x - 3, y - 3, CHECKBOX_SIZE)
		end
	else
		local marker = block.ordered and (block.number .. ".") or "•"
		Text(marker, x, y, MARKER_WIDTH, { size = BODY_SIZE, color = GOLD })
	end

	if block.task then
		return Text(block.text, textX, y, target.width - textX, MUTED_STYLE)
	end
	return Text(block.text, textX, y, target.width - textX)
end

local function Render(renderTarget, source)
	target = renderTarget
	local used = target.used
	used.FontString, used.Texture, used.Button = 0, 0, 0

	local y, previous = 0, nil
	local properties, body, metadataError = ns.Metadata.Parse(source)
	if metadataError then
		y = y + Text((metadataError:gsub("([%p])", "\\%1")), 0, y, target.width, MUTED_STYLE) + 10
	elseif next(properties) then
		y = y + Text(L["Properties"] .. (propertiesExpanded and " [-]" or " [+]"), 0, y, target.width, TABLE_HEADER_STYLE)
		local toggle = Acquire("Button")
		toggle.properties = true
		toggle:SetPoint("TOPLEFT", 0, 0)
		toggle:SetSize(target.width, y)
		if propertiesExpanded then
			local keys = {}
			for key in pairs(properties) do keys[#keys + 1] = key end
			table.sort(keys)
			for _, key in ipairs(keys) do
				local tags = key == "tags" and ns.Metadata.Tags(properties, "")
				if tags and #tags > 0 then
					y = y + Text("tags: #" .. table.concat(tags, " #"), 0, y, target.width)
				else
					local value = ns.Metadata.ValueText(properties[key])
					y = y + Text(((key .. ": " .. value):gsub("([%p])", "\\%1")), 0, y, target.width)
				end
			end
		end
		y = y + 10
	end
	for _, block in ipairs(Markdown.Parse(body)) do
		y = y + Gap(previous, block)

		if block.type == "heading" then
			local r, g, b = ns.ThemeColor("heading")
			y = y + Text(block.text, 0, y, target.width, HEADING_STYLES[block.level])
			if block.level == 1 then
				y = y + 4
				Box(0, y, target.width, 1, r, g, b, 0.4)
				y = y + 1
			end
		elseif block.type == "paragraph" then
			y = y + Text(block.text, 0, y, target.width)
		elseif block.type == "item" then
			y = y + RenderItem(block, y)
		elseif block.type == "quote" then
			local height = Text(block.text, QUOTE_INDENT, y, target.width - QUOTE_INDENT, QUOTE_STYLE)
			local r, g, b = ns.ThemeColor("heading")
			Box(0, y, 3, height, r, g, b, 0.6)
			y = y + height
		elseif block.type == "code" then
			local height = CodeText(CODE_PADDING, y + CODE_PADDING, target.width - 2 * CODE_PADDING, block.text)
			if not QuillDB.settings.theme or QuillDB.settings.theme == "standard" then
				Box(0, y, target.width, height + 2 * CODE_PADDING, 0, 0, 0, 0.45)
			else
				local r, g, b = ns.ThemeColor("body")
				Box(0, y, target.width, height + 2 * CODE_PADDING, r, g, b, 0.06)
			end
			y = y + height + 2 * CODE_PADDING
		elseif block.type == "rule" then
			y = y + 4
			Box(0, y, target.width, 1, 0.6, 0.6, 0.6, 0.5)
			y = y + 5
		elseif block.type == "table" then
			y = y + RenderTable(block, y)
		end

		previous = block
	end

	for kind, pool in pairs(target.pools) do
		for index = used[kind] + 1, #pool do
			pool[index]:Hide()
		end
	end
	target.frame:SetHeight(math.max(y, 1))
	target.scroll:UpdateScrollChildRect()
	return previous ~= nil or y > 0
end
ns.NewRenderTarget = NewTarget
ns.RenderNote = Render

function ns.TextScale(state)
	local scale = tonumber(state.textScale)
	if not scale or scale ~= scale then return 1 end
	return math.min(2, math.max(0.75, scale))
end

function ns.CreateTextSizeButtons(parent, state, onChange)
	local controls = CreateFrame("Frame", nil, parent)
	controls:SetSize(62, BUTTON_HEIGHT)
	local function Make(text, label, step)
		local button = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
		button:SetSize(30, BUTTON_HEIGHT)
		button:SetText(text)
		button:SetScript("OnClick", function()
			state.textScale = math.min(2, math.max(0.75, ns.TextScale(state) + step))
			controls.refresh()
			onChange()
		end)
		button:SetScript("OnEnter", function(self) Tooltip(self, label) end)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return button
	end
	controls.decrease = Make("A-", L["Decrease text size"], -0.25)
	controls.increase = Make("A+", L["Increase text size"], 0.25)
	controls.decrease:SetPoint("LEFT", 0, 0)
	controls.increase:SetPoint("RIGHT", 0, 0)
	controls.refresh = function()
		local scale = ns.TextScale(state)
		controls.decrease:SetEnabled(scale > 0.75)
		controls.increase:SetEnabled(scale < 2)
	end
	controls.refresh()
	return controls
end

local function ApplyLayout()
	local width, height = window:GetSize()
	PANE_WIDTH = width - PANE_LEFT - MARGIN
	CONTENT_WIDTH = PANE_WIDTH - 2 * PANE_PADDING - SCROLLBAR_WIDTH
	EDITOR_WIDTH = PANE_WIDTH - PANE_PADDING - EDITOR_RIGHT - 18
	VISIBLE_ROWS = math.max(1, math.floor((height + LIST_TOP - MARGIN) / ROW_HEIGHT))

	list:SetSize(LIST_WIDTH - SCROLLBAR_WIDTH, VISIBLE_ROWS * ROW_HEIGHT)
	titleBox:SetWidth(PANE_WIDTH - TITLE_RESERVED)
	editor:SetWidth(EDITOR_WIDTH)
	reader:SetWidth(CONTENT_WIDTH)
	main.width = CONTENT_WIDTH
	placeholder:SetWidth(PANE_WIDTH - 40)

	for index = 1, VISIBLE_ROWS do
		if not rows[index] then
			rows[index] = CreateRow(index)
		end
	end
	RefreshList()

	local note = ns.GetNote(selected)
	if note and readerScroll:IsShown() then
		Render(main, note.text)
	end
end

-- Modes ----------------------------------------------------------------------

local function UpdateMode()
	local note = ns.GetNote(selected)
	local editing = note ~= nil and mode == "edit"
	main.scale = ns.TextScale(QuillDB.settings)
	local path, size, flags = unpack(editor.baseFont)
	editor:SetFont(path, size * main.scale, flags)

	editorScroll:SetShown(editing)
	readerScroll:SetShown(note ~= nil and not editing)
	modeButton:SetText(editing and L["Read"] or L["Edit"])
	modeButton:SetEnabled(note ~= nil)
	deleteButton:SetEnabled(note ~= nil)
	moveButton:SetEnabled(note ~= nil)
	popoutButton:SetEnabled(note ~= nil)
	starButton:SetEnabled(note ~= nil)
	local pinned = note ~= nil and note.pinned == true
	starButton.icon:SetDesaturated(not pinned)
	starButton.icon:SetAlpha(pinned and 1 or 0.5)
	local notebookPrivate = note ~= nil and ns.GetNotebook(note.notebook).owner ~= nil
	scopeCheck:SetChecked(ns.IsNoteCharacterOnly(selected))
	scopeCheck:SetEnabled(note ~= nil and not notebookPrivate)
	notebookLabel:SetText(ns.NotebookPath(ns.ActiveNotebook()) .. " [" .. ns.NotebookScopeText(ns.ActiveNotebook()) .. "]")
	if note then
		titleBox:Enable()
	else
		titleBox:Disable()
	end

	local hint
	if not note then
		hint = L["No note selected. Create one with \"New note\"."]
	elseif not editing then
		editor:ClearFocus()
		if not Render(main, note.text) then
			hint = L["This note is empty. Switch to edit mode to write it."]
		end
	end
	placeholder:SetText(hint or "")
	placeholder:SetShown(hint ~= nil)
end

local function SetMode(newMode)
	mode = newMode
	QuillDB.settings.mode = newMode
	UpdateMode()
	if newMode == "edit" then
		editor:SetFocus()
	end
end

local function DeleteSelected()
	DeleteNote(selected)
end

-- Undo history ---------------------------------------------------------------

-- Starts a fresh history unless it still matches the note text.
local function SyncHistory(id, text)
	local history = histories[id]
	if not history or history.last ~= text then
		histories[id] = { undo = {}, redo = {}, last = text }
	end
end

-- Typing within HISTORY_PAUSE seconds of the last change extends the current step.
local function RecordEdit(id, text)
	SyncHistory(id, histories[id] and histories[id].last or text)
	local history = histories[id]
	if text == history.last then
		return
	end
	local now = GetTime()
	if #history.undo == 0 or not history.time or now - history.time > HISTORY_PAUSE then
		table.insert(history.undo, history.last)
		if #history.undo > HISTORY_LIMIT then
			table.remove(history.undo, 1)
		end
	end
	history.time = now
	history.last = text
	history.redo = {}
end

local function StepHistory(from, to)
	local history = histories[selected]
	if not (history and #history[from] > 0) then
		return
	end
	local text = table.remove(history[from])
	table.insert(history[to], history.last)
	history.last, history.time = text, nil
	local cursor = editor:GetCursorPosition()
	editor:SetText(text)
	editor:SetCursorPosition(math.min(cursor, #text))
	ns.UpdateNote(selected, "text", text)
end

local function ChangeText(text)
	RecordEdit(selected, text)
	ns.UpdateNote(selected, "text", text)
end

function ns.Undo() StepHistory("undo", "redo") end
function ns.Redo() StepHistory("redo", "undo") end

-- Construction ---------------------------------------------------------------

-- Right column: favorite, popout, title, mode, delete and trash
local function BuildToolbar(optionsButton)
	local trashButton = IconButton(TRASH_ICON, L["Trash"], function() ns.ShowTrash() end)
	trashButton:SetPoint("RIGHT", optionsButton, "LEFT", -4, 0)

	deleteButton = Button(L["Delete"], BUTTON_WIDTH, DeleteSelected)
	deleteButton:SetPoint("RIGHT", trashButton, "LEFT", -4, 0)

	modeButton = Button(L["Edit"], BUTTON_WIDTH, function()
		SetMode(mode == "edit" and "read" or "edit")
	end)
	modeButton:SetPoint("RIGHT", deleteButton, "LEFT", -4, 0)

	popoutButton = IconButton(POPOUT_ICON, L["Open in small window"], function()
		ns.OpenNoteWindow(selected)
	end)

	starButton = IconButton(STAR_ICON, function()
		local note = ns.GetNote(selected)
		return note and note.pinned and L["Remove from favorites"] or L["Add to favorites"]
	end, function(self)
		TogglePinned(selected)
		self:GetScript("OnEnter")(self)
	end)
	starButton:SetPoint("TOPLEFT", PANE_LEFT, TOP)
	popoutButton:SetPoint("LEFT", starButton, "RIGHT", 4, 0)
end

local function BuildEditor(pane)
	-- Edit mode: the Markdown source
	editorScroll = CreateFrame("ScrollFrame", nil, pane, "InputScrollFrameTemplate")
	editorScroll:SetPoint("TOPLEFT", PANE_PADDING, -PANE_PADDING)
	editorScroll:SetPoint("BOTTOMRIGHT", -EDITOR_RIGHT, PANE_PADDING)
	if editorScroll.CharCount then
		editorScroll.CharCount:Hide()
	end
	editor = editorScroll.EditBox
	editor:SetFontObject("ChatFontNormal")
	editor.baseFont = { editor:GetFont() }
	ns.StyleText(editor)
	editor:SetWidth(EDITOR_WIDTH)
	editor:SetMaxLetters(0)
	editor:SetAutoFocus(false)
	if editor.Instructions then
		editor.Instructions:SetText(L["Write in Markdown …"])
	end
	-- Hooked, the template's own handler keeps the cursor in view
	editor:HookScript("OnTextChanged", function(self, userInput)
		if userInput and selected then
			ChangeText(self:GetText())
		end
	end)
	editor:SetScript("OnTabPressed", function(self)
		self:Insert("  ")
		ChangeText(self:GetText())
	end)
	editor:HookScript("OnKeyDown", function(_, key)
		if not (selected and IsControlKeyDown()) then
			return
		end
		if key == "Z" and IsShiftKeyDown() or key == "Y" then
			ns.Redo()
		elseif key == "Z" then
			ns.Undo()
		end
	end)
	local textSize = ns.CreateTextSizeButtons(window, QuillDB.settings, ns.RefreshWindow)
	textSize:SetPoint("TOPRIGHT", -MARGIN, TOP - 28)
end

local function Build()
	window = CreateFrame("Frame", "QuillWindow", UIParent, "BasicFrameTemplateWithInset")
	window:SetSize(WIDTH, HEIGHT)
	window:SetFrameStrata("HIGH")
	window:SetClampedToScreen(true)
	ns.StyleFrame(window)
	window:SetResizable(true)
	window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	window:Hide()
	table.insert(UISpecialFrames, "QuillWindow")

	local heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOP", 0, -5)
	heading:SetText("Quill")

	local optionsButton = Button("", 22, function()
		ns.OpenOptions()
	end)
	optionsButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -MARGIN, TOP)
	local optionsIcon = optionsButton:CreateTexture(nil, "ARTWORK")
	optionsIcon:SetPoint("TOPLEFT", 4, -4)
	optionsIcon:SetPoint("BOTTOMRIGHT", -4, 4)
	optionsIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
	optionsIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	optionsButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Options"])
		if InCombatLockdown() then
			GameTooltip:AddLine(L["The options cannot be opened in combat."], 1, 0.3, 0.3, true)
		end
		GameTooltip:Show()
	end)
	optionsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Left column: new note, search and list
	local newButton = Button(L["New note"], LIST_WIDTH, function()
		search:SetText("")
		local id, err = ns.CreateNote("")
		if not id then ns.Say(err); return end
		ns.OpenNote(id, "edit")
		titleBox:SetFocus()
		titleBox:HighlightText()
	end)
	newButton:SetPoint("TOPLEFT", MARGIN, TOP)

	local newNotebook = Button(L["New notebook"], 104, function() ns.ShowNotebookManager() end)
	newNotebook:SetPoint("TOPLEFT", MARGIN, TOP - 28)
	local manageNotebook = Button(L["Manage"], 102, function() ns.ShowNotebookManager(ns.ActiveNotebook()) end)
	manageNotebook:SetPoint("LEFT", newNotebook, "RIGHT", 4, 0)

	search = CreateFrame("EditBox", nil, window, "SearchBoxTemplate")
	search:SetSize(LIST_WIDTH - 36, 20)
	search:SetPoint("TOPLEFT", MARGIN + 6, SEARCH_TOP)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", function()
		if list then
			RefreshList()
		end
	end)
	search:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Search: tag:raid status:open"])
		local _, err = ns.Metadata.Query(self:GetText())
		if err then GameTooltip:AddLine(err, 1, 0.3, 0.3, true) end
		GameTooltip:Show()
	end)
	search:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local tagButton = Button("#", 28, function(self)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then
			ns.Say(L["Tag menu is not available in this client. Type tag:name in the search box."])
			return
		end
		MenuUtil.CreateContextMenu(self, function(_, root)
			local tags = ns.AllTags()
			root:CreateButton(L["All notes"], function() ns.FilterTag(nil) end)
			if #tags == 0 then
				root:CreateTitle(L["No tags yet"])
			end
			for _, tag in ipairs(tags) do
				root:CreateRadio("#" .. tag, function() return search:GetText() == "tag:" .. tag end,
					function() ns.FilterTag(tag) end)
			end
			if root.SetScrollMode and #tags > 20 then root:SetScrollMode(400) end
		end)
	end)
	tagButton:SetPoint("LEFT", search, "RIGHT", 2, 0)
	tagButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Filter by tag"])
		GameTooltip:Show()
	end)
	tagButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	list = CreateFrame("ScrollFrame", nil, window, "FauxScrollFrameTemplate")
	list:SetPoint("TOPLEFT", MARGIN, LIST_TOP)
	list:SetSize(LIST_WIDTH - SCROLLBAR_WIDTH, VISIBLE_ROWS * ROW_HEIGHT)
	list:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, RefreshList)
	end)
	searchError = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	searchError:SetPoint("TOPLEFT", list, "TOPLEFT", 4, 0)
	searchError:SetWidth(LIST_WIDTH - SCROLLBAR_WIDTH - 8)
	searchError:SetJustifyH("LEFT")
	ns.StyleText(searchError, "error")
	for index = 1, VISIBLE_ROWS do
		rows[index] = CreateRow(index)
	end

	BuildToolbar(optionsButton)

	moveButton = Button(L["Move note"], 110, function()
		local id = selected
		ns.ChooseNotebook(L["Move note"], function(notebook)
			local ok, err = ns.MoveNote(id, notebook)
			if not ok then ns.Say(err); return end
			ns.OpenNote(id)
		end)
	end)
	moveButton:SetPoint("TOPLEFT", PANE_LEFT, TOP - 28)
	scopeCheck = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
	scopeCheck:SetSize(24, 24)
	scopeCheck:SetPoint("LEFT", moveButton, "RIGHT", 6, 0)
	scopeCheck:SetScript("OnClick", function(self)
		local ok, err = ns.SetNoteCharacterOnly(selected, self:GetChecked())
		if not ok then
			ns.Say(err)
		end
		UpdateMode()
		RefreshList()
	end)
	scopeCheck:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Only available to this character"])
		GameTooltip:AddLine(L["Notes in a character notebook are always character-only."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	scopeCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local scopeLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	scopeLabel:SetPoint("LEFT", scopeCheck, "RIGHT", 0, 0)
	scopeLabel:SetText(L["Character only"])
	ns.StyleText(scopeLabel)
	notebookLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	notebookLabel:SetPoint("LEFT", scopeLabel, "RIGHT", 12, 0)
	notebookLabel:SetPoint("RIGHT", window, "TOPRIGHT", -MARGIN - 70, TOP - 28 - BUTTON_HEIGHT / 2)
	notebookLabel:SetJustifyH("LEFT")
	notebookLabel:SetWordWrap(false)
	ns.StyleText(notebookLabel)

	titleBox = CreateFrame("EditBox", nil, window, "InputBoxInstructionsTemplate")
	titleBox:SetSize(PANE_WIDTH - TITLE_RESERVED, BUTTON_HEIGHT)
	titleBox:SetPoint("TOPLEFT", PANE_LEFT + 2 * BUTTON_HEIGHT + 14, TOP)
	titleBox:SetAutoFocus(false)
	titleBox:SetMaxLetters(100)
	if titleBox.Instructions then
		titleBox.Instructions:ClearAllPoints()
		titleBox.Instructions:SetPoint("LEFT")
		titleBox.Instructions:SetPoint("RIGHT")
		titleBox.Instructions:SetText(L["Title"])
	end
	titleBox:HookScript("OnTextChanged", function(self, userInput)
		if userInput and selected then
			local ok, err = ns.UpdateNote(selected, "title", self:GetText())
			self.conflict = not ok and err or nil
			if ok then
				self:SetTextColor(1, 1, 1)
				local text = ns.GetNote(selected).text
				editor:SetText(text)
				SyncHistory(selected, text)
				RefreshList()
			else
				self:SetTextColor(1, 0.3, 0.3)
			end
		end
	end)
	titleBox:HookScript("OnEditFocusLost", function(self)
		if self.conflict then
			ns.Say(self.conflict)
			self.conflict = nil
			self:SetTextColor(1, 1, 1)
			local note = ns.GetNote(selected)
			self:SetText(note and note.title or "")
		end
	end)
	titleBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		if mode == "edit" then
			editor:SetFocus()
		end
	end)

	local pane = CreateFrame("Frame", nil, window)
	pane:SetPoint("TOPLEFT", PANE_LEFT, PANE_TOP)
	pane:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN)
	local background = pane:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.3)

	BuildEditor(pane)

	-- Read mode: the rendered note
	readerScroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
	readerScroll:SetPoint("TOPLEFT", PANE_PADDING, -PANE_PADDING)
	readerScroll:SetPoint("BOTTOMRIGHT", -PANE_PADDING - SCROLLBAR_WIDTH, PANE_PADDING)
	reader = CreateFrame("Frame", nil, readerScroll)
	reader:SetSize(CONTENT_WIDTH, 1)
	readerScroll:SetScrollChild(reader)
	main = NewTarget(reader, readerScroll)

	placeholder = pane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	placeholder:SetPoint("CENTER")
	placeholder:SetWidth(PANE_WIDTH - 40)
	ns.StyleText(placeholder, "muted")

	local resizeHandle = CreateFrame("Button", nil, window)
	resizeHandle:SetSize(16, 16)
	resizeHandle:SetPoint("BOTTOMRIGHT", -4, 4)
	resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resizeHandle:SetFrameLevel(window:GetFrameLevel() + 2)
	resizeHandle:SetScript("OnMouseDown", function()
		window:StartSizing("BOTTOMRIGHT")
	end)
	resizeHandle:SetScript("OnMouseUp", function()
		window:StopMovingOrSizing()
		SavePosition()
	end)

	window:SetScript("OnSizeChanged", ApplyLayout)
	window:SetScript("OnHide", function()
		editor:ClearFocus()
		titleBox:ClearFocus()
		search:ClearFocus()
	end)

	RestorePosition()
	ApplyLayout()
	mode = QuillDB.settings.mode == "edit" and "edit" or "read"
end

local function EnsureWindow()
	if window then
		return
	end
	local ok, err = pcall(Build)
	if not ok then
		window = nil
		error(err, 0)
	end
end

-- Public ---------------------------------------------------------------------

function ns.RefreshWindow()
	if ns.RefreshNoteWindows then ns.RefreshNoteWindows() end
	if not window then return end
	UpdateMode()
	RefreshList()
end

function ns.FilterTag(tag)
	EnsureWindow()
	search:SetText(tag and "tag:" .. tag or "")
	RefreshList()
end

-- Tags of every note this character can see, sorted
function ns.AllTags()
	local seen, result = {}, {}
	for _, id in ipairs(ns.SortedNotes()) do
		local properties, body = ns.Metadata.Parse(ns.GetNote(id).text)
		for _, tag in ipairs(ns.Metadata.Tags(properties, body)) do
			if not seen[tag] then
				seen[tag] = true
				result[#result + 1] = tag
			end
		end
	end
	table.sort(result)
	return result
end

-- Selects a note (or none), optionally switches the mode, and shows the window
function ns.OpenNote(id, newMode)
	EnsureWindow()

	selected = ns.GetNote(id) and id or nil
	QuillDB.settings.selected = selected
	if newMode then
		mode = newMode
		QuillDB.settings.mode = newMode
	end

	local note = ns.GetNote(selected)
	if note then
		QuillDB.settings.notebook = note.notebook
		local parent = note.notebook
		while parent do
			collapsed[parent] = nil
			parent = ns.GetNotebook(parent).parent
		end
	end
	titleBox.conflict = nil
	titleBox:SetTextColor(1, 1, 1)
	titleBox:SetText(note and note.title or "")
	titleBox:SetCursorPosition(0)
	editor:SetText(note and note.text or "")
	if note then SyncHistory(selected, editor:GetText()) end
	editor:SetCursorPosition(0)
	editorScroll:SetVerticalScroll(0)
	readerScroll:SetVerticalScroll(0)

	window:Show()
	UpdateMode()
	RefreshList()
end

function ns.SelectNotebook(id)
	if not ns.GetNotebook(id) then
		ns.Say(L["This notebook is not available."])
		return
	end
	QuillDB.settings.notebook = id
	ns.OpenNote(nil)
end

function ns.InsertChatLink(link)
	if window and window:IsShown() and mode == "edit" and editor:HasFocus() and ns.GetNote(selected)
		and type(link) == "string" and ns.Markdown.ReadHyperlink(link, 1) then
		editor:Insert(link)
		ChangeText(editor:GetText())
		return true
	end
	return false
end

-- Since 11.2 the chat code calls ChatFrameUtil.InsertLink; older clients only have the global
if ChatFrameUtil and ChatFrameUtil.InsertLink then
	hooksecurefunc(ChatFrameUtil, "InsertLink", function(link) ns.InsertChatLink(link) end)
elseif ChatEdit_InsertLink then
	hooksecurefunc("ChatEdit_InsertLink", function(link) ns.InsertChatLink(link) end)
end

function ns.ResetWindow()
	QuillDB.settings.window = nil
	if window then
		window:StopMovingOrSizing()
		RestorePosition()
		ApplyLayout()
	end
	ns.Say(L["Window size and position reset."])
end

function ns.ToggleWindow()
	if window and window:IsShown() then
		window:Hide()
		return
	end

	local id = QuillDB.settings.selected
	if not ns.GetNote(id) then
		id = ns.SortedNotes()[1]
	end
	ns.OpenNote(id)
end
