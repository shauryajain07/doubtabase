import SwiftUI

@main
struct RecallMacApp: App {
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
    }
}
