const PALETTE = chrome.runtime.getURL("palette.html");
const WIDTH = 700, HEIGHT = 520;

// ⌘⇧O is the action's own shortcut (_execute_action), so both arrive here.
chrome.action.onClicked.addListener(tab => toggle(tab));
chrome.windows.onRemoved.addListener(async id => {
  const { paletteWindow } = await chrome.storage.session.get("paletteWindow");
  if (paletteWindow === id) await chrome.storage.session.remove("paletteWindow");
});

async function toggle(tab) {
  const { paletteWindow } = await chrome.storage.session.get("paletteWindow");
  if (paletteWindow != null) {
    await chrome.storage.session.remove("paletteWindow");
    try { await chrome.windows.remove(paletteWindow); return; } catch {}
  }
  tab ??= (await chrome.tabs.query({ active: true, lastFocusedWindow: true }))[0];
  if (!tab || tab.url?.startsWith(PALETTE)) return;
  const src = `${PALETTE}?mode=overlay&tab=${tab.id}&win=${tab.windowId}`;
  try {
    await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: toggleOverlay, args: [src] });
  } catch {
    await openWindow(tab);
  }
}

async function openWindow(tab) {
  const win = await chrome.windows.get(tab.windowId);
  const left = Math.round(win.left + Math.max(0, (win.width - WIDTH) / 2));
  const top = Math.round(win.top + Math.min(120, win.height * 0.12));
  const created = await chrome.windows.create({
    url: `${PALETTE}?mode=window&tab=${tab.id}&win=${tab.windowId}`,
    type: "popup", width: WIDTH, height: HEIGHT, left, top, focused: true,
  });
  await chrome.storage.session.set({ paletteWindow: created.id });
}

// Runs in the page's isolated world, so the page's scripts and CSS never touch it.
function toggleOverlay(src) {
  if (globalThis.__quickOpenClose) { globalThis.__quickOpenClose(); return "closed"; }
  const previous = document.activeElement;
  const host = document.createElement("div");
  host.style.cssText = "all: initial; position: fixed; inset: 0; z-index: 2147483647;";
  host.dataset.quickOpen = ""; // left out when the page is copied as Markdown
  const root = host.attachShadow({ mode: "closed" });
  const style = document.createElement("style");
  style.textContent = `
    .backdrop { position: fixed; inset: 0; display: flex; justify-content: center; align-items: flex-start;
      background: rgba(0, 0, 0, .3); animation: fade .1s ease-out; }
    iframe { margin-top: max(40px, 11vh); width: min(700px, calc(100vw - 32px)); height: 120px;
      max-height: min(620px, calc(100vh - max(40px, 11vh) - 24px)); border: 0; border-radius: 12px;
      background: transparent; color-scheme: normal;
      box-shadow: 0 0 0 1px rgba(0, 0, 0, .14), 0 22px 70px rgba(0, 0, 0, .4); }
    @keyframes fade { from { opacity: 0; } }
  `;
  const backdrop = document.createElement("div");
  backdrop.className = "backdrop";
  const frame = document.createElement("iframe");
  frame.src = src;
  frame.allow = "clipboard-write";
  backdrop.append(frame);
  root.append(style, backdrop);
  document.documentElement.appendChild(host);

  const onMessage = e => {
    if (e.source !== frame.contentWindow || typeof e.data?.quickOpen !== "string") return;
    if (e.data.quickOpen === "close") close();
    else if (e.data.quickOpen === "height") frame.style.height = Math.ceil(e.data.height) + "px";
  };
  function close() {
    removeEventListener("message", onMessage, true);
    host.remove();
    globalThis.__quickOpenClose = null;
    if (previous && previous !== document.body && previous.focus) previous.focus({ preventScroll: true });
  }
  addEventListener("message", onMessage, true);
  backdrop.addEventListener("mousedown", e => { if (e.target === backdrop) close(); });
  frame.addEventListener("load", () => frame.focus());
  frame.focus();
  globalThis.__quickOpenClose = close;
  return "opened";
}
