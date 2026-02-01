import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Keep TimeDial menu bar item alive")

        let contentView = ContentView()
            .environmentObject(AppState.shared)
            .frame(width: 600, height: 420)

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 600, height: 420)
        popover.contentViewController = NSHostingController(rootView: contentView)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.autosaveName = "TimeDialStatusItem"
        statusItem?.isVisible = true
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "TimeDial") {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageLeft
            }
            button.title = ""
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let anchor = NSRect(
                x: button.bounds.midX - 1,
                y: button.bounds.minY,
                width: 2,
                height: button.bounds.height
            )
            popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func popoverWillShow(_ notification: Notification) {
        AppState.shared.isPopoverVisible = true
    }

    func popoverDidClose(_ notification: Notification) {
        AppState.shared.isPopoverVisible = false
    }
}
