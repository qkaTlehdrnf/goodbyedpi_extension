// GoodbyeDPI for Chrome — background service worker
// Routes ONLY Chrome's traffic through a local ByeDPI (ciadpi) SOCKS5 proxy,
// so DPI-bypass applies to this browser only. Other apps are untouched.

const NATIVE_HOST = "com.goodbyedpi.chrome";

// Liveness probe target: a benign endpoint that returns 204. We fetch it in
// no-cors mode, so the request resolves whenever the connection succeeds and
// rejects when nothing is listening on the proxy port.
const PROBE_URL = "https://www.gstatic.com/generate_204";

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

// True if the just-applied proxy actually forwards traffic. Used in manual
// mode, where no native host is available to report ciadpi's status.
function proxyReachable() {
  return new Promise((resolve) => {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 4000);
    fetch(PROBE_URL, { mode: "no-cors", cache: "no-store", signal: ctrl.signal })
      .then(() => resolve(true))
      .catch(() => resolve(false))
      .finally(() => clearTimeout(t));
  });
}

function getPlatformOs() {
  return new Promise((resolve) => {
    try {
      chrome.runtime.getPlatformInfo((info) => resolve((info && info.os) || ""));
    } catch (e) {
      resolve("");
    }
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

// Bring the proxy up only when a working backend is confirmed, so a missing or
// dead ciadpi never silently breaks Chrome's connectivity. Returns
// { ok, reason?, hostInstalled?, ... } describing what happened.
async function ensureBackendAndProxy(s) {
  const host = await backendStatus();
  const hostInstalled = !!(host && host.ok);

  if (s.autostart) {
    // Automatic mode relies on the native host to launch ciadpi.
    if (!hostInstalled) {
      return { ok: false, reason: "host-missing", hostInstalled: false };
    }
    let running = !!host.running;
    if (!running) {
      const started = await startBackend(s);
      running = !!(started && started.ok && started.running);
      if (!running) {
        return { ok: false, reason: "start-failed", hostInstalled: true, detail: started };
      }
    }
    await applyProxy(s);
    return { ok: true, hostInstalled: true, running: true };
  }

  // Manual mode: the user starts ciadpi themselves. Apply the proxy, then
  // verify it forwards traffic; if not, roll back so the browser stays usable.
  await applyProxy(s);
  const reachable = await proxyReachable();
  if (!reachable) {
    await clearProxy();
    return { ok: false, reason: "proxy-unreachable", hostInstalled, manual: true };
  }
  return { ok: true, manual: true, running: true, hostInstalled };
}

async function enable() {
  await setSettings({ enabled: true });
  const s = await getSettings();
  const r = await ensureBackendAndProxy(s);
  if (!r.ok) {
    await setSettings({ enabled: false }); // toggle snaps back — nothing is protecting the user
    setBadge(false);
    return { enabled: false, ...r };
  }
  setBadge(true);
  return { enabled: true, ...r };
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
  const r = await ensureBackendAndProxy(s);
  if (!r.ok) {
    await setSettings({ enabled: false });
    setBadge(false);
    return;
  }
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
          const platform = await getPlatformOs();
          sendResponse({ ok: true, settings: s, backend, platform });
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
            const r = await ensureBackendAndProxy(s); // re-apply with new args, guarded
            if (!r.ok) {
              await setSettings({ enabled: false });
              setBadge(false);
              sendResponse({ ok: true, settings: { ...s, enabled: false }, backendResult: r });
              break;
            }
            setBadge(true);
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
