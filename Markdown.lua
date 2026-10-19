local _, ns = ...

-- Markdown subset for the read mode. Pure Lua without game API calls, so it can be tested
-- outside the client. Parse returns blocks; Spans returns inline text and font styles.
local Markdown = {}
ns.Markdown = Markdown

-- Colors for links, code and the color-only Inline compatibility helper.
Markdown.COLORS = {
	bold = "ffffd100",
	italic = "ffa8c8ff",
	boldItalic = "ffffe680",
	strike = "ff808080",
	code = "ff7fd4a0",
	link = "ff4fb8ff",
}

local COLORS = Markdown.COLORS

local namedColors = {}
for name, hex in ([[
	aliceblue=f0f8ff antiquewhite=faebd7 aqua=00ffff aquamarine=7fffd4 azure=f0ffff
	beige=f5f5dc bisque=ffe4c4 black=000000 blanchedalmond=ffebcd blue=0000ff blueviolet=8a2be2
	brown=a52a2a burlywood=deb887 cadetblue=5f9ea0 chartreuse=7fff00 chocolate=d2691e coral=ff7f50
	cornflowerblue=6495ed cornsilk=fff8dc crimson=dc143c cyan=00ffff darkblue=00008b darkcyan=008b8b
	darkgoldenrod=b8860b darkgray=a9a9a9 darkgreen=006400 darkgrey=a9a9a9 darkkhaki=bdb76b
	darkmagenta=8b008b darkolivegreen=556b2f darkorange=ff8c00 darkorchid=9932cc darkred=8b0000
	darksalmon=e9967a darkseagreen=8fbc8f darkslateblue=483d8b darkslategray=2f4f4f darkslategrey=2f4f4f
	darkturquoise=00ced1 darkviolet=9400d3 deeppink=ff1493 deepskyblue=00bfff dimgray=696969
	dimgrey=696969 dodgerblue=1e90ff firebrick=b22222 floralwhite=fffaf0 forestgreen=228b22
	fuchsia=ff00ff gainsboro=dcdcdc ghostwhite=f8f8ff gold=ffd700 goldenrod=daa520 gray=808080
	green=008000 greenyellow=adff2f grey=808080 honeydew=f0fff0 hotpink=ff69b4 indianred=cd5c5c
	indigo=4b0082 ivory=fffff0 khaki=f0e68c lavender=e6e6fa lavenderblush=fff0f5 lawngreen=7cfc00
	lemonchiffon=fffacd lightblue=add8e6 lightcoral=f08080 lightcyan=e0ffff lightgoldenrodyellow=fafad2
	lightgray=d3d3d3 lightgreen=90ee90 lightgrey=d3d3d3 lightpink=ffb6c1 lightsalmon=ffa07a
	lightseagreen=20b2aa lightskyblue=87cefa lightslategray=778899 lightslategrey=778899 lightsteelblue=b0c4de
	lightyellow=ffffe0 lime=00ff00 limegreen=32cd32 linen=faf0e6 magenta=ff00ff maroon=800000
	mediumaquamarine=66cdaa mediumblue=0000cd mediumorchid=ba55d3 mediumpurple=9370db
	mediumseagreen=3cb371 mediumslateblue=7b68ee mediumspringgreen=00fa9a mediumturquoise=48d1cc
	mediumvioletred=c71585 midnightblue=191970 mintcream=f5fffa mistyrose=ffe4e1 moccasin=ffe4b5
	navajowhite=ffdead navy=000080 oldlace=fdf5e6 olive=808000 olivedrab=6b8e23 orange=ffa500
	orangered=ff4500 orchid=da70d6 palegoldenrod=eee8aa palegreen=98fb98 paleturquoise=afeeee
	palevioletred=db7093 papayawhip=ffefd5 peachpuff=ffdab9 peru=cd853f pink=ffc0cb plum=dda0dd
	powderblue=b0e0e6 purple=800080 rebeccapurple=663399 red=ff0000 rosybrown=bc8f8f royalblue=4169e1
	saddlebrown=8b4513 salmon=fa8072 sandybrown=f4a460 seagreen=2e8b57 seashell=fff5ee sienna=a0522d
	silver=c0c0c0 skyblue=87ceeb slateblue=6a5acd slategray=708090 slategrey=708090 snow=fffafa
	springgreen=00ff7f steelblue=4682b4 tan=d2b48c teal=008080 thistle=d8bfd8 tomato=ff6347
	turquoise=40e0d0 violet=ee82ee wheat=f5deb3 white=ffffff whitesmoke=f5f5f5 yellow=ffff00
	yellowgreen=9acd32
]]):gmatch("(%a+)=(%x+)") do
	namedColors[name] = hex
end

local function FontTag(text, position)
	local tag, finish = text:match("^(<[^<>\r\n]+>)()", position)
	if not tag then return end
	local lower = tag:lower()
	if lower:match("^</font%s*>$") then return finish, nil, true end
	local value = lower:match("^<font%s+color%s*=%s*(.-)%s*>$")
	if not value then return end
	local quote = value:sub(1, 1)
	if quote == '"' or quote == "'" then
		if value:sub(-1) ~= quote then return end
		value = value:sub(2, -2)
	end
	local hex = namedColors[value] or value:match("^#(%x%x%x%x%x%x)$")
	if not hex then
		local r, g, b = value:match("^#(%x)(%x)(%x)$")
		if r then hex = r .. r .. g .. g .. b .. b end
	end
	if hex then return finish, "ff" .. hex end
end

-- "|" starts escape sequences in FontStrings. Edit boxes may already return a typed pipe as
-- "||", so both forms become one literal pipe.
function Markdown.Escape(text)
	return (text:gsub("||", "|"):gsub("|", "||"))
end

local function IsWord(char)
	return char ~= "" and char:match("[%w]") ~= nil
end

local function IsSpace(char)
	return char == "" or char:match("%s") ~= nil
end

function Markdown.ReadHyperlink(text, position)
	local start = position
	local pipe = text:sub(start, start + 1) == "||" and "||" or "|"
	local color = text:match("^" .. pipe .. "c(%x%x%x%x%x%x%x%x)", start)
	if color then
		start = start + #pipe + 9
	else
		local namedColor = text:match("^" .. pipe .. "cn[%w_]+:()", start)
		if namedColor then start = namedColor end
	end

	local link, label, finish = text:match("^" .. pipe .. "H([^|%c]+)" .. pipe .. "h([^|%c]*)" .. pipe .. "h()", start)
	if not link or not link:match("^[%a][%w_]*:") then
		return nil
	end
	if text:sub(finish, finish + #pipe) == pipe .. "r" then
		finish = finish + #pipe + 1
	end
	return link, label, color, finish
end

function Markdown.ReadWikiLink(text, position)
	if text:sub(position, position + 1) ~= "[[" then return end
	local close = text:find("]]", position + 2, true)
	if not close then return end
	local content = text:sub(position + 2, close - 1)
	if content:find("[\r\n%[%]]") then return end
	local separator = content:find("|", 1, true)
	local target = (separator and content:sub(1, separator - 1) or content):match("^%s*(.-)%s*$")
	local alias = separator and content:sub(separator + (content:sub(separator, separator + 1) == "||" and 2 or 1)) or nil
	if target == "" then return end
	return target, alias, close + 2
end

-- Keep source offsets and pipe escaping intact when updating links after a rename.
function Markdown.MapWikiLinks(source, replace)
	local output, fence, frontmatter = {}, nil, false
	local first = true
	for line, newline in (source .. "\n"):gmatch("(.-)(\n)") do
		local original = line
		local logical = line:gsub("\r$", "")
		local delimiter = logical:match("^%s*([`~][`~][`~]+)")
		if first and logical == "---" then
			frontmatter = true
		elseif frontmatter then
			if logical == "---" then frontmatter = false end
		elseif fence then
			if delimiter and delimiter:sub(1, 1) == fence:sub(1, 1) and #delimiter >= #fence
				and line:match("^%s*[`~]+%s*$") then fence = nil end
		elseif delimiter then
			fence = delimiter
		else
			local parts, i = {}, 1
			while i <= #line do
				local target, alias, finish = Markdown.ReadWikiLink(line, i)
				local _, _, _, linkEnd = Markdown.ReadHyperlink(line, i)
				local webEnd = line:match("^%[[^%]]+%]%([^%)%s]*%)()", i)
				local codeEnd = line:sub(i, i) == "`" and line:find("`", i + 1, true)
				if line:sub(i, i) == "\\" then
					parts[#parts + 1] = line:sub(i, i + 1)
					i = i + 2
				elseif linkEnd or codeEnd or webEnd then
					local last = linkEnd and linkEnd - 1 or webEnd and webEnd - 1 or codeEnd
					parts[#parts + 1] = line:sub(i, last)
					i = last + 1
				elseif target then
					parts[#parts + 1] = replace(target, alias, line:sub(i, finish - 1)) or line:sub(i, finish - 1)
					i = finish
				else
					parts[#parts + 1] = line:sub(i, i)
					i = i + 1
				end
			end
			original = table.concat(parts)
		end
		first = false
		output[#output + 1] = original .. newline
	end
	return table.concat(output):sub(1, -2)
end

-- Pair tags first so incomplete tags stay visible, without consuming code or link labels.
local function FontTags(text)
	local tags, stack, i = {}, {}, 1
	while i <= #text do
		local char = text:sub(i, i)
		local _, _, _, hyperlinkEnd = Markdown.ReadHyperlink(text, i)
		local _, _, wikiEnd = Markdown.ReadWikiLink(text, i)
		local webEnd = text:match("^%[[^%]]+%]%([^%)%s]*%)()", i)
		local codeEnd = char == "`" and text:find("`", i + 1, true)
		if char == "\\" and text:sub(i + 1, i + 1):match("[%p]") then
			i = i + 2
		elseif hyperlinkEnd or wikiEnd or webEnd or codeEnd then
			i = hyperlinkEnd or wikiEnd or webEnd or codeEnd + 1
		else
			local finish, color, closing = FontTag(text, i)
			if finish then
				if closing then
					local opening = table.remove(stack)
					if opening then
						tags[opening.position] = { finish = opening.finish, color = opening.color }
						tags[i] = { finish = finish, closing = true }
					end
				else
					stack[#stack + 1] = { position = i, finish = finish, color = color }
				end
				i = finish
			else
				i = i + 1
			end
		end
	end
	return tags
end

function Markdown.Spans(text)
	text = text:gsub("||", "|")

	local out, buffer = {}, {}
	local bold, italic, strike = false, false, false
	local fontTags, fontColors = FontTags(text), {}
	local fontColor

	local function Flush()
		if #buffer == 0 then
			return
		end
		local segment = table.concat(buffer)
		buffer = {}
		out[#out + 1] = {
			text = segment,
			bold = bold or nil,
			italic = italic or nil,
			strike = strike or nil,
			color = fontColor,
		}
	end

	local function Special(kind, segment)
		Flush()
		out[#out + 1] = {
			text = segment,
			bold = bold or nil,
			italic = italic or nil,
			strike = strike or nil,
			color = fontColor,
			[kind] = true,
		}
		return out[#out]
	end

	-- Opens only when a closing delimiter follows, closes only when open
	local function Toggle(active, delimiter, position)
		local before = text:sub(position - 1, position - 1)
		local after = text:sub(position + #delimiter, position + #delimiter)
		local underscore = delimiter:sub(1, 1) == "_"
		if active then
			if IsSpace(before) or (underscore and IsWord(after)) then
				return nil
			end
			return false
		end
		if IsSpace(after) or (underscore and IsWord(before)) then
			return nil
		end
		if text:find(delimiter, position + #delimiter + 1, true) then
			return true
		end
		return nil
	end

	local i, length = 1, #text
	while i <= length do
		local char = text:sub(i, i)
		local pair = text:sub(i, i + 1)
		local handled = false

		if fontTags[i] then
			Flush()
			local tag = fontTags[i]
			if tag.closing then
				table.remove(fontColors)
			else
				fontColors[#fontColors + 1] = tag.color
			end
			fontColor = fontColors[#fontColors]
			i = tag.finish
			handled = true
		elseif char == "|" then
			local link, label, color, finish = Markdown.ReadHyperlink(text, i)
			if link then
				local span = Special("hyperlink", label)
				span.hyperlink, span.color = link, color or fontColor
				i = finish
				handled = true
			end
		elseif char == "\\" and text:sub(i + 1, i + 1):match("[%p]") then
			buffer[#buffer + 1] = text:sub(i + 1, i + 1)
			i = i + 2
			handled = true
		elseif char == "`" then
			local close = text:find("`", i + 1, true)
			if close then
				Special("code", text:sub(i + 1, close - 1))
				i = close + 1
				handled = true
			end
		elseif char == "[" then
			local target, alias, wikiEnd = Markdown.ReadWikiLink(text, i)
			local label, finish = text:match("^%[([^%]]+)%]%([^%)%s]*%)()", i)
			if target then
				local span = Special("wiki", alias or target)
				span.wiki = target
				i = wikiEnd
				handled = true
			elseif label then
				Special("link", label)
				i = finish
				handled = true
			end
		elseif char == "#" and (i == 1 or text:sub(i - 1, i - 1):match("[%s%(]")) then
			local tag = text:match("^#([%w_\128-\255][%w_/%-\128-\255]*)", i)
			if tag and not tag:find("//", 1, true) and tag:sub(-1) ~= "/" then
				local span = Special("tag", "#" .. tag)
				span.tag = tag:lower()
				i = i + #tag + 1
				handled = true
			end
		elseif pair == "**" or pair == "__" then
			local state = Toggle(bold, pair, i)
			if state ~= nil then
				Flush()
				bold = state
				i = i + 2
				handled = true
			end
		elseif pair == "~~" then
			local state = Toggle(strike, pair, i)
			if state ~= nil then
				Flush()
				strike = state
				i = i + 2
				handled = true
			end
		elseif char == "*" or char == "_" then
			local state = Toggle(italic, char, i)
			if state ~= nil then
				Flush()
				italic = state
				i = i + 1
				handled = true
			end
		end

		if not handled then
			buffer[#buffer + 1] = char
			i = i + 1
		end
	end
	Flush()

	return out
end

function Markdown.Inline(text)
	local out = {}
	for _, span in ipairs(Markdown.Spans(text)) do
		local color = (span.code and COLORS.code)
			or (span.hyperlink and (span.color or COLORS.link))
			or span.color
			or ((span.link or span.wiki or span.tag) and COLORS.link)
			or (span.strike and COLORS.strike)
			or (span.bold and span.italic and COLORS.boldItalic)
			or (span.bold and COLORS.bold)
			or (span.italic and COLORS.italic)
		local escaped = span.text:gsub("|", "||")
		out[#out + 1] = color and ("|c" .. color .. escaped .. "|r") or escaped
	end
	return table.concat(out)
end

local function IsRule(line)
	local compact = line:gsub("%s", "")
	return #compact >= 3 and (compact:match("^%-+$") or compact:match("^%*+$") or compact:match("^_+$")) ~= nil
end

local function IndentWidth(indent)
	return #indent:gsub("\t", "    ")
end

local function TableCells(line)
	line = line:match("^%s*(.-)%s*$")
	local cells, start, index = {}, 1, 1
	local inCode, lastPipe = false, nil
	while index <= #line do
		local char = line:sub(index, index)
		local _, _, _, finish = Markdown.ReadHyperlink(line, index)
		local _, _, wikiEnd = Markdown.ReadWikiLink(line, index)
		if not inCode and finish then
			index = finish
		elseif not inCode and wikiEnd then
			index = wikiEnd
		elseif char == "\\" then
			index = index + (line:sub(index + 1, index + 2) == "||" and 3 or 2)
		else
			if char == "`" then
				inCode = not inCode
			elseif char == "|" and not inCode then
				cells[#cells + 1] = line:sub(start, index - 1)
				-- Edit boxes store one visible pipe as two bytes.
				if line:sub(index + 1, index + 1) == "|" then
					index = index + 1
				end
				start = index + 1
				lastPipe = index
			end
			index = index + 1
		end
	end
	if not lastPipe then
		return nil
	end
	cells[#cells + 1] = line:sub(start)
	if line:sub(1, 1) == "|" then
		table.remove(cells, 1)
	end
	if lastPipe == #line then
		table.remove(cells)
	end
	for column, cell in ipairs(cells) do
		cells[column] = cell:match("^%s*(.-)%s*$")
	end
	return #cells > 0 and cells or nil
end

local function TableAlignment(line)
	local cells = TableCells(line)
	if not cells then
		return nil
	end
	local alignment = {}
	for column, cell in ipairs(cells) do
		local dashes = cell:match("^:?(%-+):?$")
		if not dashes or #dashes < 3 then
			return nil
		end
		alignment[column] = cell:sub(-1) == ":" and (cell:sub(1, 1) == ":" and "center" or "right") or "left"
	end
	return alignment
end

-- Blocks: heading (level, text), paragraph (text), item (depth, ordered, number, task, text),
-- quote (text), code (text), rule, table (header, alignment, rows). Paragraph line breaks are kept.
function Markdown.Parse(source)
	source = (source or ""):gsub("\r\n", "\n"):gsub("\r", "\n")

	local blocks = {}
	local paragraph, quote, code, activeTable
	local indents = {}
	local blank = false

	-- afterBlank lets the reader separate two lists that only a blank line divides
	local function Add(block)
		if blank and #blocks > 0 then
			block.afterBlank = true
		end
		blank = false
		blocks[#blocks + 1] = block
	end

	local function CloseText()
		if paragraph then
			Add({ type = "paragraph", text = table.concat(paragraph, "\n") })
			paragraph = nil
		end
		if quote then
			Add({ type = "quote", text = table.concat(quote, "\n") })
			quote = nil
		end
	end

	local function CloseAll()
		CloseText()
		indents = {}
	end

	-- Nesting follows the indentation of earlier items, whether it uses 2 or 4 spaces
	local function Depth(width)
		while #indents > 0 and indents[#indents] > width do
			indents[#indents] = nil
		end
		if #indents == 0 or indents[#indents] < width then
			indents[#indents + 1] = width
		end
		return #indents - 1
	end

	local lines = {}
	for line in (source .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end
	local lineIndex = 1
	while lineIndex <= #lines do
		local line = lines[lineIndex]
		local cells = not code and TableCells(line)
		if code then
			local fence = line:match("^%s*([`~][`~][`~]+)%s*$")
			if fence and fence:sub(1, 1) == code.fence and #fence >= code.size then
				Add({ type = "code", text = table.concat(code.lines, "\n") })
				code = nil
			else
				code.lines[#code.lines + 1] = line
			end
		elseif activeTable and cells then
			local row = {}
			for column = 1, #activeTable.header do
				row[column] = cells[column] or ""
			end
			activeTable.rows[#activeTable.rows + 1] = row
		else
			activeTable = nil
			local fence = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
			local hashes, heading = line:match("^%s*(#+)%s+(.-)%s*$")
			local alignment = cells and TableAlignment(lines[lineIndex + 1] or "")
			local indent, bullet, itemText = line:match("^(%s*)([-*+])%s+(.*)$")
			local number
			if not bullet then
				indent, number, itemText = line:match("^(%s*)(%d+)[.)]%s+(.*)$")
			end
			local previous = blocks[#blocks]

			if fence then
				CloseAll()
				code = { fence = fence:sub(1, 1), size = #fence, lines = {} }
			elseif cells and alignment and #cells == #alignment then
				CloseAll()
				activeTable = { type = "table", header = cells, alignment = alignment, rows = {} }
				Add(activeTable)
				lineIndex = lineIndex + 1
			elseif line:match("^%s*$") then
				CloseText()
				blank = true
			elseif hashes and #hashes <= 6 then
				CloseAll()
				heading = heading:gsub("%s+#+$", "")
				Add({ type = "heading", level = #hashes, text = heading })
			elseif IsRule(line) then
				CloseAll()
				Add({ type = "rule" })
			elseif line:match("^%s*>") then
				if paragraph then
					CloseText()
				end
				indents = {}
				quote = quote or {}
				quote[#quote + 1] = line:match("^%s*>%s?(.*)$")
			elseif itemText then
				CloseText()
				local item = {
					type = "item",
					depth = Depth(IndentWidth(indent)),
					ordered = number ~= nil,
					number = tonumber(number),
				}
				local mark, rest = itemText:match("^%[([ xX])%]%s+(.*)$")
				if mark then
					item.task = mark ~= " "
					itemText = rest
				end
				item.text = itemText
				Add(item)
			elseif not paragraph and not quote and previous and previous.type == "item" and line:match("^%s") then
				-- Indented continuation of the previous list item
				previous.text = previous.text .. "\n" .. line:match("^%s*(.-)%s*$")
			elseif quote then
				quote[#quote + 1] = line
			else
				indents = {}
				paragraph = paragraph or {}
				paragraph[#paragraph + 1] = line:match("^%s*(.-)%s*$")
			end
		end
		lineIndex = lineIndex + 1
	end

	-- An unclosed fence runs to the end of the note
	if code then
		Add({ type = "code", text = table.concat(code.lines, "\n") })
	end
	CloseText()

	return blocks
end
