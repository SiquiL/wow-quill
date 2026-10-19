# Roadmap

Ideas for releases after 1.0.0.

## Sharing and data

- **Export and import**: copy a note or a whole notebook as Markdown with YAML properties and
  paste it back in. Allows sharing guides with guild or group, moving notes between accounts and
  importing from Obsidian.
- **Large data test**: check that search, list and read mode stay smooth with several hundred notes
  and very long notes.

## Usability

- **Key binding**: a configurable hotkey to open and close Quill.
- **Sorting**: sort the note list by title, last change or a property value.
- **Timestamps**: show created and last changed dates in the list and allow filtering by them.
- **Filter comparisons**: numeric and date comparisons such as `ilvl:>480` or `date:>=2026-10-01`.
- **More languages**: at least the interface strings for frFR, esES and others.

## Release

- **Game versions**: check that the interface numbers in `Quill.toc` cover every intended client
  (Retail, Classic variants) and test in Classic if supported.
- **Release automation**: a GitHub Action that builds the zip on tags and uploads it to the
  GitHub release, CurseForge or Wago.
