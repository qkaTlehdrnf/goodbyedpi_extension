const $ = (id) => document.getElementById(id);
const toggle = $("toggle");

const REPO = "https://github.com/qkaTlehdrnf/goodbyedpi_extension";
const WIN_INSTALLER =
  REPO + "/releases/latest/download/GoodbyeDPI-for-Chrome-Setup.exe";
// One-line permanent installer for macOS/Linux — the user pastes this, never
// has to open a GitHub page. The URL inside it fetches the install script.
const MAC_INSTALL_BASE =
  "curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/" +
  "goodbyedpi_extension/master/native-host/mac-install.sh | sh";

// Bake THIS extension's own id into the command, so the native host is
// registered for whatever build is actually running — the Web Store build or
// an unpacked/dev load. The user copies and pastes once; no id to look up.
function macInstallCmd() {
  const id = (chrome.runtime && chrome.runtime.id) || "";
  return id ? MAC_INSTALL_BASE + " -s -- " + id : MAC_INSTALL_BASE;
}

// Latest state, so the install panel can build a command from live settings.
let state = { settings: null, platform: "" };

function send(message) {
  return new Promise((resolve) => chrome.runtime.sendMessage(message, resolve));
}

function isWindows() {
  return state.platform === "win";
}

// Permanent install: a one-click .exe on Windows, a one-line copy-paste command
// on macOS/Linux (no GitHub page to visit).
function installerUrl() {
  return WIN_INSTALLER;
}

function renderProxy(on) {
  $("proxyDot").className = "dot " + (on ? "ok" : "");
  $("proxyText").textContent = "Proxy: " + (on ? "on (Chrome only)" : "off");
  toggle.className = "toggle " + (on ? "on" : "off");
  toggle.setAttribute("aria-pressed", on ? "true" : "false");
  toggle.querySelector(".label").textContent = on ? "ON" : "OFF";
}

function renderBackend(backend, autostart) {
  const dot = $("backendDot");
  const text = $("backendText");
  $("hint").classList.add("hidden");

  if (!autostart) {
    dot.className = "dot warn";
    text.textContent = "Backend: manual mode";
    return;
  }
  if (backend && backend.ok && backend.running) {
    dot.className = "dot ok";
    text.textContent = "Backend: running (ciadpi" + (backend.pid ? " #" + backend.pid : "") + ")";
  } else if (backend && backend.ok) {
    dot.className = "dot warn";
    text.textContent = "Backend: stopped";
  } else {
    dot.className = "dot bad";
    text.textContent = "Backend: helper not installed";
  }
}

// ---- Install guidance panel ---------------------------------------------

const REASON_TEXT = {
  "host-missing": "The companion app isn't installed, so the proxy can't start.",
  "start-failed": "The companion app is installed but ciadpi failed to launch.",
  "proxy-unreachable": "Nothing is answering on the proxy port — the proxy isn't running.",
};

function fillInstallPanel(reason) {
  $("installSub").textContent =
    (reason && REASON_TEXT[reason]) ||
    "Chrome's traffic is not routed until the local proxy runs. Pick one:";

  const permBtn = $("permBtn");
  const permCmdWrap = $("permCmdWrap");
  if (isWindows()) {
    // Windows: one-click installer download.
    permBtn.href = installerUrl();
    permBtn.textContent = "Get the installer (.exe)";
    permBtn.classList.remove("hidden");
    permCmdWrap.classList.add("hidden");
    $("permDesc").textContent =
      "Install once. The toggle then starts it automatically and it survives reboots.";
  } else {
    // macOS/Linux: one-line copy-paste command, no GitHub page to open.
    $("permCmd").textContent = macInstallCmd();
    permCmdWrap.classList.remove("hidden");
    permBtn.classList.add("hidden");
    $("permDesc").textContent =
      "Paste this once into Terminal. Installs and registers everything; survives reboots.";
  }
}

function showInstall(reason) {
  fillInstallPanel(reason);
  $("install").classList.remove("hidden");
}

function hideInstall() {
  $("install").classList.add("hidden");
}

// ---- Wiring --------------------------------------------------------------

async function refresh() {
  const res = await send({ type: "getState" });
  if (!res || !res.ok) return;
  state.settings = res.settings;
  state.platform = res.platform || "";
  renderProxy(res.settings.enabled);
  renderBackend(res.backend, res.settings.autostart);
  $("endpoint").textContent = res.settings.host + ":" + res.settings.port;
  // Surface guidance up front when auto-start is on but the helper is absent.
  if (res.settings.autostart && res.backend && !res.backend.ok) {
    showInstall("host-missing");
  } else {
    hideInstall();
  }
}

toggle.addEventListener("click", async () => {
  const turningOn = !toggle.classList.contains("on");
  toggle.disabled = true;
  const res = await send({ type: "toggle", enabled: turningOn });
  toggle.disabled = false;
  if (!res || !res.ok) return;

  renderProxy(res.enabled);
  if (turningOn && !res.enabled && res.reason) {
    // Enable was refused because the backend isn't available — don't break the
    // internet, guide the user to install or run it instead.
    showInstall(res.reason);
  } else {
    hideInstall();
  }
  const st = await send({ type: "getState" });
  if (st && st.ok) renderBackend(st.backend, st.settings.autostart);
});

async function copyToButton(text, btn) {
  try {
    await navigator.clipboard.writeText(text);
    btn.textContent = "Copied";
    setTimeout(() => (btn.textContent = "Copy"), 1500);
  } catch (e) {
    /* clipboard blocked — user can still select the text */
  }
}

$("copyPerm").addEventListener("click", () => copyToButton(macInstallCmd(), $("copyPerm")));

$("showInstall").addEventListener("click", (e) => {
  e.preventDefault();
  const panel = $("install");
  if (panel.classList.contains("hidden")) showInstall();
  else hideInstall();
});

$("openOptions").addEventListener("click", (e) => {
  e.preventDefault();
  chrome.runtime.openOptionsPage();
});

refresh();
