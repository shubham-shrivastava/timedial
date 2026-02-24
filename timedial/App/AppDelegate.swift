import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var sizeObserver: AnyCancellable?
    private var pickerBehaviorObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Keep TimeDial menu bar item alive")

        let appState = AppState.shared

        let contentView = ContentView()
            .environmentObject(appState)

        let initialSize = appState.preferredPopoverSize
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: initialSize.width, height: initialSize.height)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.sizingOptions = []   // Prevent auto-reporting preferredContentSize
        popover.contentViewController = hostingController

        sizeObserver = appState.$preferredPopoverSize
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] newSize in
                self?.popover.contentSize = NSSize(width: newSize.width, height: newSize.height)
            }

        pickerBehaviorObserver = appState.$activePickerMode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.popover.behavior = mode != nil ? .applicationDefined : .transient
            }

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
        AppState.shared.pickerPanel.close()
        AppState.shared.isPopoverVisible = false
    }
}
