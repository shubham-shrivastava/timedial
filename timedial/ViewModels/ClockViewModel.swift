//
//  ClockViewModel.swift
//  timedial
//
//  Created by Shubham Shrivastav on 31/01/26.
//

import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
class ClockViewModel: ObservableObject {
    // MARK: - Published State
    @Published var localTime: Date = Date()
    @Published var isDragging: Bool = false
    @Published var isManualMode: Bool = false
    
    // Stored angles for local clock - single source of truth
    @Published var hourAngle: Double = 0
    @Published var minuteAngle: Double = 0
    
    // App state reference
    @Published private(set) var appState: AppState
    
    // Timer for real-time updates
    private var timerCancellable: AnyCancellable?
    private var stateCancellable: AnyCancellable?
    private var visibilityCancellable: AnyCancellable?
    
    // Track for hour rollover detection during drag
    private var isFirstDragUpdate: Bool = true
    
    // MARK: - Initialization
    
    init() {
        self.appState = AppState.shared
        updateAnglesFromCurrentTime()
        startTimer()
        observeAppState()
        observePopoverVisibility()
    }
    
    private func observeAppState() {
        stateCancellable = appState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private func observePopoverVisibility() {
        visibilityCancellable = appState.$isPopoverVisible
            .removeDuplicates()
            .sink { [weak self] isVisible in
                guard let self = self else { return }
                if isVisible && !self.isDragging && !self.isManualMode {
                    self.updateAnglesFromCurrentTime()
                }
            }
    }
    
    // MARK: - Computed Properties
    
    var clocks: [ClockConfig] {
        appState.clocks
    }
    
    var isCompactMode: Bool {
        get { appState.isCompactMode }
        set { appState.isCompactMode = newValue }
    }
    
    var selectedClockId: UUID? {
        appState.selectedClockId
    }
    
    var canAddMoreClocks: Bool {
        appState.canAddMoreClocks
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                autoreleasepool {
                    guard let self = self else { return }
                    if self.appState.isPopoverVisible && !self.isDragging && !self.isManualMode {
                        self.updateAnglesFromCurrentTime()
                    }
                }
            }
    }
    
    // MARK: - Angle Computation
    
    private func computeHourAngle(from date: Date, timezone: TimeZone = .current) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        return Double(hour % 12) * 30.0 + Double(minute) * 0.5 + Double(second) * (0.5 / 60.0)
    }
    
    private func computeMinuteAngle(from date: Date, timezone: TimeZone = .current) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        let components = calendar.dateComponents([.minute, .second], from: date)
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        return Double(minute) * 6.0 + Double(second) * 0.1
    }
    
    func updateAnglesFromCurrentTime() {
        let now = Date()
        localTime = now
        hourAngle = computeHourAngle(from: now)
        minuteAngle = computeMinuteAngle(from: now)
    }
    
    // Get angles for a specific timezone clock
    func hourAngle(for config: ClockConfig) -> Double {
        return computeHourAngle(from: localTime, timezone: config.timezone)
    }
    
    func minuteAngle(for config: ClockConfig) -> Double {
        return computeMinuteAngle(from: localTime, timezone: config.timezone)
    }
    
    // MARK: - Drag Handling
    
    func startDrag() {
        isDragging = true
        isFirstDragUpdate = true
    }
    
    func addAngleDelta(_ delta: Double, isHourHand: Bool) {
        if isHourHand {
            hourAngle += delta
            while hourAngle < 0 { hourAngle += 360 }
            while hourAngle >= 360 { hourAngle -= 360 }
            updateTimeFromHourAngle()
        } else {
            let oldMinuteAngle = minuteAngle
            minuteAngle += delta
            
            // Detect hour rollover when crossing 0/360
            if !isFirstDragUpdate {
                let oldNorm = normalizeAngle(oldMinuteAngle)
                let newNorm = normalizeAngle(minuteAngle)
                
                if oldNorm > 300 && newNorm < 60 && delta > 0 {
                    adjustHourForMinuteRollover(forward: true)
                } else if oldNorm < 60 && newNorm > 300 && delta < 0 {
                    adjustHourForMinuteRollover(forward: false)
                }
            }
            isFirstDragUpdate = false
            
            while minuteAngle < 0 { minuteAngle += 360 }
            while minuteAngle >= 360 { minuteAngle -= 360 }
            
            updateTimeFromMinuteAngle()
        }
    }
    
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }
    
    private func adjustHourForMinuteRollover(forward: Bool) {
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: localTime)
        var hour = components.hour ?? 0
        
        hour += forward ? 1 : -1
        
        components.hour = hour
        if let newDate = calendar.date(from: components) {
            localTime = newDate
            hourAngle = computeHourAngle(from: newDate)
        }
    }
    
    private func updateTimeFromHourAngle() {
        var calendar = Calendar.current
        calendar.timeZone = .current
        
        let normalizedAngle = normalizeAngle(hourAngle)
        let totalMinutesInHalf = (normalizedAngle / 360.0) * 12.0 * 60.0
        let hours = Int(totalMinutesInHalf / 60.0) % 12
        let minutes = Int(totalMinutesInHalf) % 60
        
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: localTime)
        let currentHour = components.hour ?? 0
        let isAfternoon = currentHour >= 12
        
        components.hour = isAfternoon ? hours + 12 : hours
        components.minute = minutes
        components.second = 0
        
        if let newDate = calendar.date(from: components) {
            localTime = newDate
            minuteAngle = computeMinuteAngle(from: newDate)
        }
    }
    
    private func updateTimeFromMinuteAngle() {
        var calendar = Calendar.current
        calendar.timeZone = .current
        
        let normalizedAngle = normalizeAngle(minuteAngle)
        let totalMinutes = normalizedAngle / 6.0
        let minutes = Int(totalMinutes) % 60
        let seconds = Int((totalMinutes - Double(Int(totalMinutes))) * 60.0) % 60
        
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: localTime)
        components.minute = minutes
        components.second = seconds
        
        if let newDate = calendar.date(from: components) {
            localTime = newDate
            let hour = calendar.component(.hour, from: newDate)
            hourAngle = Double(hour % 12) * 30.0 + Double(minutes) * 0.5 + Double(seconds) * (0.5 / 60.0)
        }
    }
    
    func endDrag() {
        isDragging = false
        isFirstDragUpdate = true
        isManualMode = true
    }
    
    // MARK: - Reset
    
    func resetToCurrentTime() {
        isDragging = false
        isFirstDragUpdate = true
        isManualMode = false
        updateAnglesFromCurrentTime()
    }
    
    // MARK: - Clock Management (delegates to AppState)
    
    func addClock(timezoneIdentifier: String) {
        _ = appState.addClock(timezoneIdentifier: timezoneIdentifier)
    }
    
    func removeClock(id: UUID) {
        appState.removeClock(id: id)
    }
    
    func updateClockTimezone(id: UUID, timezoneIdentifier: String) {
        appState.updateClockTimezone(id: id, timezoneIdentifier: timezoneIdentifier)
    }
    
    func moveClock(from source: IndexSet, to destination: Int) {
        appState.moveClock(from: source, to: destination)
    }
    
    func selectClock(_ id: UUID?) {
        appState.selectClock(id)
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(timezoneIdentifier: String) {
        appState.toggleFavorite(timezoneIdentifier: timezoneIdentifier)
    }
    
    func isFavorite(_ timezoneIdentifier: String) -> Bool {
        appState.isFavorite(timezoneIdentifier)
    }
    
    // MARK: - Clipboard
    
    func copyTimeToClipboard(timezone: TimeZone) {
        let timeString = TimeConversionService.formatTime(localTime, timezone: timezone)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(timeString, forType: .string)
    }
    
    func copyTimezoneToClipboard(_ timezone: TimeZone) {
        let displayName = timezone.identifier.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? timezone.identifier
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayName, forType: .string)
    }
    
    func copyTimeAndTimezoneToClipboard(timezone: TimeZone) {
        let timeString = TimeConversionService.formatTime(localTime, timezone: timezone)
        let displayName = timezone.identifier.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? timezone.identifier
        
        let combined = "\(timeString) (\(displayName))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(combined, forType: .string)
    }
    
    // MARK: - Helpers
    
    func getFormattedTime(for timezone: TimeZone) -> String {
        TimeConversionService.formatTime(localTime, timezone: timezone)
    }
    
    func timeDifference(for config: ClockConfig) -> String {
        return config.timeDifferenceFromLocal()
    }
}
