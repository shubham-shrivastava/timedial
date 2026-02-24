//
//  PickerPanelController.swift
//  timedial
//
//  Manages a native NSPanel for the timezone picker dropdown.
//  This avoids the crash-prone nested SwiftUI .popover() inside
//  the menu bar NSPopover.
//

import AppKit
import SwiftUI
import Combine

// MARK: - Screen Frame Helpers

class ScreenFrameRef: ObservableObject {
    weak var nsView: NSView?

    var screenFrame: CGRect {
        guard let view = nsView, let window = view.window else { return .zero }
        let frameInWindow = view.convert(view.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }
}

struct ScreenFrameCapture: NSViewRepresentable {
    let ref: ScreenFrameRef

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        ref.nsView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        ref.nsView = nsView
    }
}

// MARK: - Keyable Panel (borderless but accepts keyboard input)

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Picker Panel Controller

@MainActor
class PickerPanelController {
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyMonitor: Any?

    var onDismiss: (() -> Void)?

    func show(at sourceFrame: CGRect, appState: AppState, onSelect: @escaping (String) -> Void) {
        close()

        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 420

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovable = false
        panel.hidesOnDeactivate = false

        let content = TimezonePickerPanel(
            onSelect: { [weak self] id in
                onSelect(id)
                self?.close()
            },
            onDismiss: { [weak self] in
                self?.close()
            }
        )
        .environmentObject(appState)

        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView

        let origin = panelOrigin(
            sourceFrame: sourceFrame,
            panelSize: NSSize(width: panelWidth, height: panelHeight)
        )
        panel.setFrameOrigin(origin)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        installEventMonitors()
    }

    func close() {
        removeEventMonitors()

        guard let panel else { return }
        let captured = panel
        self.panel = nil

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            captured.animator().alphaValue = 0
        } completionHandler: {
            captured.orderOut(nil)
        }

        onDismiss?()
    }

    var isVisible: Bool { panel != nil }

    // MARK: - Positioning

    private func panelOrigin(sourceFrame: CGRect, panelSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSPoint(x: sourceFrame.midX - panelSize.width / 2,
                           y: sourceFrame.minY - panelSize.height - 4)
        }
        let visibleFrame = screen.visibleFrame
        let gap: CGFloat = 4

        // Horizontal: center on source, clamped to screen
        var x = sourceFrame.midX - panelSize.width / 2
        x = max(visibleFrame.minX + 4, min(x, visibleFrame.maxX - panelSize.width - 4))

        // Vertical: prefer below the trigger (screen coords: y-up, so "below" = smaller y)
        let belowY = sourceFrame.minY - panelSize.height - gap
        let aboveY = sourceFrame.maxY + gap

        let y: CGFloat
        if belowY >= visibleFrame.minY {
            y = belowY
        } else if aboveY + panelSize.height <= visibleFrame.maxY {
            y = aboveY
        } else {
            y = visibleFrame.minY + 4
        }

        return NSPoint(x: x, y: y)
    }

    // MARK: - Event Monitors

    private func installEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if event.window !== panel {
                self.close()
            }
            return event
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.close()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
