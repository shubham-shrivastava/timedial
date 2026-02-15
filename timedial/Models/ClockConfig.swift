//
//  ClockConfig.swift
//  timedial
//
//  Configuration for a single timezone clock
//

import Foundation

struct ClockConfig: Identifiable, Equatable, Hashable {
    let id: UUID
    var timezoneIdentifier: String {
        didSet { _timezone = TimeZone(identifier: timezoneIdentifier) ?? .current }
    }
    var isFavorite: Bool
    var order: Int
    
    /// Cached TimeZone instance — avoids repeated `TimeZone(identifier:)` lookups.
    private(set) var _timezone: TimeZone
    var timezone: TimeZone { _timezone }
    
    init(id: UUID = UUID(), timezoneIdentifier: String, isFavorite: Bool = false, order: Int = 0) {
        self.id = id
        self.timezoneIdentifier = timezoneIdentifier
        self.isFavorite = isFavorite
        self.order = order
        self._timezone = TimeZone(identifier: timezoneIdentifier) ?? .current
    }
    
    init(timezone: TimeZone, order: Int = 0) {
        self.id = UUID()
        self.timezoneIdentifier = timezone.identifier
        self.isFavorite = false
        self.order = order
        self._timezone = timezone
    }
    
    // MARK: - Codable (skip _timezone, reconstruct from identifier)
    
    enum CodingKeys: String, CodingKey {
        case id, timezoneIdentifier, isFavorite, order
    }
}

extension ClockConfig: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let identifier = try container.decode(String.self, forKey: .timezoneIdentifier)
        timezoneIdentifier = identifier
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        _timezone = TimeZone(identifier: identifier) ?? .current
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timezoneIdentifier, forKey: .timezoneIdentifier)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(order, forKey: .order)
    }
    
    // Display name for the timezone
    var displayName: String {
        ClockConfig.displayName(for: timezoneIdentifier)
    }
    
    /// Shared utility: extract a human-readable city name from a timezone identifier.
    static func displayName(for identifier: String) -> String {
        identifier.split(separator: "/").last
            .map { String($0).replacingOccurrences(of: "_", with: " ") } ?? identifier
    }
    
    // UTC offset string like "UTC-5" or "UTC+9"
    var utcOffsetString: String {
        let seconds = timezone.secondsFromGMT()
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        
        if minutes == 0 {
            return hours >= 0 ? "GMT+\(hours)" : "GMT\(hours)"
        } else {
            let sign = hours >= 0 ? "+" : "-"
            return "GMT\(sign)\(abs(hours)):\(String(format: "%02d", minutes))"
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
        "PET": "America/Lima",
    ]
    
    static func timezoneIdentifier(fromAbbreviation abbr: String) -> String? {
        return abbreviationMap[abbr.uppercased()]
    }

}
