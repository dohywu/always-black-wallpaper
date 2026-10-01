# 변경 이력

버전 형식은 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

- MAJOR: 기존 동작과 호환되지 않는 변경
- MINOR: 기능 추가
- PATCH: 버그 수정

각 버전은 GitHub에 `vX.Y.Z` 태그와 Release로 올라갑니다.

## [1.2.0] - 2026-10-01

### 변경
- 평소에는 Dock에 아이콘을 표시하지 않고 메뉴바에만 있습니다 (`LSUIElement`).
- 메뉴바에서 **창 열기…**를 누르면 창과 함께 Dock 아이콘이 나타나고, 창을 닫으면 Dock 아이콘이 사라집니다. 앱은 계속 실행됩니다.

## [1.1.0] - 2026-10-01

### 추가
- **즉시 적용** 토글 (기본 켜짐): 모니터 연결·Space 전환 알림이 오면 0.5초 기다리지 않고 바로 검은 배경을 적용합니다.
  끄면 연속 알림이 끝난 뒤 0.5초 후에 한 번만 적용합니다.
- **깜빡임 방지 덮개** 토글 (기본 꺼짐): 외장 디스플레이의 배경화면 바로 위에 검은 창을 깔아 둡니다.
  모든 Space에 고정되어 Space 전환 때 이전 배경화면이 보이지 않습니다. 클릭은 통과하고, 바탕화면 아이콘과 위젯은 덮개 위에 보입니다.
- 앱 창 하단과 메뉴바 메뉴에 앱 버전 표시.

### 수정
- 깜빡임 방지 덮개가 켜져 있으면 Dock 아이콘을 눌러도 앱 창이 열리지 않던 문제.

## [1.0.0] - 2026-09-28

### 추가
- 빌트인을 제외한 모든 디스플레이에 검은 배경화면 적용.
- 디스플레이 연결/해제/해상도 변경, Space 전환, 잠자기에서 깨어날 때 자동 재적용 (0.5초 debounce).
- `black.png`를 첫 실행 시 Application Support에 코드로 생성.
- 끄면 원래 배경화면으로 복원.
- 로그인 시 자동 실행 (`SMAppService.mainApp`).
- 앱 창과 메뉴바 아이콘.
- 앱 아이콘 (`ABW-icon.icon`).

[1.2.0]: https://github.com/dohywu/always-black-wallpaper/releases/tag/v1.2.0
[1.1.0]: https://github.com/dohywu/always-black-wallpaper/releases/tag/v1.1.0
[1.0.0]: https://github.com/dohywu/always-black-wallpaper/releases/tag/v1.0.0
