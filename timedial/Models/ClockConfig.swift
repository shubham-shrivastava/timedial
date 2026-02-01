//
//  ClockConfig.swift
//  timedial
//
//  Configuration for a single timezone clock
//

import Foundation

struct ClockConfig: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var timezoneIdentifier: String
    var isFavorite: Bool
    var order: Int
    
    var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }
    
    init(id: UUID = UUID(), timezoneIdentifier: String, isFavorite: Bool = false, order: Int = 0) {
        self.id = id
        self.timezoneIdentifier = timezoneIdentifier
        self.isFavorite = isFavorite
        self.order = order
    }
    
    init(timezone: TimeZone, order: Int = 0) {
        self.id = UUID()
        self.timezoneIdentifier = timezone.identifier
        self.isFavorite = false
        self.order = order
    }
    
    // Display name for the timezone
    var displayName: String {
        let identifier = timezoneIdentifier
        if let lastComponent = identifier.split(separator: "/").last {
            return String(lastComponent).replacingOccurrences(of: "_", with: " ")
        }
        return identifier
    }
    
    // UTC offset string like "UTC-5" or "UTC+9"
    var utcOffsetString: String {
        let seconds = timezone.secondsFromGMT()
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        
        if minutes == 0 {
            return hours >= 0 ? "UTC+\(hours)" : "UTC\(hours)"
        } else {
            let sign = hours >= 0 ? "+" : "-"
            return "UTC\(sign)\(abs(hours)):\(String(format: "%02d", minutes))"
        }
    }
    
    // Time difference from local timezone
    func timeDifferenceFromLocal() -> String {
        let localOffset = TimeZone.current.secondsFromGMT()
        let thisOffset = timezone.secondsFromGMT()
        let diffSeconds = thisOffset - localOffset
        let diffHours = diffSeconds / 3600
        let diffMinutes = abs(diffSeconds % 3600) / 60
        
        if diffSeconds == 0 {
            return "Same time"
        }
        
        let sign = diffHours >= 0 ? "+" : ""
        if diffMinutes == 0 {
            return "\(sign)\(diffHours)h"
        } else {
            return "\(sign)\(diffHours)h \(diffMinutes)m"
        }
    }
}

// MARK: - Timezone Abbreviation Mapping

extension ClockConfig {
    static let abbreviationMap: [String: String] = [
        "PST": "America/Los_Angeles",
        "PDT": "America/Los_Angeles",
        "MST": "America/Denver",
        "MDT": "America/Denver",
        "CST": "America/Chicago",
        "CDT": "America/Chicago",
        "EST": "America/New_York",
        "EDT": "America/New_York",
        "GMT": "Europe/London",
        "UTC": "UTC",
        "BST": "Europe/London",
        "CET": "Europe/Paris",
        "CEST": "Europe/Paris",
        "JST": "Asia/Tokyo",
        "KST": "Asia/Seoul",
        "IST": "Asia/Kolkata",
        "AEST": "Australia/Sydney",
        "AEDT": "Australia/Sydney",
        "NZST": "Pacific/Auckland",
        "NZDT": "Pacific/Auckland",
        "HKT": "Asia/Hong_Kong",
        "SGT": "Asia/Singapore",
        "GST": "Asia/Dubai",
    ]
    
    static func timezoneIdentifier(fromAbbreviation abbr: String) -> String? {
        return abbreviationMap[abbr.uppercased()]
    }
}
