const $ = (id) => document.getElementById(id);
const toggle = $("toggle");

function send(message) {
  return new Promise((resolve) => chrome.runtime.sendMessage(message, resolve));
}

function renderProxy(on) {
  $("proxyDot").className = "dot " + (on ? "ok" : "");
  $("proxyText").textContent = "프록시: " + (on ? "켜짐 (Chrome 전용)" : "꺼짐");
  toggle.className = "toggle " + (on ? "on" : "off");
  toggle.setAttribute("aria-pressed", on ? "true" : "false");
  toggle.querySelector(".label").textContent = on ? "켜짐" : "꺼짐";
}

function renderBackend(backend, autostart) {
  const dot = $("backendDot");
  const text = $("backendText");
  const hint = $("hint");
  hint.classList.add("hidden");

  if (!autostart) {
    dot.className = "dot warn";
    text.textContent = "백엔드: 수동 실행 모드";
    return;
  }
  if (backend && backend.ok && backend.running) {
    dot.className = "dot ok";
    text.textContent = "백엔드: 실행 중 (ciadpi" + (backend.pid ? " #" + backend.pid : "") + ")";
  } else if (backend && backend.ok) {
    dot.className = "dot warn";
    text.textContent = "백엔드: 중지됨";
  } else {
    dot.className = "dot bad";
    text.textContent = "백엔드: 네이티브 호스트 미설치";
    hint.innerHTML =
      "자동 실행을 쓰려면 <code>native-host\\install-host.ps1</code> 을 실행하세요. " +
      "또는 <code>backend\\start-ciadpi.bat</code> 로 직접 프록시를 켜세요.";
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
