local _, ns = ...

if GetLocale() ~= "deDE" then
	return
end

local L = ns.L

-- Core
L["Untitled"] = "Ohne Titel"
L["A note named \"%s\" already exists in this notebook."] = "In diesem Notizbuch gibt es bereits eine Notiz namens „%s“."
L["%d notes with a duplicate name in the same notebook were renamed."] = "%d Notizen mit doppeltem Namen im selben Notizbuch wurden umbenannt."
L["The notebook could not be opened – %s"] = "Das Notizbuch konnte nicht geöffnet werden – %s"
L["Created note \"%s\"."] = "Notiz „%s“ erstellt."
L["Commands:"] = "Befehle:"
L["/quill – open or close the notebook"] = "/quill – Notizbuch öffnen oder schließen"
L["/quill new [title] – create a note and edit it"] = "/quill new [Titel] – Notiz erstellen und bearbeiten"
L["Click to open or close the notebook."] = "Klicken, um das Notizbuch zu öffnen oder zu schließen."

-- UI
L["Options"] = "Einstellungen"
L["New note"] = "Neue Notiz"
L["Delete"] = "Löschen"
L["Edit"] = "Bearbeiten"
L["Read"] = "Lesen"
L["Title"] = "Titel"
L["Write in Markdown …"] = "In Markdown schreiben …"
L["Last changed: %s"] = "Zuletzt geändert: %s"
L["Move the note \"%s\" to the trash?"] = "Notiz „%s“ in den Papierkorb verschieben?"
L["No note selected. Create one with \"New note\"."] = "Keine Notiz ausgewählt. Erstelle eine mit „Neue Notiz“."
L["This note is empty. Switch to edit mode to write it."] = "Diese Notiz ist leer. Wechsle zum Bearbeiten, um sie zu schreiben."
L["General"] = "Allgemein"
L["New notebook"] = "Neues Notizbuch"
L["Manage"] = "Verwalten"
L["Manage notebook"] = "Notizbuch verwalten"
L["Notebook name"] = "Name des Notizbuchs"
L["Parent notebook"] = "Übergeordnetes Notizbuch"
L["Top level"] = "Oberste Ebene"
L["Global"] = "Global"
L["Character only"] = "Nur dieser Charakter"
L["Only available to this character"] = "Nur für diesen Charakter verfügbar"
L["Notes in a character notebook are always character-only."] = "Notizen in einem Charakter-Notizbuch sind immer nur für diesen Charakter sichtbar."
L["This note is not available."] = "Diese Notiz ist nicht verfügbar."
L["Changing visibility also changes all notes and subnotebooks. Character notebooks cannot contain global notebooks."] = "Eine Änderung der Sichtbarkeit gilt auch für alle Notizen und Unternotizbücher. Charakter-Notizbücher können keine globalen Notizbücher enthalten."
L["Save"] = "Speichern"
L["Cancel"] = "Abbrechen"
L["Move note"] = "Notiz verschieben"
L["This notebook is not available."] = "Dieses Notizbuch ist nicht verfügbar."
L["Enter a notebook name."] = "Gib einen Namen für das Notizbuch ein."
L["A notebook cannot be placed inside itself or its children."] = "Ein Notizbuch kann nicht in sich selbst oder seine Unternotizbücher verschoben werden."
L["The default notebook must remain global and at the top level."] = "Das Standardnotizbuch muss global und auf der obersten Ebene bleiben."
L["The default notebook cannot be deleted."] = "Das Standardnotizbuch kann nicht gelöscht werden."
L["The current character is not available yet."] = "Der aktuelle Charakter ist noch nicht verfügbar."
L["This notebook contains another character's notebooks or notes."] = "Dieses Notizbuch enthält Notizbücher oder Notizen eines anderen Charakters."
L["The note or destination notebook is not available."] = "Die Notiz oder das Zielnotizbuch ist nicht verfügbar."
L["Move notebook \"%s\" with all notes and subnotebooks to the trash?"] = "Notizbuch „%s“ mit allen Notizen und Unternotizbüchern in den Papierkorb verschieben?"
L["An invalid notebook parent was reset."] = "Eine ungültige Notizbuch-Zuordnung wurde zurückgesetzt."
L["/quill options – open the options panel"] = "/quill options – Einstellungen öffnen"
L["Left-click: toggle the window"] = "Linksklick: Fenster öffnen oder schließen"
L["Right-click: open the options"] = "Rechtsklick: Einstellungen öffnen"
L["The options panel is not available in this client."] = "Die Einstellungen sind in diesem Client nicht verfügbar."
L["The options cannot be opened in combat."] = "Die Einstellungen können im Kampf nicht geöffnet werden."
L["Reset window size and position"] = "Fenstergröße und Position zurücksetzen"
L["Restore the default window size and center it on the screen. Notes and notebooks are not changed."] = "Stellt die Standardgröße wieder her und zentriert das Fenster. Notizen und Notizbücher bleiben unverändert."
L["Window size and position reset."] = "Fenstergröße und Position zurückgesetzt."
L["Links"] = "Links"
L["Click the address and press Ctrl+C to copy it. The game cannot open a browser by itself."] = "Klicke die Adresse an und kopiere sie mit Strg+C. Das Spiel kann selbst keinen Browser öffnen."
L["Report a bug"] = "Fehler melden"
L["Found a bug or have an idea? Please open an issue on GitHub and describe what happened."] = "Einen Fehler gefunden oder eine Idee? Bitte erstelle ein Issue auf GitHub und beschreibe, was passiert ist."
L["Close"] = "Schließen"

L["Choose linked note"] = "Verknüpfte Notiz auswählen"
L["Create the missing note \"%s\"?"] = "Die fehlende Notiz „%s“ erstellen?"
L["Click to create this note."] = "Klicken, um diese Notiz zu erstellen."
L["Filter by tag: %s"] = "Nach Tag filtern: %s"
L["Filter by tag"] = "Nach Tag filtern"
L["All notes"] = "Alle Notizen"
L["No tags yet"] = "Noch keine Tags"
L["Tag menu is not available in this client. Type tag:name in the search box."] = "Das Tag-Menü ist in diesem Client nicht verfügbar. Gib tag:name in die Suche ein."
L["Search: tag:raid status:open"] = "Suche: tag:raid status:offen"
L["Properties"] = "Eigenschaften"
L["Show or hide properties"] = "Eigenschaften ein- oder ausblenden"
L["Notebook color"] = "Notizbuchfarbe"
L["Custom color"] = "Eigene Farbe"
L["Default color"] = "Standardfarbe"
L["Invalid color."] = "Ungültige Farbe."
L["An invalid notebook color was reset."] = "Eine ungültige Notizbuchfarbe wurde zurückgesetzt."
L["The color picker is not available in this client."] = "Die Farbauswahl ist in diesem Client nicht verfügbar."
L["Theme"] = "Design"
L["Standard"] = "Standard"
L["Changes Quill and its dialogs for all characters."] = "Ändert Quill und seine Dialogfenster für alle Charaktere."
L["Background color"] = "Hintergrundfarbe"
L["Choose color"] = "Farbe auswählen"
L["Used by the Custom color theme. Text contrast adjusts automatically. The opacity applies to every theme."] = "Wird vom Design „Eigene Farbe“ verwendet. Der Textkontrast passt sich automatisch an. Die Deckkraft gilt für alle Designs."
L["Background opacity"] = "Hintergrund-Deckkraft"
L["Transparency of the Quill window and its dialogs in every theme. Text and borders stay opaque."] = "Transparenz des Quill-Fensters und seiner Dialoge in allen Designs. Text und Rahmen bleiben deckend."
L["Unknown theme."] = "Unbekanntes Design."
L["An invalid theme was reset."] = "Ein ungültiges Design wurde zurückgesetzt."
L["An invalid background color was reset."] = "Eine ungültige Hintergrundfarbe wurde zurückgesetzt."
L["Invalid metadata on line %d: %s"] = "Ungültige Eigenschaften in Zeile %d: %s"
L["Duplicate metadata property: %s"] = "Doppelte YAML-Eigenschaft: %s"
L["Unclosed metadata frontmatter"] = "Der YAML-Eigenschaftenblock ist nicht abgeschlossen"
L["Invalid metadata value"] = "Ungültiger Eigenschaftswert"
L["Invalid filter: malformed quoted token"] = "Ungültiger Filter: fehlerhafte Anführungszeichen"
L["Invalid filter: unsupported escape"] = "Ungültiger Filter: nicht unterstützte Maskierung"
L["Invalid filter: unclosed quote"] = "Ungültiger Filter: Anführungszeichen nicht geschlossen"
L["Invalid filter: empty value for %s"] = "Ungültiger Filter: leerer Wert für %s"
L["Invalid filter: empty text"] = "Ungültiger Filter: leerer Text"
L["empty scalar"] = "leerer Wert"
L["tags must start with #"] = "Tags müssen mit # beginnen"
L["characters after quoted scalar"] = "Zeichen hinter dem abgeschlossenen Textwert"
L["unsupported string escape"] = "nicht unterstützte Textmaskierung"
L["control character in scalar"] = "Steuerzeichen im Wert"
L["unclosed quoted scalar"] = "Anführungszeichen im Textwert nicht geschlossen"
L["null is unsupported"] = "null wird nicht unterstützt"
L["non-finite number"] = "nicht endliche Zahl"
L["non-decimal number is unsupported"] = "nur Dezimalzahlen werden unterstützt"
L["unsupported YAML scalar"] = "nicht unterstützter YAML-Wert"
L["unclosed inline list"] = "Liste in eckigen Klammern nicht geschlossen"
L["comment inside inline list"] = "Kommentar innerhalb einer Liste in eckigen Klammern"
L["empty inline list item"] = "leerer Listeneintrag"
L["expected a flat property or indented list item"] = "eine einfache Eigenschaft oder ein eingerückter Listeneintrag wird erwartet"

-- Trash, favorites and note windows
L["Decrease text size"] = "Text verkleinern"
L["Increase text size"] = "Text vergrößern"
L["Favorites"] = "Favoriten"
L["Add to favorites"] = "Zu Favoriten hinzufügen"
L["Remove from favorites"] = "Aus Favoriten entfernen"
L["Right-click for more actions"] = "Rechtsklick für weitere Aktionen"
L["Open in small window"] = "In kleinem Fenster öffnen"
L["Lock window"] = "Fenster sperren"
L["Unlock window"] = "Fenster entsperren"
L["A locked window cannot be moved and lets clicks through."] = "Ein gesperrtes Fenster lässt sich nicht verschieben und lässt Klicks durch."
L["Trash"] = "Papierkorb"
L["Note"] = "Notiz"
L["Notebook"] = "Notizbuch"
L["Restore"] = "Wiederherstellen"
L["Delete permanently"] = "Endgültig löschen"
L["Empty trash"] = "Papierkorb leeren"
L["The trash is empty."] = "Der Papierkorb ist leer."
L["%d days left"] = "noch %d Tage"
L["Entries are deleted permanently after %d days."] = "Einträge werden nach %d Tagen endgültig gelöscht."
L["Permanently delete \"%s\"? This cannot be undone."] = "„%s“ endgültig löschen? Das lässt sich nicht rückgängig machen."
L["Permanently delete everything in the trash? This cannot be undone."] = "Alles im Papierkorb endgültig löschen? Das lässt sich nicht rückgängig machen."
L["This note is not in the trash."] = "Diese Notiz ist nicht im Papierkorb."
L["This notebook is not in the trash."] = "Dieses Notizbuch ist nicht im Papierkorb."
L["This entry is not in the trash."] = "Dieser Eintrag ist nicht im Papierkorb."
L["/quill trash – open the trash"] = "/quill trash – Papierkorb öffnen"

L.WELCOME_TITLE = "Willkommen bei Quill"
L.WELCOME_TEXT = [==[
# Willkommen bei Quill

Quill ist dein Notizbuch im Spiel für Raidpläne, Charaktertagebücher, Checklisten, Erinnerungen und alles andere, was du griffbereit haben willst. Schreibe im Modus **Bearbeiten** in Markdown; wechsle zu **Lesen** für die formatierte Notiz.

## Schnellstart

- `/quill` öffnet oder schließt Quill.
- `/quill new [Titel]` erstellt eine Notiz und öffnet sie zum Bearbeiten.
- `/quill trash` öffnet den Papierkorb; `/quill options` öffnet die Einstellungen; `/quill help` listet alle Befehle auf.
- **Neue Notiz** legt eine Notiz im ausgewählten Notizbuch an. Ihr Titel lautet zunächst „Ohne Titel“ und ist markiert, sodass du ihn direkt überschreiben kannst.
- WoW speichert Änderungen beim Ausloggen, Beenden oder bei `/reload`. Bei einem Absturz des Spiels können Änderungen seit dem letzten Speichern verloren gehen.

## Notizen und Notizbücher

- **Bearbeiten** und **Lesen** wechseln zwischen Markdown-Quelltext und formatierter Ansicht. Quill merkt sich den zuletzt genutzten Modus.
- Notiztitel sind innerhalb eines Notizbuchs eindeutig; Leerzeichen am Rand und Groß-/Kleinschreibung zählen nicht. Ist ein Titel schon vergeben, wird er rot und nicht gespeichert.
- **Neues Notizbuch** legt ein verschachteltes Notizbuch an. Wähle **Oberste Ebene**, um es neben den anderen anzulegen. **Verwalten** benennt ein Notizbuch um, ändert das übergeordnete Notizbuch, setzt seine Farbe oder macht es nur für deinen aktuellen Charakter sichtbar.
- **Notiz verschieben** ändert das Notizbuch einer Notiz. **Nur dieser Charakter** macht die Notiz für den aktuellen Charakter privat. Notizen in einem charakterbezogenen Notizbuch sind immer privat.
- Charakterbezogene Notizen sind für andere Charaktere in Quill ausgeblendet, aber weder verschlüsselt noch in einer eigenen Datei gespeichert.
- Ein Klick auf ein Notizbuch wählt es aus und klappt seinen Inhalt auf oder zu. Die Suche findet auch Notizen in zugeklappten Notizbüchern.

## Finden, verknüpfen und ordnen

- Das Suchfeld durchsucht Titel und Text. Probiere `tag:raid`, `status:open` oder `tag:raid status:open`; mehrere Filter müssen alle zutreffen.
- Füge Tags im Text mit `#raid` oder verschachtelt wie `#raid/tank` hinzu. Ein Klick auf einen Tag filtert die Notizliste. Die Schaltfläche **#** neben der Suche listet die Tags der sichtbaren Notizen auf.
- Einfache YAML-Eigenschaften stehen ganz am Anfang einer Notiz. Eine Zeile mit nur `---` öffnet und schließt den Block:

  ```yaml
  ---
  status: open
  level: 80
  tags: [raid, tank]
  ---
  ```

  Suche nach einer Eigenschaft mit `status:open` oder `level:80`. Unterstützt werden Text, endliche Zahlen, true/false und Listen. Verschachtelte YAML-Objekte und mehrzeilige Werte werden nicht unterstützt.
- Schreibe `[[Andere Notiz]]` für einen Verweis auf eine Notiz oder `[[Andere Notiz|Linktext]]` für einen anderen angezeigten Text. Klicke den Verweis im Modus Lesen an. Passt ein Titel zu mehreren Notizen, lässt Quill dich wählen; ein fehlendes Ziel kann nach Bestätigung angelegt werden.
- Ein Klick auf den Stern neben dem Titel fügt eine Notiz den **Favoriten** hinzu. Favoriten stehen über den Notizbüchern und bleiben in ihrem ursprünglichen Notizbuch. Ein Klick auf die Überschrift Favoriten klappt sie zu.
- Ein Rechtsklick auf eine Notiz in der Liste bietet **Zu Favoriten hinzufügen**, **In kleinem Fenster öffnen** und **Löschen**.

## Markdown im Modus Lesen

Diese Zeichen verwendest du im Modus Bearbeiten:

| Eingabe | Ergebnis |
| --- | --- |
| `# Überschrift` bis `###### Überschrift` | Sechs Überschriftengrößen |
| `**fett**`, `*kursiv*`, `~~durchgestrichen~~` | Fett, kursiv und durchgestrichen |
| `- Punkt`, `1. Punkt`, eingerückte Punkte | Aufzählungen, nummerierte und verschachtelte Listen |
| `- [ ] Aufgabe`, `- [x] Aufgabe` | Checklisten |
| `> zitierter Text` | Ein Zitat |
| `` `Code im Text` `` oder Blöcke mit drei Backticks | Code im Text oder als Block |
| `---` | Eine horizontale Linie |
| `| A | B |` mit einer Trennzeile `| --- | --- |` | Eine Tabelle |
| `<font color="#1eff00">grüner Text</font>` | Farbiger Text |

Für eine Tabelle ist die Trennzeile erforderlich. Die Spalten teilen sich die verfügbare Breite und Zellen brechen um.
HTML wird grundsätzlich nicht dargestellt; `<font color>` ist eine kleine unterstützte Erweiterung. Sie akzeptiert
`#RGB`, `#RRGGBB` und die üblichen CSS-Farbnamen.

## Spielverweise und kleine Fenster

- Um einen Gegenstands-, Quest- oder anderen WoW-Verweis einzufügen, klicke in den Editor und dann mit **Umschalt** auf den Verweis im Chat oder einem anderen Spielfenster. Im Modus Lesen sind unterstützte Verweise anklickbar und zeigen beim Darüberfahren einen Tooltip.
- Klicke auf das Notizsymbol neben dem Favoritenstern oder wähle **In kleinem Fenster öffnen**, um eine schreibgeschützte Kopie anzuzeigen. Öffne mehrere Notizen gleichzeitig, etwa für einen Bossplan oder als Nachschlagehilfe beim Spielen.
- Kleine Fenster lassen sich verschieben und in der Größe ändern. Größe, Position und Sperre werden pro Notiz gespeichert; nach `/reload` öffnen sie sich nicht automatisch wieder.
- Sperre ein kleines Fenster, damit es sich nicht mehr verschieben oder skalieren lässt und Klicks zum Spiel durchgehen. Schließen und Sperre bleiben anklickbar. Verweise in der Notiz sind nutzbar, solange das Fenster entsperrt ist.
- **A-** / **A+** ändern die Textgröße im Hauptfenster und in jedem kleinen Fenster unabhängig voneinander, von 75 % bis 200 %. Die Textgrößen-Schaltflächen eines kleinen Fensters sind ausgeblendet, solange es gesperrt ist.
- **Strg+Z** macht Änderungen rückgängig, **Strg+Y** (oder **Strg+Umschalt+Z**) stellt sie wieder her. Tippen mit Pausen unter einer Sekunde zählt als ein Schritt. Jede Notiz behält bis zu 100 Schritte bis zum nächsten `/reload`.

## Papierkorb und Aussehen

- **Löschen** fragt nach und verschiebt eine Notiz in den Papierkorb. Ein gelöschtes Notizbuch wandert zusammen mit seinen Notizen und Unternotizbüchern in den Papierkorb.
- Einträge lassen sich innerhalb von 7 Tagen aus dem Papierkorb wiederherstellen. Du kannst einen Eintrag auch endgültig löschen oder den Papierkorb leeren; beides musst du bestätigen. Abgelaufene Einträge werden bei einem späteren Login entfernt.
- Öffne die Einstellungen mit dem Zahnrad oder `/quill options`. Wähle das Standard-Design oder eine eigene Farbe und die Hintergrund-Deckkraft; Text und Schaltflächen bleiben lesbar. Die Einstellungen bieten außerdem das Zurücksetzen der Fensterposition und einen Link zum Melden von Fehlern.
- Das Add-on-Fach neben der Minikarte öffnet Quill mit Linksklick und die Einstellungen mit Rechtsklick.

## Deine Notizen sichern

Quill speichert Notizen in den lokalen gespeicherten Variablen von WoW. Retail und Classic haben getrennte Daten.
WoW schreibt Änderungen beim Ausloggen, Beenden und bei `/reload` auf die Festplatte; schließe das Spiel, bevor du
eine Sicherung zurückspielst, damit sie nicht überschrieben wird. „Nur dieser Charakter“ dient der Ordnung,
nicht der Verschlüsselung.
]==]
