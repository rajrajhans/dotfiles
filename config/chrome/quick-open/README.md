# Quick Open (Chrome)

One search bar for open tabs, saved aliases, recently closed tabs, history and bookmarks, on ⌘⇧O
(or the toolbar icon). It opens centered over the page. On pages Chrome keeps scripts out of
(chrome:// pages, the New Tab page, the Web Store) it opens as a small centered window instead.

Install once: `chrome://extensions` → Developer mode → Load unpacked → pick this folder.
The key is the action's own shortcut ("Activate the extension" at `chrome://extensions/shortcuts`).
Chrome sets it only on a fresh install: a reload that changes `commands` can drop it, so set it
there again. After editing files here, press the reload button on the extension's card. It has no site access beyond the tab you open it on
(`activeTab`); Copy as Markdown asks Chrome for one site at a time when it needs another.

Sections, in order: Open tabs (by last use, the current tab last), Saved, Recently closed,
Recently opened (History when searching), Bookmarks (when searching). `tab:`, `s:`, `c:`,
`h:` and `bm:` show one section. Text that matches nothing opens as an address or searches
with the default engine.

| Key | Does |
| --- | --- |
| ↵ | switch to the tab; anything already open switches to it; else a new tab; a closed tab is restored |
| ⌘↵ | open in a new tab (any item) |
| ⇧↵ | open in the current tab |
| ⌘1–⌘9 | switch to that open tab |
| ⌘K | actions for the item: copy link, copy as Markdown, save or rename alias, remove from saved, close tab, remove bookmark, delete from history |
| ⌘S | save the item under an alias |
| ⌘⇧C | copy link |
| ⌘⇧M | copy the page as Markdown |
| ⌃⌫ | close the selected tab |
| esc | back, or close |

Aliases are bookmarks in "Other bookmarks / Quick Open" (title = alias), so they sync and can be
edited in the bookmark manager. ⌘T also opens in a new tab if Chrome passes it on, but Chrome
usually keeps ⌘T, ⌘W and ⌘N for itself, so ⌘↵ is the key to rely on.

Copy as Markdown gives `# Title`, a `Source:` line, then the article (Readability picks it,
Turndown writes it, GFM tables kept, links and images absolute). A page open in a tab is read
from the tab as you see it, signed in and rendered; anything else is fetched with your cookies.
Reading a site other than the tab the bar was opened on needs that site's access once (Chrome
asks; the bar waits). chrome:// pages, the Web Store, local files and PDFs can't be copied.

Vendored in `vendor/` (licenses alongside): Readability 0.6.0 (`@mozilla/readability`,
Apache-2.0), Turndown 7.2.5 (MIT), turndown-plugin-gfm 1.0.2 (MIT).

Tests: `node test.js` (search, sections, actions).
