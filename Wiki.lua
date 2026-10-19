local _, ns = ...
local L = ns.L

local function Normalize(title)
	return title:match("^%s*(.-)%s*$"):lower()
end

-- Shown when several notes share a linked title.
function ns.NotePath(id)
	local note = ns.GetNote(id)
	return note and ns.NotebookPath(note.notebook) .. " / " .. ns.NoteTitle(note) or ""
end

function ns.ResolveWikiLink(target)
	local matches = {}
	local key = Normalize(target)
	for _, id in ipairs(ns.SortedNotes()) do
		if Normalize(ns.NoteTitle(ns.GetNote(id))) == key then matches[#matches + 1] = id end
	end
	return matches
end

function ns.CaptureWikiLinks()
	local snapshot = {}
	for _, id in ipairs(ns.SortedNotes()) do
		local references = {}
		ns.Markdown.MapWikiLinks(ns.GetNote(id).text, function(target)
			local matches = ns.ResolveWikiLink(target)
			references[#references + 1] = #matches == 1
				and { id = matches[1], title = ns.NoteTitle(ns.GetNote(matches[1])) } or false
		end)
		snapshot[id] = references
	end
	return snapshot
end

function ns.RewriteWikiLinks(snapshot)
	for id, references in pairs(snapshot) do
		local note = ns.GetNote(id)
		if note then
			local index = 0
			local rewritten = ns.Markdown.MapWikiLinks(note.text, function(_, alias, original)
				index = index + 1
				local ref = references[index]
				local target = ref and ns.GetNote(ref.id)
				local title = target and ns.NoteTitle(target)
				if title and title ~= ref.title then
					local separator = original:find("||", 1, true) and "||" or "|"
					return "[[" .. title .. (alias and separator .. alias or "") .. "]]"
				end
			end)
			if rewritten ~= note.text then
				note.text, note.modified = rewritten, time()
			end
		end
	end
end

function ns.FollowWikiLink(target)
	local matches = ns.ResolveWikiLink(target)
	if #matches == 1 then
		ns.OpenNote(matches[1], "read")
	elseif #matches > 1 then
		ns.ChooseNote(L["Choose linked note"], matches, function(id) ns.OpenNote(id, "read") end)
	else
		local title = target:match("^%s*(.-)%s*$")
		ns.Confirm(L["Create the missing note \"%s\"?"]:format(title), function()
			if #ns.ResolveWikiLink(target) > 0 then ns.FollowWikiLink(target); return end
			local id, err = ns.CreateNote(title, "", ns.ActiveNotebook())
			if not id then ns.Say(err); return end
			ns.OpenNote(id, "edit")
		end)
	end
end
