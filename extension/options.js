const $ = (id) => document.getElementById(id);
const DEFAULTS = {
  host: "127.0.0.1",
  port: 1080,
  mode: "all",
  domains: [],
  args: "-s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s",
  autostart: true,
};

function send(message) {
  return new Promise((resolve) => chrome.runtime.sendMessage(message, resolve));
}

async function load() {
  const stored = await chrome.storage.local.get(DEFAULTS);
  const s = { ...DEFAULTS, ...stored };
  $("host").value = s.host;
  $("port").value = s.port;
  $("args").value = s.args;
  $("mode").value = s.mode;
  $("domains").value = (s.domains || []).join("\n");
  $("autostart").checked = !!s.autostart;
}

document.querySelectorAll(".presets button").forEach((b) =>
  b.addEventListener("click", () => ($("args").value = b.dataset.args))
);

$("save").addEventListener("click", async () => {
  const patch = {
    host: $("host").value.trim() || "127.0.0.1",
    port: Math.min(65535, Math.max(1, parseInt($("port").value, 10) || 1080)),
    args: $("args").value.trim(),
    mode: $("mode").value,
    domains: $("domains").value
      .split("\n")
      .map((d) => d.trim())
      .filter(Boolean),
    autostart: $("autostart").checked,
  };
  const res = await send({ type: "saveSettings", patch });
  $("status").textContent = res && res.ok ? "Saved ✓" : "Save failed: " + (res && res.error);
  setTimeout(() => ($("status").textContent = ""), 2500);
});

load();
