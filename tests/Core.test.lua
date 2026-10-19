local character = "Player-A"
local events, messages = {}, {}
_G.UnitGUID = function() return character end
_G.time = function() return 12345 end
_G.YES, _G.NO = "Yes", "No"
_G.SlashCmdList, _G.StaticPopupDialogs = {}, {}
_G.CreateFrame = function()
	local frame = {}
	function frame:RegisterEvent() end
	function frame:UnregisterEvent() end
	function frame:SetScript(_, callback) self.callback = callback end
	events[#events + 1] = frame
	return frame
end
local ns = { L = setmetatable({ WELCOME_TITLE = "Welcome", WELCOME_TEXT = "Hello" }, {
	__index = function(_, key) return key end,
}) }
assert(loadfile("Markdown.lua"))("Quill", ns)
assert(loadfile("Metadata.lua"))("Quill", ns)
assert(loadfile("Wiki.lua"))("Quill", ns)
assert(loadfile("Appearance.lua"))("Quill", ns)
local function Init()
	assert(loadfile("Core.lua"))("Quill", ns)
	ns.Say = function(message) messages[#messages + 1] = message end
	local frame = events[#events]
	frame.callback(frame, "ADDON_LOADED", "Quill")
end
local count = 0
local function Check(name, condition)
	count = count + 1
	assert(condition, name)
end
local function Size(table)
	local result = 0
	for _ in pairs(table) do result = result + 1 end
	return result
end
_G.QuillDB = { version = 1, notes = {
	[1] = { title = "Existing", text = "original", created = 42, modified = 43 },
	[4] = { title = "Another", text = "another" },
}, settings = { selected = 1, window = { width = 900 } }, nextId = 5 }
Init()
local general = QuillDB.defaultNotebook
Check("migration adds global default notebook", ns.GetNotebook(general).owner == nil)
Check("migration keeps note data", ns.GetNote(1).text == "original" and ns.GetNote(1).created == 42)
Check("migration assigns existing notes", ns.GetNote(1).notebook == general and ns.GetNote(4).notebook == general)
Check("migration keeps selection and window", QuillDB.settings.selected == 1 and QuillDB.settings.window.width == 900)
Init()
Check("migration is idempotent", Size(QuillDB.notebooks) == 1 and Size(QuillDB.notes) == 2 and QuillDB.nextId == 5)

local root = assert(ns.CreateNotebook("World"))
local child = assert(ns.CreateNotebook("Dungeons", root))
local leaf = assert(ns.CreateNotebook("Quests", child))
local note = assert(ns.CreateNote("Private quest", "needle", leaf))
Check("nested path", ns.NotebookPath(leaf) == "World / Dungeons / Quests")
Check("cycles rejected", ns.UpdateNotebook(root, "World", leaf, false) == nil)
Check("self parent rejected", ns.UpdateNotebook(root, "World", root, false) == nil)
Check("blank name rejected", ns.CreateNotebook("   ") == nil)
Check("missing parent rejected", ns.CreateNotebook("Invalid", 9999) == nil)
Check("default cannot be private", ns.UpdateNotebook(general, "General", nil, true) == nil)
Check("default cannot be deleted", ns.DeleteNotebook(general) == nil)
assert(ns.UpdateNotebook(child, "Dungeons", root, true))
Check("scope changes cascade to descendants", ns.GetNotebook(child).owner == character and ns.GetNotebook(leaf).owner == character)
assert(ns.UpdateNotebook(root, "World renamed", nil, false))
Check("rename preserves private subnotebooks", ns.GetNotebook(child).owner == character)
local nested = assert(ns.CreateNotebook("Inherited", child, false))
Check("private parent forces child scope", ns.GetNotebook(nested).owner == character)
local scopedNote = assert(ns.CreateNote("Inherited note", "", nested))

character = "Player-B"
Check("other character cannot see private notebooks", ns.GetNotebook(child) == nil and ns.GetNotebook(leaf) == nil)
Check("other character cannot read notes", ns.GetNote(note) == nil and ns.GetNote(scopedNote) == nil)
Check("other character still sees globals", ns.GetNote(1) ~= nil and ns.GetNotebook(root) ~= nil)
ns.UpdateNote(note, "text", "changed")
ns.DeleteNote(note)
Check("hidden notes are not changed or deleted", QuillDB.notes[note].text == "needle")
Check("move rejects hidden notes", ns.MoveNote(note, general) == nil)
Check("creation rejects hidden notebooks", ns.CreateNote("Hidden", "", child) == nil)
Check("search does not reveal hidden notes", #ns.SortedNotes("needle") == 0)
Check("picker does not reveal hidden notebooks", #ns.NotebookList() == 2)
Check("delete protects foreign private descendants", ns.DeleteNotebook(root) == nil)
Check("scope change protects foreign private descendants", ns.UpdateNotebook(root, "World", nil, true) == nil)
QuillDB.settings.notebook = child
Check("invalid active notebook falls back to global", ns.ActiveNotebook() == general)

character = "Player-A"
Check("owner sees private notes again", ns.GetNote(note) ~= nil)
Check("search finds private note for owner", ns.SortedNotes("needle", leaf)[1] == note)
Check("picker excludes moved subtree", #ns.NotebookList(child) == 2)
local entries = ns.TreeEntries("needle", { [root] = true })
local found = false
for _, entry in ipairs(entries) do
	if entry.kind == "note" and entry.id == note then found = true end
end
Check("search expands collapsed tree", found)
entries = ns.TreeEntries("", { [root] = true })
found = false
for _, entry in ipairs(entries) do
	if entry.id == note and entry.kind == "note" then found = true end
end
Check("collapsed tree hides descendant notes", not found)
assert(ns.MoveNote(note, general))
character = "Player-B"
Check("moving to global makes note available", ns.GetNote(note) ~= nil)
character = "Player-A"
assert(ns.UpdateNotebook(child, "Shared", root, false))
character = "Player-B"
Check("making notebook global exposes its notes", ns.GetNote(scopedNote) ~= nil)
assert(ns.DeleteNotebook(child))
Check("deleting subtree hides its notes", ns.GetNotebook(leaf) == nil and ns.GetNote(scopedNote) == nil)
Check("deleted subtree stays in trash", QuillDB.notebooks[leaf] ~= nil and QuillDB.notes[scopedNote] ~= nil)
Check("deleting subtree preserves moved and unrelated notes", ns.GetNote(note) ~= nil and ns.GetNote(1) ~= nil)
local trash = ns.TrashEntries()
Check("trash lists only the deleted root notebook", #trash == 1 and trash[1].kind == "notebook" and trash[1].id == child
	and trash[1].expires == 12345 + 7 * 86400)
Check("hidden notebook cannot take new notes", ns.CreateNote("Inside trash", "", leaf) == nil)
assert(ns.RestoreNotebook(child))
Check("restoring notebook restores its subtree", ns.GetNotebook(leaf) ~= nil and ns.GetNote(scopedNote) ~= nil
	and ns.GetNotebook(child).parent == root)
assert(ns.DeleteNotebook(child))
assert(ns.PurgeTrashEntry("notebook", child))
Check("purging notebook removes subtree for good", QuillDB.notebooks[leaf] == nil and QuillDB.notes[scopedNote] == nil
	and #ns.TrashEntries() == 0)

-- Visibility of a single note
character = "Player-A"
Check("global note in global notebook", not ns.IsNoteCharacterOnly(1))
assert(ns.MoveNote(1, root))
assert(ns.SetNoteCharacterOnly(1, true))
Check("note can be made character-only", ns.IsNoteCharacterOnly(1) and QuillDB.notes[1].owner == "Player-A")
character = "Player-B"
Check("other character cannot see private note", ns.GetNote(1) == nil)
Check("private note hidden from search and tree", #ns.SortedNotes("original") == 0)
Check("other character cannot change visibility", ns.SetNoteCharacterOnly(1, false) == nil)
Check("notebook with foreign private note cannot be deleted", ns.DeleteNotebook(root) == nil)
character = "Player-A"
Check("owner still sees private note", ns.GetNote(1) ~= nil)
assert(ns.SetNoteCharacterOnly(1, false))
character = "Player-B"
Check("note can be made global again", ns.GetNote(1) ~= nil and QuillDB.notes[1].owner == nil)
character = "Player-A"
QuillDB.notes[4].owner = 42
Init()
Check("invalid note owner is cleared", QuillDB.notes[4].owner == nil)

_G.QuillDB = nil
Init()
Check("fresh install creates welcome note in global notebook", #ns.SortedNotes() == 1 and ns.GetNote(QuillDB.settings.selected).notebook == QuillDB.defaultNotebook)

local raid = assert(ns.CreateNotebook("Raid"))
local target = assert(ns.CreateNote("Boss", "", raid))
local source = assert(ns.CreateNote("Guide",
	"---\nsummary: '[[Boss]]'\nstatus: open\ntags: [raid, tank]\n---\n[[Boss]] [[Boss||Strategy]] `[[Boss]]`\n#raid/tank", QuillDB.defaultNotebook))
local foreign = assert(ns.CreateNote("Other character", "[[Boss]]", QuillDB.defaultNotebook))
assert(ns.SetNoteCharacterOnly(foreign, true))
character = "Player-B"
ns.UpdateNote(target, "title", "New Boss")
Check("note rename updates bare links", ns.GetNote(source).text:find("[[New Boss]] ", 1, true))
Check("rename preserves stored aliases", ns.GetNote(source).text:find("[[New Boss||Strategy]]", 1, true))
Check("rename leaves frontmatter and code alone", ns.GetNote(source).text:find("summary: '[[Boss]]'", 1, true)
	and ns.GetNote(source).text:find("`[[Boss]]`", 1, true))
Check("rename cannot modify foreign private references", QuillDB.notes[foreign].text == "[[Boss]]")
local renamed = ns.GetNote(source).text
assert(ns.MoveNote(target, QuillDB.defaultNotebook))
assert(ns.UpdateNotebook(QuillDB.defaultNotebook, "Shared", nil, false))
Check("moves and notebook renames keep title links", ns.GetNote(source).text == renamed)
Check("wiki title ignores spacing and case", ns.ResolveWikiLink("  new boss ")[1] == target)
Check("notebook paths are not link syntax", #ns.ResolveWikiLink("Shared/New Boss") == 0)
Check("missing link returns no candidates", #ns.ResolveWikiLink("missing") == 0)
local duplicate = assert(ns.CreateNote("New Boss", "", raid))
Check("duplicate titles return both candidates", #ns.ResolveWikiLink("New Boss") == 2)
local chosen, openedNote
ns.ChooseNote = function(_, ids, callback) chosen = ids; callback(ids[2]) end
ns.OpenNote = function(id) openedNote = id end
ns.FollowWikiLink("New Boss")
Check("ambiguous wiki links show picker", #chosen == 2 and openedNote == chosen[2])
ns.UpdateNote(duplicate, "title", "Boss two")
chosen = nil
ns.FollowWikiLink("new boss")
Check("unique wiki link opens target", openedNote == target and chosen == nil)
ns.Confirm = function(_, callback) callback() end
QuillDB.settings.notebook = raid
ns.FollowWikiLink(" New plan ")
Check("missing target is created in active notebook", ns.GetNote(openedNote).title == "New plan" and ns.GetNote(openedNote).notebook == raid)Check("property and tag filters combine with AND", ns.SortedNotes("tag:raid status:open")[1] == source)
Check("property filter excludes wrong value", #ns.SortedNotes("tag:raid status:closed") == 0)
Check("parent tag finds nested inline tag", ns.SortedNotes("tag:raid/tank")[1] == source)
local invalidResults, invalidError = ns.TreeEntries("tag:", {})
Check("invalid filter returns explicit error", #invalidResults == 0 and invalidError ~= nil)
character = "Player-A"
assert(ns.SetNoteCharacterOnly(source, true))
character = "Player-B"
Check("property filters cannot expose hidden notes", #ns.SortedNotes("tag:raid status:open") == 0)
assert(ns.SetNotebookColor(raid, { 0.2, 0.4, 0.8 }))
Check("notebook color persists independently", ns.GetNotebook(raid).color[3] == 0.8 and ns.GetNotebook(QuillDB.defaultNotebook).color == nil)
Check("invalid colors rejected", ns.SetNotebookColor(raid, { 2, 0, 0 }) == nil)
assert(ns.SetNotebookColor(raid, nil))
Check("notebook color reset", ns.GetNotebook(raid).color == nil)
QuillDB.notebooks[raid].color = { 0 / 0, 0, 0 }
Init()
Check("invalid saved colors repaired", ns.GetNotebook(raid).color == nil)

local unique = assert(ns.CreateNotebook("Unique"))
local first = assert(ns.CreateNote("Plan", "", unique))
local copy, copyError = ns.CreateNote(" plan ", "", unique)
Check("duplicate title rejected in same notebook", copy == nil and copyError ~= nil)
Check("same title allowed in another notebook", ns.CreateNote("Plan", "", raid) ~= nil)
local second = assert(ns.CreateNote("Other", "", unique))
Check("rename to existing title rejected", ns.UpdateNote(second, "title", "PLAN") == nil and ns.GetNote(second).title == "Other")
Check("rename keeping own title allowed", ns.UpdateNote(first, "title", "Plan") == true)
Check("move into notebook with same title rejected", ns.MoveNote(second, unique) == true
	and ns.MoveNote(assert(ns.CreateNote("Other", "", raid)), unique) == nil)
local untitled = assert(ns.CreateNote("", "", unique))
local untitled2 = assert(ns.CreateNote(nil, "", unique))
Check("new untitled notes get unique names", ns.GetNote(untitled).title == "Untitled" and ns.GetNote(untitled2).title == "Untitled 2")
Check("empty title cannot collide with Untitled", ns.UpdateNote(first, "title", "") == nil)
character = "Player-A"
local hidden = assert(ns.CreateNote("Secret", "", unique))
assert(ns.SetNoteCharacterOnly(hidden, true))
character = "Player-B"
Check("other characters' private titles do not block", ns.CreateNote("Secret", "", unique) ~= nil)
QuillDB.settings.theme = "marble"
QuillDB.settings.backgroundOpacity = 2
Init()
Check("removed test themes fall back to standard", QuillDB.settings.theme == "standard")
Check("invalid opacity is reset", QuillDB.settings.backgroundOpacity == nil and ns.BackgroundOpacity() == 1)

local function Login()
	local frame = events[#events]
	frame.callback(frame, "PLAYER_LOGIN")
end
local legacy = assert(ns.CreateNotebook("Legacy"))
local function Legacy(id, title, owner)
	QuillDB.notes[id] = { title = title, text = "", notebook = legacy, owner = owner }
end
Legacy(901, "Plan")
Legacy(902, " plan ")
Legacy(903, "Plan 2")
Legacy(904, "")
Legacy(905, "Untitled")
Legacy(906, "Plan", "Player-A")
QuillDB.notes[907] = { title = "Plan", text = "", notebook = QuillDB.defaultNotebook }
character = "Player-B"
messages = {}
Init()
Login()
Check("oldest duplicate keeps its name", QuillDB.notes[901].title == "Plan")
Check("later duplicate gets a free number", QuillDB.notes[902].title == "plan 3" and QuillDB.notes[903].title == "Plan 2")
Check("duplicate untitled notes are numbered", QuillDB.notes[905].title == "Untitled 2")
Check("other character's private duplicate is untouched", QuillDB.notes[906].title == "Plan")
Check("same title in another notebook is allowed", QuillDB.notes[907].title == "Plan")
Check("migration reports renamed notes", #messages == 1)
character = "Player-A"
Init()
Login()
Check("private duplicate resolved on owner's login", QuillDB.notes[906].title == "Plan 4")
Check("second migration is idempotent", ns.ResolveDuplicateTitles() == 0)

-- Trash and favorites
local trashBook = assert(ns.CreateNotebook("Trash test"))
local trashed = assert(ns.CreateNote("Boss plan", "[[Boss plan]]", trashBook))
QuillDB.settings.selected = trashed
ns.DeleteNote(trashed)
Check("deleted note is hidden", ns.GetNote(trashed) == nil and QuillDB.settings.selected == nil)
Check("deleted note is hidden from search and wiki links", #ns.SortedNotes("Boss plan") == 0 and #ns.ResolveWikiLink("Boss plan") == 0)
Check("deleted note frees its title", ns.NoteTitleTaken("Boss plan", trashBook) == false)
local replacement = assert(ns.CreateNote("Boss plan", "", trashBook))
Check("restore renames on title conflict", ns.RestoreNote(trashed) == "Boss plan 2" and ns.GetNote(trashed).notebook == trashBook)
Check("restoring twice is rejected", ns.RestoreNote(trashed) == nil)
ns.DeleteNote(trashed)
assert(ns.DeleteNotebook(trashBook))
Check("restore into deleted notebook falls back to default", ns.RestoreNote(trashed) == "Boss plan 2"
	and ns.GetNote(trashed).notebook == QuillDB.defaultNotebook)
local ownTrash = ns.TrashEntries()
Check("trash shows notebook but not its contained notes", #ownTrash == 1 and ownTrash[1].id == trashBook)
character = "Player-B"
Check("other character does not see private trash", #ns.TrashEntries() == 1)
character = "Player-A"
local childBook = assert(ns.CreateNotebook("Trash child", nil))
assert(ns.UpdateNotebook(childBook, "Trash child", QuillDB.defaultNotebook, false))
local privateTrash = assert(ns.CreateNote("Private trash", "", childBook))
assert(ns.SetNoteCharacterOnly(privateTrash, true))
ns.DeleteNote(privateTrash)
character = "Player-B"
Check("other character cannot restore or purge private trash",
	ns.RestoreNote(privateTrash) == nil and ns.PurgeTrashEntry("note", privateTrash) == nil)
Check("other character's empty trash keeps private entries", ns.EmptyTrash() == 1 and QuillDB.notes[privateTrash] ~= nil
	and QuillDB.notebooks[trashBook] == nil and QuillDB.notes[replacement] == nil)
character = "Player-A"
Check("purging requires a trash entry", ns.PurgeTrashEntry("note", trashed) == nil and QuillDB.notes[trashed] ~= nil)
QuillDB.settings.popouts = { [privateTrash] = { width = 300 } }
Check("expired entries stay before seven days", ns.PurgeExpiredTrash(12345 + 7 * 86400 - 1) == 0)
Check("expired entries are purged after seven days", ns.PurgeExpiredTrash(12345 + 7 * 86400) == 1
	and QuillDB.notes[privateTrash] == nil and QuillDB.settings.popouts[privateTrash] == nil)
QuillDB.notes[trashed].deleted = 12345 - 7 * 86400
QuillDB.notebooks[childBook].deleted = "yesterday"
Init()
Check("login purges expired trash", QuillDB.notes[trashed] == nil)
Check("invalid deletion marks are cleared", ns.GetNotebook(childBook) ~= nil)

local pinned = assert(ns.CreateNote("Pinned", "", childBook))
Check("pinning hidden note is rejected", ns.SetNotePinned(9999, true) == nil)
assert(ns.SetNotePinned(pinned, true))
local tree = ns.TreeEntries("", {})
Check("favorites section comes first", tree[1].kind == "favorites" and tree[2].id == pinned and tree[2].favorite)
local inNotebook = false
for index = 3, #tree do
	if tree[index].id == pinned and not tree[index].favorite then inNotebook = true end
end
Check("favorite note also stays in its notebook", inNotebook)
tree = ns.TreeEntries("", { favorites = true })
Check("collapsed favorites hide their notes", tree[1].kind == "favorites" and tree[2].id ~= pinned)
Check("filter matches favorites", ns.TreeEntries("Pinned", { favorites = true })[2].id == pinned)
Check("filter without favorite matches hides section", ns.TreeEntries("nothing matches", {})[1].kind ~= "favorites")
ns.DeleteNote(pinned)
Check("deleted favorites leave the section", ns.TreeEntries("", {})[1].kind ~= "favorites")
ns.RestoreNote(pinned)
assert(ns.SetNotePinned(pinned, false))
Check("unpinned notes leave favorites", ns.TreeEntries("", {})[1].kind ~= "favorites" and QuillDB.notes[pinned].pinned == nil)
QuillDB.notes[pinned].pinned = "yes"
QuillDB.settings.popouts = "broken"
Init()
Check("invalid pin and window data are cleared", QuillDB.notes[pinned].pinned == nil and QuillDB.settings.popouts == nil)
print(("%d core tests passed"):format(count))
