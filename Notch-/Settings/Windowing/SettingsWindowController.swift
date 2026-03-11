import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController(settingsStore: AppSettingsStore.shared)

    private static let defaultWindowSize = NSSize(width: 920, height: 720)
    private static let minimumWindowSize = NSSize(width: 880, height: 680)

    private let settingsStore: AppSettingsStore

    private init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        setupWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        guard let window else { return }

        window.title = "Controll Notch Settings"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = false
        window.isRestorable = true
        window.setContentSize(Self.defaultWindowSize)
        window.minSize = Self.minimumWindowSize
        window.identifier = NSUserInterfaceItemIdentifier("NotchSettingsWindow")
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: SettingsView(settings: settingsStore)
        )
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)

        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.orderFrontRegardless()
            window?.makeKeyAndOrderFront(nil)
            return
        }

        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }

    override func close() {
        super.close()
        relinquishFocus()
    }

    private func relinquishFocus() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        relinquishFocus()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
