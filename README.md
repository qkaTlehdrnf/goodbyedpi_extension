# /ㅠGoodbyeDPI for Chrome

Chrome **한 곳에서만** DPI(심층 패킷 검사) 우회를 켜고 끄는 확장 프로그램입니다.
켜면 **Chrome 트래픽만** 로컬 우회 프록시로 흐르고, 다른 앱(다른 브라우저·게임·Windows 자체)은 전혀 영향을 받지 않습니다.

---

## 왜 이런 구조인가 (중요)

먼저 GoodbyeDPI 동작 방식을 조사했습니다.

- **GoodbyeDPI** 는 `WinDivert` **커널 드라이버**로 네트워크/전송 계층에서 **원시 TCP 패킷**을 조작합니다.

  - TLS ClientHello / HTTP 요청을 **조각내기(fragmentation)**, **역순 전송(disorder)**, **가짜 패킷(fake, 낮은 TTL·잘못된 체크섬)**, **Host 헤더 변형** 등.
  - 필터링은 **포트 기준(80/443)** 이며 **프로세스(앱) 기준이 아닙니다.** → 그래서 "Chrome만" 적용이 원천적으로 불가능합니다. 켜면 시스템 전체에 적용됩니다.
- **Chrome 확장 프로그램**은 샌드박스 안에 있어 **원시 소켓·TCP 세그먼트·TLS 핸드셰이크**에 접근할 수 없습니다.
  확장이 볼 수 있는 시점엔 이미 TCP/TLS 연결이 끝나 있어서, GoodbyeDPI의 핵심 기법을 **순수 JS 확장만으로는 재현할 수 없습니다.**

### 그래서 실제로 "Chrome 전용"이 되는 방법

> **확장(프록시 토글) + 로컬 우회 프록시(ByeDPI / `ciadpi.exe`)**

- `ciadpi` 는 GoodbyeDPI 와 **같은 기법(split·disorder·fake·oob·tlsrec·mod-http)** 을 쓰지만, 커널 드라이버 대신
  **로컬 SOCKS5 프록시**로 동작합니다. 소켓을 자기가 소유하므로 조각내기·재정렬 등을 스스로 수행합니다.
- 확장은 Chrome 의 `chrome.proxy` API 로 **Chrome 트래픽만** `127.0.0.1:1080` 로 보냅니다.
  이 프록시 설정은 **Chrome 에만 적용**되므로 → **다른 앱은 우회를 쓰지 않습니다.** ✅ 요구사항 충족.
- 확장의 토글이 (1) 프록시 On/Off 와 (2) `ciadpi.exe` 실행/종료를 함께 제어합니다.

```
 Chrome ──(이 확장이 설정한 SOCKS5 프록시)──▶ 127.0.0.1:1080  ciadpi.exe  ──(DPI 우회)──▶ 인터넷
 다른 앱 ────────────────────────────────────────────────(그대로 직접 연결)────────────▶ 인터넷
```

---

## 설치 (Windows)

### 사전 준비

- Windows + Chrome
- Python 3 (자동 실행용 네이티브 호스트에 필요). `python --version` 으로 확인.

### 1) 우회 프록시(ciadpi) 내려받기

`backend` 폴더에서 PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File download-ciadpi.ps1
```

→ `backend\ciadpi.exe` 가 생깁니다. (출처: https://github.com/hufrea/byedpi 최신 릴리스)

### 2) 확장 프로그램 로드

1. Chrome 에서 `chrome://extensions` 열기 → 오른쪽 위 **개발자 모드** ON
2. **압축해제된 확장 프로그램 로드** → 이 프로젝트의 **`extension`** 폴더 선택
3. 표시된 **ID**(예: `abcdef...`) 를 복사

### 3) 네이티브 호스트 등록 (토글 하나로 자동 실행되게)

`native-host` 폴더에서 PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File install-host.ps1 -ExtensionId 붙여넣은_ID
```

그다음 **Chrome 을 완전히 종료 후 재실행**.

### 4) 사용

툴바의 아이콘 클릭 → 큰 스위치로 **켜짐/꺼짐**. 끝.

- 팝업의 상태 표시:
  - **프록시**: 초록 = Chrome 이 우회 프록시를 사용 중
  - **백엔드**: 초록 = `ciadpi.exe` 실행 중

---

## macOS / Linux

`ciadpi` 는 크로스플랫폼 C 코드지만 공식 릴리스는 Windows/Android 바이너리만 제공하므로, 데스크톱 *nix 는 소스에서 빌드합니다.
단계별 화면과 함께 보려면 → **[설치 단계별 안내 (스크린샷)](docs/SETUP_GUIDE.md)**

### 가장 간단: 한 줄 설치 (권장)

웹스토어에서 확장을 설치한 뒤, 터미널에 아래 **한 줄**만 붙여넣으면 됩니다. 네이티브 호스트 다운로드 · `ciadpi` 빌드 · 등록까지 자동으로 하고, 재부팅해도 유지됩니다. (확장 팝업의 안내 패널에서 이 명령을 복사할 수도 있습니다.)

```bash
curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master/native-host/mac-install.sh | sh
```

그다음 **Chrome 을 완전히 종료(Cmd+Q) 후 재실행** → 토글 ON. 빌드 도구가 없으면 macOS 에서 `xcode-select --install` 를 한 번 실행하세요.

> 개발용(압축해제 로드) 확장은 ID 가 달라 위 한 줄로는 안 됩니다. 아래 수동 절차에서 `./install-host.sh <확장-ID>` 로 그 ID 를 넘기세요.

### 수동 설치 (개발용 / 세부 제어)

#### 사전 준비

- Chrome
- `git`, `make`, C 컴파일러 · `python3` (네이티브 호스트용)
  - macOS: `xcode-select --install` (이 한 번으로 컴파일러 + python3 대부분 해결)
  - Linux(Debian/Ubuntu): `sudo apt install build-essential git python3`

#### 1) 우회 프록시(ciadpi) 빌드

`backend` 폴더에서:

```bash
./get-ciadpi.sh
```

→ `backend/ciadpi` 가 생깁니다. (출처: https://github.com/hufrea/byedpi)

#### 2) 확장 프로그램 로드

웹스토어에서 설치하거나, 개발용이면 `chrome://extensions` → 개발자 모드 → **압축해제된 확장 로드** → `extension` 폴더 선택.

#### 3) 네이티브 호스트 등록 (토글 하나로 자동 실행 · 영구)

`native-host` 폴더에서:

```bash
./install-host.sh                # 웹스토어 버전 ID 사용 (기본)
./install-host.sh <확장-ID>      # 개발용(압축해제 로드) 확장이면 그 ID를 전달
```

그다음 **Chrome 을 완전히 종료 후 재실행**. 이 등록은 재부팅해도 유지되므로 다시 할 필요가 없습니다.

#### 4) 사용

툴바 아이콘 → 토글 ON. 확장이 `ciadpi` 를 자동 실행/종료하고 Chrome 트래픽만 프록시로 보냅니다.

### 이번 세션만 (등록 없이)

`native-host` 등록을 건너뛰고 터미널에서 직접 띄워도 됩니다. 창을 열어둔 동안만 동작합니다:

```bash
./ciadpi -i 127.0.0.1 -p 1080 -s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s
```

그리고 확장 **설정**에서 "자동 실행" 을 끄고 토글 ON. (팝업의 안내 패널에서 이 명령을 복사할 수도 있습니다.)

### 제거 (macOS / Linux)

한 줄 설치로 깔았다면:

```bash
rm -rf "$HOME/Library/Application Support/GoodbyeDPIChrome" \
       "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.goodbyedpi.chrome.json"
pkill -f ciadpi
```

저장소에서 수동 등록했다면:

```bash
./native-host/uninstall-host.sh
pkill -f ciadpi   # 남은 프록시 종료
```

---

## 자동 실행 없이 쓰기 (네이티브 호스트 생략)

Python 설치가 싫으면 3단계를 건너뛰고:

1. `backend\start-ciadpi.bat` 더블클릭 (이 창을 열어두면 프록시가 켜진 상태)
2. 확장 팝업에서 토글 ON → Chrome 만 프록시 사용
3. 확장 **설정**에서 "ciadpi.exe 자동 실행" 체크 해제

---

## 우회 전략 바꾸기 (설정 페이지)

ISP·지역마다 통하는 조합이 다릅니다. 팝업 → **설정** 에서 프리셋 선택 또는 직접 입력:

| 프리셋     | 인자                                               |
| ---------- | -------------------------------------------------- |
| 가벼움     | `-s 1 -r 1+s`                                    |
| 권장       | `-s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s` |
| 강력(fake) | `-d 1 -f 0 --ttl 1 --auto=torst -r 1+s`          |

`-s` split · `-d` disorder · `-f` fake · `-o` oob · `-r` tlsrec · `-M/--mod-http` HTTP 변형 · `-A/--auto` 차단 감지 시 자동 적용.
전체 옵션: https://github.com/hufrea/byedpi

**적용 범위**도 고를 수 있습니다: *전체 사이트* 또는 *지정한 도메인만*(나머지는 직접 연결).

---

## 제거

```powershell
powershell -ExecutionPolicy Bypass -File native-host\uninstall-host.ps1
```

그리고 `chrome://extensions` 에서 확장 삭제. 남은 프록시는 `taskkill /IM ciadpi.exe /F`.

---

## 참고 / 한계

- **QUIC/HTTP3(UDP)**: 프록시를 켜면 Chrome 이 TCP 로 폴백하므로 대부분 문제없지만, 특정 사이트가 안 되면
  `chrome://flags/#enable-quic` 를 **Disabled** 로 두세요.
- 이 도구는 **검열 우회(anti-censorship)** 용도입니다. 사용 지역의 법·정책을 확인하세요.
- `ciadpi.exe` 는 `127.0.0.1` 로만 바인딩되어 외부에서 접근할 수 없습니다.

## 폴더 구조

```
extension/        Chrome 확장 (MV3): 팝업 토글 · 프록시 제어 · 설정
native-host/      Python 네이티브 호스트: ciadpi.exe 자동 실행/종료 + 설치 스크립트
backend/          ciadpi 내려받기·수동 실행 스크립트, 아이콘 생성기
```
