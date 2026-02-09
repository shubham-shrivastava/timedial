//
//  ContentView.swift
//  timedial
//
//  Created by Shubham Shrivastav on 31/01/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ClockViewModel()
    @StateObject private var loginManager = LoginItemManager()
    @EnvironmentObject private var appState: AppState
    @State private var isSettingsPresented = false
    
    var body: some View {
        VStack(spacing: 16) {
            HeaderView(
                isCompactMode: appState.isCompactMode,
                onToggleCompact: {
                    withAnimation(.spring(duration: 0.3)) {
                        appState.isCompactMode.toggle()
                    }
                },
                onOpenSettings: {
                    isSettingsPresented = true
                }
            )
            
            ClockGridView(viewModel: viewModel, appState: appState)
            
            Spacer(minLength: 0)
            
            BottomToolbarView(viewModel: viewModel, appState: appState)
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 350)
        .background(.regularMaterial)
        .popover(isPresented: $isSettingsPresented, arrowEdge: .top) {
            SettingsView(loginManager: loginManager)
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    let isCompactMode: Bool
    let onToggleCompact: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack {
            Text("TimeDial")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
            
            Button(action: onToggleCompact) {
                Image(systemName: isCompactMode ? "square.grid.2x2" : "list.bullet")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isCompactMode ? "Full view" : "Compact view")

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Clock Grid View

struct ClockGridView: View {
    @ObservedObject var viewModel: ClockViewModel
    @ObservedObject var appState: AppState
    
    private var totalClocks: Int {
        appState.clocks.count + 1 // +1 for local clock
    }
    
    var body: some View {
        HStack(spacing: 20) {
            Spacer(minLength: 0)
            
            localClockCard
            
            ForEach(appState.clocks) { config in
                TimezoneClockCard(
                    config: config,
                    viewModel: viewModel,
                    appState: appState
                )
            }
            
            Spacer(minLength: 0)
        }
        .animation(.spring(duration: 0.3), value: appState.clocks.count)
    }
    
    private var localClockCard: some View {
        LocalClockCardView(
            hourAngle: viewModel.hourAngle,
            minuteAngle: viewModel.minuteAngle,
            time: viewModel.localTime,
            isDragging: viewModel.isDragging,
            isCompact: appState.isCompactMode,
            isManualMode: viewModel.isManualMode,
            onDragDelta: { delta, isHour in
                viewModel.addAngleDelta(delta, isHourHand: isHour)
            },
            onDragStart: {
                viewModel.startDrag()
            },
            onDragEnd: {
                viewModel.endDrag()
            },
            onReset: {
                viewModel.resetToCurrentTime()
            }
        )
        .animation(viewModel.isDragging ? nil : .easeInOut(duration: 0.2), value: viewModel.hourAngle)
        .animation(viewModel.isDragging ? nil : .easeInOut(duration: 0.2), value: viewModel.minuteAngle)
    }
}

// MARK: - Timezone Clock Card (Wrapper to simplify)

struct TimezoneClockCard: View {
    let config: ClockConfig
    @ObservedObject var viewModel: ClockViewModel
    @ObservedObject var appState: AppState
    
    var body: some View {
        ClockCardView(
            config: config,
            hourAngle: viewModel.hourAngle(for: config),
            minuteAngle: viewModel.minuteAngle(for: config),
            time: viewModel.localTime,
            isCompact: appState.isCompactMode,
            isDragging: viewModel.isDragging,
            onRemove: {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.removeClock(id: config.id)
                }
            },
            onTimezoneChange: { newTz in
                viewModel.updateClockTimezone(id: config.id, timezoneIdentifier: newTz)
            },
            onDragDelta: { delta, isHour in
                viewModel.addAngleDelta(delta, isHourHand: isHour)
            },
            onDragStart: {
                viewModel.startDrag()
            },
            onDragEnd: {
                viewModel.endDrag()
            }
        )
        .transition(.scale.combined(with: .opacity))
        .animation(viewModel.isDragging ? nil : .easeInOut(duration: 0.2), value: viewModel.hourAngle(for: config))
        .animation(viewModel.isDragging ? nil : .easeInOut(duration: 0.2), value: viewModel.minuteAngle(for: config))
    }
}

// MARK: - Bottom Toolbar View

struct BottomToolbarView: View {
    @ObservedObject var viewModel: ClockViewModel
    @ObservedObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 16) {
            addClockSection
            
            Spacer()
            
            clockCountIndicator
            
            Spacer()
            
            resetSection
            
            quitSection
        }
        .animation(.spring(duration: 0.3), value: viewModel.isManualMode)
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var addClockSection: some View {
        if appState.canAddMoreClocks {
            AddClockPicker { timezoneId in
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.addClock(timezoneIdentifier: timezoneId)
                }
            }
        } else {
            Text("Max 3 clocks")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
    
    private var clockCountIndicator: some View {
        HStack(spacing: 4) {
            // Show 3 dots for 3 total clocks (1 local + 2 timezone)
            ForEach(0..<(AppState.maxClocks + 1), id: \.self) { index in
                Circle()
                    .fill(index <= appState.clocks.count ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    @ViewBuilder
    private var resetSection: some View {
        if viewModel.isManualMode {
            Button(action: {
                viewModel.resetToCurrentTime()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Reset All")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var quitSection: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                Text("Quit")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule())
        .help("Quit TimeDial")
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var loginManager: LoginItemManager
    private let privacyURL = URL(string: "https://shubham-shrivastava.github.io/timedial-privacy.html")!
    private let supportURL = URL(string: "https://shubham-shrivastava.github.io/timedial-support.html")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))

            Toggle(isOn: Binding(
                get: { loginManager.isEnabled },
                set: { loginManager.setEnabled($0) }
            )) {
                Text("Launch at Login")
            }
            .toggleStyle(.switch)

            if let message = loginManager.lastErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Menu Bar Icon")
                    .font(.system(size: 13, weight: .semibold))
                Text("If you don't see the clock icon, go to System Settings → Menu Bar → Allow in Menu Bar → TimeDial and toggle it on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Links")
                    .font(.system(size: 13, weight: .semibold))
                Link("Privacy Policy", destination: privacyURL)
                Link("Support", destination: supportURL)
            }
            .font(.footnote)
        }
        .padding(16)
        .frame(width: 360)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .frame(width: 600, height: 500)
}
