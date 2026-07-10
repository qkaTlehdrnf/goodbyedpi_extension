const $ = (id) => document.getElementById(id);
const toggle = $("toggle");

function send(message) {
  return new Promise((resolve) => chrome.runtime.sendMessage(message, resolve));
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
  const hint = $("hint");
  hint.classList.add("hidden");

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
    hint.innerHTML =
      "Install the companion app to enable one-click start, " +
      "or run <code>start-ciadpi.bat</code> to start the proxy manually.";
    hint.classList.remove("hidden");
  }
}

async function refresh() {
  const res = await send({ type: "getState" });
  if (!res || !res.ok) return;
  const s = res.settings;
  renderProxy(s.enabled);
  renderBackend(res.backend, s.autostart);
  $("endpoint").textContent = s.host + ":" + s.port;
}

toggle.addEventListener("click", async () => {
  const turningOn = !toggle.classList.contains("on");
  toggle.disabled = true;
  const res = await send({ type: "toggle", enabled: turningOn });
  toggle.disabled = false;
  if (res && res.ok) {
    renderProxy(res.enabled);
    const st = await send({ type: "getState" });
    if (st && st.ok) renderBackend(st.backend, st.settings.autostart);
  }
});

$("openOptions").addEventListener("click", (e) => {
  e.preventDefault();
  chrome.runtime.openOptionsPage();
});

refresh();
