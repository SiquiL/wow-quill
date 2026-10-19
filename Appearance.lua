local _, ns = ...
local L = ns.L
local frames, texts = {}, {}
local themes = {
	standard = {
		body = { 1, 1, 1 }, heading = { 1, 0.82, 0 }, muted = { 0.6, 0.6, 0.6 },
		link = { 0.31, 0.72, 1 }, code = { 0.5, 0.83, 0.63 }, error = { 1, 0.35, 0.35 },
	},
	light = {
		body = { 0.16, 0.1, 0.05 }, heading = { 0.34, 0.16, 0.04 }, muted = { 0.4, 0.32, 0.23 },
		link = { 0.04, 0.24, 0.58 }, code = { 0.05, 0.32, 0.15 }, error = { 0.65, 0.04, 0.04 },
	},
}

-- The saved ID "solid" is kept so existing settings stay valid.
ns.THEMES = {
	{ id = "standard", label = "Standard" },
	{ id = "solid", label = "Custom color" },
}
local themeById = {}
for _, theme in ipairs(ns.THEMES) do themeById[theme.id] = theme end

function ns.IsTheme(id)
	return themeById[id] ~= nil
end

function ns.ValidColor(color)
	if type(color) ~= "table" then return false end
	for i = 1, 3 do
		if type(color[i]) ~= "number" or color[i] ~= color[i] or color[i] < 0 or color[i] > 1 then return false end
	end
	return true
end

function ns.ValidOpacity(alpha)
	return type(alpha) == "number" and alpha == alpha and alpha >= 0 and alpha <= 1
end

-- Applies to every theme; only backgrounds fade, text and borders stay opaque.
function ns.BackgroundOpacity()
	local alpha = QuillDB.settings.backgroundOpacity
	return ns.ValidOpacity(alpha) and alpha or 1
end

function ns.SetBackgroundOpacity(alpha)
	if not ns.ValidOpacity(alpha) then return end
	QuillDB.settings.backgroundOpacity = alpha
	ns.RefreshAppearance()
end

local function Light()
	local color = QuillDB.settings.backgroundColor or { 0.08, 0.08, 0.08 }
	-- A mostly transparent background shows the game world, so keep light text.
	return QuillDB.settings.theme == "solid" and ns.BackgroundOpacity() >= 0.5
		and color[1] * 0.2126 + color[2] * 0.7152 + color[3] * 0.0722 > 0.55
end

function ns.ThemeColor(role)
	local palette = Light() and themes.light or themes.standard
	return unpack(palette[role] or palette.body)
end

local function ApplyFrame(entry)
	local texture, alpha = entry.texture, ns.BackgroundOpacity()
	local solid = QuillDB.settings.theme == "solid"
	if solid then
		local r, g, b = unpack(QuillDB.settings.backgroundColor or { 0.08, 0.08, 0.08 })
		texture:SetColorTexture(r, g, b, alpha)
		texture:Show()
	else
		texture:Hide()
	end
	-- The template's own backgrounds would otherwise cover the custom color.
	for _, background in ipairs(entry.backgrounds) do
		background:SetAlpha(solid and 0 or alpha)
	end
end

-- Every background texture of the frame template (Bg, InsetBg, Inset.Bg, ...), whatever the client names them.
local function TemplateBackgrounds(frame)
	-- The title bar stays opaque like in Tally.
	local list, seen = {}, {}
	for _, key in ipairs({ "TitleBg", "TopTileStreaks" }) do
		if frame[key] then seen[frame[key]] = true end
	end
	local function Add(region)
		if region and not seen[region] and region.SetAlpha then
			seen[region] = true
			list[#list + 1] = region
		end
	end
	local function Scan(owner)
		if not (owner and owner.GetRegions) then return end
		for _, region in ipairs({ owner:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "Texture"
				and region.GetDrawLayer and region:GetDrawLayer() == "BACKGROUND" then
				Add(region)
			end
		end
	end
	Scan(frame)
	Scan(frame.Inset)
	Add(frame.Bg)
	Add(frame.InsetBg)
	Add(frame.Inset and frame.Inset.Bg)
	return list
end

function ns.StyleFrame(frame)
	local backgrounds = TemplateBackgrounds(frame)
	local texture = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
	texture:SetPoint("TOPLEFT", 5, -24)
	texture:SetPoint("BOTTOMRIGHT", -5, 5)
	local entry = { texture = texture, frame = frame, backgrounds = backgrounds }
	frames[#frames + 1] = entry
	ApplyFrame(entry)
end

function ns.StyleText(text, role)
	texts[#texts + 1] = { text = text, role = role or "body" }
	text:SetTextColor(ns.ThemeColor(role))
end

function ns.RefreshAppearance()
	for _, entry in ipairs(frames) do ApplyFrame(entry) end
	for _, entry in ipairs(texts) do entry.text:SetTextColor(ns.ThemeColor(entry.role)) end
	if ns.RefreshWindow then ns.RefreshWindow() end
end

function ns.SetTheme(theme)
	if not ns.IsTheme(theme) then
		ns.Say(L["Unknown theme."])
		return
	end
	QuillDB.settings.theme = theme
	ns.RefreshAppearance()
end

-- Passing an opacity adds the picker's opacity slider; onChange then also receives the alpha.
function ns.PickColor(color, onChange, opacity)
	if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
		ns.Say(L["The color picker is not available in this client."])
		return
	end
	local original = { unpack(color) }
	local hasOpacity = opacity ~= nil and ColorPickerFrame.GetColorAlpha ~= nil
	local function Changed()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		onChange({ r, g, b }, hasOpacity and ColorPickerFrame:GetColorAlpha() or opacity)
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = color[1], g = color[2], b = color[3],
		hasOpacity = hasOpacity, opacity = opacity,
		swatchFunc = Changed,
		opacityFunc = hasOpacity and Changed or nil,
		cancelFunc = function() onChange(original, opacity) end,
	})
end

function ns.SetNotebookColor(id, color)
	local notebook = ns.GetNotebook(id)
	if not notebook then return nil, L["This notebook is not available."] end
	if color ~= nil and not ns.ValidColor(color) then return nil, L["Invalid color."] end
	notebook.color = color and { unpack(color) } or nil
	return true
end
