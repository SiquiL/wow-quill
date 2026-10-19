local _, ns = ...

-- The English text is the key, so a missing translation falls back to English
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})

local L = ns.L

L.WELCOME_TITLE = "Welcome to Quill"
L.WELCOME_TEXT = [==[
# Welcome to Quill

Quill is your in-game notebook for raid plans, character journals, checklists, reminders and anything else you want to keep close. Write in Markdown in **Edit** mode; switch to **Read** for the formatted note.

## Quick start

- `/quill` opens or closes Quill.
- `/quill new [title]` creates a note and opens it for editing.
- `/quill trash` opens the trash; `/quill options` opens settings; `/quill help` lists commands.
- Click **New note** to make a note in the selected notebook. Its title starts as "Untitled"; the title is selected so you can type over it.
- Changes are saved by WoW on logout, exit or `/reload`. A game crash can lose changes since the last save.

## Notes and notebooks

- **Edit** and **Read** switch between the Markdown source and formatted view. Quill remembers the last mode.
- Note titles are unique within each notebook, ignoring surrounding spaces and letter case. If a title is already taken, the title turns red and is not saved.
- Use **New notebook** for a nested notebook. Choose **Top level** to create one alongside the others. **Manage** renames a notebook, changes its parent, sets its color, or makes it available only to your current character.
- **Move note** changes a note's notebook. **Character only** keeps that note private to the current character. Notes in a character-only notebook are always private.
- Character-only notes are hidden from other characters in Quill, but are not encrypted or stored in a separate file.
- Click a notebook to select it and expand or collapse its contents. Searching also finds notes in collapsed notebooks.

## Find, connect and organize

- The search box matches note titles and text. Try `tag:raid`, `status:open` or `tag:raid status:open`; multiple filters must all match.
- Add tags in text with `#raid` or nested tags like `#raid/tank`. Click a tag to filter the note list. The **#** button beside search lists tags from visible notes.
- Add flat YAML properties at the very start of a note. Use `---` on a line by itself to open and close the block:

  ```yaml
  ---
  status: open
  level: 80
  tags: [raid, tank]
  ---
  ```

  Search for a property with `status:open` or `level:80`. Supported values are text, finite numbers, true/false and lists. Nested YAML objects and multiline values are not supported.
- Write `[[Another note]]` to link to a note, or `[[Another note|link text]]` to show different text. Click the link in Read mode. If a title matches several notes, Quill lets you choose; a missing target can be created after confirmation.
- Click the star beside the title to add a note to **Favorites**. Favorites appear above the notebooks and remain in their original notebook. Click the Favorites heading to collapse it.
- Right-click a note in the list for **Add to favorites**, **Open in small window** or **Delete**.

## Markdown in Read mode

Use these markers in Edit mode:

| Type this | To get |
| --- | --- |
| `# Heading` through `###### Heading` | Six heading sizes |
| `**bold**`, `*italic*`, `~~struck~~` | Bold, italic and strikethrough |
| `- item`, `1. item`, indented items | Bulleted, numbered and nested lists |
| `- [ ] task`, `- [x] task` | Checklists |
| `> quoted text` | A quote |
| `` `inline code` `` or triple-backtick fences | Inline or block code |
| `---` | A horizontal rule |
| `| A | B |` with a `| --- | --- |` separator | A table |
| `<font color="#1eff00">green text</font>` | Colored text |

For a table, the separator is required. Columns share the available width and cells wrap.
HTML is not generally rendered; `<font color>` is a small supported extension. It accepts
`#RGB`, `#RRGGBB` and standard CSS color names.

## Game links and small windows

- To insert an item, quest or other native WoW link, click in the editor and **Shift-click** the link in chat or another game window. In Read mode, supported links can be clicked and show a game tooltip on hover.
- Click the note icon beside the favorite star, or choose **Open in small window**, to show a read-only copy. Open several notes at once for a boss plan or reference during play.
- Small windows can be dragged and resized. Their size, position and lock state are remembered per note; they do not reopen automatically after `/reload`.
- Lock a small window to stop it moving or resizing and let clicks pass through to the game. The close and lock controls remain clickable. Links in the note are interactive while the window is unlocked.
- **A-** / **A+** change text size in the main window and each small window independently, from 75% to 200%. A small window's text-size buttons are hidden while it is locked.
- Press **Ctrl+Z** to undo and **Ctrl+Y** (or **Ctrl+Shift+Z**) to redo edits. Typing with pauses shorter than a second is grouped into one step. Each note keeps up to 100 steps until the next `/reload`.

## Trash and appearance

- **Delete** asks for confirmation and moves a note to the trash. Deleting a notebook moves it and its notes and subnotebooks together.
- Restore an item from the trash within 7 days. You can also delete an item permanently or empty the trash; both require confirmation. Expired items are removed at a later login.
- Open settings with the gear button or `/quill options`. Choose the standard or custom-color theme and background opacity; text and buttons stay readable. Settings include a window-position reset and a bug-report link.
- The addon compartment beside the minimap opens Quill on left-click and settings on right-click.

## Keep your notes safe

Quill stores notes in WoW's local saved variables. Retail and Classic keep separate data.
WoW writes changes to disk on logout, exit and `/reload`; closing the game before restoring
a backup helps prevent it overwriting that backup. Character-only visibility is organization,
not encryption.
]==]
