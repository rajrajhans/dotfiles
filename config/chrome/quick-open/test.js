// node config/chrome/quick-open/test.js
const assert = require("assert");
const Q = require("./search.js");
const now = Date.UTC(2026, 0, 10);
const day = 864e5;

const items = Q.dedupe([
  { kind: "history", title: "GitHub - dotfiles", url: "https://github.com/me/dotfiles", visits: 40, time: now },
  { kind: "tab", id: 1, title: "GitHub - dotfiles", url: "https://github.com/me/dotfiles", time: now - 1000 },
  { kind: "tab", id: 2, title: "Inbox", url: "https://mail.example.com/", time: now - 5000 },
  { kind: "tab", id: 3, title: "Current page", url: "https://current.example.com/", time: 0 },
  { kind: "saved", title: "standup", url: "https://meet.example.com/abc", time: now - 9 * day },
  { kind: "saved", title: "mail", url: "https://mail.example.com/", time: now - 9 * day },
  { kind: "closed", sessionId: "s1", title: "Closed thing", url: "https://closed.example.com/", time: now - 60e3 },
  { kind: "closed", sessionId: "s2", title: "Inbox again", url: "https://mail.example.com/", time: now - 30e3 },
  { kind: "bookmark", title: "Hacker News", url: "https://news.ycombinator.com/", folder: "Bar / Reading", time: now - 300 * day },
  { kind: "history", title: "Hacker News", url: "https://news.ycombinator.com/", visits: 9, time: now - day },
  { kind: "history", title: "Rust book", url: "https://doc.rust-lang.org/book/", visits: 3, time: now - 30 * day },
  { kind: "history", title: "Some page mentioning github", url: "https://blog.example.org/post", visits: 1, time: now - 2 * day },
]);

const urls = kind => items.filter(i => i.kind === kind).map(i => i.url);
assert.ok(!urls("history").includes("https://github.com/me/dotfiles"), "open tab hides its history entry");
assert.ok(!urls("closed").includes("https://mail.example.com/"), "open tab hides a closed copy");
assert.ok(urls("saved").includes("https://mail.example.com/"), "saved aliases stay even when open");
assert.ok(urls("bookmark").includes("https://news.ycombinator.com/") && !urls("history").includes("https://news.ycombinator.com/"), "bookmark beats history");

assert.deepStrictEqual(Q.parse("bm:  hacker news"), { kind: "bookmark", terms: ["hacker", "news"] });
assert.deepStrictEqual(Q.parse("foo:bar"), { kind: null, terms: ["foo:bar"] });

const view = q => Q.sections(items, q, { now }).map(s => s.title + ": " + s.items.map(i => i.title).join(", "));
assert.deepStrictEqual(view(""), [
  "Open tabs: GitHub - dotfiles, Inbox, Current page",
  "Saved: mail, standup",
  "Recently closed: Closed thing",
  "Recently opened: Some page mentioning github, Rust book",
], "empty: fixed order, current tab last, no bookmarks");
assert.deepStrictEqual(view("github"), [
  "Open tabs: GitHub - dotfiles",
  "History: Some page mentioning github",
], "searching renames the history section");
assert.deepStrictEqual(view("standup"), ["Saved: standup"], "alias matches");
assert.deepStrictEqual(view("meet"), ["Saved: standup"], "alias url matches");
assert.deepStrictEqual(view("reading"), ["Bookmarks: Hacker News"], "folder names match");
assert.deepStrictEqual(view("rust zzz"), [], "all terms must match");
assert.deepStrictEqual(view("bm:"), ["Bookmarks: Hacker News"], "prefix shows its kind even when empty");
assert.deepStrictEqual(view("c: closed"), ["Recently closed: Closed thing"]);

assert.deepStrictEqual(Q.fallback("example.com/a"), { kind: "url", url: "https://example.com/a" });
assert.deepStrictEqual(Q.fallback("localhost:3000"), { kind: "url", url: "http://localhost:3000" });
assert.deepStrictEqual(Q.fallback("how to rust"), { kind: "web", text: "how to rust" });
assert.strictEqual(Q.fallback("tab: x"), null);

const ids = (item, o) => Q.actions(item, o).map(a => a.id).join(" ");
assert.strictEqual(ids({ kind: "tab" }), "open new here copy markdown alias close");
assert.strictEqual(ids({ kind: "tab" }, { saved: true }), "open new here copy markdown alias unsave close");
assert.strictEqual(ids({ kind: "history" }), "open new here copy markdown alias forget");
assert.strictEqual(ids({ kind: "closed" }), "open new here copy markdown alias");
assert.strictEqual(ids({ kind: "url" }), "open new here copy alias", "an address row has no page to copy yet");
assert.strictEqual(ids({ kind: "bookmark" }), "open new here copy markdown alias unbookmark");
assert.strictEqual(ids({ kind: "saved" }), "open new here copy markdown alias unsave");
assert.strictEqual(ids({ kind: "web" }), "open new here");
assert.strictEqual(Q.actions({ kind: "closed" })[0].label, "Restore");
assert.strictEqual(Q.actions({ kind: "history" }, { openTab: true })[0].label, "Switch to tab");
assert.deepStrictEqual(Q.filterActions(Q.actions({ kind: "tab" }), "clo").map(a => a.id), ["close"]);
assert.deepStrictEqual(Q.filterActions(Q.actions({ kind: "tab" }), "mark").map(a => a.id), ["markdown"]);

const blocked = url => Q.markdownBlocker(url);
assert.strictEqual(blocked("https://example.com/post"), null);
assert.strictEqual(blocked("http://localhost:3000/"), null);
assert.match(blocked("chrome://settings"), /chrome: pages/);
assert.match(blocked("chrome-extension://abc/x.html"), /chrome-extension: pages/);
assert.match(blocked("file:///Users/x/a.html"), /Local files/);
assert.match(blocked("https://chromewebstore.google.com/detail/x"), /Web Store/);
assert.match(blocked("https://chrome.google.com/webstore/detail/x"), /Web Store/);
assert.match(blocked("https://example.com/paper.PDF"), /PDFs/);
assert.match(blocked(""), /no web address/);
console.log("ok");
