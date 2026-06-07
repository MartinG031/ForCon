import SwiftUI

@main
struct ForConApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowStyle(.titleBar)

        Window("关于 ForCon", id: "about-forcon") {
            AboutForConView()
        }
        .windowResizability(.contentSize)
        .commands {
            ForConCommands()
        }
    }
}

private struct ForConCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 ForCon") {
                openWindow(id: "about-forcon")
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("添加文件...") {
                post(.forConAddFiles)
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("选择输出目录...") {
                post(.forConChooseOutputDirectory)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button("开始转换") {
                post(.forConStartConversion)
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button("清空列表") {
                post(.forConClearFiles)
            }
            .keyboardShortcut(.delete, modifiers: [.command])

            Divider()

            Button("自动更新") {
                post(.forConCheckForUpdates)
            }
            .keyboardShortcut("u", modifiers: [.command])
        }

        CommandGroup(replacing: .help) {
            Button("ForCon GitHub") {
                if let url = URL(string: "https://github.com/MartinG031/ForCon") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
