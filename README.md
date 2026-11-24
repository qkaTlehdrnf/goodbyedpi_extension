# GoodbyeDPI for Chrome

**English** · [한국어](#한국어)

A Chrome extension that turns DPI (deep packet inspection) bypass on and off **for Chrome only**.
When it is on, only Chrome's traffic goes through a local bypass proxy. Other browsers, games and the rest of your system are not touched.

---

## Quick start

You need two things: the **extension**, and a small **companion app** that runs the bypass proxy on your computer. Setup takes about a minute.

### Windows

1. Install the extension from the [Chrome Web Store](https://chromewebstore.google.com/detail/aiclkdmpdfgaeaibbpeeaaolkmfkmiog).
2. Download and run **[GoodbyeDPI-for-Chrome-Setup.exe](https://github.com/qkaTlehdrnf/goodbyedpi_extension/releases/latest/download/GoodbyeDPI-for-Chrome-Setup.exe)**. Click through the installer. No admin rights or Python needed.
3. **Quit Chrome completely and open it again.** (Closing the window is not enough. Right-click the Chrome icon in the tray and choose Exit if it is still running.)
4. Click the extension icon in the toolbar and turn the switch **ON**.

### macOS / Linux

1. Install the extension from the [Chrome Web Store](https://chromewebstore.google.com/detail/aiclkdmpdfgaeaibbpeeaaolkmfkmiog).
2. Open **Terminal**, paste this one line and press Enter:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master/native-host/mac-install.sh | sh
   ```

3. **Quit Chrome completely** (Cmd+Q on macOS) and open it again.
4. Click the extension icon in the toolbar and turn the switch **ON**.

### Is it working?

In the popup, both dots should be **green**:

- **Proxy**: Chrome is sending its traffic through the bypass proxy.
- **Backend**: the bypass proxy (`ciadpi`) is running.

You only do this once. The setup survives reboots, and from now on the switch alone starts and stops everything.

> **Tip:** if you turn the switch on before installing the companion app, the popup notices, keeps your connection working, and shows the same download button / copy-paste command as above.
> Step-by-step screenshots: **[Setup guide](docs/SETUP_GUIDE.md)** (Korean).

### A site still doesn't open?

1. Open the popup → **Settings**, and try another preset (**Light**, **Recommended**, **Strong**). What works depends on your ISP.
2. If one specific site fails, set `chrome://flags/#enable-quic` to **Disabled** and restart Chrome.

---

## How it works

GoodbyeDPI itself cannot be limited to one app:

- **GoodbyeDPI** uses the `WinDivert` **kernel driver** to rewrite raw TCP packets (splitting the TLS ClientHello, sending pieces out of order, fake packets with low TTL, Host header tricks, and so on). It filters by **port (80/443), not by app**, so turning it on affects the whole system.
- A **Chrome extension** runs in a sandbox and cannot touch raw sockets, TCP segments or the TLS handshake, so these tricks cannot be done in extension JavaScript alone.

So this project combines two parts:

- **[ByeDPI](https://github.com/hufrea/byedpi) (`ciadpi`)** uses the same techniques (split, disorder, fake, oob, tlsrec, mod-http), but as a **local SOCKS5 proxy** instead of a kernel driver. It owns the socket, so it can split and reorder data itself. It listens only on `127.0.0.1`.
- The **extension** uses Chrome's `chrome.proxy` API to send **only Chrome's** traffic to `127.0.0.1:1080`. Through native messaging, the same switch also starts and stops `ciadpi`.

```
 Chrome ──(SOCKS5 proxy set by this extension)──▶ 127.0.0.1:1080  ciadpi  ──(DPI bypass)──▶ Internet
 Other apps ──────────────────────────────────────────(direct, unchanged)──────────────────▶ Internet
```

## Settings

Popup → **Settings**:

| Preset      | ciadpi arguments                                 |
| ----------- | ------------------------------------------------ |
| Light       | `-s 1 -r 1+s`                                    |
| Recommended | `-s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s` |
| Strong      | `-d 1 -f 0 --ttl 1 --auto=torst -r 1+s`          |

`-s` split · `-d` disorder · `-f` fake · `-o` oob · `-r` tlsrec · `-M/--mod-http` HTTP tweaks · `-A/--auto` apply only when blocking is detected.
All options: https://github.com/hufrea/byedpi

You can also choose the **scope**: all sites, or only the domains in a list (everything else connects directly). Changes take effect immediately, even while the switch is on.

## Uninstall

**Windows**: Settings → Apps → Installed apps → remove "GoodbyeDPI for Chrome". Then remove the extension in `chrome://extensions`.

**macOS** (installed with the one-line command):

```bash
rm -rf "$HOME/Library/Application Support/GoodbyeDPIChrome" \
       "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.goodbyedpi.chrome.json"
pkill -f ciadpi
```

**Linux** (installed with the one-line command):

```bash
rm -rf "$HOME/.local/share/GoodbyeDPIChrome" \
       "$HOME/.config/google-chrome/NativeMessagingHosts/com.goodbyedpi.chrome.json"
pkill -f ciadpi
```

## Manual install (developers)

Use this if you load the extension unpacked or want full control.

### Windows

The native host runs on the **PowerShell** built into Windows, so Python is not needed.

1. Get the proxy. In the `backend` folder:

   ```powershell
   powershell -ExecutionPolicy Bypass -File download-ciadpi.ps1
   ```

   This creates `backend\ciadpi.exe` from the latest [byedpi](https://github.com/hufrea/byedpi) release.
2. Load the extension: open `chrome://extensions` → turn on **Developer mode** → **Load unpacked** → choose the `extension` folder. Copy the **ID** shown on the card.
3. Register the native host. In the `native-host` folder:

   ```powershell
   powershell -ExecutionPolicy Bypass -File install-host.ps1 -ExtensionId <your-extension-id>
   ```

   This writes `native-host\com.goodbyedpi.chrome.json` and registers it in the registry. The file contains paths specific to your PC, so it is not committed.
4. Quit Chrome completely and reopen it.

To remove: `powershell -ExecutionPolicy Bypass -File native-host\uninstall-host.ps1`, then `taskkill /IM ciadpi.exe /F` if a proxy is still running.

### macOS / Linux

The byedpi project only ships Windows and Android binaries, so this repository builds `ciadpi` for macOS (universal: Apple Silicon + Intel) and Linux and publishes it in [Releases](https://github.com/qkaTlehdrnf/goodbyedpi_extension/releases/latest). The one-line installer downloads it, so no compiler is needed. If the release can't be downloaded, the script falls back to building from source; only then does macOS need `xcode-select --install` once.

**Unpacked extension with the one-line installer:** an unpacked extension has a different ID from the store version, so pass it at the end:

```bash
curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master/native-host/mac-install.sh | sh -s -- <your-extension-id>
```

**Fully manual from the repository:**

Requirements: Chrome, `git`, `make`, a C compiler and `python3` (macOS: `xcode-select --install`; Debian/Ubuntu: `sudo apt install build-essential git python3`).

1. Build the proxy: in `backend`, run `./get-ciadpi.sh`. This creates `backend/ciadpi`.
2. Load the extension from the store, or unpacked from the `extension` folder.
3. Register the native host. In `native-host`:

   ```bash
   ./install-host.sh                    # uses the Web Store extension ID (default)
   ./install-host.sh <your-extension-id> # for an unpacked extension
   ```

4. Quit Chrome completely and reopen it. The registration survives reboots.

To remove: `./native-host/uninstall-host.sh`, then `pkill -f ciadpi`.

### Without the companion app

You can skip native messaging and run the proxy yourself (Windows example):

1. Double-click `backend\start-ciadpi.bat` and keep the window open.
2. In the extension **Settings**, uncheck "Start/stop the local proxy automatically via the companion app".
3. Turn the switch on. Chrome now uses the proxy you started.

## Notes and limits

- **QUIC / HTTP3 (UDP)**: with the proxy on, Chrome falls back to TCP, which is fine for most sites. If a site fails, disable `chrome://flags/#enable-quic`.
- This tool is meant for **anti-censorship**. Check the laws and policies where you use it.
- `ciadpi` binds to `127.0.0.1` only and cannot be reached from other machines.

## Repository layout

```
extension/     Chrome extension (MV3): popup toggle, proxy control, settings
native-host/   Native host (Windows: PowerShell, macOS/Linux: Python) that starts/stops ciadpi, plus install scripts
installer/     Windows installer (Inno Setup); files/ is a copy of native-host
backend/       Scripts to download / build / run ciadpi by hand, icon generator
```

---

# 한국어

[English](#goodbyedpi-for-chrome) · **한국어**

Chrome **한 곳에서만** DPI(심층 패킷 검사) 우회를 켜고 끄는 확장 프로그램입니다.
켜면 **Chrome 트래픽만** 로컬 우회 프록시로 흐르고, 다른 브라우저·게임·시스템 전체는 영향을 받지 않습니다.

## 빠른 시작

필요한 것은 두 가지입니다. **확장 프로그램**, 그리고 우회 프록시를 실행해 주는 작은 **동반 앱**입니다. 1분이면 끝납니다.

### Windows

1. [Chrome 웹스토어](https://chromewebstore.google.com/detail/aiclkdmpdfgaeaibbpeeaaolkmfkmiog)에서 확장을 설치합니다.
2. **[GoodbyeDPI-for-Chrome-Setup.exe](https://github.com/qkaTlehdrnf/goodbyedpi_extension/releases/latest/download/GoodbyeDPI-for-Chrome-Setup.exe)** 를 내려받아 실행하고 다음을 눌러 설치합니다. 관리자 권한·Python 이 필요 없습니다.
3. **Chrome 을 완전히 종료한 뒤 다시 엽니다.** (창만 닫으면 안 됩니다. 트레이에 Chrome 아이콘이 남아 있으면 우클릭 → 종료.)
4. 툴바의 확장 아이콘을 눌러 스위치를 **ON** 합니다.

### macOS / Linux

1. [Chrome 웹스토어](https://chromewebstore.google.com/detail/aiclkdmpdfgaeaibbpeeaaolkmfkmiog)에서 확장을 설치합니다.
2. **터미널**을 열고 아래 한 줄을 붙여넣은 뒤 Enter:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master/native-host/mac-install.sh | sh
   ```

3. **Chrome 을 완전히 종료**(macOS 는 Cmd+Q)한 뒤 다시 엽니다.
4. 툴바의 확장 아이콘을 눌러 스위치를 **ON** 합니다.

### 잘 되는지 확인

팝업의 두 점이 모두 **초록**이면 성공입니다.

- **Proxy**: Chrome 이 우회 프록시를 사용 중
- **Backend**: 우회 프록시(`ciadpi`)가 실행 중

설치는 한 번만 하면 됩니다. 재부팅해도 유지되고, 이후에는 스위치 하나로 모두 켜고 끕니다.

> **팁:** 동반 앱을 깔기 전에 스위치를 켜면, 확장이 이를 감지해 인터넷을 끊지 않고 위와 같은 다운로드 버튼 / 복사용 명령어를 보여줍니다.
> 단계별 스크린샷: **[설치 단계별 안내](docs/SETUP_GUIDE.md)**

### 그래도 사이트가 안 열리면

1. 팝업 → **Settings** 에서 다른 프리셋(**Light**, **Recommended**, **Strong**)을 골라 보세요. 통신사마다 통하는 조합이 다릅니다.
2. 특정 사이트만 안 되면 `chrome://flags/#enable-quic` 를 **Disabled** 로 바꾸고 Chrome 을 재시작하세요.

## 동작 원리

GoodbyeDPI 자체는 앱 하나에만 적용할 수 없습니다.

- **GoodbyeDPI** 는 `WinDivert` **커널 드라이버**로 원시 TCP 패킷을 조작합니다(TLS ClientHello 조각내기, 역순 전송, 낮은 TTL 의 가짜 패킷, Host 헤더 변형 등). 필터링이 **포트(80/443) 기준이지 앱 기준이 아니라서**, 켜면 시스템 전체에 적용됩니다.
- **Chrome 확장**은 샌드박스 안에 있어 원시 소켓·TCP 세그먼트·TLS 핸드셰이크에 접근할 수 없으므로, 이 기법을 확장 JS 만으로는 재현할 수 없습니다.

그래서 두 부분을 조합합니다.

- **[ByeDPI](https://github.com/hufrea/byedpi) (`ciadpi`)** 는 같은 기법(split·disorder·fake·oob·tlsrec·mod-http)을 커널 드라이버 대신 **로컬 SOCKS5 프록시**로 수행합니다. 소켓을 직접 소유하므로 조각내기·재정렬을 스스로 하고, `127.0.0.1` 에서만 받습니다.
- **확장**은 `chrome.proxy` API 로 **Chrome 트래픽만** `127.0.0.1:1080` 으로 보냅니다. 같은 스위치가 네이티브 메시징으로 `ciadpi` 실행/종료도 함께 제어합니다.

```
 Chrome ──(이 확장이 설정한 SOCKS5 프록시)──▶ 127.0.0.1:1080  ciadpi  ──(DPI 우회)──▶ 인터넷
 다른 앱 ──────────────────────────────────────────(그대로 직접 연결)──────────────▶ 인터넷
```

## 설정

팝업 → **Settings**:

| 프리셋      | ciadpi 인자                                      |
| ----------- | ------------------------------------------------ |
| Light       | `-s 1 -r 1+s`                                    |
| Recommended | `-s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s` |
| Strong      | `-d 1 -f 0 --ttl 1 --auto=torst -r 1+s`          |

`-s` split · `-d` disorder · `-f` fake · `-o` oob · `-r` tlsrec · `-M/--mod-http` HTTP 변형 · `-A/--auto` 차단 감지 시에만 적용.
전체 옵션: https://github.com/hufrea/byedpi

**적용 범위**도 고를 수 있습니다: 전체 사이트, 또는 목록의 도메인만(나머지는 직접 연결). 스위치가 켜진 상태에서도 바꾸면 바로 적용됩니다.

## 제거

**Windows**: 설정 → 앱 → 설치된 앱 에서 "GoodbyeDPI for Chrome" 제거. 그다음 `chrome://extensions` 에서 확장 삭제.

**macOS** (한 줄 설치로 깔았다면):

```bash
rm -rf "$HOME/Library/Application Support/GoodbyeDPIChrome" \
       "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.goodbyedpi.chrome.json"
pkill -f ciadpi
```

**Linux** (한 줄 설치로 깔았다면):

```bash
rm -rf "$HOME/.local/share/GoodbyeDPIChrome" \
       "$HOME/.config/google-chrome/NativeMessagingHosts/com.goodbyedpi.chrome.json"
pkill -f ciadpi
```

## 수동 설치 (개발자용)

압축해제로 확장을 로드하거나 세부 제어가 필요할 때 사용합니다.

### Windows

네이티브 호스트는 Windows 에 기본 포함된 **PowerShell** 로 동작하므로 Python 이 필요 없습니다.

1. 프록시 받기. `backend` 폴더에서:

   ```powershell
   powershell -ExecutionPolicy Bypass -File download-ciadpi.ps1
   ```

   [byedpi](https://github.com/hufrea/byedpi) 최신 릴리스에서 `backend\ciadpi.exe` 가 생깁니다.
2. 확장 로드: `chrome://extensions` → **개발자 모드** ON → **압축해제된 확장 프로그램 로드** → `extension` 폴더 선택. 카드에 표시된 **ID** 를 복사합니다.
3. 네이티브 호스트 등록. `native-host` 폴더에서:

   ```powershell
   powershell -ExecutionPolicy Bypass -File install-host.ps1 -ExtensionId <확장-ID>
   ```

   `native-host\com.goodbyedpi.chrome.json` 을 만들고 레지스트리에 등록합니다. PC 마다 경로가 달라서 저장소에 커밋하지 않습니다.
4. Chrome 을 완전히 종료 후 재실행.

제거: `powershell -ExecutionPolicy Bypass -File native-host\uninstall-host.ps1`, 남은 프록시는 `taskkill /IM ciadpi.exe /F`.

### macOS / Linux

byedpi 공식 릴리스는 Windows/Android 바이너리만 제공하므로, 이 저장소가 macOS(유니버설: Apple Silicon + Intel)·Linux 용 `ciadpi` 를 빌드해 [Releases](https://github.com/qkaTlehdrnf/goodbyedpi_extension/releases/latest) 에 올립니다. 한 줄 설치가 이것을 받으므로 컴파일러가 필요 없습니다. 릴리스를 못 받는 환경이면 소스 빌드로 넘어가며, 그때만 macOS 에서 `xcode-select --install` 이 한 번 필요합니다.

**압축해제 로드 확장 + 한 줄 설치:** 압축해제 로드 확장은 ID 가 스토어판과 다르므로 뒤에 붙여 줍니다.

```bash
curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master/native-host/mac-install.sh | sh -s -- <확장-ID>
```

**저장소에서 완전 수동:**

사전 준비: Chrome, `git`, `make`, C 컴파일러, `python3` (macOS: `xcode-select --install`, Debian/Ubuntu: `sudo apt install build-essential git python3`).

1. 프록시 빌드: `backend` 에서 `./get-ciadpi.sh` → `backend/ciadpi` 생성.
2. 확장을 스토어에서 설치하거나 `extension` 폴더를 압축해제 로드.
3. 네이티브 호스트 등록. `native-host` 에서:

   ```bash
   ./install-host.sh             # 웹스토어 확장 ID 사용 (기본)
   ./install-host.sh <확장-ID>   # 압축해제 로드 확장일 때
   ```

4. Chrome 을 완전히 종료 후 재실행. 등록은 재부팅해도 유지됩니다.

제거: `./native-host/uninstall-host.sh`, 그다음 `pkill -f ciadpi`.

### 동반 앱 없이 쓰기

네이티브 호스트 없이 프록시를 직접 띄워 쓸 수도 있습니다 (Windows 예시).

1. `backend\start-ciadpi.bat` 더블클릭 (창을 열어두는 동안 프록시가 켜져 있음)
2. 확장 **Settings** 에서 "Start/stop the local proxy automatically via the companion app" 체크 해제
3. 스위치 ON → Chrome 만 그 프록시를 사용

## 참고 / 한계

- **QUIC/HTTP3(UDP)**: 프록시를 켜면 Chrome 이 TCP 로 폴백하므로 대부분 문제없습니다. 특정 사이트가 안 되면 `chrome://flags/#enable-quic` 를 Disabled 로 두세요.
- 이 도구는 **검열 우회(anti-censorship)** 용도입니다. 사용 지역의 법·정책을 확인하세요.
- `ciadpi` 는 `127.0.0.1` 로만 바인딩되어 외부에서 접근할 수 없습니다.

## 폴더 구조

```
extension/     Chrome 확장 (MV3): 팝업 토글 · 프록시 제어 · 설정
native-host/   네이티브 호스트 (Windows: PowerShell, macOS/Linux: Python): ciadpi 자동 실행/종료 + 설치 스크립트
installer/     Windows 설치 프로그램 (Inno Setup) · files/ 는 native-host 의 사본
backend/       ciadpi 내려받기·빌드·수동 실행 스크립트, 아이콘 생성기
```
