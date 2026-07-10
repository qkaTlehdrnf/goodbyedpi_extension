# Chrome Web Store — 리스팅 작성용 자료

개발자 콘솔(https://chrome.google.com/webstore/devconsole)의 각 칸에 아래 내용을 붙여넣으세요.

---

## Item name
GoodbyeDPI for Chrome

## Summary (최대 132자)
Toggle DPI-bypass for Chrome only. Routes just this browser through a local ByeDPI proxy so other apps stay untouched.

## Category
Productivity (또는 Tools)

## Language
English / 한국어

---

## Detailed description (붙여넣기)

GoodbyeDPI for Chrome lets you turn censorship-circumvention (DPI bypass) on and off with a single toggle — and it applies to THIS browser only.

How it works
• When ON, the extension routes Chrome's traffic through a local ByeDPI (ciadpi) SOCKS5 proxy running on 127.0.0.1.
• The proxy applies DPI-desync techniques (TLS record splitting, packet reordering, fake packets) that many DPI systems fail to inspect.
• Because only Chrome is pointed at the proxy, other apps, other browsers, and other Chrome profiles are NOT affected.

Requirements
• Windows.
• The free companion app "GoodbyeDPI for Chrome (backend)" must be installed once — it contains the local proxy the extension controls. Download: https://github.com/qkaTlehdrnf/goodbyedpi-chrome/releases/latest/download/GoodbyeDPI-for-Chrome-Setup.exe
  (A browser extension cannot manipulate TCP/TLS packets by itself, so the actual bypass runs in this small local helper.)

Privacy
• No data is collected, stored, or transmitted to us. All traffic stays between your PC and the sites you visit.

This is an anti-censorship tool. Please follow the laws and policies that apply where you use it.

---

## Single purpose (정책상 필수 한 줄)
Enable or disable a local DPI-bypass proxy for the user's Chrome browser via a single toggle.

---

## Permission justifications (각 권한 사유 — 콘솔에 입력)

- **proxy**: To route this browser's traffic through the local DPI-bypass proxy (127.0.0.1) while enabled, and to clear it when disabled. This is the extension's core function.
- **storage**: To remember the on/off state and the user's proxy port and bypass-strategy settings.
- **nativeMessaging**: To start and stop the bundled local proxy (ciadpi.exe) through the companion app, so the user only needs one toggle.
- **host access**: The extension does not request host permissions; it does not read page content.

## Data usage disclosures (콘솔 체크박스)
- Does your item collect user data? → **No.**
- 판매/양도 없음, 광고 없음, 신용 목적 사용 없음 모두 체크.

## Privacy policy URL (필수)
PRIVACY.md 를 공개 URL(GitHub Pages, Gist 등)에 올리고 그 주소를 입력하세요.

---

## 심사 시 주의 (읽어두기)
- **companion app 필요**를 설명에 반드시 명시하세요. 심사자가 확장만 설치하고 "작동 안 함"으로 볼 수 있으므로,
  팝업에 이미 "백엔드 미설치" 안내가 뜨도록 되어 있습니다. 설명의 다운로드 URL을 실제 링크로 채우세요.
- DPI 우회 = 검열 우회 도구입니다. 정직하게 기술하면 정책상 허용되지만, 심사에서 추가 질문이 올 수 있습니다.
- 스크린샷 1280x800 최소 1장 필요: 팝업 토글 ON 화면을 캡처하세요.

## 게시 후 할 일 (중요)
1. 업로드하면 **영구 확장 ID**가 생깁니다 (모든 사용자 공통). 대시보드에서 확인.
2. 그 ID를 다음에 넣으세요:
   - `installer/install.ps1` 의 `$StoreExtensionId`
   - `installer/setup.iss` 의 `MyStoreId`
3. Inno Setup 으로 `setup.iss` 컴파일 → `GoodbyeDPI-for-Chrome-Setup.exe` 생성 → 다운로드 링크로 배포.
4. (선택) 스토어 공개키를 `extension/manifest.json` 의 `"key"` 로 추가하면, 개발용 Load unpacked ID 도 스토어 ID 와 같아져 테스트가 편합니다.
