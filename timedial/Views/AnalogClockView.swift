//
//  AnalogClockView.swift
//  timedial
//
//  Created by Shubham Shrivastav on 31/01/26.
//

import SwiftUI

struct AnalogClockView: View {
    let hourAngle: Double
    let minuteAngle: Double
    let radius: CGFloat
    let timezone: TimeZone
    let time: Date
    let isDragging: Bool
    let onDragDelta: ((Double, Bool) -> Void)?
    let onDragStart: (() -> Void)?
    let onDragEnd: (() -> Void)?
    
    @State private var activeDrag: DraggingHand = .none
    @State private var lastAngle: Double = 0
    
    enum DraggingHand {
        case none, hour, minute
    }
    
    init(
        hourAngle: Double,
        minuteAngle: Double,
        radius: CGFloat,
        timezone: TimeZone,
        time: Date,
        isDragging: Bool = false,
        onDragDelta: ((Double, Bool) -> Void)? = nil,
        onDragStart: (() -> Void)? = nil,
        onDragEnd: (() -> Void)? = nil
    ) {
        self.hourAngle = hourAngle
        self.minuteAngle = minuteAngle
        self.radius = radius
        self.timezone = timezone
        self.time = time
        self.isDragging = isDragging
        self.onDragDelta = onDragDelta
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Clock face
                ClockFaceView(radius: radius)
                
                // Hour hand
                ClockHandView(
                    angle: hourAngle,
                    length: radius * 0.5,
                    width: activeDrag == .hour ? 8 : 6,
                    color: activeDrag == .hour ? .accentColor : .primary
                )
                .allowsHitTesting(false)
                
                // Minute hand
                ClockHandView(
                    angle: minuteAngle,
                    length: radius * 0.7,
                    width: activeDrag == .minute ? 5 : 4,
                    color: activeDrag == .minute ? .accentColor : .blue
                )
                .allowsHitTesting(false)
                
                // Invisible drag area covering the whole clock
                if onDragDelta != nil {
                    Circle()
                        .fill(Color.clear)
                        .contentShape(Circle())
                        .frame(width: radius * 2, height: radius * 2)
                        .gesture(dragGesture)
                }
            }
            .frame(width: radius * 2, height: radius * 2)
            // Only animate when NOT dragging
            .animation(isDragging ? nil : .easeInOut(duration: 0.2), value: hourAngle)
            .animation(isDragging ? nil : .easeInOut(duration: 0.2), value: minuteAngle)
            
            // Time display
            VStack(spacing: 4) {
                Text(TimeConversionService.formatTime(time, timezone: timezone))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(isDragging ? .identity : .numericText())
                    .animation(isDragging ? nil : .easeInOut(duration: 0.15), value: time)
                
                Text(timezoneName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5) // Require small movement to avoid accidental taps
            .onChanged { value in
                let center = CGPoint(x: radius, y: radius)
                let location = value.location
                let distanceFromCenter = hypot(location.x - center.x, location.y - center.y)
                
                // Skip if too close to center (angle calculations are unstable)
                guard distanceFromCenter > radius * 0.15 else { return }
                
                let rawAngle = calculateAngle(from: center, to: location)
                
                // On first touch, determine which hand to drag
                if activeDrag == .none {
                    onDragStart?()
                    
                    // Hour hand zone: between center and 55% radius
                    // Minute hand zone: beyond 55% radius
                    if distanceFromCenter < radius * 0.55 {
                        activeDrag = .hour
                    } else {
                        activeDrag = .minute
                    }
                    // Initialize to touch position - subsequent deltas are relative to this
                    lastAngle = rawAngle
                    return // Don't apply delta on first touch
                }
                
                // Calculate delta with wraparound handling
                var delta = rawAngle - lastAngle
                
                // Handle crossing 0/360 boundary
                if delta > 180 {
                    delta -= 360
                } else if delta < -180 {
                    delta += 360
                }
                
                // Limit delta to prevent jumps from fast movements or glitches
                delta = max(-30, min(30, delta))
                
                lastAngle = rawAngle
                
                // Send delta to ViewModel
                onDragDelta?(delta, activeDrag == .hour)
            }
            .onEnded { _ in
                activeDrag = .none
                onDragEnd?()
            }
    }
    
    private func calculateAngle(from center: CGPoint, to point: CGPoint) -> Double {
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        let radians = atan2(deltaY, deltaX)
        var degrees = radians * 180 / .pi + 90
        if degrees < 0 {
            degrees += 360
        }
        return degrees
    }
    
    private var timezoneName: String {
        ClockConfig.displayName(for: timezone.identifier)
    }
}
