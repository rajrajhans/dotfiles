// `var` so injecting it into the same tab again does not throw.
var QuickMarkdown = (() => {
  const CLUTTER = "script, style, noscript, template, svg, canvas, iframe, object, embed, nav, header, footer, aside, form, button, dialog, [hidden], [aria-hidden=true], [data-quick-open]";

  function absolutize(doc, base) {
    const abs = value => { try { return new URL(value, base).href; } catch { return null; } };
    for (const a of doc.querySelectorAll("a[href]")) {
      const href = a.getAttribute("href").trim();
      if (/^javascript:/i.test(href)) { a.removeAttribute("href"); continue; }
      const url = abs(href);
      if (url) a.setAttribute("href", url);
    }
    for (const img of doc.querySelectorAll("img")) {
      const src = img.getAttribute("src") || "";
      const lazy = img.getAttribute("data-src") || img.getAttribute("data-original");
      const url = abs(lazy && (!src || src.startsWith("data:")) ? lazy : src);
      if (url) img.setAttribute("src", url);
      img.removeAttribute("srcset");
    }
  }

  function words(text) { return (text.match(/\S+/g) || []).length; }

  // `source` is left alone; Readability edits the copy it gets.
  function fromDocument(source, url, base = url) {
    const doc = source.cloneNode(true);
    doc.querySelectorAll("[data-quick-open]").forEach(n => n.remove());
    absolutize(doc, base);
    let article = null;
    try { article = new Readability(doc.cloneNode(true), { serializer: el => el }).parse(); } catch {}
    let node, title = (article?.title || doc.title || "").trim() || url;
    if (article?.content && (article.textContent || "").trim().length > 140) node = article.content;
    else {
      node = (doc.body || doc.documentElement).cloneNode(true);
      node.querySelectorAll(CLUTTER).forEach(n => n.remove());
    }
    const service = new TurndownService({ headingStyle: "atx", codeBlockStyle: "fenced", bulletListMarker: "-", emDelimiter: "_", hr: "---" });
    service.use(turndownPluginGfm.gfm);
    service.remove(["script", "style", "noscript", "template"]);
    let body = service.turndown(node).trim();
    // Readability often keeps the page's own <h1>; the title line already says it.
    const lead = body.match(/^#{1,2} (.+)\n+/);
    if (lead && lead[1].trim().toLowerCase() === title.toLowerCase()) body = body.slice(lead[0].length);
    return {
      title, url,
      words: words(node.textContent || ""),
      markdown: `# ${title}\n\nSource: ${url}\n\n${body}\n`,
    };
  }

  return { fromDocument, absolutize, words };
})();
