// Ranking and sections for the palette, kept free of chrome.* so `node test.js` can run it.
const QuickSearch = (() => {
  const SECTIONS = [
    { id: "tab", title: "Open tabs" },
    { id: "saved", title: "Saved" },
    { id: "closed", title: "Recently closed" },
    { id: "history", title: "Recently opened", searching: "History" },
    { id: "bookmark", title: "Bookmarks" },
  ];
  const CAPS = {
    empty: { tab: 50, saved: 20, closed: 5, history: 10, bookmark: 0 },
    search: { tab: 50, saved: 20, closed: 5, history: 12, bookmark: 8 },
    only: 200,
  };
  const PREFIXES = {
    t: "tab", tab: "tab", tabs: "tab", s: "saved", saved: "saved", alias: "saved",
    c: "closed", closed: "closed", h: "history", history: "history",
    b: "bookmark", bm: "bookmark", bookmark: "bookmark", bookmarks: "bookmark",
  };
  // Who keeps a url seen twice. Tabs and saved aliases always show.
  const PRIORITY = ["tab", "saved", "closed", "bookmark", "history"];

  // "bm: foo" -> { kind: "bookmark", terms: ["foo"] }
  function parse(query) {
    let kind = null, rest = query.trim();
    const m = rest.match(/^(\w+):\s*/);
    if (m && PREFIXES[m[1].toLowerCase()]) { kind = PREFIXES[m[1].toLowerCase()]; rest = rest.slice(m[0].length); }
    return { kind, terms: rest.toLowerCase().split(/\s+/).filter(Boolean) };
  }

  const bare = url => url.replace(/^[a-z-]+:\/\/(www\.)?/i, "");
  const host = url => { try { return new URL(url).hostname.replace(/^www\./, ""); } catch { return ""; } };

  // Every term must hit the title, url or folder; word starts and the host count more.
  function score(item, terms, now) {
    const title = (item.title || "").toLowerCase(), url = bare(item.url || "").toLowerCase(), h = host(item.url || "").toLowerCase();
    const folder = (item.folder || "").toLowerCase();
    let s = 0;
    for (const t of terms) {
      const ti = title.indexOf(t);
      if (ti === 0 || (ti > 0 && /[\s\-_/.:|([]/.test(title[ti - 1]))) s += 4;
      else if (ti > 0) s += 2;
      else if (h.startsWith(t)) s += 4;
      else if (h.includes(t)) s += 3;
      else if (url.includes(t)) s += 1;
      else if (folder.includes(t)) s += 1;
      else return -1;
    }
    if (item.kind === "history") {
      s += Math.min(3, Math.log2(1 + (item.visits || 0)) / 2);
      const days = (now - (item.time || 0)) / 864e5;
      s += days < 1 ? 2 : days < 7 ? 1 : 0;
    }
    return s;
  }

  function dedupe(items) {
    const seen = new Set(), out = [];
    const ordered = [...items].sort((a, b) => PRIORITY.indexOf(a.kind) - PRIORITY.indexOf(b.kind));
    for (const item of ordered) {
      if (item.kind !== "tab" && item.kind !== "saved" && seen.has(item.url)) continue;
      seen.add(item.url);
      out.push(item);
    }
    return out;
  }

  function sortRecent(pool, kind) {
    if (kind === "saved") return [...pool].sort((a, b) => a.title.localeCompare(b.title));
    return [...pool].sort((a, b) => (b.time || 0) - (a.time || 0));
  }

  // [{ id, title, items }] in the fixed order, empty sections left out.
  function sections(items, query, { now = Date.now() } = {}) {
    const { kind, terms } = parse(query);
    const searching = terms.length > 0;
    return SECTIONS.filter(s => !kind || s.id === kind).map(s => {
      const pool = items.filter(i => i.kind === s.id);
      const cap = kind ? CAPS.only : (searching ? CAPS.search : CAPS.empty)[s.id];
      const list = !searching ? sortRecent(pool, s.id) : pool
        .map(item => ({ item, s: score(item, terms, now) }))
        .filter(x => x.s >= 0)
        .sort((a, b) => b.s - a.s || (b.item.time || 0) - (a.item.time || 0))
        .map(x => x.item);
      return { id: s.id, title: searching && s.searching ? s.searching : s.title, items: list.slice(0, cap) };
    }).filter(s => s.items.length);
  }

  // What Enter does with text that matches nothing: a url, or a web search.
  function fallback(query) {
    const q = query.trim();
    if (!q || parse(q).kind) return null;
    if (/^[a-z][a-z0-9+.-]*:\/\/\S+$/i.test(q)) return { kind: "url", url: q };
    if (/^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?(\/\S*)?$/i.test(q)) return { kind: "url", url: "http://" + q };
    if (/^[\w-]+(\.[\w-]+)*\.[a-z]{2,}(:\d+)?(\/\S*)?$/i.test(q)) return { kind: "url", url: "https://" + q };
    return { kind: "web", text: q };
  }

  // The ⌘K list for one item: [{ id, label, keys }].
  function actions(item, { saved = false, openTab = false } = {}) {
    if (!item) return [];
    const k = item.kind, out = [];
    const primary = k === "tab" || openTab ? "Switch to tab" : k === "closed" ? "Restore" : k === "web" ? "Search the web" : "Open";
    out.push({ id: "open", label: primary, keys: "↵" });
    out.push({ id: "new", label: "Open in new tab", keys: "⌘↵" });
    out.push({ id: "here", label: "Open in current tab", keys: "⇧↵" });
    if (k === "web") return out;
    out.push({ id: "copy", label: "Copy link", keys: "⌘⇧C" });
    if (k !== "url") out.push({ id: "markdown", label: "Copy as Markdown", keys: "⌘⇧M" });
    out.push({ id: "alias", label: saved || k === "saved" ? "Rename alias" : "Save as alias", keys: "⌘S" });
    if (saved || k === "saved") out.push({ id: "unsave", label: "Remove from saved", keys: "" });
    if (k === "tab") out.push({ id: "close", label: "Close tab", keys: "⌃⌫" });
    if (k === "bookmark") out.push({ id: "unbookmark", label: "Remove bookmark", keys: "" });
    if (k === "history") out.push({ id: "forget", label: "Delete from history", keys: "" });
    return out;
  }

  // Why a url can't be read as Markdown, or null when it can.
  function markdownBlocker(url) {
    let u;
    try { u = new URL(url); } catch { return "This item has no web address"; }
    if (u.hostname === "chromewebstore.google.com" || (u.hostname === "chrome.google.com" && u.pathname.startsWith("/webstore")))
      return "Chrome keeps extensions out of the Web Store";
    if (u.protocol === "file:") return "Local files can't be copied as Markdown";
    if (!/^https?:$/.test(u.protocol)) return `Chrome keeps extensions out of ${u.protocol.slice(0, -1)}: pages`;
    if (/\.pdf$/i.test(u.pathname)) return "PDFs can't be copied as Markdown";
    return null;
  }

  function filterActions(list, query) {
    const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
    return list.filter(a => terms.every(t => a.label.toLowerCase().includes(t)));
  }

  return { SECTIONS, parse, score, dedupe, sections, fallback, actions, markdownBlocker, filterActions };
})();

if (typeof module !== "undefined") module.exports = QuickSearch;
