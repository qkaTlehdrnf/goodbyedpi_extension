// GoodbyeDPI for Chrome — background service worker
// Routes ONLY Chrome's traffic through a local ByeDPI (ciadpi) SOCKS5 proxy,
// so DPI-bypass applies to this browser only. Other apps are untouched.

const NATIVE_HOST = "com.goodbyedpi.chrome";

// Diagnostic logging — visible in the service worker console
// (chrome://extensions -> this extension -> "service worker" -> Inspect).
function log(...a) {
  try {
    console.log("[GoodbyeDPI]", ...a);
  } catch (e) {
    /* console unavailable */
  }
}

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
  // flexiblePort: if the port is taken by another program (e.g. VS Code
  // forwarding 1080), the host picks a free one and reports it as `port`.
  return nativeSend({ cmd: "start", args: s.args, port: Number(s.port), flexiblePort: true });
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

// Shown when the watchdog had to turn the proxy off because ciadpi died and
// could not be restarted. Cleared the next time the user turns it on.
function setBadgeError() {
  chrome.action.setBadgeText({ text: "!" });
  chrome.action.setBadgeBackgroundColor({ color: "#dc2626" });
}

// Remember why the proxy was turned off behind the user's back, so the popup
// can explain it instead of just showing OFF.
async function recordFailure(r) {
  await chrome.storage.local.set({
    lastFailure: { reason: r.reason || "unknown", detail: r.detail, hostVersion: r.hostVersion || null, at: Date.now() },
  });
}
async function clearFailure() {
  await chrome.storage.local.remove("lastFailure");
}

// ---- Enable / disable ----------------------------------------------------

// Bring the proxy up only when a working backend is confirmed, so a missing or
// dead ciadpi never silently breaks Chrome's connectivity. Returns
// { ok, reason?, hostInstalled?, ... } describing what happened.
// With opts.restart, ciadpi is relaunched even if it is already running, so
// changed arguments or port actually take effect.
async function ensureBackendAndProxy(s, opts = {}) {
  const host = await backendStatus();
  const hostInstalled = !!(host && host.ok);
  log("enable: ext", chrome.runtime.getManifest().version,
      "host", (host && host.hostVersion) || "?", "autostart=", s.autostart,
      "native status ->", host);
  // Versions ride along on every result so the popup's error panel shows them.
  const base = { hostVersion: (host && host.hostVersion) || null };

  if (s.autostart) {
    // Automatic mode relies on the native host to launch ciadpi.
    if (!hostInstalled) {
      log("FAIL host-missing: native host did not answer.", host && host.error);
      return { ...base, ok: false, reason: "host-missing", hostInstalled: false, detail: host };
    }
    let running = !!host.running;
    // The host may run ciadpi on a different port than configured (fallback
    // when the configured one is busy); always point Chrome at the real one.
    let port = host.port;
    if (!running || opts.restart) {
      const started = await startBackend(s);
      log("started ciadpi ->", started);
      running = !!(started && started.ok && started.running);
      if (!running) {
        log("FAIL start-failed:", started && started.error);
        return { ...base, ok: false, reason: "start-failed", hostInstalled: true, detail: started };
      }
      port = started.port;
    }
    const live = port ? { ...s, port: Number(port) } : s;
    if (live.port !== Number(s.port)) log("configured port busy; using", live.port);
    try {
      await applyProxy(live);
    } catch (e) {
      log("FAIL proxy-set threw:", e);
      return { ...base, ok: false, reason: "proxy-set-failed", hostInstalled: true, detail: String(e) };
    }
    log("OK: backend running, proxy applied (Chrome only).");
    return { ...base, ok: true, hostInstalled: true, running: true, port: Number(live.port) };
  }

  // Manual mode: the user starts ciadpi themselves. Apply the proxy, then
  // verify it forwards traffic; if not, roll back so the browser stays usable.
  await applyProxy(s);
  const reachable = await proxyReachable();
  if (!reachable) {
    await clearProxy();
    log("FAIL proxy-unreachable: nothing answering on", s.host + ":" + s.port);
    return { ...base, ok: false, reason: "proxy-unreachable", hostInstalled, manual: true };
  }
  log("OK (manual): proxy reachable.");
  return { ...base, ok: true, manual: true, running: true, hostInstalled };
}

async function enable() {
  await setSettings({ enabled: true });
  await clearFailure();
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
  await clearFailure();
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

// ---- Watchdog ------------------------------------------------------------

// Chrome reports this when it cannot connect to the proxy itself, i.e. ciadpi
// is gone. Errors reaching a site *through* the proxy (e.g.
// ERR_SOCKS_CONNECTION_FAILED) are per-site problems and are ignored.
const PROXY_DOWN_ERRORS = new Set(["net::ERR_PROXY_CONNECTION_FAILED"]);
const WATCHDOG_INTERVAL_MS = 30 * 1000;
let watchdogBusy = false;
let watchdogLast = 0;

async function watchdog(details) {
  const now = Date.now();
  if (watchdogBusy || now - watchdogLast < WATCHDOG_INTERVAL_MS) return;
  watchdogBusy = true;
  watchdogLast = now;
  try {
    const s = await getSettings();
    if (!s.enabled) return;
    log("watchdog: proxy unreachable (", details && details.error, ") — checking backend");
    let r;
    if (s.autostart) {
      // Always relaunch: Chrome just failed to reach the proxy, so whatever the
      // host's PID file claims (it can be stale), ciadpi is not serving.
      r = await ensureBackendAndProxy(s, { restart: true });
    } else {
      r = (await proxyReachable()) ? { ok: true } : { ok: false, reason: "proxy-unreachable", manual: true };
    }
    if (r.ok) {
      log("watchdog: backend OK");
      setBadge(true);
      return;
    }
    // Could not bring it back: release Chrome so it stays online, and say so.
    log("watchdog: recovery failed, turning proxy off", r);
    await clearProxy();
    await setSettings({ enabled: false });
    await recordFailure({ ...r, reason: "backend-stopped", detail: r.detail || r.reason });
    setBadgeError();
  } catch (e) {
    log("watchdog error", e);
  } finally {
    watchdogBusy = false;
  }
}

chrome.proxy.onProxyError.addListener((details) => {
  console.warn("proxy error", details);
  if (details && PROXY_DOWN_ERRORS.has(details.error)) watchdog(details);
});

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  (async () => {
    try {
      switch (msg.type) {
        case "getState": {
          const s = await getSettings();
          const backend = await backendStatus();
          const platform = await getPlatformOs();
          const { lastFailure } = await chrome.storage.local.get("lastFailure");
          sendResponse({ ok: true, settings: s, backend, platform, lastFailure: lastFailure || null });
          break;
        }
        case "toggle": {
          const result = msg.enabled ? await enable() : await disable();
          sendResponse({ ok: true, ...result });
          break;
        }
        case "saveSettings": {
          const before = await getSettings();
          const s = await setSettings(msg.patch);
          if (s.enabled) {
            // A running ciadpi keeps its old arguments and port until it is
            // relaunched, so restart it whenever either of them changed.
            const restart = s.args !== before.args || Number(s.port) !== Number(before.port);
            const r = await ensureBackendAndProxy(s, { restart }); // re-apply, guarded
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
