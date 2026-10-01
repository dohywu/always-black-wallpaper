import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var wallpaper: WallpaperManager
    @EnvironmentObject private var loginItem: LoginItemManager

    var body: some View {
        Form {
            Section {
                Toggle("외장 디스플레이 검은 배경 유지", isOn: $wallpaper.isEnabled)
                Text("끄면 앱이 처음 검은색으로 바꾸기 전의 배경화면으로 복원합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("즉시 적용", isOn: $wallpaper.applyImmediately)
                    .disabled(!wallpaper.isEnabled)
                Text("모니터 연결·Space 전환 알림이 오면 0.5초 기다리지 않고 바로 검은색으로 바꿉니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("깜빡임 방지 덮개", isOn: $wallpaper.overlayEnabled)
                    .disabled(!wallpaper.isEnabled)
                Text("외장 디스플레이의 배경화면 바로 위에 검은 창을 깔아 둡니다. 모든 Space에 고정되어 Space 전환 때 이전 배경화면이 보이지 않습니다. 바탕화면 아이콘과 위젯은 그대로 보입니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { loginItem.isEnabled || loginItem.requiresApproval },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.requiresApproval {
                    HStack {
                        Text("시스템 설정 > 로그인 항목에서 허용이 필요합니다.")
                            .font(.caption)
                        Button("열기") { loginItem.openSystemSettings() }
                    }
                }
                if let error = loginItem.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("디스플레이") {
                ForEach(wallpaper.displays) { display in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(display.name)
                            Spacer()
                            Text(display.isBuiltin ? "빌트인 · 제외" : "외장")
                                .font(.caption)
                                .foregroundStyle(display.isBuiltin ? Color.secondary : Color.accentColor)
                        }
                        Text(display.wallpaperPath ?? "알 수 없음")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(display.wallpaperPath ?? "")
                    }
                }
            }

            Section {
                HStack {
                    Button("지금 다시 적용") { wallpaper.applyNow() }
                        .disabled(!wallpaper.isEnabled)
                    Spacer()
                    if let date = wallpaper.lastApplied {
                        Text("마지막 적용: \(date.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = wallpaper.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } footer: {
                Text("버전 \(AppVersion.display)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            wallpaper.refreshDisplays()
            loginItem.refresh()
        }
    }
}
