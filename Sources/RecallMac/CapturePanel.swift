import AppKit
import SwiftUI

@MainActor
final class CapturePanelController: ObservableObject {
    enum PanelState: Equatable {
        case compact
        case expanded
        case saved
    }

    @Published private(set) var panelState: PanelState = .compact
    private var panel: RecallCapturePanel?
    private var collapseTask: Task<Void, Never>?
    private var savedTask: Task<Void, Never>?
    private var frameTask: Task<Void, Never>?
    @Published private var retainsExpandedFrame = false

    var topInset: CGFloat {
        (NSScreen.main ?? NSScreen.screens.first)?.safeAreaInsets.top ?? 0
    }

    var compactWidth: CGFloat {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return 156 }
        return screen.frame.width - left.width - right.width + 20
    }

    // Keep the expanded surface intentionally compact. The idle width follows
    // the screen's camera/menu-bar safe areas; the action surface should still
    // read as a focused control instead of a wide banner.
    var expandedWidth: CGFloat {
        min(max(360, compactWidth + 48), 520)
    }

    private var expandedHeight: CGFloat { topInset + 72 }

    var panelSize: CGSize {
        switch panelState {
        case .compact:
            return retainsExpandedFrame
                ? CGSize(width: expandedWidth, height: expandedHeight)
                : CGSize(width: compactWidth, height: topInset > 0 ? topInset + 2 : 20)
        case .expanded:
            return CGSize(width: expandedWidth, height: expandedHeight)
        case .saved:
            return CGSize(width: expandedWidth, height: expandedHeight)
        }
    }

    func show(store: LibraryStore) {
        if let panel {
            applyWindowFrame()
            panel.orderFrontRegardless()
            return
        }

        let contentView = NSHostingView(
            rootView: CapturePanelView(controller: self)
                .environmentObject(store)
        )
        contentView.frame = NSRect(origin: .zero, size: panelSize)
        contentView.autoresizingMask = [.width, .height]

        let capturePanel = RecallCapturePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        capturePanel.contentView = contentView
        capturePanel.setContentSize(panelSize)
        capturePanel.backgroundColor = .clear
        capturePanel.isOpaque = false
        capturePanel.hasShadow = false
        capturePanel.level = .statusBar
        capturePanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        capturePanel.hidesOnDeactivate = false
        capturePanel.ignoresMouseEvents = false
        capturePanel.onMouseDown = { RecallHaptics.play(.levelChange, pulses: 2) }

        panel = capturePanel
        applyWindowFrame()
        capturePanel.orderFrontRegardless()
    }

    func setState(_ state: PanelState) {
        switch state {
        case .compact:
            // The drag system can briefly report that the pointer left the target
            // while the panel is changing size. Keep the expanded hit region alive
            // for a beat so it does not jitter under the screenshot thumbnail.
            collapseTask?.cancel()
            collapseTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 90_000_000)
                guard let self, !Task.isCancelled, self.panelState != .compact else { return }
                // Allow the artwork to settle before trimming the hosting window.
                self.retainsExpandedFrame = true
                self.panelState = .compact
                self.frameTask?.cancel()
                self.frameTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard let self, !Task.isCancelled, self.panelState == .compact else { return }
                    self.retainsExpandedFrame = false
                    self.applyWindowFrame()
                }
            }

        case .expanded:
            frameTask?.cancel()
            retainsExpandedFrame = false
            collapseTask?.cancel()
            savedTask?.cancel()
            guard panelState != .expanded else { return }
            panelState = .expanded
            applyWindowFrame()

        case .saved:
            frameTask?.cancel()
            retainsExpandedFrame = false
            collapseTask?.cancel()
            savedTask?.cancel()
            panelState = .saved
            applyWindowFrame()

            savedTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, !Task.isCancelled, self.panelState == .saved else { return }
                self.setState(.compact)
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func applyWindowFrame() {
        guard let panel else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        let size = panelSize
        let x = screenFrame.midX - size.width / 2
        // The panel's upper edge sits just inside the screen edge; the idle shape
        // visually tucks into the menu-bar area without touching the physical notch.
        let y = screenFrame.maxY - size.height + 1
        let frame = NSRect(origin: NSPoint(x: x, y: y), size: size)
        // SwiftUI owns the visual transition. Animating the NSPanel frame as well
        // makes the hit region chase the pointer and produces drag lag.
        panel.setFrame(frame, display: true, animate: false)
        panel.contentView?.setFrameSize(size)
    }
}

private final class RecallCapturePanel: NSPanel {
    var onMouseDown: (() -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            onMouseDown?()
        }
        super.sendEvent(event)
    }
}

private struct CapturePanelView: View {
    @ObservedObject var controller: CapturePanelController
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        VStack(spacing: 0) {
            CaptureOverlay(
                onBrowse: store.importWithOpenPanel,
                compactMode: controller.panelState == .compact,
                panelState: controller.panelState,
                onPanelStateChange: controller.setState,
                topInset: controller.topInset,
                compactWidth: controller.compactWidth
            )
            Spacer(minLength: 0)
        }
        .frame(width: controller.panelSize.width, height: controller.panelSize.height, alignment: .top)
        .background(Color.clear)
    }
}
