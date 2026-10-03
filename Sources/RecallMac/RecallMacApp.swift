import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
}

@main
struct RecallMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LibraryStore()
    @StateObject private var capturePanel = CapturePanelController()

    var body: some Scene {
        WindowGroup("Doubtabase") {
            LibraryView()
                .environmentObject(store)
                .onAppear {
                    capturePanel.show(store: store)
                }
                .onDisappear {
                    capturePanel.hide()
                }
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.updaterController.checkForUpdates(nil)
                }
                .disabled(!appDelegate.updaterController.updater.canCheckForUpdates)
            }
        }
    }
}
