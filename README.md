# Always Black Wallpaper

빌트인 디스플레이를 **제외한** 모든 디스플레이의 배경화면을 검은색 단색으로 유지하는 macOS 메뉴바 앱입니다. 처음 연결하는 모니터에도 자동으로 적용됩니다.

기존 Hammerspoon 설정(`hs.screen.watcher` + `desktopImageURL`)을 독립 앱으로 옮긴 것입니다.

## 동작 방식

| 시점 | API |
| --- | --- |
| 앱 실행 | `NSScreen.screens` 중 `CGDisplayIsBuiltin`이 false인 디스플레이에 적용 |
| 디스플레이 연결/해제, 해상도·배치 변경 | `NSApplication.didChangeScreenParametersNotification` |
| Space 전환 (`setDesktopImageURL`은 각 디스플레이의 현재 Space에만 적용됨) | `NSWorkspace.activeSpaceDidChangeNotification` |
| 잠자기에서 깨어남 | `NSWorkspace.didWakeNotification`, `NSWorkspace.screensDidWakeNotification` |

- 모든 알림은 0.5초 debounce를 거칩니다. 알림이 연속으로 와도 한 번만 적용합니다.
- 이미 `black.png`인 디스플레이는 건너뜁니다. 배경화면을 불필요하게 다시 쓰지 않습니다.
- `black.png`(64×64 검은색)는 첫 실행 시 코드로 생성합니다.
  위치: `~/Library/Application Support/AlwaysBlackWallpaper/black.png`.
  `imageScaling = scaleAxesIndependently`, `fillColor = black` 옵션으로 적용하므로 어떤 해상도에서도 화면을 채웁니다.
- **끄면 원래 배경화면으로 복원:** 디스플레이를 검은색으로 바꾸기 전에 기존 배경화면 URL을
  `UserDefaults`(`originalWallpapers`)에 디스플레이 UUID별로 저장합니다. 토글을 끄면 이 URL로 복원합니다.
  다시 켜면 그 시점의 배경화면을 새로 저장합니다.
- **로그인 시 자동 실행:** `SMAppService.mainApp` 사용.
- 앱 창(설정, 디스플레이 목록)과 메뉴바 아이콘이 모두 있습니다. 로그인 시 실행될 때는 창을 띄우지 않습니다
  (`defaultLaunchBehavior(.suppressed)`). 창은 메뉴바 메뉴나 Dock 아이콘 클릭으로 엽니다.
  창을 닫아도 앱은 종료되지 않습니다. 종료는 메뉴바 메뉴에서 합니다.

## 호환성 확인 결과 (macOS 27.0, Apple Silicon)

- `NSWorkspace.setDesktopImageURL(_:for:options:)`, `desktopImageURL(for:)`: 정상 동작, deprecated 아님.
  실제 확인: 외장 DELL U2723QE는 `black.png`로 바뀌고, 빌트인 디스플레이는 그대로였습니다.
- `didChangeScreenParametersNotification`, `activeSpaceDidChangeNotification`: deprecated 아님.
- `SMAppService`(macOS 13+): 사용 가능. `defaultLaunchBehavior` 때문에 앱 최소 요구 버전은 macOS 15입니다.
- App Sandbox 꺼짐, Hardened Runtime 꺼짐, ad-hoc 서명("Sign to Run Locally").

## 빌드 및 설치

### 방법 A: Xcode

1. `AlwaysBlackWallpaper.xcodeproj`를 엽니다.
2. `AlwaysBlackWallpaper` 스킴과 "My Mac"을 선택하고 ⌘R로 실행합니다.
3. 릴리스 빌드: **Product > Archive** → **Distribute App > Custom > Copy App**으로 내보낸 뒤
   `Always Black Wallpaper.app`을 `/Applications`로 옮깁니다.
   터미널에서 빌드하려면:
   ```bash
   xcodebuild -project AlwaysBlackWallpaper.xcodeproj -scheme AlwaysBlackWallpaper -configuration Release -derivedDataPath build/xcode
   ```
   ```bash
   cp -R "build/xcode/Build/Products/Release/Always Black Wallpaper.app" /Applications/
   ```

Apple ID 팀으로 서명하려면 **Signing & Capabilities**에서 Team을 지정하고 "Automatically manage signing"을 켭니다.
App Sandbox capability는 추가하지 마세요.

### 방법 B: Xcode 없이 (Command Line Tools만)

`build.sh`가 `swiftc`로 컴파일하고 `.app` 번들을 직접 만듭니다.

```bash
./build.sh --install
```

`build/Always Black Wallpaper.app`을 빌드하고, `/Applications`에 복사한 뒤 실행합니다.
`--install` 없이 실행하면 빌드만 합니다.

일부 Command Line Tools 버전은 `ServiceManagement`를 import할 때 `redefinition of module 'SwiftBridging'` 에러가 납니다.
`build.sh`는 이 경우를 감지해서 VFS overlay로 우회합니다. 시스템 파일은 수정하지 않습니다.

### 로그인 시 자동 실행

1. 먼저 앱을 `/Applications`에 설치합니다. `SMAppService.mainApp`은 앱의 현재 경로를 등록합니다.
2. 앱 창에서 **로그인 시 자동 실행**을 켭니다.
3. "허용 필요"가 표시되면 **열기**를 눌러 **시스템 설정 > 일반 > 로그인 항목**에서 허용합니다.

등록 후 앱 위치를 옮겼다면 토글을 껐다가 다시 켜세요.

## 알려진 제약

- `setDesktopImageURL`은 각 디스플레이의 **현재 Space**만 바꿉니다. 다른 Space는 전환하는 순간 검은색으로 바뀝니다.
  전환 직후 약 0.5초 동안 이전 배경화면이 보일 수 있습니다.
- 복원은 디스플레이당 배경화면 하나만 기억합니다. Space별로 기억하지 않습니다.
- 원래 배경화면이 다이내믹/Aerial 배경화면이면, macOS가 보고한 파일 URL(예: `/System/Library/CoreServices/DefaultDesktop.heic`)로 복원합니다.
  원래 모습과 다를 수 있습니다.
- Sidecar, AirPlay 디스플레이도 외장으로 취급되어 검은색이 됩니다.

## 파일 구성

```
AlwaysBlackWallpaper/
  AlwaysBlackWallpaperApp.swift  앱 진입점, 창, 메뉴바
  ContentView.swift              설정 창
  WallpaperManager.swift         알림 감지, debounce, 적용/복원, black.png 생성
  LoginItemManager.swift         SMAppService.mainApp 래퍼
  Info.plist
AlwaysBlackWallpaper.xcodeproj
build.sh                         Xcode 없이 swiftc로 빌드
```

## 설정 초기화

```bash
defaults delete com.dohywu.AlwaysBlackWallpaper
```
