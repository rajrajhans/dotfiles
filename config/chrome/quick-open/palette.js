const params = new URLSearchParams(location.search);
const MODE = params.get("mode") === "overlay" ? "overlay" : "window";
const ORIGIN = { tab: Number(params.get("tab")), win: Number(params.get("win")) };
const SELF = chrome.runtime.getURL("palette.html");
const SAVED_FOLDER = "Quick Open";
const MAC = /Mac/.test(navigator.platform);

const $q = document.getElementById("q"), $list = document.getElementById("list"), $scroll = document.getElementById("scroll");
const $footer = document.getElementById("footer"), $chip = document.getElementById("chip");

let base = [], hist = [], items = [], savedByUrl = new Map(), tabsByUrl = new Map();
let rows = [], sel = 0, numbered = [];
let mode = "list", listQuery = "", listSel = 0, target = null, flashTimer = null, busy = false;


const otherFolder = root => root.children.find(n => n.folderType === "other") ?? root.children.find(n => n.id === "2") ?? root.children[1] ?? root.children[0];

async function load() {
  const [tabs, [root], closed] = await Promise.all([
    chrome.tabs.query({}), chrome.bookmarks.getTree(), chrome.sessions.getRecentlyClosed({ maxResults: 25 }),
  ]);
  const own = url => !url || url.startsWith(SELF);
  const blank = url => own(url) || url === "about:blank" || url.startsWith("chrome://newtab");
  const tabItems = tabs.filter(t => !own(t.url || t.pendingUrl)).map(t => ({
    kind: "tab", id: t.id, windowId: t.windowId, title: t.title || t.url, url: t.url || t.pendingUrl, discarded: t.discarded,
    time: t.id === ORIGIN.tab ? 0 : t.lastAccessed || 1,
  }));
  const savedFolder = otherFolder(root).children?.find(n => !n.url && n.title === SAVED_FOLDER);
  const saved = [], bookmarks = [];
  (function walk(nodes, path) {
    for (const n of nodes) {
      if (n === savedFolder) {
        for (const c of n.children || []) if (c.url) saved.push({ kind: "saved", bookmarkId: c.id, title: c.title || c.url, url: c.url, time: c.dateAdded });
        continue;
      }
      if (n.url) bookmarks.push({ kind: "bookmark", bookmarkId: n.id, title: n.title || n.url, url: n.url, folder: path, time: n.dateAdded });
      if (n.children) walk(n.children, n.title ? (path ? path + " / " : "") + n.title : path);
    }
  })(root.children, "");
  const closedItems = closed.flatMap(e => {
    const time = (e.lastModified || 0) * 1000;
    if (e.tab && !blank(e.tab.url)) return [{ kind: "closed", sessionId: e.tab.sessionId, title: e.tab.title || e.tab.url, url: e.tab.url, time }];
    if (e.window?.tabs?.length) {
      const first = e.window.tabs[0], n = e.window.tabs.length;
      return [{ kind: "closed", sessionId: e.window.sessionId, title: `Window · ${n} tab${n === 1 ? "" : "s"}`, url: first.url, note: first.title, time }];
    }
    return [];
  });
  base = [...tabItems, ...saved, ...closedItems, ...bookmarks];
  savedByUrl = new Map(saved.map(s => [s.url, s]));
  tabsByUrl = new Map();
  for (const t of tabItems) if (!tabsByUrl.has(t.url)) tabsByUrl.set(t.url, t);
  apply();
}

async function loadHistory() {
  const found = await chrome.history.search({ text: "", startTime: 0, maxResults: 20000 });
  hist = found.filter(h => h.url && !h.url.startsWith(SELF) && !h.url.startsWith("chrome://newtab")).map(h => ({
    kind: "history", title: h.title || h.url, url: h.url, visits: h.visitCount, time: h.lastVisitTime,
  }));
  apply();
}

async function reload() { await load(); }

function apply() {
  items = QuickSearch.dedupe([...base, ...hist]);
  if (mode === "list") render();
}


const readable = url => { try { return decodeURI(url); } catch { return url; } };
const short = url => readable(url || "").replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "");
function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]); }
function highlight(text, terms) {
  if (!terms.length) return esc(text);
  const re = new RegExp("(" + terms.map(t => t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|") + ")", "gi");
  return String(text).split(re).map((part, i) => i % 2 ? "<mark>" + esc(part) + "</mark>" : esc(part)).join("");
}
function ago(time) {
  const s = (Date.now() - time) / 1000;
  if (s < 60) return "just now";
  if (s < 3600) return Math.floor(s / 60) + " min ago";
  if (s < 86400) return Math.floor(s / 3600) + " h ago";
  if (s < 86400 * 30) return Math.floor(s / 86400) + " d ago";
  return new Date(time).toLocaleDateString();
}
const favicon = url => chrome.runtime.getURL("/_favicon/") + "?size=32&pageUrl=" + encodeURIComponent(url);
const GLYPHS = {
  web: '<svg class="glyph" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5 14 14" stroke-linecap="round"/></svg>',
  action: '<svg class="glyph" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M6 4l4 4-4 4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
};

function note(item) {
  switch (item.kind) {
    case "tab": return short(item.url);
    case "saved": return short(item.url);
    case "closed": return (item.note ? item.note + " · " : short(item.url) + " · ") + ago(item.time);
    case "history": return short(item.url) + " · " + ago(item.time);
    case "bookmark": return (item.folder ? item.folder + " · " : "") + short(item.url);
    case "url": return "Open this address";
    default: return "";
  }
}

function render() {
  const query = $q.value;
  const terms = QuickSearch.parse(query).terms;
  rows = []; numbered = [];
  for (const s of QuickSearch.sections(items, query)) {
    rows.push({ header: s.title });
    for (const item of s.items) {
      let hint = "";
      if (s.id === "tab" && numbered.length < 9) { numbered.push(item); hint = (MAC ? "⌘" : "Ctrl+") + numbered.length; }
      rows.push({ item, hint, terms });
    }
  }
  const extra = QuickSearch.fallback(query);
  if (extra) {
    rows.push({ header: extra.kind === "web" ? "Web" : "Address" });
    rows.push({ item: extra.kind === "web" ? { ...extra, title: `Search for “${extra.text}”` } : { ...extra, title: short(extra.url) }, hint: "", terms: [] });
  }
  sel = firstItem(Math.min(sel, rows.length - 1));
  draw(rows.length ? "" : "No matches");
  footer([["↑↓", "navigate"], ["↵", "open"], ["⌘↵", "new tab"], ["⌘1–9", "switch tab"], ["⌘K", "actions"], ["⌘S", "save"], ["esc", "dismiss"]]);
}

function rowHtml(r) {
  if (r.header) return `<li class="section">${esc(r.header)}</li>`;
  if (r.action) return `<li class="row">${GLYPHS.action}<div class="text"><div class="title">${esc(r.action.label)}</div></div><span class="hint">${esc(r.action.keys)}</span></li>`;
  const it = r.item, n = note(it);
  const icon = it.kind === "web" ? GLYPHS.web : `<img class="icon" src="${esc(favicon(it.url))}" alt="">`;
  return `<li class="row">${icon}<div class="text"><div class="title">${highlight(it.title, r.terms || [])}</div>`
    + (n ? `<div class="note">${highlight(n, r.terms || [])}</div>` : "") + `</div>`
    + (r.hint ? `<span class="hint">${esc(r.hint)}</span>` : "") + `</li>`;
}

function draw(empty) {
  $list.innerHTML = rows.map(rowHtml).join("") + (empty ? `<li class="empty">${esc(empty)}</li>` : "");
  [...$list.children].forEach((li, i) => {
    if (!li.classList.contains("row")) return;
    li.onmousemove = () => { if (sel !== i) { sel = i; mark(false); } };
    li.onclick = e => { sel = i; activate(e.metaKey || e.ctrlKey ? "new" : e.shiftKey ? "here" : "open"); };
  });
  mark(true);
  resize();
}

function mark(scroll) {
  [...$list.children].forEach((li, i) => li.classList.toggle("sel", i === sel));
  if (!scroll) return;
  if (sel === firstItem(0)) $scroll.scrollTop = 0;
  else $list.children[sel]?.scrollIntoView({ block: "nearest" });
}

const selectable = i => rows[i] && !rows[i].header;
function firstItem(from) {
  for (let i = Math.max(0, from); i < rows.length; i++) if (selectable(i)) return i;
  for (let i = Math.min(from, rows.length - 1); i >= 0; i--) if (selectable(i)) return i;
  return 0;
}
function move(d) {
  if (!rows.some((_, i) => selectable(i))) return;
  let i = sel;
  do { i = (i + d + rows.length) % rows.length; } while (!selectable(i));
  sel = i; mark(true);
}

function footer(pairs) {
  $footer.innerHTML = pairs.map(([k, p]) => `<span><span class="cmd">${esc(k)}</span>${esc(p)}</span>`).join("");
}
function flash(text) {
  clearTimeout(flashTimer);
  const keep = $footer.innerHTML;
  $footer.innerHTML = `<span class="flash">${esc(text)}</span>`;
  flashTimer = setTimeout(() => { $footer.innerHTML = keep; }, 1600);
}
// Stays until the footer is drawn again (errors stay readable).
function notice(text, error = false) {
  clearTimeout(flashTimer);
  $footer.innerHTML = `<span class="flash${error ? " error" : ""}">${esc(text)}</span>`;
}

function resize() {
  if (MODE !== "overlay") return;
  const bar = document.querySelector(".bar").offsetHeight;
  const height = bar + $list.offsetHeight + $footer.offsetHeight + 1;
  parent.postMessage({ quickOpen: "height", height }, "*");
}


const current = () => rows[sel]?.item;
function context(item) {
  return { saved: item.kind === "saved" || savedByUrl.has(item.url), openTab: item.kind !== "tab" && tabsByUrl.has(item.url) };
}

function showActions(item) {
  if (!item) return;
  if (mode === "list") { listQuery = $q.value; listSel = sel; }
  mode = "actions"; target = item;
  $chip.textContent = item.title; $chip.hidden = false;
  $q.value = ""; $q.placeholder = "Search actions…";
  renderActions();
}
function renderActions() {
  const list = QuickSearch.filterActions(QuickSearch.actions(target, context(target)), $q.value);
  rows = [{ header: "Actions" }, ...list.map(action => ({ action }))];
  sel = firstItem(1);
  draw(list.length ? "" : "No actions");
  footer([["↑↓", "navigate"], ["↵", "run"], ["esc", "back"]]);
}

function startAlias(item) {
  if (!item || item.kind === "web") return;
  if (mode === "list") { listQuery = $q.value; listSel = sel; }
  mode = "alias"; target = item;
  const existing = item.kind === "saved" ? item : savedByUrl.get(item.url);
  $chip.textContent = existing ? "Rename alias" : "Save as alias"; $chip.hidden = false;
  $q.value = existing ? existing.title : "";
  $q.placeholder = `Alias for ${item.title}…`;
  $q.select();
  rows = [{ header: existing ? "Rename alias for" : "Save as alias" }, { item, hint: "", terms: [] }];
  sel = 1;
  draw("");
  footer([["↵", "save"], ["esc", "cancel"]]);
}

function backToList() {
  mode = "list"; target = null;
  $chip.hidden = true;
  $q.placeholder = "Search tabs, saved, history, bookmarks…";
  $q.value = listQuery; sel = listSel;
  render();
  $q.focus();
}


function closePalette() {
  if (MODE === "overlay") parent.postMessage({ quickOpen: "close" }, "*");
  else window.close();
}

async function windowAlive(id) { try { await chrome.windows.get(id); return true; } catch { return false; } }
async function switchTo(tab) {
  await chrome.tabs.update(tab.id, { active: true });
  await chrome.windows.update(tab.windowId, { focused: true });
}
async function newTab(url) {
  const opts = { url, active: true };
  if (await windowAlive(ORIGIN.win)) opts.windowId = ORIGIN.win;
  const tab = await chrome.tabs.create(opts);
  if (opts.windowId != null) await chrome.windows.update(opts.windowId, { focused: true });
  return tab;
}

async function openItem(item, how) {
  if (how === "open") {
    if (item.kind === "tab") return switchTo(item);
    if (item.kind === "closed") return chrome.sessions.restore(item.sessionId);
    const open = item.url && tabsByUrl.get(item.url);
    if (open) return switchTo(open);
    how = "new";
  }
  if (how === "new") {
    if (item.kind === "web") { const tab = await newTab("about:blank"); return chrome.search.query({ text: item.text, tabId: tab.id }); }
    return newTab(item.url);
  }
  if (item.kind === "web") return chrome.search.query({ text: item.text, tabId: ORIGIN.tab });
  if (item.kind === "tab" && item.id === ORIGIN.tab) return;
  await chrome.tabs.update(ORIGIN.tab, { url: item.url });
  await chrome.windows.update(ORIGIN.win, { focused: true });
}

async function copy(text) {
  try { await navigator.clipboard.writeText(text); }
  catch {
    const area = document.createElement("textarea");
    area.value = text; document.body.append(area); area.select();
    document.execCommand("copy"); area.remove(); $q.focus();
  }
}


const READERS = ["vendor/Readability.js", "vendor/turndown.js", "vendor/turndown-plugin-gfm.js", "markdown.js"];

async function markdownFromTab(tabId) {
  const target = { tabId };
  await chrome.scripting.executeScript({ target, files: READERS });
  const [{ result }] = await chrome.scripting.executeScript({ target, func: () => QuickMarkdown.fromDocument(document, location.href) });
  if (!result?.markdown) throw new Error("The page gave nothing back");
  return result;
}

async function markdownFromFetch(url) {
  const res = await fetch(url, { credentials: "include", redirect: "follow" });
  if (!res.ok) throw new Error(`The page answered ${res.status}`);
  const type = (res.headers.get("content-type") || "").toLowerCase();
  if (type.includes("pdf")) throw new Error("PDFs can't be copied as Markdown");
  const text = await res.text();
  if (type.startsWith("text/plain")) return { title: res.url, url: res.url, words: QuickMarkdown.words(text), markdown: `# ${res.url}\n\nSource: ${res.url}\n\n${text.trim()}\n` };
  if (type && !/html|xml/.test(type)) throw new Error(`Not a web page (${type.split(";")[0]})`);
  const doc = new DOMParser().parseFromString(text, "text/html");
  const own = doc.querySelector("base[href]")?.getAttribute("href");
  let base = res.url;
  try { if (own) base = new URL(own, res.url).href; } catch {}
  const tag = doc.createElement("base");
  tag.href = base;
  doc.head.prepend(tag);
  return QuickMarkdown.fromDocument(doc, res.url, base);
}

// Everything before the first await runs inside the key press, so Chrome can ask for the site.
async function copyMarkdown(item) {
  const blocked = QuickSearch.markdownBlocker(item.url);
  if (blocked) return notice(blocked, true);
  const tab = item.kind === "tab" ? item : tabsByUrl.get(item.url);
  const site = new URL(item.url);
  if (!(MODE === "overlay" && tab?.id === ORIGIN.tab)) {
    notice(`Waiting for access to ${site.host}…`);
    let granted = false;
    try { granted = await chrome.permissions.request({ origins: [site.origin + "/*"] }); }
    catch (err) { return notice(String(err.message || err), true); }
    if (!granted) return notice(`Allow access to ${site.host} to copy its pages`, true);
  }
  notice("Reading page…");
  let page = null, liveError = null;
  if (tab && !tab.discarded) {
    try { page = await markdownFromTab(tab.id); } catch (err) { liveError = err; }
  }
  if (!page) {
    try { page = await markdownFromFetch(item.url); }
    catch (err) { return notice(String((liveError || err).message || err), true); }
  }
  await copy(page.markdown);
  notice(`Copied ${page.words.toLocaleString()} words as Markdown`);
  if (mode !== "list") { mode = "list"; target = null; }
  setTimeout(closePalette, 900);
}

async function savedFolderId() {
  const [root] = await chrome.bookmarks.getTree();
  const other = otherFolder(root);
  const found = other.children?.find(n => !n.url && n.title === SAVED_FOLDER);
  return (found ?? await chrome.bookmarks.create({ parentId: other.id, title: SAVED_FOLDER })).id;
}
async function saveAlias(item, alias) {
  const existing = item.kind === "saved" ? item : savedByUrl.get(item.url);
  if (existing) await chrome.bookmarks.update(existing.bookmarkId, { title: alias });
  else await chrome.bookmarks.create({ parentId: await savedFolderId(), title: alias, url: item.url });
}

async function run(id, item) {
  if (!item || busy) return;
  busy = true;
  try {
    switch (id) {
      case "open": case "new": case "here":
        await openItem(item, id);
        return closePalette();
      case "copy":
        if (!item.url) break;
        await copy(item.url);
        if (mode !== "list") backToList();
        return flash("Copied link");
      case "markdown":
        if (!item.url || item.kind === "url" || item.kind === "web") break;
        return await copyMarkdown(item);
      case "alias": return startAlias(item);
      case "unsave": {
        const saved = item.kind === "saved" ? item : savedByUrl.get(item.url);
        if (saved) await chrome.bookmarks.remove(saved.bookmarkId);
        await reload(); backToList(); return flash("Removed from saved");
      }
      case "close":
        if (item.kind !== "tab") break;
        await chrome.tabs.remove(item.id);
        await reload(); if (mode !== "list") backToList(); return flash("Closed tab");
      case "unbookmark":
        await chrome.bookmarks.remove(item.bookmarkId);
        await reload(); backToList(); return flash("Removed bookmark");
      case "forget":
        await chrome.history.deleteUrl({ url: item.url });
        hist = hist.filter(h => h.url !== item.url);
        await reload(); backToList(); return flash("Deleted from history");
    }
  } catch (err) {
    flash(String(err.message || err));
  } finally {
    busy = false;
  }
}

async function commitAlias() {
  const alias = $q.value.trim();
  if (!alias || busy) return;
  busy = true;
  try { await saveAlias(target, alias); await reload(); backToList(); flash(`Saved as “${alias}”`); }
  catch (err) { flash(String(err.message || err)); }
  finally { busy = false; }
}

function activate(how) {
  if (mode === "actions") {
    const r = rows[sel];
    if (r?.action) run(how === "open" ? r.action.id : how, target);
    return;
  }
  if (mode === "alias") return;
  run(how, current());
}

$q.addEventListener("input", () => {
  if (mode === "list") { sel = 0; render(); }
  else if (mode === "actions") renderActions();
});

$q.addEventListener("keydown", e => {
  const mod = MAC ? e.metaKey : e.ctrlKey;
  const subject = mode === "list" ? current() : target;
  const key = e.key.toLowerCase();
  let handled = true;
  if (e.key === "Escape") { mode === "list" ? closePalette() : backToList(); }
  else if (mode === "alias") {
    if (e.key === "Enter") commitAlias();
    else handled = false;
  }
  else if (e.key === "ArrowDown" || (e.ctrlKey && key === "n") || (e.key === "Tab" && !e.shiftKey)) move(1);
  else if (e.key === "ArrowUp" || (e.ctrlKey && key === "p") || (e.key === "Tab" && e.shiftKey)) move(-1);
  else if (e.key === "Enter") activate(mod ? "new" : e.shiftKey ? "here" : "open");
  else if (mod && key === "t") run("new", subject);
  else if (mod && key === "k") mode === "actions" ? backToList() : showActions(current());
  else if (mod && key === "s") run("alias", subject);
  else if (mod && e.shiftKey && key === "c") run("copy", subject);
  else if (mod && e.shiftKey && key === "m") run("markdown", subject);
  else if (e.ctrlKey && e.key === "Backspace") run("close", subject);
  else if (mod && mode === "list" && /^Digit[1-9]$/.test(e.code)) { const t = numbered[Number(e.code.slice(5)) - 1]; if (t) run("open", t); }
  else handled = false;
  if (handled) { e.preventDefault(); e.stopPropagation(); }
});

// Keys typed before the input had focus still land in it.
addEventListener("focus", () => $q.focus());
document.addEventListener("visibilitychange", () => { if (document.hidden && !busy && MODE === "overlay") closePalette(); });
if (MODE === "window") {
  let focused = false;
  addEventListener("focus", () => { focused = true; });
  addEventListener("blur", () => { if (focused && !busy) window.close(); });
}

$q.focus();
load().then(loadHistory);
