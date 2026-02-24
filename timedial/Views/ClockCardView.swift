//
//  ClockCardView.swift
//  timedial
//
//  A card wrapper for timezone clocks with controls
//

import SwiftUI
import AppKit

// MARK: - Cursor Helper

extension View {
    /// Sets the cursor when hovering over this view.
    /// Uses NSCursor.set() instead of push/pop to avoid stack imbalance during drag gestures.
    func cursorOnHover(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

struct ClockCardView: View {
    let config: ClockConfig
    let hourAngle: Double
    let minuteAngle: Double
    let time: Date
    let isCompact: Bool
    let isDragging: Bool
    let clockRadius: CGFloat
    let onRemove: () -> Void
    let onDragDelta: (Double, Bool) -> Void
    let onDragStart: () -> Void
    let onDragEnd: () -> Void
    let onCopyTime: () -> Void
    let onCopyTimeAndTimezone: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 10) {
            HStack {
                TimezoneInlinePicker(
                    timezoneIdentifier: config.timezoneIdentifier,
                    clockId: config.id
                )
                .cursorOnHover(.pointingHand)
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
                .allowsHitTesting(isHovering)
                .help("Remove clock")
                .cursorOnHover(.pointingHand)
            }
            
            if isCompact {
                compactView
            } else {
                fullView
            }
        }
        .padding(isCompact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Copy Time") { onCopyTime() }
            Button("Copy Time & Timezone") { onCopyTimeAndTimezone() }
            Divider()
            Button("Remove Clock", role: .destructive) { onRemove() }
        }
    }
    
    private var fullView: some View {
        VStack(spacing: 4) {
            // Interactive analog clock (already shows time and timezone name)
            AnalogClockView(
                hourAngle: hourAngle,
                minuteAngle: minuteAngle,
                radius: clockRadius,
                timezone: config.timezone,
                time: time,
                isDragging: isDragging,
                onDragDelta: onDragDelta,
                onDragStart: onDragStart,
                onDragEnd: onDragEnd
            )
            
            // Time difference only (time is shown by AnalogClockView)
            Text(config.timeDifferenceFromLocal())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    
    private var compactView: some View {
        HStack(spacing: 12) {
            // Mini analog clock
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                
                // Hour hand
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 12)
                    .offset(y: -6)
                    .rotationEffect(.degrees(hourAngle))
                
                // Minute hand
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 1.5, height: 16)
                    .offset(y: -8)
                    .rotationEffect(.degrees(minuteAngle))
                
                // Center dot
                Circle()
                    .fill(Color.primary)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(TimeConversionService.formatTime(time, timezone: config.timezone))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                
                Text(config.timeDifferenceFromLocal())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Local Clock Card (Special first clock that's draggable)

struct LocalClockCardView: View {
    let hourAngle: Double
    let minuteAngle: Double
    let time: Date
    let isDragging: Bool
    let isCompact: Bool
    let isManualMode: Bool
    let clockRadius: CGFloat
    let onDragDelta: (Double, Bool) -> Void
    let onDragStart: () -> Void
    let onDragEnd: () -> Void
    let onReset: () -> Void
    let onCopyTime: () -> Void
    
    init(
        hourAngle: Double,
        minuteAngle: Double,
        time: Date,
        isDragging: Bool,
        isCompact: Bool,
        isManualMode: Bool,
        clockRadius: CGFloat = 70,
        onDragDelta: @escaping (Double, Bool) -> Void,
        onDragStart: @escaping () -> Void,
        onDragEnd: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onCopyTime: @escaping () -> Void = {}
    ) {
        self.hourAngle = hourAngle
        self.minuteAngle = minuteAngle
        self.time = time
        self.isDragging = isDragging
        self.isCompact = isCompact
        self.isManualMode = isManualMode
        self.clockRadius = clockRadius
        self.onDragDelta = onDragDelta
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
        self.onReset = onReset
        self.onCopyTime = onCopyTime
    }
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 10) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text("Local Time")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isManualMode {
                    Button(action: onReset) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Reset")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .cursorOnHover(.pointingHand)
                }
            }
            
            if isCompact {
                compactView
            } else {
                fullView
            }
        }
        .padding(isCompact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .contextMenu {
            Button("Copy Time") { onCopyTime() }
        }
    }
    
    private var fullView: some View {
        VStack(spacing: 8) {
            // Interactive analog clock
            AnalogClockView(
                hourAngle: hourAngle,
                minuteAngle: minuteAngle,
                radius: clockRadius,
                timezone: .current,
                time: time,
                isDragging: isDragging,
                onDragDelta: onDragDelta,
                onDragStart: onDragStart,
                onDragEnd: onDragEnd
            )
        }
    }
    
    private var compactView: some View {
        HStack(spacing: 12) {
            // Mini analog clock (not interactive in compact mode)
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 12)
                    .offset(y: -6)
                    .rotationEffect(.degrees(hourAngle))
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 1.5, height: 16)
                    .offset(y: -8)
                    .rotationEffect(.degrees(minuteAngle))
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(TimeConversionService.formatTime(time, timezone: .current))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                
                Text(ClockConfig.displayName(for: TimeZone.current.identifier))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}
