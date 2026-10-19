local _, ns = ...
local L = ns.L

-- Small read-only windows showing one note each, e.g. a boss strategy during a fight.
-- They are plain addon frames, so they work in combat and are not closed by Escape.

local WIDTH, HEIGHT = 320, 260
local MIN_WIDTH, MIN_HEIGHT = 180, 100
local MAX_WIDTH, MAX_HEIGHT = 1200, 1200
local PADDING = 10
local SCROLLBAR_WIDTH = 22
local LOCKED_ICON = "Interface\\Buttons\\LockButton-Locked-Up"
local UNLOCKED_ICON = "Interface\\Buttons\\LockButton-Unlocked-Up"
local VALID_POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
	RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local windows = {}
local count = 0

local function State(id)
	local popouts = QuillDB.settings.popouts or {}
	QuillDB.settings.popouts = popouts
	if type(popouts[id]) ~= "table" then popouts[id] = {} end
	return popouts[id]
end

local function Save(window)
	local state = State(window.noteId)
	local point, _, relativePoint, x, y = window:GetPoint(1)
	state.point = VALID_POINTS[point] and point or "CENTER"
	state.relativePoint = VALID_POINTS[relativePoint] and relativePoint or "CENTER"
	state.x, state.y = x or 0, y or 0
	state.width, state.height = window:GetWidth(), window:GetHeight()
end

local function Restore(window)
	local state = State(window.noteId)
	local width = math.min(MAX_WIDTH, math.max(MIN_WIDTH, tonumber(state.width) or WIDTH))
	local height = math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, tonumber(state.height) or HEIGHT))
	window:SetSize(width, height)
	window:ClearAllPoints()
	if VALID_POINTS[state.point] then
		local relativePoint = VALID_POINTS[state.relativePoint] and state.relativePoint or state.point
		window:SetPoint(state.point, UIParent, relativePoint, tonumber(state.x) or 0, tonumber(state.y) or 0)
	else
		-- Cascade new windows so they do not cover each other.
		local offset = (count % 8) * 24
		window:SetPoint("TOPLEFT", UIParent, "CENTER", 200 + offset, 150 - offset)
	end
end

local function Render(window)
	local note = ns.GetNote(window.noteId)
	if not note then
		window:Hide()
		return
	end
	window.heading:SetText(ns.NoteTitle(note))
	window.target.width = math.max(1, window:GetWidth() - 2 * PADDING - SCROLLBAR_WIDTH)
	window.target.locked = window.locked
	window.target.scale = ns.TextScale(State(window.noteId))
	window.content:SetWidth(window.target.width)
	ns.RenderNote(window.target, note.text)
end

local function ApplyLock(window)
	local locked = window.locked
	window:EnableMouse(not locked)
	window.resize:SetShown(not locked)
	window.textSize:SetShown(not locked)
	-- Without the text size row the note moves up into its space.
	window.scroll:SetPoint("TOPLEFT", PADDING, locked and -30 or -56)
	window.lock:SetNormalTexture(locked and LOCKED_ICON or UNLOCKED_ICON)
	State(window.noteId).locked = locked or nil
	Render(window)
end

local function Create(id)
	count = count + 1
	local window = CreateFrame("Frame", "QuillNoteWindow" .. count, UIParent, "BasicFrameTemplateWithInset")
	window.noteId = id
	window:SetFrameStrata("MEDIUM")
	window:SetClampedToScreen(true)
	ns.StyleFrame(window)
	window:SetMovable(true)
	window:SetResizable(true)
	window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self)
		if not self.locked then self:StartMoving() end
	end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Save(self)
	end)

	local close = window.CloseButton
	window.lock = CreateFrame("Button", nil, window)
	window.lock:SetSize(24, 24)
	if close then
		window.lock:SetPoint("RIGHT", close, "LEFT", -2, 0)
	else
		window.lock:SetPoint("TOPRIGHT", -28, -4)
	end
	window.lock:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	window.lock:SetScript("OnClick", function()
		window.locked = not window.locked
		ApplyLock(window)
	end)
	window.lock:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(window.locked and L["Unlock window"] or L["Lock window"])
		GameTooltip:AddLine(L["A locked window cannot be moved and lets clicks through."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	window.lock:SetScript("OnLeave", function() GameTooltip:Hide() end)

	window.heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.heading:SetPoint("TOPLEFT", 8, -5)
	window.heading:SetPoint("RIGHT", window.lock, "LEFT", -4, 0)
	window.heading:SetJustifyH("LEFT")
	window.heading:SetWordWrap(false)

	window.textSize = ns.CreateTextSizeButtons(window, State(id), function() Render(window) end)
	window.textSize:SetPoint("TOPRIGHT", -PADDING, -28)

	local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
	window.scroll = scroll
	scroll:SetPoint("TOPLEFT", PADDING, -56)
	scroll:SetPoint("BOTTOMRIGHT", -PADDING - SCROLLBAR_WIDTH, PADDING)
	window.content = CreateFrame("Frame", nil, scroll)
	window.content:SetSize(1, 1)
	scroll:SetScrollChild(window.content)
	window.target = ns.NewRenderTarget(window.content, scroll)

	window.resize = CreateFrame("Button", nil, window)
	window.resize:SetSize(16, 16)
	window.resize:SetPoint("BOTTOMRIGHT", -4, 4)
	window.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	window.resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	window.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	window.resize:SetFrameLevel(window:GetFrameLevel() + 2)
	window.resize:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
	window.resize:SetScript("OnMouseUp", function()
		window:StopMovingOrSizing()
		Save(window)
	end)

	window:SetScript("OnSizeChanged", function(self)
		if self:IsShown() then Render(self) end
	end)
	window:Hide()
	return window
end

function ns.OpenNoteWindow(id)
	if not ns.GetNote(id) then
		ns.Say(L["This note is not available."])
		return
	end
	local window = windows[id]
	if not window then
		window = Create(id)
		windows[id] = window
		Restore(window)
	end
	window.locked = State(id).locked == true
	window:Show()
	window:Raise()
	ApplyLock(window)
end

-- Re-renders the windows of one note, or of all notes without an id; unavailable notes close.
function ns.RefreshNoteWindows(id)
	for noteId, window in pairs(windows) do
		if (id == nil or id == noteId) and window:IsShown() then
			Render(window)
		end
	end
end

function ns.NoteWindow(id)
	return windows[id]
end
