//
//  TimeConversionService.swift
//  timedial
//
//  Created by Shubham Shrivastav on 31/01/26.
//

import Foundation

struct TimeConversionService {
    
    /// Convert angle (in degrees) to minutes (0-59)
    static func angleToMinutes(angle: Double) -> Int {
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 360)
        let minutes = Int((normalizedAngle / 6.0).rounded()) % 60
        return minutes < 0 ? minutes + 60 : minutes
    }
    
    /// Convert angle (in degrees) to hours (0-11 for 12-hour format)
    static func angleToHours(angle: Double) -> Int {
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 360)
        let hours = Int((normalizedAngle / 30.0).rounded()) % 12
        return hours < 0 ? hours + 12 : hours
    }
    
    /// Update date with new minutes
    static func updateDate(_ date: Date, withMinutes minutes: Int, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .second], from: date)
        components.minute = minutes
        return calendar.date(from: components) ?? date
    }
    
    /// Update date with new hours (preserving AM/PM)
    static func updateDate(_ date: Date, withHours hours: Int, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let currentHour = components.hour ?? 0
        let isAfternoon = currentHour >= 12
        
        var newHour = hours
        if isAfternoon && hours < 12 {
            newHour = hours + 12
        } else if !isAfternoon && hours == 12 {
            newHour = 0
        }
        
        components.hour = newHour
        return calendar.date(from: components) ?? date
    }
    
    /// Convert time from one timezone to another
    static func convertTimezone(date: Date, from sourceTimezone: TimeZone, to targetTimezone: TimeZone) -> Date {
        // Date objects are timezone-agnostic, so we just return the same date
        // The display will handle timezone conversion
        return date
    }
    
    /// Get time components in a specific timezone
    static func getComponents(from date: Date, timezone: TimeZone) -> DateComponents {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
    
    /// Format time for display in a specific timezone
    @MainActor
    static func formatTime(_ date: Date, timezone: TimeZone, style: DateFormatter.Style = .medium) -> String {
        DateFormatterCache.shared.string(from: date, timeZone: timezone, style: style)
    }
    
    /// Get common timezones for picker
    static var commonTimezones: [(name: String, timezone: TimeZone)] {
        let timezones: [(String, String)] = [
            ("New York", "America/New_York"),
            ("Los Angeles", "America/Los_Angeles"),
            ("Chicago", "America/Chicago"),
            ("London", "Europe/London"),
            ("Paris", "Europe/Paris"),
            ("Berlin", "Europe/Berlin"),
            ("Tokyo", "Asia/Tokyo"),
            ("Hong Kong", "Asia/Hong_Kong"),
            ("Singapore", "Asia/Singapore"),
            ("Sydney", "Australia/Sydney"),
            ("Dubai", "Asia/Dubai"),
            ("Mumbai", "Asia/Kolkata"),
        ]
        
        return timezones.compactMap { name, identifier in
            guard let timezone = TimeZone(identifier: identifier) else { return nil }
            return (name, timezone)
        }
    }
}
