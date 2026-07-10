#!/usr/bin/env python3
"""Generate 5 Chrome Web Store promo slides (1280x800) as standalone HTML (English)."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1280px;height:800px;overflow:hidden}
body{font-family:'Segoe UI',system-ui,Arial,sans-serif;
  background:radial-gradient(1100px 600px at 18% -10%,#1e3a8a 0%,transparent 55%),
             radial-gradient(900px 600px at 105% 110%,#0f766e 0%,transparent 50%),
             #0b1220;color:#e2e8f0;position:relative}
.wrap{position:absolute;inset:0;padding:88px 96px;display:flex;flex-direction:column}
.badge{display:inline-flex;align-items:center;gap:10px;font-size:19px;color:#7dd3fc;
  font-weight:700;letter-spacing:1px;margin-bottom:22px}
.badge img{width:34px;height:34px}
h1{font-size:62px;font-weight:800;line-height:1.1;letter-spacing:-1.5px}
h1 .accent{background:linear-gradient(90deg,#38bdf8,#2dd4bf);-webkit-background-clip:text;
  background-clip:text;color:transparent}
.sub{font-size:26px;color:#94a3b8;margin-top:22px;line-height:1.5;font-weight:400}
.bullets{margin-top:30px;font-size:23px;color:#cbd5e1;line-height:2}
.bullets b{color:#5eead4}

/* real popup card, scaled up */
.popup{width:440px;background:#0f172a;border:1px solid #24324a;border-radius:22px;
  padding:26px;box-shadow:0 40px 80px rgba(0,0,0,.5)}
.p-head{display:flex;align-items:center;gap:14px;margin-bottom:22px}
.p-head img{width:40px;height:40px}
.p-title{font-size:22px;font-weight:800}
.p-title span{font-weight:400;color:#94a3b8;font-size:18px}
.toggle{width:100%;height:78px;border-radius:18px;display:flex;align-items:center;
  padding:0 26px;font-size:22px;font-weight:800;color:#fff;position:relative}
.toggle .knob{position:absolute;width:32px;height:32px;border-radius:50%;background:#fff}
.toggle.on{background:linear-gradient(135deg,#2563eb,#16b9a0)}
.toggle.on .knob{right:26px}
.toggle.on .label{margin-right:auto}
.toggle.off{background:#334155}
.toggle.off .knob{left:26px}
.toggle.off .label{margin-left:auto}
.status{margin-top:22px;background:#1e293b;border-radius:14px;padding:16px 18px;font-size:18px}
.row{display:flex;align-items:center;gap:12px;padding:6px 0}
.dot{width:13px;height:13px;border-radius:50%;background:#64748b}
.dot.ok{background:#16b9a0}.dot.warn{background:#f59e0b}
.foot{margin-top:20px;display:flex;justify-content:space-between;font-size:17px;color:#94a3b8}
.foot .lnk{color:#60a5fa}

/* lanes / diagram */
.lane{display:flex;align-items:center;gap:22px;font-size:24px;font-weight:700}
.pill{padding:16px 26px;border-radius:16px;font-size:23px;font-weight:700}
.pill.chrome{background:#1e293b;border:1px solid #334155}
.pill.proxy{background:linear-gradient(135deg,#1d4ed8,#0d9488);color:#fff}
.pill.app{background:#161f31;border:1px solid #263349;color:#94a3b8}
.pill.net{background:#0e1a2b;border:1px solid #24324a}
.arrow{color:#475569;font-size:30px;font-weight:800}
.arrow.hot{color:#2dd4bf}
.tag{font-size:16px;padding:6px 14px;border-radius:999px;font-weight:700}
.tag.ok{background:rgba(45,212,191,.15);color:#5eead4}
.tag.no{background:rgba(148,163,184,.12);color:#94a3b8}

/* steps */
.steps{display:flex;gap:26px;margin-top:44px}
.step{flex:1;background:#0f172a;border:1px solid #24324a;border-radius:20px;padding:30px}
.step .n{width:46px;height:46px;border-radius:12px;background:linear-gradient(135deg,#2563eb,#16b9a0);
  display:flex;align-items:center;justify-content:center;font-size:24px;font-weight:800;color:#fff}
.step h3{font-size:24px;margin:20px 0 12px}
.step p{font-size:18px;color:#94a3b8;line-height:1.55}

.row2{display:flex;gap:60px;align-items:center;margin-top:26px}
.center{align-items:center;text-align:center}
.footnote{position:absolute;left:96px;bottom:54px;font-size:17px;color:#5c6b82}
"""

ICON = "../../extension/icons/icon128.png"

def popup(state):
    on = state == "on"
    return f"""
    <div class="popup">
      <div class="p-head"><img src="{ICON}"><div class="p-title">GoodbyeDPI <span>for Chrome</span></div></div>
      <div class="toggle {'on' if on else 'off'}"><span class="knob"></span><span class="label">{'ON' if on else 'OFF'}</span></div>
      <div class="status">
        <div class="row"><span class="dot {'ok' if on else ''}"></span><span>Proxy: {'on (Chrome only)' if on else 'off'}</span></div>
        <div class="row"><span class="dot {'ok' if on else ''}"></span><span>Backend: {'running (ciadpi #56308)' if on else 'stopped'}</span></div>
      </div>
      <div class="foot"><span>127.0.0.1:1080</span><span class="lnk">Settings</span></div>
    </div>"""

def page(body, extra=""):
    return f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}{extra}</style></head><body>{body}</body></html>"

# S1 hero
s1 = page(f"""
<div class="wrap">
  <div class="badge"><img src="{ICON}">GOODBYEDPI FOR CHROME</div>
  <h1>One click,<br><span class="accent">Chrome-only</span><br>DPI bypass</h1>
  <div class="sub">Toggle censorship bypass on and off.<br>It applies to this browser only.</div>
</div>
<div style="position:absolute;right:120px;top:50%;transform:translateY(-50%)">{popup('on')}</div>
""")

# S2 isolation
s2 = page(f"""
<div class="wrap center" style="align-items:center">
  <div class="badge" style="justify-content:center"><img src="{ICON}">CHROME-ONLY ISOLATION</div>
  <h1 style="text-align:center">Only Chrome.<br><span class="accent">Everything else untouched.</span></h1>
  <div style="margin-top:72px;display:flex;flex-direction:column;gap:34px">
     <div class="lane"><span class="pill chrome">🌐 Chrome</span><span class="arrow hot">──▶</span>
        <span class="pill proxy">Local ByeDPI proxy</span><span class="arrow hot">──▶</span>
        <span class="pill net">Internet</span><span class="tag ok">bypassed</span></div>
     <div class="lane"><span class="pill app">🎮 Other apps &amp; browsers</span><span class="arrow">─────────▶</span>
        <span class="pill net">Internet</span><span class="tag no">direct · unaffected</span></div>
  </div>
</div>
""")

# S3 how it works
s3 = page(f"""
<div class="wrap">
  <div class="badge"><img src="{ICON}">HOW IT WORKS</div>
  <h1>How does it work?</h1>
  <div class="steps">
     <div class="step"><div class="n">1</div><h3>Toggle ON</h3>
        <p>The extension routes Chrome's traffic to a local proxy (127.0.0.1) running on your own PC.</p></div>
     <div class="step"><div class="n">2</div><h3>DPI bypass</h3>
        <p>The local ByeDPI proxy uses TLS record splitting, packet reordering and fake packets to evade DPI.</p></div>
     <div class="step"><div class="n">3</div><h3>Chrome only</h3>
        <p>Only Chrome is pointed at the proxy, so other apps and other profiles are unaffected.</p></div>
  </div>
  <div class="footnote">A browser extension can't touch packets directly, so the real bypass runs in a small local helper app.</div>
</div>
""")

# S4 options / strategies
options_card = f"""
<div class="popup" style="width:520px">
  <div class="p-head"><img src="{ICON}"><div class="p-title">Settings <span>bypass strategy</span></div></div>
  <div style="display:flex;gap:12px;margin:6px 0 18px">
     <span class="pill proxy" style="font-size:18px;padding:11px 18px">Recommended</span>
     <span class="pill chrome" style="font-size:18px;padding:11px 18px">Light</span>
     <span class="pill chrome" style="font-size:18px;padding:11px 18px">Strong</span>
  </div>
  <div class="status" style="font-family:Consolas,monospace;font-size:16px">-s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s</div>
  <div class="status" style="margin-top:14px">
     <div class="row"><span class="dot ok"></span><span>Scope: all sites / specific domains</span></div>
     <div class="row"><span class="dot ok"></span><span>Port: 1080 · Auto-start: on</span></div>
  </div>
</div>"""
s4 = page(f"""
<div class="wrap">
  <div class="row2">
    <div style="flex:1">
      <div class="badge"><img src="{ICON}">CUSTOMIZE</div>
      <h1>Choose a strategy<br><span class="accent">for your network</span></h1>
      <div class="bullets">
        · <b>One-click</b> preset switching<br>
        · All sites or <b>specific domains only</b><br>
        · Fine-tune per region &amp; ISP
      </div>
    </div>
    <div>{options_card}</div>
  </div>
</div>
""")

# S5 simple on/off
s5 = page(f"""
<div class="wrap center" style="align-items:center">
  <div class="badge" style="justify-content:center"><img src="{ICON}">STATUS AT A GLANCE</div>
  <h1 style="text-align:center">Off and <span class="accent">on</span>, just like that.</h1>
  <div style="margin-top:56px;display:flex;gap:80px;align-items:center">
     <div style="text-align:center"><div style="font-size:20px;color:#94a3b8;margin-bottom:18px">OFF</div>{popup('off')}</div>
     <div class="arrow hot" style="font-size:54px">➔</div>
     <div style="text-align:center"><div style="font-size:20px;color:#5eead4;margin-bottom:18px">ON · Chrome only</div>{popup('on')}</div>
  </div>
</div>
""")

for name, html in [("s1",s1),("s2",s2),("s3",s3),("s4",s4),("s5",s5)]:
    with open(os.path.join(HERE, name+".html"),"w",encoding="utf-8") as f:
        f.write(html)
    print("wrote", name+".html")
