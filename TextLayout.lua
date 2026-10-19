local _, ns = ...

local TextLayout = {}
ns.TextLayout = TextLayout

-- Wrap visible text before adding WoW escape sequences. A word may contain several styles.
function TextLayout.Wrap(spans, width, measure)
	assert(width > 0, "Text layout width must be positive")
	local tokens = {}
	local function Token(kind, text, span)
		if text == "" then
			return
		end
		local token = tokens[#tokens]
		if not token or token.kind ~= kind or kind == "newline" then
			token = { kind = kind, parts = {} }
			tokens[#tokens + 1] = token
		end
		token.parts[#token.parts + 1] = { text = text, span = span }
	end

	for _, span in ipairs(spans) do
		local index = 1
		while index <= #span.text do
			local char = span.text:sub(index, index)
			if char == "\n" then
				Token("newline", char, span)
				index = index + 1
			else
				local space = char:match("%s") ~= nil
				local finish = index
				while finish < #span.text do
					local nextChar = span.text:sub(finish + 1, finish + 1)
					if nextChar == "\n" or (nextChar:match("%s") ~= nil) ~= space then
						break
					end
					finish = finish + 1
				end
				Token(space and "space" or "word", span.text:sub(index, finish):gsub("\t", "    "), span)
				index = finish + 1
			end
		end
	end

	local lines = { { runs = {}, width = 0 } }
	local line = lines[1]
	local pendingSpace, spaces = 0, {}
	local function NewLine()
		line = { runs = {}, width = 0 }
		lines[#lines + 1] = line
		pendingSpace = 0
		spaces = {}
	end
	local function Append(text, span)
		local runWidth = measure(text, span)
		line.runs[#line.runs + 1] = { text = text, span = span, x = line.width, width = runWidth }
		line.width = line.width + runWidth
	end

	for _, token in ipairs(tokens) do
		if token.kind == "newline" then
			NewLine()
		elseif token.kind == "space" then
			for _, part in ipairs(token.parts) do
				pendingSpace = pendingSpace + measure(part.text, part.span)
				spaces[#spaces + 1] = part
			end
		else
			local wordWidth = 0
			for _, part in ipairs(token.parts) do
				wordWidth = wordWidth + measure(part.text, part.span)
			end
			if line.width > 0 and line.width + pendingSpace + wordWidth > width then
				NewLine()
			end
			if line.width > 0 then
				for _, part in ipairs(spaces) do
					Append(part.text, part.span)
				end
			end
			pendingSpace = 0
			spaces = {}
			for _, part in ipairs(token.parts) do
				if wordWidth <= width then
					Append(part.text, part.span)
				else
					local index, chunk = 1, ""
					while index <= #part.text do
						local finish = index
						-- Keep UTF-8 continuation bytes with their leading byte when splitting long words.
						while finish < #part.text do
							local byte = part.text:byte(finish + 1)
							if byte < 128 or byte > 191 then
								break
							end
							finish = finish + 1
						end
						local char = part.text:sub(index, finish)
						if line.width + measure(chunk .. char, part.span) > width then
							if chunk ~= "" then
								Append(chunk, part.span)
								chunk = ""
							end
							if line.width > 0 then
								NewLine()
							end
						end
						chunk = chunk .. char
						index = finish + 1
					end
					if chunk ~= "" then
						Append(chunk, part.span)
					end
				end
			end
		end
	end
	return lines
end
