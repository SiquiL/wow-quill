local addonName, ns = ...
local L = ns.L

local DB_VERSION = 2
local PREFIX = "|cff33ff99Quill|r: "

function ns.Say(message)
	print(PREFIX .. message)
end

StaticPopupDialogs["QUILL_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, onAccept)
		onAccept()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

function ns.Confirm(text, onAccept)
	StaticPopup_Show("QUILL_CONFIRM", text, nil, onAccept)
end

-- Notebooks ------------------------------------------------------------------

-- Deleted notebooks and everything inside them are hidden unless includeDeleted is set.
function ns.GetNotebook(id, includeDeleted)
	local notebook = id and QuillDB.notebooks[id]
	local current, seen = notebook, {}
	while current do
		if seen[current] or (current.owner and current.owner ~= UnitGUID("player"))
			or (current.deleted and not includeDeleted) then
			return nil
		end
		seen[current] = true
		current = current.parent and QuillDB.notebooks[current.parent]
	end
	return notebook
end

function ns.ActiveNotebook()
	local id = QuillDB.settings.notebook
	return ns.GetNotebook(id) and id or QuillDB.defaultNotebook
end

function ns.IsNotebookWithin(id, ancestor)
	local seen = {}
	while id and not seen[id] do
		if id == ancestor then
			return true
		end
		seen[id] = true
		local notebook = QuillDB.notebooks[id]
		id = notebook and notebook.parent
	end
	return false
end

function ns.NotebookList(exclude)
	local children = {}
	for id, notebook in pairs(QuillDB.notebooks) do
		if ns.GetNotebook(id) and not (exclude and ns.IsNotebookWithin(id, exclude)) then
			local parent = notebook.parent or 0
			children[parent] = children[parent] or {}
			table.insert(children[parent], id)
		end
	end
	for _, ids in pairs(children) do
		table.sort(ids, function(a, b)
			local titleA, titleB = QuillDB.notebooks[a].title:lower(), QuillDB.notebooks[b].title:lower()
			return titleA < titleB or (titleA == titleB and a < b)
		end)
	end
	local entries = {}
	local function Visit(parent, depth, path)
		for _, id in ipairs(children[parent] or {}) do
			local notebook = QuillDB.notebooks[id]
			local fullPath = path == "" and notebook.title or path .. " / " .. notebook.title
			entries[#entries + 1] = { id = id, depth = depth, path = fullPath }
			Visit(id, depth + 1, fullPath)
		end
	end
	Visit(0, 0, "")
	return entries
end

function ns.NotebookPath(id)
	for _, entry in ipairs(ns.NotebookList()) do
		if entry.id == id then
			return entry.path
		end
	end
	return ""
end

local function HasForeignChildren(id)
	local player = UnitGUID("player")
	for other, child in pairs(QuillDB.notebooks) do
		if ns.IsNotebookWithin(other, id) and child.owner and child.owner ~= player then
			return true
		end
	end
	for _, note in pairs(QuillDB.notes) do
		if note.owner and note.owner ~= player and ns.IsNotebookWithin(note.notebook, id) then
			return true
		end
	end
	return false
end

function ns.UpdateNotebook(id, title, parent, characterOnly)
	local notebook = ns.GetNotebook(id)
	if not notebook then
		return nil, L["This notebook is not available."]
	end
	title = (title or ""):match("^%s*(.-)%s*$")
	if title == "" then
		return nil, L["Enter a notebook name."]
	end
	if parent and not ns.GetNotebook(parent) then
		return nil, L["This notebook is not available."]
	end
	if parent and ns.IsNotebookWithin(parent, id) then
		return nil, L["A notebook cannot be placed inside itself or its children."]
	end
	if id == QuillDB.defaultNotebook and (parent or characterOnly) then
		return nil, L["The default notebook must remain global and at the top level."]
	end
	local owner = characterOnly and UnitGUID("player") or nil
	if characterOnly and not owner then
		return nil, L["The current character is not available yet."]
	end
	if parent and QuillDB.notebooks[parent].owner then
		owner = QuillDB.notebooks[parent].owner
	end
	local changedScope = notebook.owner ~= owner
	if changedScope and HasForeignChildren(id) then
		return nil, L["This notebook contains another character's notebooks or notes."]
	end
	notebook.title, notebook.parent = title, parent
	if changedScope then
		for other, child in pairs(QuillDB.notebooks) do
			if ns.IsNotebookWithin(other, id) then
				child.owner = owner
			end
		end
	end
	return id
end

function ns.CreateNotebook(title, parent, characterOnly)
	local id = QuillDB.nextNotebookId
	QuillDB.notebooks[id] = { title = "" }
	local result, err = ns.UpdateNotebook(id, title, parent, characterOnly)
	if not result then
		QuillDB.notebooks[id] = nil
		return nil, err
	end
	QuillDB.nextNotebookId = id + 1
	return id
end

function ns.DeleteNotebook(id)
	if not ns.GetNotebook(id) then
		return nil, L["This notebook is not available."]
	end
	if id == QuillDB.defaultNotebook then
		return nil, L["The default notebook cannot be deleted."]
	end
	if HasForeignChildren(id) then
		return nil, L["This notebook contains another character's notebooks or notes."]
	end
	QuillDB.notebooks[id].deleted = time()
	if not ns.GetNotebook(QuillDB.settings.notebook) then
		QuillDB.settings.notebook = QuillDB.defaultNotebook
	end
	if not ns.GetNote(QuillDB.settings.selected) then
		QuillDB.settings.selected = nil
	end
	ns.NotesChanged()
	return true
end

-- Notes ----------------------------------------------------------------------

function ns.GetNote(id, includeDeleted)
	local note = id and QuillDB.notes[id]
	if note and ((note.owner and note.owner ~= UnitGUID("player")) or (note.deleted and not includeDeleted)) then
		return nil
	end
	return note and ns.GetNotebook(note.notebook, includeDeleted) and note or nil
end

-- Lets open windows follow deletions, restores and edits.
function ns.NotesChanged(id)
	if ns.RefreshNoteWindows then ns.RefreshNoteWindows(id) end
	if id == nil and ns.RefreshTrash then ns.RefreshTrash() end
end

-- A note is character-only by itself or through a character-only notebook
function ns.IsNoteCharacterOnly(id)
	local note = ns.GetNote(id)
	return note ~= nil and (note.owner ~= nil or ns.GetNotebook(note.notebook).owner ~= nil)
end

function ns.SetNoteCharacterOnly(id, characterOnly)
	local note = ns.GetNote(id)
	if not note then
		return nil, L["This note is not available."]
	end
	local owner = characterOnly and UnitGUID("player") or nil
	if characterOnly and not owner then
		return nil, L["The current character is not available yet."]
	end
	if note.owner ~= owner then
		note.owner = owner
		note.modified = time()
	end
	return true
end

function ns.NoteTitle(note)
	local title = note and note.title and note.title:match("^%s*(.-)%s*$") or ""
	return title ~= "" and title or L["Untitled"]
end

-- Titles are unique per notebook among notes this character can see, ignoring ASCII case
function ns.NoteTitleTaken(title, notebook, except)
	local key = ns.NoteTitle({ title = title }):lower()
	for id, note in pairs(QuillDB.notes) do
		if id ~= except and note.notebook == notebook and ns.GetNote(id) and ns.NoteTitle(note):lower() == key then
			return true
		end
	end
	return false
end

-- Older saved data may contain duplicates; the oldest note keeps its name, later ones get a number.
-- Other characters' private notes are resolved when that character logs in.
function ns.ResolveDuplicateTitles()
	local ids = {}
	for id in pairs(QuillDB.notes) do
		if ns.GetNote(id) then ids[#ids + 1] = id end
	end
	table.sort(ids)
	local seen, renamed = {}, 0
	for _, id in ipairs(ids) do
		local note = QuillDB.notes[id]
		local used = seen[note.notebook] or {}
		seen[note.notebook] = used
		local title = ns.NoteTitle(note)
		if used[title:lower()] then
			local number, candidate = 2
			repeat
				candidate = title .. " " .. number
				number = number + 1
			until not used[candidate:lower()] and not ns.NoteTitleTaken(candidate, note.notebook, id)
			note.title, note.modified = candidate, time()
			title = candidate
			renamed = renamed + 1
		end
		used[title:lower()] = true
	end
	if renamed > 0 then
		ns.Say(L["%d notes with a duplicate name in the same notebook were renamed."]:format(renamed))
	end
	return renamed
end

local function TitleTakenError(title)
	return L["A note named \"%s\" already exists in this notebook."]:format(ns.NoteTitle({ title = title }))
end

function ns.CreateNote(title, text, notebook)
	notebook = notebook or ns.ActiveNotebook()
	if not ns.GetNotebook(notebook) then
		return nil, L["This notebook is not available."]
	end
	title = (title or ""):match("^%s*(.-)%s*$")
	if title == "" then
		title = L["Untitled"]
		local number = 1
		while ns.NoteTitleTaken(title, notebook) do
			number = number + 1
			title = L["Untitled"] .. " " .. number
		end
	elseif ns.NoteTitleTaken(title, notebook) then
		return nil, TitleTakenError(title)
	end
	local id = QuillDB.nextId
	QuillDB.nextId = id + 1
	local now = time()
	QuillDB.notes[id] = {
		title = title,
		text = text or "",
		created = now,
		modified = now,
		notebook = notebook,
	}
	return id
end

function ns.UpdateNote(id, field, value)
	local note = ns.GetNote(id)
	if not note then return nil end
	if field == "title" and ns.NoteTitleTaken(value, note.notebook, id) then
		return nil, TitleTakenError(value)
	end
	if note[field] ~= value then
		local links = field == "title" and ns.CaptureWikiLinks and ns.CaptureWikiLinks()
		note[field] = value
		note.modified = time()
		if links then ns.RewriteWikiLinks(links) end
		ns.NotesChanged(not links and id or nil)
	end
	return true
end

function ns.DeleteNote(id)
	if not ns.GetNote(id) then
		return
	end
	QuillDB.notes[id].deleted = time()
	if QuillDB.settings.selected == id then
		QuillDB.settings.selected = nil
	end
	ns.NotesChanged()
end

function ns.SetNotePinned(id, pinned)
	local note = ns.GetNote(id)
	if not note then
		return nil, L["This note is not available."]
	end
	note.pinned = pinned and true or nil
	return true
end

-- Trash ----------------------------------------------------------------------

ns.TRASH_DAYS = 7
local TRASH_SECONDS = ns.TRASH_DAYS * 24 * 60 * 60

-- Deleted notes and notebooks this character may see, newest first
function ns.TrashEntries()
	local entries = {}
	for id, notebook in pairs(QuillDB.notebooks) do
		if notebook.deleted and ns.GetNotebook(id, true) then
			entries[#entries + 1] = { kind = "notebook", id = id, title = notebook.title, deleted = notebook.deleted }
		end
	end
	for id, note in pairs(QuillDB.notes) do
		if note.deleted and ns.GetNote(id, true) then
			entries[#entries + 1] = { kind = "note", id = id, title = ns.NoteTitle(note), deleted = note.deleted }
		end
	end
	table.sort(entries, function(a, b)
		if a.deleted ~= b.deleted then return a.deleted > b.deleted end
		if a.kind ~= b.kind then return a.kind == "notebook" end
		return a.id < b.id
	end)
	for _, entry in ipairs(entries) do
		entry.expires = entry.deleted + TRASH_SECONDS
	end
	return entries
end

local function FreeTitle(title, notebook, except)
	if not ns.NoteTitleTaken(title, notebook, except) then return title end
	local number = 2
	while ns.NoteTitleTaken(title .. " " .. number, notebook, except) do
		number = number + 1
	end
	return title .. " " .. number
end

-- Returns the restored title, which gets a number if the name is taken meanwhile.
function ns.RestoreNote(id)
	local note = ns.GetNote(id, true)
	if not (note and note.deleted) then
		return nil, L["This note is not in the trash."]
	end
	note.deleted = nil
	if not ns.GetNotebook(note.notebook) then
		note.notebook = QuillDB.defaultNotebook
	end
	note.title = FreeTitle(ns.NoteTitle(note), note.notebook, id)
	note.modified = time()
	ns.NotesChanged()
	return note.title
end

function ns.RestoreNotebook(id)
	local notebook = ns.GetNotebook(id, true)
	if not (notebook and notebook.deleted) then
		return nil, L["This notebook is not in the trash."]
	end
	notebook.deleted = nil
	if not ns.GetNotebook(id) then
		notebook.parent = nil
	end
	ns.NotesChanged()
	return true
end

local function Purge(kind, id)
	if kind == "note" then
		QuillDB.notes[id] = nil
		if QuillDB.settings.popouts then QuillDB.settings.popouts[id] = nil end
		return
	end
	local removed = {}
	for other in pairs(QuillDB.notebooks) do
		if ns.IsNotebookWithin(other, id) then removed[other] = true end
	end
	for noteId, note in pairs(QuillDB.notes) do
		if removed[note.notebook] then Purge("note", noteId) end
	end
	for other in pairs(removed) do
		QuillDB.notebooks[other] = nil
	end
end

function ns.PurgeTrashEntry(kind, id)
	local entry = kind == "note" and ns.GetNote(id, true) or kind == "notebook" and ns.GetNotebook(id, true)
	if not (entry and entry.deleted) then
		return nil, L["This entry is not in the trash."]
	end
	Purge(kind, id)
	ns.NotesChanged()
	return true
end

function ns.EmptyTrash()
	local entries = ns.TrashEntries()
	for _, entry in ipairs(entries) do
		if QuillDB[entry.kind == "note" and "notes" or "notebooks"][entry.id] then
			Purge(entry.kind, entry.id)
		end
	end
	ns.NotesChanged()
	return #entries
end

-- Runs for every character's entries, so private trash is cleaned up even while its owner is offline.
function ns.PurgeExpiredTrash(now)
	local expired = (now or time()) - TRASH_SECONDS
	local purged = 0
	for id, notebook in pairs(QuillDB.notebooks) do
		if QuillDB.notebooks[id] and notebook.deleted and notebook.deleted <= expired then
			Purge("notebook", id)
			purged = purged + 1
		end
	end
	for id, note in pairs(QuillDB.notes) do
		if note.deleted and note.deleted <= expired then
			Purge("note", id)
			purged = purged + 1
		end
	end
	return purged
end

function ns.MoveNote(id, notebook)
	local note = ns.GetNote(id)
	if not note or not ns.GetNotebook(notebook) then
		return nil, L["The note or destination notebook is not available."]
	end
	if note.notebook ~= notebook and ns.NoteTitleTaken(note.title, notebook, id) then
		return nil, TitleTakenError(note.title)
	end
	note.notebook = notebook
	note.modified = time()
	return true
end

-- Note IDs sorted by title; the filter matches title or text, ignoring case
function ns.SortedNotes(filter, notebook, terms)
	local err
	if not terms then terms, err = ns.Metadata.Query(filter or "") end
	if not terms then return {}, err end
	local ids = {}
	for id, note in pairs(QuillDB.notes) do
		if ns.GetNote(id) and (not notebook or note.notebook == notebook)
			and ns.Metadata.Matches(ns.NoteTitle(note), note.text, terms) then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids, function(a, b)
		local titleA, titleB = ns.NoteTitle(QuillDB.notes[a]):lower(), ns.NoteTitle(QuillDB.notes[b]):lower()
		if titleA ~= titleB then
			return titleA < titleB
		end
		return a < b
	end)
	return ids
end

function ns.TreeEntries(filter, collapsed)
	local terms, err = ns.Metadata.Query(filter or "")
	if not terms then return {}, err end
	local entries, hiddenDepth = {}, nil
	local favorites = {}
	for _, id in ipairs(ns.SortedNotes(filter, nil, terms)) do
		if QuillDB.notes[id].pinned then favorites[#favorites + 1] = id end
	end
	if #favorites > 0 then
		entries[1] = { kind = "favorites", depth = 0 }
		if not collapsed.favorites or (filter and filter ~= "") then
			for _, id in ipairs(favorites) do
				entries[#entries + 1] = { kind = "note", id = id, depth = 1, favorite = true }
			end
		end
	end
	for _, entry in ipairs(ns.NotebookList()) do
		if hiddenDepth and entry.depth <= hiddenDepth then
			hiddenDepth = nil
		end
		if not hiddenDepth then
			entries[#entries + 1] = { kind = "notebook", id = entry.id, depth = entry.depth }
			if collapsed[entry.id] and (not filter or filter == "") then
				hiddenDepth = entry.depth
			else
				for _, id in ipairs(ns.SortedNotes(filter, entry.id, terms)) do
					entries[#entries + 1] = { kind = "note", id = id, depth = entry.depth + 1 }
				end
			end
		end
	end
	return entries
end

-- Saved variables ------------------------------------------------------------

local function InitDB()
	local fresh = QuillDB == nil
	QuillDB = QuillDB or {}
	QuillDB.notes = QuillDB.notes or {}
	QuillDB.notebooks = QuillDB.notebooks or {}
	QuillDB.settings = QuillDB.settings or {}
	local theme = QuillDB.settings.theme
	if theme and not ns.IsTheme(theme) then
		QuillDB.settings.theme = "standard"
		-- Background themes from earlier test builds fall back silently.
		if theme ~= "parchment" and theme ~= "marble" and theme ~= "rock" and theme ~= "dialog" then
			ns.Say(L["An invalid theme was reset."])
		end
	end
	if QuillDB.settings.backgroundOpacity ~= nil and not ns.ValidOpacity(QuillDB.settings.backgroundOpacity) then
		QuillDB.settings.backgroundOpacity = nil
	end
	if QuillDB.settings.backgroundColor and ns.ValidColor and not ns.ValidColor(QuillDB.settings.backgroundColor) then
		QuillDB.settings.backgroundColor = nil
		ns.Say(L["An invalid background color was reset."])
	end
	QuillDB.version = DB_VERSION

	local highestNotebook = 0
	for id, notebook in pairs(QuillDB.notebooks) do
		highestNotebook = math.max(highestNotebook, id)
		notebook.title = notebook.title or L["Untitled"]
		notebook.deleted = type(notebook.deleted) == "number" and notebook.deleted or nil
		if notebook.color and ns.ValidColor and not ns.ValidColor(notebook.color) then
			notebook.color = nil
			ns.Say(L["An invalid notebook color was reset."])
		end
	end
	QuillDB.nextNotebookId = math.max(tonumber(QuillDB.nextNotebookId) or 1, highestNotebook + 1)
	if not QuillDB.notebooks[QuillDB.defaultNotebook] then
		QuillDB.defaultNotebook = ns.CreateNotebook(L["General"])
	end
	QuillDB.notebooks[QuillDB.defaultNotebook].deleted = nil
	for id, notebook in pairs(QuillDB.notebooks) do
		if notebook.parent and (not QuillDB.notebooks[notebook.parent] or ns.IsNotebookWithin(notebook.parent, id)) then
			notebook.parent = nil
			ns.Say(L["An invalid notebook parent was reset."])
		end
	end
	local highest = 0
	for id, note in pairs(QuillDB.notes) do
		if type(id) ~= "number" or type(note) ~= "table" then
			QuillDB.notes[id] = nil
		else
			note.title = type(note.title) == "string" and note.title or ""
			note.text = type(note.text) == "string" and note.text or ""
			note.owner = type(note.owner) == "string" and note.owner or nil
			note.deleted = type(note.deleted) == "number" and note.deleted or nil
			note.pinned = note.pinned == true or nil
			if not QuillDB.notebooks[note.notebook] then
				note.notebook = QuillDB.defaultNotebook
			end
			highest = math.max(highest, id)
		end
	end
	QuillDB.nextId = math.max(tonumber(QuillDB.nextId) or 1, highest + 1)
	if type(QuillDB.settings.popouts) ~= "table" then
		QuillDB.settings.popouts = nil
	end
	ns.PurgeExpiredTrash()

	if fresh then
		QuillDB.settings.selected = ns.CreateNote(L.WELCOME_TITLE, L.WELCOME_TEXT)
		QuillDB.settings.mode = "read"
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		InitDB()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		-- Visibility of private notes needs the player's GUID.
		ns.ResolveDuplicateTitles()
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)

-- Slash command and addon compartment ----------------------------------------

local function Open(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		ns.Say(L["The notebook could not be opened – %s"]:format(tostring(err)))
	end
end

SLASH_QUILL1 = "/quill"

SlashCmdList["QUILL"] = function(msg)
	local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	command = command:lower()

	if command == "" then
		Open(ns.ToggleWindow)
	elseif command == "new" then
		local id, err = ns.CreateNote(rest)
		if not id then
			ns.Say(err)
			return
		end
		ns.Say(L["Created note \"%s\"."]:format(ns.NoteTitle(ns.GetNote(id))))
		Open(ns.OpenNote, id, "edit")
	elseif command == "options" then
		ns.OpenOptions()
	elseif command == "trash" then
		Open(ns.ShowTrash)
	else
		ns.Say(L["Commands:"])
		print("  " .. L["/quill – open or close the notebook"])
		print("  " .. L["/quill new [title] – create a note and edit it"])
		print("  " .. L["/quill trash – open the trash"])
		print("  " .. L["/quill options – open the options panel"])
	end
end

function Quill_OnAddonCompartmentClick(_, button)
	if button == "RightButton" then
		ns.OpenOptions()
	else
		Open(ns.ToggleWindow)
	end
end

function Quill_OnAddonCompartmentEnter(_, frame)
	GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
	GameTooltip:SetText("Quill")
	GameTooltip:AddLine(L["Left-click: toggle the window"], 1, 1, 1)
	GameTooltip:AddLine(L["Right-click: open the options"], 1, 1, 1)
	GameTooltip:Show()
end

function Quill_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
