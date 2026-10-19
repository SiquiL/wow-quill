local _, ns = ...

-- Flat YAML only: ASCII [A-Za-z_][A-Za-z0-9_-]* keys, decimal numbers, booleans,
-- strings and scalar lists. Double quotes support \n, \r, \t, \" and \\; single
-- quotes escape apostrophes by doubling them. Unsupported YAML is an error.
local Metadata = {}
ns.Metadata = Metadata

local function Message(key, ...)
	return (ns.L and ns.L[key] or key):format(...)
end

local function Trim(text)
	return text:match("^%s*(.-)%s*$")
end

local function Finite(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function Decimal(text)
	local mantissa = text:match("^(.-)[eE][+-]?%d+$") or text
	return mantissa:match("^[+-]?%d+%.?%d*$") ~= nil
		or mantissa:match("^[+-]?%.%d+$") ~= nil
end

-- Locate comments and separators without interpreting punctuation inside quotes.
local function Scan(text, separator)
	local quote, index = nil, 1
	local canQuote, flow = true, separator ~= nil
	while index <= #text do
		local char = text:sub(index, index)
		if quote then
			if quote == '"' and char == "\\" then
				index = index + 1
			elseif char == quote then
				if quote == "'" and text:sub(index + 1, index + 1) == "'" then
					index = index + 1
				else
					quote = nil
				end
			end
		elseif (char == '"' or char == "'") and canQuote then
			quote = char
			canQuote = false
		elseif char == "#" and (index == 1 or text:sub(index - 1, index - 1):match("%s")) then
			return index, "comment"
		elseif char == separator then
			return index, "separator"
		elseif char == "[" then
			flow, canQuote = true, true
		elseif char == ":" or (flow and char == ",") then
			canQuote = true
		elseif char == "-" and canQuote and text:sub(index + 1, index + 1):match("%s") then
			canQuote = true
		elseif not char:match("%s") then
			canQuote = false
		end
		index = index + 1
	end
	return nil, quote and "quote" or nil
end

local escapes = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\" }

local function Scalar(text)
	text = Trim(text)
	if text == "" then return nil, "empty scalar" end
	local quote = text:sub(1, 1)
	if quote == "'" or quote == '"' then
		local out, index = {}, 2
		while index <= #text do
			local char = text:sub(index, index)
			if char == quote then
				if quote == "'" and text:sub(index + 1, index + 1) == "'" then
					out[#out + 1] = "'"
					index = index + 2
				elseif index == #text then
					return table.concat(out)
				else
					return nil, "characters after quoted scalar"
				end
			elseif quote == '"' and char == "\\" then
				local escaped = escapes[text:sub(index + 1, index + 1)]
				if not escaped then return nil, "unsupported string escape" end
				out[#out + 1] = escaped
				index = index + 2
			else
				if char:byte() < 32 then return nil, "control character in scalar" end
				out[#out + 1] = char
				index = index + 1
			end
		end
		return nil, "unclosed quoted scalar"
	end
	local lower = text:lower()
	if lower == "true" then return true end
	if lower == "false" then return false end
	if lower == "null" or text == "~" then return nil, "null is unsupported" end
	if lower:match("^[+-]?%.inf$") or lower == ".nan" then return nil, "non-finite number" end
	if lower:match("^[+-]?0[xo]") then return nil, "non-decimal number is unsupported" end
	if Decimal(text) then
		local number = tonumber(text)
		if not number or not Finite(number) then return nil, "non-finite number" end
		return number
	end
	if text:find("[%[%]{}]") or text:find(":%s") or text:sub(-1) == ":"
		or text:match("^[!&*|>@`%%\"']") or text:match("^[?:%-]%s") or text == "-" or text == "?"
		or text:find("[%z\1-\31]") then
		return nil, "unsupported YAML scalar"
	end
	return text
end

local function Value(text)
	if text:sub(1, 1) ~= "[" then return Scalar(text) end
	if text:sub(-1) ~= "]" then return nil, "unclosed inline list" end
	local content, result = Trim(text:sub(2, -2)), {}
	if content == "" then return result end
	while true do
		local position, kind = Scan(content, ",")
		if kind == "comment" then return nil, "comment inside inline list" end
		local scalar, err = Scalar(position and content:sub(1, position - 1) or content)
		if err then return nil, err end
		result[#result + 1] = scalar
		if not position then return result end
		content = Trim(content:sub(position + 1))
		if content == "" then return nil, "empty inline list item" end
	end
end

local function Line(source, position)
	local finish = source:find("[\r\n]", position)
	if not finish then return source:sub(position), #source + 1 end
	local nextPosition = finish + 1
	if source:sub(finish, finish + 1) == "\r\n" then nextPosition = nextPosition + 1 end
	return source:sub(position, finish - 1), nextPosition
end

-- Errors always retain the complete source as the renderable body.
function Metadata.Parse(source)
	source = source or ""
	local first, position = Line(source, 1)
	if not first:match("^%-%-%-[ \t]*$") then return {}, source end
	local properties, pending, indent = {}, nil, nil
	local lineNumber = 1
	while position <= #source do
		local line
		line, position = Line(source, position)
		lineNumber = lineNumber + 1
		if line:match("^%-%-%-[ \t]*$") then
			if pending and #properties[pending] == 0 then
				return nil, source, Message("Invalid metadata on line %d: %s", lineNumber, Message("empty scalar"))
			end
			return properties, source:sub(position)
		end
		-- Obsidian-style "tags: #raid #tank" would otherwise be read as a YAML comment.
		local hashTags = line:match("^tags:[ \t]*(#[^%s#].*)$")
		if hashTags and pending and #properties[pending] == 0 then
			return nil, source, Message("Invalid metadata on line %d: %s", lineNumber, Message("empty scalar"))
		elseif hashTags and properties.tags == nil then
			local list = {}
			for token in hashTags:gmatch("[^%s,]+") do
				if token == "#" then break end
				local tag = token:match("^#(.+)$")
				if not tag then
					return nil, source, Message("Invalid metadata on line %d: %s", lineNumber, Message("tags must start with #"))
				end
				list[#list + 1] = tag
			end
			properties.tags, pending, indent = list, nil, nil
			line = ""
		elseif hashTags then
			return nil, source, Message("Duplicate metadata property: %s", "tags")
		end
		local comment = Scan(line)
		if comment then line = line:sub(1, comment - 1) end
		line = line:gsub("%s+$", "")
		if line ~= "" then
			local key, raw = line:match("^([A-Za-z_][A-Za-z0-9_-]*):%s*(.*)$")
			local err
			if key then
				if pending and #properties[pending] == 0 then
					err = "empty scalar"
				elseif properties[key] ~= nil then
					return nil, source, Message("Duplicate metadata property: %s", key)
				else
					pending, indent = nil, nil
					if raw == "" then
						properties[key], pending = {}, key
					else
						properties[key], err = Value(raw)
					end
				end
			else
				local spaces, item = line:match("^( +)%- +(.*)$")
				if pending and spaces and (not indent or indent == #spaces) then
					indent = #spaces
					local value
					value, err = Scalar(item)
					if not err then table.insert(properties[pending], value) end
				else
					err = "expected a flat property or indented list item"
				end
			end
			if err then
				return nil, source, Message("Invalid metadata on line %d: %s", lineNumber, Message(err))
			end
		end
	end
	return nil, source, Message("Unclosed metadata frontmatter")
end

local function Encode(value)
	local kind = type(value)
	if kind == "string" then
		if value:find("[%z\1-\8\11\12\14-\31]") then return nil end
		return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"')
			:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind == "number" and Finite(value) then
		return ("%.17g"):format(value)
	end
end

function Metadata.ValueText(value)
	local encoded = Encode(value)
	if type(value) == "table" then
		local entries, size = {}, 0
		for index in pairs(value) do
			if type(index) ~= "number" or index < 1 or index % 1 ~= 0 then
				return nil, Message("Invalid metadata value")
			end
			size = size + 1
		end
		for index = 1, size do
			entries[index] = Encode(value[index])
			if not entries[index] then return nil, Message("Invalid metadata value") end
		end
		encoded = "[" .. table.concat(entries, ", ") .. "]"
	end
	if not encoded then return nil, Message("Invalid metadata value") end
	return encoded
end

function Metadata.Tags(properties, body)
	local tags = {}
	local function Add(tag)
		if type(tag) ~= "string" then return end
		tag = Trim(tag):gsub("^#", ""):lower()
		if tag ~= "" then tags[tag] = true end
	end
	local property = properties and properties.tags
	if type(property) == "table" then
		for _, tag in ipairs(property) do Add(tag) end
	else
		Add(property)
	end
	local function Text(text)
		for _, span in ipairs(ns.Markdown.Spans(text)) do
			if span.tag and not span.code and not span.link and not span.hyperlink then Add(span.tag) end
		end
	end
	for _, block in ipairs(ns.Markdown.Parse(body or "")) do
		if block.type == "paragraph" or block.type == "heading" or block.type == "item" or block.type == "quote" then
			Text(block.text)
		elseif block.type == "table" then
			for _, cell in ipairs(block.header) do Text(cell) end
			for _, row in ipairs(block.rows) do
				for _, cell in ipairs(row) do Text(cell) end
			end
		end
	end
	local result = {}
	for tag in pairs(tags) do result[#result + 1] = tag end
	table.sort(result)
	return result
end

-- Terms are { kind = "text"|"property"|"tag", value = lowercase, key = lowercase? }.
function Metadata.Query(filter)
	filter = Trim(filter or "")
	if filter == "" then return {} end
	local tokens, buffer, quoted, quote, property = {}, {}, false, nil, false
	local index = 1
	local function Flush()
		if #buffer > 0 or quoted then
			tokens[#tokens + 1] = { text = table.concat(buffer), quoted = quoted, property = property }
			buffer, quoted, property = {}, false, false
		end
	end
	while index <= #filter do
		local char = filter:sub(index, index)
		if char == quote then
			quote = nil
			local nextChar = filter:sub(index + 1, index + 1)
			if nextChar ~= "" and not nextChar:match("%s") then
				return nil, Message("Invalid filter: malformed quoted token")
			end
		elseif not quote and (char == '"' or (char == "'" and (#buffer == 0 or buffer[#buffer] == ":"))) then
			if #buffer > 0 and buffer[#buffer] ~= ":" then
				return nil, Message("Invalid filter: malformed quoted token")
			end
			quote, quoted = char, true
		elseif char == "\\" and quote then
			local nextChar = filter:sub(index + 1, index + 1)
			if nextChar ~= quote and nextChar ~= "\\" then
				return nil, Message("Invalid filter: unsupported escape")
			end
			buffer[#buffer + 1] = nextChar
			index = index + 1
		elseif char:match("%s") and not quote then
			Flush()
		else
			buffer[#buffer + 1] = char
			if char == ":" and not quote and table.concat(buffer):match("^[A-Za-z_][A-Za-z0-9_-]*:$") then
				property = true
			end
		end
		index = index + 1
	end
	if quote then return nil, Message("Invalid filter: unclosed quote") end
	Flush()
	local terms, hasProperty = {}, false
	for _, token in ipairs(tokens) do
		local key, value
		if token.property then key, value = token.text:match("^([A-Za-z_][A-Za-z0-9_-]*):(.*)$") end
		if key then
			hasProperty = true
			if Trim(value) == "" then return nil, Message("Invalid filter: empty value for %s", key) end
			key, value = key:lower(), value:lower()
			terms[#terms + 1] = { kind = key == "tag" and "tag" or "property", key = key, value = value }
		else
			if token.text == "" then return nil, Message("Invalid filter: empty text") end
			terms[#terms + 1] = { kind = "text", value = token.text:lower() }
		end
	end
	if not hasProperty then
		-- Preserve the old whole-phrase search, including its original whitespace.
		if #tokens == 1 and tokens[1].quoted then filter = tokens[1].text end
		return { { kind = "text", value = filter:lower() } }
	end
	return terms
end

local function PropertyMatches(value, expected)
	if type(value) == "table" then
		for _, entry in ipairs(value) do
			if PropertyMatches(entry, expected) then return true end
		end
		return false
	end
	return value ~= nil and tostring(value):lower() == expected
end

function Metadata.Matches(title, source, terms)
	local properties, body = Metadata.Parse(source)
	local tags
	for _, term in ipairs(terms or {}) do
		if term.kind == "text" then
			local value = term.value
			if not (title or ""):lower():find(value, 1, true) and not body:lower():find(value, 1, true) then
				return false
			end
		elseif term.kind == "tag" then
			tags = tags or Metadata.Tags(properties, body)
			local expected, found = term.value:gsub("^#", ""), false
			for _, tag in ipairs(tags) do
				if tag == expected or tag:sub(1, #expected + 1) == expected .. "/" then found = true end
			end
			if not found then return false end
		elseif term.kind == "property" then
			local found = false
			for key, value in pairs(properties or {}) do
				if key:lower() == term.key and PropertyMatches(value, term.value) then found = true end
			end
			if not found then return false end
		else
			return false
		end
	end
	return true
end
