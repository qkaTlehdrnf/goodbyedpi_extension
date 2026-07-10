// GoodbyeDPI for Chrome — background service worker
// Routes ONLY Chrome's traffic through a local ByeDPI (ciadpi) SOCKS5 proxy,
// so DPI-bypass applies to this browser only. Other apps are untouched.

const NATIVE_HOST = "com.goodbyedpi.chrome";

const DEFAULTS = {
  enabled: false,
  host: "127.0.0.1",
  port: 1080,
  mode: "all", // "all" = everything via proxy, "list" = only listed domains
  domains: [], // used when mode === "list"
  args: "-s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s",
  autostart: true, // let the native host launch/stop ciadpi.exe automatically
};

async function getSettings() {
  const stored = await chrome.storage.local.get(DEFAULTS);
  return { ...DEFAULTS, ...stored };
}

async function setSettings(patch) {
  await chrome.storage.local.set(patch);
  return getSettings();
}

// ---- Proxy configuration -------------------------------------------------

function buildProxyConfig(s) {
  const bypass = ["localhost", "127.0.0.1", "[::1]", "<local>"];
  if (s.mode === "list" && s.domains.length) {
    // PAC: only listed domains go through the proxy, everything else DIRECT.
    const domainsJson = JSON.stringify(s.domains);
    const pac =
      "function FindProxyForURL(url, host) {\n" +
      "  var proxy = 'SOCKS5 " + s.host + ":" + s.port + "';\n" +
      "  if (isPlainHostName(host) || host === '127.0.0.1' || shExpMatch(host,'localhost')) return 'DIRECT';\n" +
      "  var list = " + domainsJson + ";\n" +
      "  for (var i = 0; i < list.length; i++) {\n" +
      "    if (host === list[i] || dnsDomainIs(host, '.' + list[i]) || shExpMatch(host, list[i])) return proxy;\n" +
      "  }\n" +
      "  return 'DIRECT';\n" +
      "}";
    return { mode: "pac_script", pacScript: { data: pac } };
  }
  // Default: send all Chrome traffic through the local SOCKS5 proxy.
  return {
    mode: "fixed_servers",
    rules: {
      singleProxy: { scheme: "socks5", host: s.host, port: Number(s.port) },
      bypassList: bypass,
    },
  };
}

function applyProxy(s) {
  return new Promise((resolve, reject) => {
    chrome.proxy.settings.set(
      { value: buildProxyConfig(s), scope: "regular" },
      () => (chrome.runtime.lastError ? reject(chrome.runtime.lastError) : resolve())
    );
  });
}

function clearProxy() {
  return new Promise((resolve) => {
    chrome.proxy.settings.clear({ scope: "regular" }, () => resolve());
  });
}

// ---- Native host (manages ciadpi.exe) ------------------------------------

function nativeSend(message) {
  return new Promise((resolve) => {
    try {
      chrome.runtime.sendNativeMessage(NATIVE_HOST, message, (resp) => {
        if (chrome.runtime.lastError) {
          resolve({ ok: false, error: chrome.runtime.lastError.message });
        } else {
          resolve(resp || { ok: false, error: "empty response" });
        }
      });
    } catch (e) {
      resolve({ ok: false, error: String(e) });
    }
  });
}

async function startBackend(s) {
  return nativeSend({ cmd: "start", args: s.args, port: Number(s.port) });
}
async function stopBackend() {
  return nativeSend({ cmd: "stop" });
}
async function backendStatus() {
  return nativeSend({ cmd: "status" });
}

// ---- Badge ---------------------------------------------------------------

function setBadge(on) {
  chrome.action.setBadgeText({ text: on ? "ON" : "" });
  chrome.action.setBadgeBackgroundColor({ color: on ? "#16b9a0" : "#888888" });
}

// ---- Enable / disable ----------------------------------------------------

async function enable() {
  const s = await setSettings({ enabled: true });
  let backend = { ok: true, skipped: true };
  if (s.autostart) backend = await startBackend(s);
  await applyProxy(s);
  setBadge(true);
  return { enabled: true, backend };
}

async function disable() {
  const s = await getSettings();
  await clearProxy();
  let backend = { ok: true, skipped: true };
  if (s.autostart) backend = await stopBackend();
  await setSettings({ enabled: false });
  setBadge(false);
  return { enabled: false, backend };
}

async function reapply() {
  const s = await getSettings();
  if (!s.enabled) return;
  if (s.autostart) await startBackend(s);
  await applyProxy(s);
  setBadge(true);
}

// ---- Wiring --------------------------------------------------------------

chrome.runtime.onInstalled.addListener(async () => {
  const s = await getSettings();
  setBadge(s.enabled);
  if (s.enabled) reapply();
});

chrome.runtime.onStartup.addListener(async () => {
  const s = await getSettings();
  setBadge(s.enabled);
  if (s.enabled) reapply();
});

chrome.proxy.onProxyError.addListener((details) => {
  console.warn("proxy error", details);
});

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  (async () => {
    try {
      switch (msg.type) {
        case "getState": {
          const s = await getSettings();
          const backend = await backendStatus();
          sendResponse({ ok: true, settings: s, backend });
          break;
        }
        case "toggle": {
          const result = msg.enabled ? await enable() : await disable();
          sendResponse({ ok: true, ...result });
          break;
        }
        case "saveSettings": {
          const s = await setSettings(msg.patch);
          if (s.enabled) {
            if (s.autostart) await startBackend(s); // restart with new args
            await applyProxy(s);
          }
          sendResponse({ ok: true, settings: s });
          break;
        }
        case "checkBackend": {
          sendResponse({ ok: true, backend: await backendStatus() });
          break;
        }
        default:
          sendResponse({ ok: false, error: "unknown message" });
      }
    } catch (e) {
      sendResponse({ ok: false, error: String(e && e.message ? e.message : e) });
    }
  })();
  return true; // async response
});
