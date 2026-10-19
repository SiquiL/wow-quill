-- Parser and layout tests, run from the repository root with Lua 5.1: lua tests/Markdown.test.lua
local ns = {}
assert(loadfile("Markdown.lua"))("Quill", ns)
assert(loadfile("TextLayout.lua"))("Quill", ns)
local Markdown = ns.Markdown
local TextLayout = ns.TextLayout
local C = Markdown.COLORS

local failures, count = 0, 0

local function Describe(value)
	if type(value) ~= "table" then
		return ("%q"):format(tostring(value))
	end
	local parts = {}
	for key, inner in pairs(value) do
		parts[#parts + 1] = tostring(key) .. "=" .. Describe(inner)
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function Equal(name, actual, expected)
	count = count + 1
	if Describe(actual) ~= Describe(expected) then
		failures = failures + 1
		print("FAIL " .. name .. "\n  expected " .. Describe(expected) .. "\n  actual   " .. Describe(actual))
	end
end

-- Inline
Equal("plain", Markdown.Inline("hello"), "hello")
Equal("bold", Markdown.Inline("a **b** c"), "a |c" .. C.bold .. "b|r c")
Equal("bold underscores", Markdown.Inline("__b__"), "|c" .. C.bold .. "b|r")
Equal("italic", Markdown.Inline("*i* and _j_"), "|c" .. C.italic .. "i|r and |c" .. C.italic .. "j|r")
Equal("bold italic nesting", Markdown.Inline("**a *b* c**"),
	"|c" .. C.bold .. "a |r|c" .. C.boldItalic .. "b|r|c" .. C.bold .. " c|r")
Equal("strike", Markdown.Inline("~~x~~"), "|c" .. C.strike .. "x|r")
Equal("code keeps markers", Markdown.Inline("`**x**`"), "|c" .. C.code .. "**x**|r")
Equal("link", Markdown.Inline("see [docs](https://example.com) now"), "see |c" .. C.link .. "docs|r now")
Equal("snake_case untouched", Markdown.Inline("snake_case_name"), "snake_case_name")
Equal("lone asterisk", Markdown.Inline("2 * 3"), "2 * 3")
Equal("unclosed bold", Markdown.Inline("**open"), "**open")
Equal("escaped marker", Markdown.Inline("\\*not\\*"), "*not*")
Equal("pipe escaped", Markdown.Inline("a | b"), "a || b")
Equal("typed pipe from edit box", Markdown.Inline("a || b"), "a || b")
Equal("color codes are not interpreted", Markdown.Inline("|cffff0000red|r"), "||cffff0000red||r")
Equal("font spans", Markdown.Spans("plain **bold *both* bold** ~~gone~~"), {
	{ text = "plain " },
	{ text = "bold ", bold = true },
	{ text = "both", bold = true, italic = true },
	{ text = " bold", bold = true },
	{ text = " " },
	{ text = "gone", strike = true },
})
Equal("strike preserves nested emphasis", Markdown.Spans("~~**gone**~~"), {
	{ text = "gone", bold = true, strike = true },
})
Equal("code spans keep literal markers", Markdown.Spans("`**literal**`"), {
	{ text = "**literal**", code = true },
})
Equal("span pipes are raw for measurement", Markdown.Spans("a || b |cffff0000red|r"), {
	{ text = "a | b |cffff0000red|r" },
})
Equal("four escaped pipes display two", Markdown.Inline("||||"), "||||")
local item = "|cffa335ee|Hitem:123:0|h[Some **Item**]|h|r"
Equal("native item link is a literal styled span", Markdown.Spans(item), {
	{ text = "[Some **Item**]", hyperlink = "item:123:0", color = "ffa335ee" },
})
Equal("native uncolored quest link", Markdown.Spans("|Hquest:12:10|h[Quest]|h"), {
	{ text = "[Quest]", hyperlink = "quest:12:10" },
})
Equal("named color hyperlink wrapper", Markdown.Spans("|cnIQ4:|Hitem:1|h[Item]|h|r"), {
	{ text = "[Item]", hyperlink = "item:1" },
})
Equal("editbox escaped native link", Markdown.Spans((item:gsub("|", "||"))), Markdown.Spans(item))
Equal("native link in code stays literal", Markdown.Spans("`" .. item .. "`"), { { text = item, code = true } })
Equal("malformed link remains literal", Markdown.Spans("|Hitem:123|h[Missing end]"), { { text = "|Hitem:123|h[Missing end]" } })

-- HTML text colors
Equal("font hex color", Markdown.Spans('a <font color="#9d9d9d">Poor</font> b'), {
	{ text = "a " }, { text = "Poor", color = "ff9d9d9d" }, { text = " b" },
})
Equal("short hex and case insensitive tags", Markdown.Spans("<FONT COLOR = '#AbC'>Short</FONT>"), {
	{ text = "Short", color = "ffaabbcc" },
})
Equal("named color without quotes", Markdown.Inline("<font color=White>Common</font>"), "|cffffffffCommon|r")
Equal("named color aliases", Markdown.Spans('<font color="grey">a</font><font color="gray">b</font>'), {
	{ text = "a", color = "ff808080" }, { text = "b", color = "ff808080" },
})
Equal("CSS extended color name", Markdown.Inline('<font color="RebeccaPurple">Epic</font>'), "|cff663399Epic|r")
Equal("font color with bold", Markdown.Spans('**<font color="#a335ee">Epic</font>**'), {
	{ text = "Epic", bold = true, color = "ffa335ee" },
})
Equal("markdown inside font", Markdown.Spans('<font color="red">**bold** and *italic*</font>'), {
	{ text = "bold", bold = true, color = "ffff0000" },
	{ text = " and ", color = "ffff0000" },
	{ text = "italic", italic = true, color = "ffff0000" },
})
Equal("nested colors restore parent", Markdown.Spans('<font color="red">a<font color="blue">b</font>c</font>d'), {
	{ text = "a", color = "ffff0000" }, { text = "b", color = "ff0000ff" },
	{ text = "c", color = "ffff0000" }, { text = "d" },
})
Equal("colored wiki and tag remain interactive", Markdown.Spans('<font color="orange">[[Note|Alias]] #raid</font>'), {
	{ text = "Alias", wiki = "Note", color = "ffffa500" },
	{ text = " ", color = "ffffa500" },
	{ text = "#raid", tag = "raid", color = "ffffa500" },
})
Equal("item quality overrides enclosing font color", Markdown.Spans('<font color="red">' .. item .. '</font>'), {
	{ text = "[Some **Item**]", hyperlink = "item:123:0", color = "ffa335ee" },
})
Equal("inline code keeps HTML literal", Markdown.Spans('`<font color="red">x</font>`'), {
	{ text = '<font color="red">x</font>', code = true },
})
Equal("closing tag inside code does not close color", Markdown.Spans('<font color="red">`</font>`x</font>'), {
	{ text = "</font>", code = true, color = "ffff0000" }, { text = "x", color = "ffff0000" },
})
Equal("code color takes precedence", Markdown.Inline('<font color="red">`code`</font>'), "|c" .. C.code .. "code|r")
for _, literal in ipairs({
	'<font color="red">unclosed',
	'stray </font>',
	'<font color="notacolor">x</font>',
	'<font color="#12345">x</font>',
	'<font color="#ggg">x</font>',
	'<font color="#ff000080">x</font>',
	'<font color="red" size="7">x</font>',
	'<font color="red\'>x</font>',
	'<span style="color:red">x</span>',
}) do
	Equal("unsupported font markup stays literal: " .. literal, Markdown.Inline(literal), literal)
end
Equal("escaped opening tag stays literal", Markdown.Inline('\\<font color="red">x</font>'), '<font color="red">x</font>')
local coloredLines = TextLayout.Wrap(Markdown.Spans('<font color="red">ab cd</font>'), 2, function(text) return #text end)
Equal("colored text wraps without measuring HTML", #coloredLines, 2)
Equal("wrapped text retains color", coloredLines[2].runs[1].span.color, "ffff0000")
Equal("table cells support font colors", Markdown.Spans(
	Markdown.Parse('| Quality |\n| --- |\n| <font color="#9d9d9d">**Poor**</font> |')[1].rows[1][1]
), { { text = "Poor", bold = true, color = "ff9d9d9d" } })
Equal("fenced code retains HTML source", Markdown.Parse('```\n<font color="red">x</font>\n```')[1].text,
	'<font color="red">x</font>')

-- Blocks
local function Types(blocks)
	local types = {}
	for index, block in ipairs(blocks) do
		types[index] = block.type
	end
	local linkedTable = Markdown.Parse("| Item | Quest |\n| --- | --- |\n| " .. item .. " | |Hquest:1|h[Quest]|h |")[1]
	Equal("table preserves native link pipes", linkedTable.rows[1], { item, "|Hquest:1|h[Quest]|h" })
	local escapedItem = item:gsub("|", "||")
	linkedTable = Markdown.Parse("| Item | Quest |\n| --- | --- |\n| " .. escapedItem .. " | text |")[1]
	Equal("table preserves editbox escaped links", linkedTable.rows[1], { escapedItem, "text" })
	return types
end

Equal("empty", Markdown.Parse(""), {})
Equal("headings", Markdown.Parse("# One\n## Two ##\n#### Four"), {
	{ type = "heading", level = 1, text = "One" },
	{ type = "heading", level = 2, text = "Two" },
	{ type = "heading", level = 4, text = "Four" },
})
local headings = Markdown.Parse("# 1\n## 2\n### 3\n#### 4\n##### 5\n###### 6")
Equal("six distinct heading levels", {
	headings[1].level, headings[2].level, headings[3].level,
	headings[4].level, headings[5].level, headings[6].level,
}, { 1, 2, 3, 4, 5, 6 })
Equal("seven hashes stay text", Types(Markdown.Parse("####### text")), { "paragraph" })
Equal("no heading without space", Types(Markdown.Parse("#tag")), { "paragraph" })
Equal("paragraph keeps line breaks", Markdown.Parse("a\nb\n\nc"), {
	{ type = "paragraph", text = "a\nb" },
	{ type = "paragraph", text = "c", afterBlank = true },
})
Equal("windows line endings", Markdown.Parse("a\r\nb"), { { type = "paragraph", text = "a\nb" } })

local list = Markdown.Parse("- a\n  - b\n    - c\n  - d\n- e\n1. one\n2) two")
Equal("list depths", { list[1].depth, list[2].depth, list[3].depth, list[4].depth, list[5].depth }, { 0, 1, 2, 1, 0 })
Equal("ordered", { list[6].ordered, list[6].number, list[7].number, list[1].ordered }, { true, 1, 2, false })

local fourSpaces = Markdown.Parse("* a\n    * b\n* c")
Equal("four space nesting", { fourSpaces[1].depth, fourSpaces[2].depth, fourSpaces[3].depth }, { 0, 1, 0 })

local tasks = Markdown.Parse("- [ ] open\n- [x] done\n- [link](x)")
Equal("tasks", { tasks[1].task, tasks[1].text, tasks[2].task, tasks[3].task, tasks[3].text },
	{ false, "open", true, nil, "[link](x)" })

Equal("item continuation", Markdown.Parse("- first\n  more"), {
	{ type = "item", depth = 0, ordered = false, text = "first\nmore" },
})

Equal("quote", Markdown.Parse("> a\n> b\n\ntext"), {
	{ type = "quote", text = "a\nb" },
	{ type = "paragraph", text = "text", afterBlank = true },
})

local separated = Markdown.Parse("\n\n- a\n- b\n\n- c")
Equal("blank lines separate lists", { separated[1].afterBlank, separated[2].afterBlank, separated[3].afterBlank },
	{ nil, nil, true })

Equal("code fence", Markdown.Parse("```lua\n# not a heading\n  - not a list\n```\nafter"), {
	{ type = "code", text = "# not a heading\n  - not a list" },
	{ type = "paragraph", text = "after" },
})
Equal("unclosed fence", Markdown.Parse("~~~\nx"), { { type = "code", text = "x" } })
Equal("rules", Types(Markdown.Parse("---\n* * *\n___")), { "rule", "rule", "rule" })
Equal("mixed", Types(Markdown.Parse("# T\ntext\n- item\n> q\n---")), { "heading", "paragraph", "item", "quote", "rule" })

Equal("table with alignment", Markdown.Parse("| Name | Count | State |\n| :--- | ---: | :---: |\n| **Potion** | 2 | *Ready* |"), {
	{
		type = "table",
		header = { "Name", "Count", "State" },
		alignment = { "left", "right", "center" },
		rows = { { "**Potion**", "2", "*Ready*" } },
	},
})
Equal("tables without outer pipes", Markdown.Parse("A | B\n--- | ---\nx | y"), {
	{ type = "table", header = { "A", "B" }, alignment = { "left", "left" }, rows = { { "x", "y" } } },
})
Equal("wiki links and aliases", Markdown.Spans("[[Boss]] [[World/Boss|Guide]]"), {
	{ text = "Boss", wiki = "Boss" }, { text = " " }, { text = "Guide", wiki = "World/Boss" },
})
Equal("wiki aliases from game edit box", Markdown.Spans("[[Boss||Raid guide]]"), {
	{ text = "Raid guide", wiki = "Boss" },
})
Equal("wiki links in tables are not separators", Markdown.Parse("| Link | State |\n| --- | --- |\n| [[Boss|Guide]] | ready |")[1].rows,
	{ { "[[Boss|Guide]]", "ready" } })
Equal("stored wiki aliases in tables", Markdown.Parse("|| Link || State ||\n|| --- || --- ||\n|| [[Boss||Guide]] || ready ||")[1].rows,
	{ { "[[Boss||Guide]]", "ready" } })
Equal("nested inline tags", Markdown.Spans("#Raid/Tank, #quest"), {
	{ text = "#Raid/Tank", tag = "raid/tank" }, { text = ", " }, { text = "#quest", tag = "quest" },
})
Equal("escaped tags code and wiki are literal", Markdown.Spans("\\#raid `#raid [[Boss]]` [[Boss|#raid]]"), {
	{ text = "#raid " }, { text = "#raid [[Boss]]", code = true }, { text = " " }, { text = "#raid", wiki = "Boss" },
})
local linkedText = "---\nsummary: '[[Old]]'\n---\n[[Old|alias]] `[[Old]]` \\[[Old]]\n```\n[[Old]]\n```\n"
Equal("link rewrite skips properties and code", Markdown.MapWikiLinks(linkedText, function(_, alias)
	return "[[New" .. (alias and "|" .. alias or "") .. "]]"
end), "---\nsummary: '[[Old]]'\n---\n[[New|alias]] `[[Old]]` \\[[Old]]\n```\n[[Old]]\n```\n")
Equal("link rewrite preserves source bytes", Markdown.MapWikiLinks(linkedText, function() end), linkedText)
local windowsText = linkedText:gsub("\n", "\r\n")
Equal("link rewrite skips Windows frontmatter", Markdown.MapWikiLinks(windowsText, function() return "[[New]]" end),
	(("---\nsummary: '[[Old]]'\n---\n[[New]] `[[Old]]` \\[[Old]]\n```\n[[Old]]\n```\n"):gsub("\n", "\r\n")))
local demoTable = "| Tabelle | wird |\n| --- | --- |\n| als | Text angezeigt |"
Equal("table from demo note", Markdown.Parse(demoTable), {
	{ type = "table", header = { "Tabelle", "wird" }, alignment = { "left", "left" },
		rows = { { "als", "Text angezeigt" } } },
})
Equal("editbox escaped table delimiters", Markdown.Parse((demoTable:gsub("|", "||"))), Markdown.Parse(demoTable))
Equal("editbox escaped table without outer pipes", Markdown.Parse("A || B\n--- || ---\nx || y"),
	Markdown.Parse("A | B\n--- | ---\nx | y"))
Equal("editbox escaped one-column table", Markdown.Parse("|| A ||\n|| --- ||\n|| x ||"),
	Markdown.Parse("| A |\n| --- |\n| x |"))
local escapedTable = "| Item | Code |\n| :--- | ---: |\n| " .. item .. " | `a|b` |\n| a\\|b | |"
local escapedBlocks = Markdown.Parse((escapedTable:gsub("|", "||")))
Equal("escaped table keeps links code and literal pipes", escapedBlocks, {
	{ type = "table", header = { "Item", "Code" }, alignment = { "left", "right" },
		rows = { { (item:gsub("|", "||")), "`a||b`" }, { "a\\||b", "" } } },
})
Equal("escaped and code pipes in cells", Markdown.Parse("| A | B |\n| --- | --- |\n| a\\|b | `c|d` |")[1].rows,
	{ { "a\\|b", "`c|d`" } })
Equal("empty and surplus cells", Markdown.Parse("| A | B |\n| --- | --- |\n| x |\n| y | z | ignored |\n| | |")[1].rows,
	{ { "x", "" }, { "y", "z" }, { "", "" } })
Equal("table ends before next paragraph", Types(Markdown.Parse("A | B\n--- | ---\nx | y\n\ntext")),
	{ "table", "paragraph" })
Equal("invalid separator is plain text", Types(Markdown.Parse("| A | B |\n| -- | --- |\n| x | y |")), { "paragraph" })
Equal("mismatched column count is plain text", Types(Markdown.Parse("| A | B |\n| --- | --- | --- |")), { "paragraph" })
Equal("table in code stays literal", Types(Markdown.Parse("```\n| A | B |\n| --- | --- |\n```")), { "code" })
Equal("one-column table", Markdown.Parse("| A |\n| --- |\n| x |")[1].rows, { { "x" } })
Equal("table after text", Types(Markdown.Parse("text\n\n| A | B |\n| --- | --- |")), { "paragraph", "table" })

-- Layout uses visible text and measured font widths, not the bytes of WoW color escapes.
local function Measure(text, span)
	local _, characters = text:gsub("[^\128-\191]", "")
	return characters * (span.bold and 2 or 1)
end

local function Wrapped(source, width)
	local result = {}
	for _, line in ipairs(TextLayout.Wrap(Markdown.Spans(source), width, Measure)) do
		local text, position = {}, 0
		for _, run in ipairs(line.runs) do
			if run.x > position then
				text[#text + 1] = string.rep(" ", run.x - position)
			end
			text[#text + 1] = run.text
			position = run.x + run.width
		end
		result[#result + 1] = table.concat(text)
		Equal("line fits width: " .. source, line.width <= width, true)
	end
	return result
end

Equal("plain wrap at whitespace", Wrapped("one two end", 7), { "one two", "end" })
Equal("style boundaries do not split fitting words", Wrapped("pre*fix* test", 6), { "prefix", "test" })
Equal("real bold widths affect wrapping", Wrapped("a **bb** c", 5), { "a", "bb", "c" })
Equal("explicit and blank line breaks", Wrapped("a\n\nb", 10), { "a", "", "b" })
Equal("long words wrap", Wrapped("abcdefgh", 3), { "abc", "def", "gh" })
Equal("long words across styles wrap", Wrapped("ab*cdef*gh", 3), { "abc", "def", "gh" })
Equal("UTF-8 stays intact when wrapped", Wrapped("äöüß", 2), { "äö", "üß" })
Equal("pipes use visible width", Wrapped("a | b", 5), { "a | b" })
Equal("whitespace is discarded at wrapped line start", Wrapped("a   b", 3), { "a", "b" })
local struck = TextLayout.Wrap(Markdown.Spans("~~a b~~"), 10, Measure)[1].runs
Equal("strike spans include inter-word spaces", { struck[2].text, struck[2].span.strike }, { " ", true })

print(("%d of %d tests passed"):format(count - failures, count))
os.exit(failures == 0 and 0 or 1)
