-- Run from the repository root with Lua 5.1: lua tests/Metadata.test.lua
local ns = {}
assert(loadfile("Markdown.lua"))("Quill", ns)
assert(loadfile("Metadata.lua"))("Quill", ns)
local Metadata = ns.Metadata
local count, failures = 0, 0

local function Describe(value)
	if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
	local entries = {}
	for key, entry in pairs(value) do entries[#entries + 1] = tostring(key) .. "=" .. Describe(entry) end
	table.sort(entries)
	return "{" .. table.concat(entries, ",") .. "}"
end

local function Equal(name, actual, expected)
	count = count + 1
	if Describe(actual) ~= Describe(expected) then
		failures = failures + 1
		print("FAIL " .. name .. "\n expected " .. Describe(expected) .. "\n actual   " .. Describe(actual))
	end
end

local function ParseError(name, source)
	local properties, body, err = Metadata.Parse(source)
	Equal(name .. " properties", properties, nil)
	Equal(name .. " body", body, source)
	Equal(name .. " visible error", type(err) == "string" and #err > 0, true)
end

local properties, body, err = Metadata.Parse("plain\n---\nx: 3\n---\n")
Equal("only leading delimiter starts YAML", properties, {})
Equal("plain body unchanged", body, "plain\n---\nx: 3\n---\n")
Equal("no metadata error", err, nil)
Equal("nil source", select(2, Metadata.Parse(nil)), "")
Equal("leading whitespace is body", select(2, Metadata.Parse(" ---\nx: 3\n---")), " ---\nx: 3\n---")
Equal("empty frontmatter", Metadata.Parse("---\n---"), {})
Equal("non-delimiter dashes", select(2, Metadata.Parse("----\nx: 3")), "----\nx: 3")

local source = [==[---
name: "A, B: #C"
empty: ''
single: 'it''s fine'
escaped: "line\nnext\t\"quote\"\\"
count: -1.25e2
ready: true
hidden: false
_key-2: hello world # comment
tags: [raid, "#Tank", "a,b", 'x:y', ""]
emptyList: []
mixed:
  - false
  - 2.5
  - 'true'
---
# Body
]==]
properties, body, err = Metadata.Parse(source)
Equal("flat YAML", properties, {
	name = "A, B: #C", empty = "", single = "it's fine", escaped = 'line\nnext\t"quote"\\',
	count = -125, ready = true, hidden = false, ["_key-2"] = "hello world",
	tags = { "raid", "#Tank", "a,b", "x:y", "" }, emptyList = {}, mixed = { false, 2.5, "true" },
})
Equal("frontmatter removed from body", body, "# Body\n")
Equal("valid YAML error", err, nil)
Equal("CRLF metadata", Metadata.Parse("---\r\na: 2\r\n---\r\nbody\r\n"), { a = 2 })
Equal("CRLF body byte preservation", select(2, Metadata.Parse("---\r\na: 2\r\n---\r\nbody\r\n")), "body\r\n")
Equal("CR metadata", select(2, Metadata.Parse("---\ra: 2\r---\rbody")), "body")
Equal("comments and blank lines", Metadata.Parse("---\n# comment\n\nx: [] # yes\n---"), { x = {} })
Equal("obsidian hash tag", Metadata.Parse("---\ntags: #test\n---\n"), { tags = { "test" } })
Equal("several hash tags", Metadata.Parse("---\ntags: #raid, #raid/tank #heal # note\nx: 1\n---\n"),
	{ tags = { "raid", "raid/tank", "heal" }, x = 1 })
Equal("hash tags feed tag list", Metadata.Tags(Metadata.Parse("---\ntags: #Test\n---\n")), { "test" })
Equal("mixed hash tag syntax rejected", select(3, Metadata.Parse("---\ntags: #raid tank\n---\n")) ~= nil, true)
Equal("duplicate hash tags rejected", select(3, Metadata.Parse("---\ntags: [a]\ntags: #b\n---\n")),
	"Duplicate metadata property: tags")
Equal("plain tags comment still empty", select(3, Metadata.Parse("---\ntags: # note\n---\n")) ~= nil, true)
Equal("false duplicate detection", select(3, Metadata.Parse("---\nx: false\nx: true\n---")),
	"Duplicate metadata property: x")

for _, invalid in ipairs({
	"---", "---\nx: 2", "---\nx: [one, two\n---", "---\nx: [a,]\n---",
	"---\nx: [,a]\n---", "---\nx: [a,,b]\n---", "---\nx: [[a]]\n---",
	"---\nx: {a: b}\n---", "---\nx:\n  child: value\n---", "---\nx:\n---",
	"---\nx:\ny: yes\n---", "---\nx: null\n---", "---\nx: ~\n---",
	"---\nx: &anchor value\n---", "---\nx: *anchor\n---", "---\nx: !!str 1\n---",
	"---\nx: |\n  hello\n---", "---\nx: >\n  hello\n---", "---\nx: [true, null]\n---",
	"---\nx: \"open\n---", "---\nx: 'open\n---", "---\nx: \"closed\" junk\n---",
	"---\nx: \"bad\\q\"\n---", "---\nx: a: b\n---", "---\nx: 1e999\n---",
	"---\n1key: value\n---", "---\nbad.key: value\n---", "---\né: value\n---",
	"---\nx: 1\n x: 2\n---", "---\nx:\n\t- hi\n---",
	"---\nx:\n  - hi\n    - nested\n---", "---\nx:\n  - hi\n   - other\n---",
	"---\nx:\n  - a: b\n---", "---\nx: one\nx: two\n---",
}) do
	ParseError("invalid YAML " .. invalid, invalid)
end

for _, value in ipairs({ true, false, 42, -0.5, "42", "true", "", "a: b, #c", {}, { "raid", "tank", false, 2 } }) do
	local text, valueError = Metadata.ValueText(value)
	Equal("value text succeeds", type(text), "string")
	Equal("value text no error", valueError, nil)
	Equal("displayed value parses back", Metadata.Parse("---\nx: " .. text .. "\n---\n").x, value)
end
Equal("unsupported value text", Metadata.ValueText({ {} }), nil)

local function Matches(title, text, filter)
	local terms, queryError = Metadata.Query(filter)
	assert(terms, queryError)
	return Metadata.Matches(title, text, terms)
end

Equal("empty query", Metadata.Query(" \t "), {})
Equal("phrase compatibility", Metadata.Query("  Some  Words "), { { kind = "text", value = "some  words" } })
Equal("quoted phrase", Metadata.Query('"Some Words"'), { { kind = "text", value = "some words" } })
Equal("query term structure", Metadata.Query('status:"In Progress" urgent tag:#RAID'), {
	{ kind = "property", key = "status", value = "in progress" },
	{ kind = "text", value = "urgent" },
	{ kind = "tag", key = "tag", value = "#raid" },
})
for _, invalid in ipairs({
	"tag:", 'tag:""', 'tag:" "', 'tag:"raid', 'tag:"raid"suffix', 'status:a"b"',
	'""', '"unterminated', 'tag:"bad\\q"', 'status:"a" "b"x',
}) do
	local terms, queryError = Metadata.Query(invalid)
	Equal("bad query " .. invalid, terms, nil)
	Equal("visible query error " .. invalid, type(queryError) == "string" and #queryError > 0, true)
end
Equal("escaped query value", Matches("", '---\nx: \'say "hi"\'\n---', 'x:"say \\"hi\\""'), true)
Equal("single quoted query", Matches("", '---\nx: "In Progress"\n---', "x:'In Progress'"), true)
Equal("apostrophe in plain query", Matches("", "don't stop", "don't stop"), true)
Equal("quoted colon is text", Matches("", "tag:raid", '"tag:raid"'), true)
Equal("quoted colon with property", Matches("", "---\nx: 1\n---\ntag:raid", 'x:1 "tag:raid"'), true)

local note = '---\nStatus: "In Progress"\nlevel: 25\nready: false\nroles: [tank, healer]\nprivate: true\n---\nUrgent raid preparation'
Equal("plain title phrase", Matches("A Raid Plan", note, "raid plan"), true)
Equal("plain body phrase", Matches("", note, "urgent raid"), true)
Equal("plain phrase not separate tokens", Matches("", note, "raid urgent"), false)
Equal("AND property and text", Matches("", note, 'status:"IN PROGRESS" urgent'), true)
Equal("AND text missing", Matches("", note, 'status:"in progress" missing'), false)
Equal("AND property missing", Matches("", note, "level:25 ready:true"), false)
Equal("numeric property", Matches("", note, "level:25"), true)
Equal("exact not numeric coercion", Matches("", note, "level:025"), false)
Equal("boolean property false", Matches("", note, "ready:false"), true)
Equal("list property", Matches("", note, "roles:HEALER"), true)
Equal("exact property match", Matches("", note, "roles:heal"), false)
Equal("unknown property", Matches("", note, "unknown:no"), false)
Equal("private has no implicit visibility behavior", Matches("", note, ""), true)
Equal("private is just a property", Matches("", note, "private:true"), true)
Equal("metadata not body", Matches("", note, "In Progress"), false)
Equal("malformed YAML text remains searchable", Matches("", "---\nbroken: [\n---\nVisible body", "visible"), true)
Equal("malformed YAML property never matches", Matches("", "---\nready: true\nbroken: [\n---", "ready:true"), false)

-- Until Markdown supplies tag spans, mock only that contract, never Metadata's extraction.
local spans = ns.Markdown.Spans
local hasTag = false
for _, span in ipairs(spans("#probe")) do if span.tag == "probe" then hasTag = true end end
if not hasTag then
	local fixtures = {
		["#raid/tank"] = { { text = "#raid/tank", tag = "raid/tank" } },
		["#HeadingTag"] = { { text = "#HeadingTag", tag = "HeadingTag" } },
		["#ListTag"] = { { text = "#ListTag", tag = "ListTag" } },
		["#QuoteTag"] = { { text = "#QuoteTag", tag = "QuoteTag" } },
		["#HeaderTag"] = { { text = "#HeaderTag", tag = "HeaderTag" } },
		["#CellTag"] = { { text = "#CellTag", tag = "CellTag" } },
		["`#inlineCode` [#link](url) \\#escaped"] = {
			{ text = "#inlineCode", code = true }, { text = "#link", link = true }, { text = "#escaped" },
		},
	}
	ns.Markdown.Spans = function(text) return fixtures[text] or spans(text) end
	print("NOTE: Markdown tag spans not available; using contract fixtures")
end

local tagged = [==[# #HeadingTag

#raid/tank

- #ListTag

> #QuoteTag

| #HeaderTag |
| --- |
| #CellTag |

`#inlineCode` [#link](url) \#escaped

```
#fenced
```
]==]
Equal("tag extraction in supported blocks", Metadata.Tags({ tags = { "#RAID", "raid", " Custom ", false, 3 } }, tagged),
	{ "celltag", "custom", "headertag", "headingtag", "listtag", "quotetag", "raid", "raid/tank" })
Equal("string property tag", Metadata.Tags({ tags = "#Solo" }, ""), { "solo" })
Equal("non-string tag ignored", Metadata.Tags({ tags = true }, ""), {})
Equal("empty tags ignored", Metadata.Tags({ tags = { "#", "", " " } }, ""), {})
Equal("hierarchical parent", Matches("", "#raid/tank", "tag:raid"), true)
Equal("hierarchical exact", Matches("", "#raid/tank", "tag:raid/tank"), true)
Equal("hierarchical reverse does not match", Matches("", "---\ntags: raid\n---", "tag:raid/tank"), false)
Equal("hierarchical boundary", Matches("", "#raid/tank", "tag:rai"), false)
Equal("case insensitive property tags", Matches("", '---\ntags: ["#RAID/Tank"]\n---', "tag:#raid"), true)
Equal("tags and text AND", Matches("Plan", "#raid/tank", "tag:raid plan"), true)
Equal("tags and property AND", Matches("", "---\nready: true\n---\n#raid/tank", "tag:raid ready:true"), true)
Equal("inline tags survive malformed metadata", Matches("", "---\nbroken: [\n---\n#raid/tank", "tag:raid"), true)
Equal("body code does not supply tags", Matches("", "```\n#raid/tank\n```", "tag:raid"), false)
ns.Markdown.Spans = spans

ns.L = setmetatable({
	["Duplicate metadata property: %s"] = "Duplicate traduit : %s",
	["Invalid filter: empty value for %s"] = "Filtre vide : %s",
}, { __index = function(_, key) return key end })
Equal("localized duplicate", select(3, Metadata.Parse("---\nx: 1\nx: 2\n---")), "Duplicate traduit : x")
Equal("localized filter", select(2, Metadata.Query("tag:")), "Filtre vide : tag")

print(("%d assertions, %d failures"):format(count, failures))
if failures > 0 then os.exit(1) end
