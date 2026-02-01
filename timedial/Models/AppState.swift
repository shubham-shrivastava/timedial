//
//  AppState.swift
//  timedial
//
//  Persistent app state using UserDefaults
//

import Foundation
import Combine
import SwiftUI

@MainActor
class AppState: ObservableObject {
    // MARK: - Singleton
    static let shared = AppState()
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let clocks = "timedial.clocks"
        static let favorites = "timedial.favorites"
        static let isCompactMode = "timedial.isCompactMode"
        static let selectedClockId = "timedial.selectedClockId"
    }
    
    // MARK: - Published State
    @Published var clocks: [ClockConfig] {
        didSet { saveClocks() }
    }
    
    @Published var favoriteTimezones: Set<String> {
        didSet {
            saveFavorites()
            refreshCachedTimezoneGroups()
        }
    }
    
    @Published var isCompactMode: Bool {
        didSet { UserDefaults.standard.set(isCompactMode, forKey: Keys.isCompactMode) }
    }
    
    @Published var selectedClockId: UUID?

    @Published var isPopoverVisible: Bool = false
    @Published private(set) var cachedTimezoneGroups: [TimezoneGroup] = []
    
    // MARK: - Constants
    static let maxClocks = 2  // 2 timezone clocks + 1 local = 3 total
    static let defaultTimezone = "America/New_York"
    
    // MARK: - Initialization
    private init() {
        // Load clocks
        if let data = UserDefaults.standard.data(forKey: Keys.clocks),
           let decoded = try? JSONDecoder().decode([ClockConfig].self, from: data) {
            self.clocks = decoded
        } else {
            // Default: one timezone clock
            self.clocks = [
                ClockConfig(timezoneIdentifier: AppState.defaultTimezone, order: 0)
            ]
        }
        
        // Load favorites
        if let data = UserDefaults.standard.data(forKey: Keys.favorites),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.favoriteTimezones = decoded
        } else {
            self.favoriteTimezones = []
        }
        
        // Load compact mode
        self.isCompactMode = UserDefaults.standard.bool(forKey: Keys.isCompactMode)
        
        // Load selected clock
        if let uuidString = UserDefaults.standard.string(forKey: Keys.selectedClockId),
           let uuid = UUID(uuidString: uuidString) {
            self.selectedClockId = uuid
        }

        refreshCachedTimezoneGroups()
    }
    
    // MARK: - Persistence
    private func saveClocks() {
        if let encoded = try? JSONEncoder().encode(clocks) {
            UserDefaults.standard.set(encoded, forKey: Keys.clocks)
        }
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteTimezones) {
            UserDefaults.standard.set(encoded, forKey: Keys.favorites)
        }
    }

    private func refreshCachedTimezoneGroups() {
        cachedTimezoneGroups = buildTimezoneGroups(searchQuery: "")
    }
    
    // MARK: - Clock Management
    func addClock(timezone: TimeZone) -> Bool {
        guard clocks.count < AppState.maxClocks else { return false }
        
        let newClock = ClockConfig(
            timezoneIdentifier: timezone.identifier,
            order: clocks.count
        )
        clocks.append(newClock)
        return true
    }
    
    func addClock(timezoneIdentifier: String) -> Bool {
        guard let tz = TimeZone(identifier: timezoneIdentifier) else { return false }
        return addClock(timezone: tz)
    }
    
    func removeClock(id: UUID) {
        clocks.removeAll { $0.id == id }
        reorderClocks()
    }
    
    func removeClock(at index: Int) {
        guard index >= 0 && index < clocks.count else { return }
        clocks.remove(at: index)
        reorderClocks()
    }
    
    func updateClockTimezone(id: UUID, timezoneIdentifier: String) {
        guard let index = clocks.firstIndex(where: { $0.id == id }) else { return }
        clocks[index].timezoneIdentifier = timezoneIdentifier
    }
    
    func moveClock(from source: IndexSet, to destination: Int) {
        clocks.move(fromOffsets: source, toOffset: destination)
        reorderClocks()
    }
    
    private func reorderClocks() {
        for (index, _) in clocks.enumerated() {
            clocks[index].order = index
        }
    }
    
    // MARK: - Favorites Management
    func toggleFavorite(timezoneIdentifier: String) {
        if favoriteTimezones.contains(timezoneIdentifier) {
            favoriteTimezones.remove(timezoneIdentifier)
        } else {
            favoriteTimezones.insert(timezoneIdentifier)
        }
        
        // Also update any clocks with this timezone
        for (index, clock) in clocks.enumerated() {
            if clock.timezoneIdentifier == timezoneIdentifier {
                clocks[index].isFavorite = favoriteTimezones.contains(timezoneIdentifier)
            }
        }
    }
    
    func isFavorite(_ timezoneIdentifier: String) -> Bool {
        favoriteTimezones.contains(timezoneIdentifier)
    }
    
    // MARK: - Selection
    func selectClock(_ id: UUID?) {
        selectedClockId = id
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: Keys.selectedClockId)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.selectedClockId)
        }
    }
    
    func selectClockByIndex(_ index: Int) {
        guard index >= 0 && index < clocks.count else { return }
        selectClock(clocks[index].id)
    }
    
    // MARK: - Helpers
    var canAddMoreClocks: Bool {
        clocks.count < AppState.maxClocks
    }
    
    var clockCount: Int {
        clocks.count
    }
}

// MARK: - Grouped Timezones

extension AppState {
    private struct TimezoneInfoBase {
        let displayName: String
        let utcOffset: String
    }

    private static let regionIdentifiers: [(String, [String])] = [
        ("Americas", [
            "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
            "America/Toronto", "America/Vancouver", "America/Mexico_City", "America/Sao_Paulo",
            "America/Buenos_Aires", "America/Lima", "America/Bogota", "America/Santiago"
        ]),
        ("Europe", [
            "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Rome",
            "Europe/Madrid", "Europe/Amsterdam", "Europe/Brussels", "Europe/Vienna",
            "Europe/Stockholm", "Europe/Oslo", "Europe/Copenhagen", "Europe/Helsinki",
            "Europe/Warsaw", "Europe/Prague", "Europe/Budapest", "Europe/Athens",
            "Europe/Moscow", "Europe/Istanbul"
        ]),
        ("Asia", [
            "Asia/Tokyo", "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Singapore",
            "Asia/Seoul", "Asia/Taipei", "Asia/Bangkok", "Asia/Jakarta",
            "Asia/Kolkata", "Asia/Mumbai", "Asia/Dubai", "Asia/Riyadh",
            "Asia/Tel_Aviv", "Asia/Manila", "Asia/Kuala_Lumpur", "Asia/Ho_Chi_Minh"
        ]),
        ("Pacific", [
            "Pacific/Auckland", "Pacific/Fiji", "Pacific/Honolulu", "Pacific/Guam"
        ]),
        ("Australia", [
            "Australia/Sydney", "Australia/Melbourne", "Australia/Brisbane",
            "Australia/Perth", "Australia/Adelaide", "Australia/Darwin"
        ]),
        ("Africa", [
            "Africa/Cairo", "Africa/Johannesburg", "Africa/Lagos", "Africa/Nairobi",
            "Africa/Casablanca", "Africa/Accra"
        ])
    ]

    private static func makeTimezoneInfoBase(identifier: String) -> TimezoneInfoBase? {
        guard let tz = TimeZone(identifier: identifier) else { return nil }
        let displayName: String
        if let lastComponent = identifier.split(separator: "/").last {
            displayName = String(lastComponent).replacingOccurrences(of: "_", with: " ")
        } else {
            displayName = identifier
        }

        let seconds = tz.secondsFromGMT()
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        let utcOffset: String
        if minutes == 0 {
            utcOffset = hours >= 0 ? "GMT+\(hours)" : "GMT\(hours)"
        } else {
            let sign = hours >= 0 ? "+" : "-"
            utcOffset = "GMT\(sign)\(abs(hours)):\(String(format: "%02d", minutes))"
        }

        return TimezoneInfoBase(displayName: displayName, utcOffset: utcOffset)
    }

    private static let timezoneInfoCache: [String: TimezoneInfoBase] = {
        var cache: [String: TimezoneInfoBase] = [:]
        for (_, identifiers) in AppState.regionIdentifiers {
            for id in identifiers {
                if let info = AppState.makeTimezoneInfoBase(identifier: id) {
                    cache[id] = info
                }
            }
        }
        return cache
    }()

    private static let baseTimezoneGroups: [TimezoneGroup] = {
        var groups: [TimezoneGroup] = []
        for (regionName, identifiers) in AppState.regionIdentifiers {
            let infos = identifiers.compactMap { id -> TimezoneInfo? in
                guard let base = AppState.timezoneInfoCache[id] else { return nil }
                return TimezoneInfo(
                    identifier: id,
                    displayName: base.displayName,
                    utcOffset: base.utcOffset,
                    isFavorite: false
                )
            }
            if !infos.isEmpty {
                groups.append(TimezoneGroup(id: regionName.lowercased(), name: regionName, timezones: infos))
            }
        }
        return groups
    }()

    struct TimezoneGroup: Identifiable, Equatable {
        let id: String
        let name: String
        let timezones: [TimezoneInfo]
    }
    
    struct TimezoneInfo: Identifiable, Hashable {
        let id: String // timezone identifier
        let displayName: String
        let utcOffset: String
        let isFavorite: Bool

        init(identifier: String, displayName: String, utcOffset: String, isFavorite: Bool) {
            self.id = identifier
            self.displayName = displayName
            self.utcOffset = utcOffset
            self.isFavorite = isFavorite
        }
        
        init(identifier: String, isFavorite: Bool = false) {
            self.id = identifier
            self.isFavorite = isFavorite
            
            let tz = TimeZone(identifier: identifier) ?? .current
            
            // Display name
            if let lastComponent = identifier.split(separator: "/").last {
                self.displayName = String(lastComponent).replacingOccurrences(of: "_", with: " ")
            } else {
                self.displayName = identifier
            }
            
            // UTC offset
            let seconds = tz.secondsFromGMT()
            let hours = seconds / 3600
            let minutes = abs(seconds % 3600) / 60
            
            if minutes == 0 {
                self.utcOffset = hours >= 0 ? "GMT+\(hours)" : "GMT\(hours)"
            } else {
                let sign = hours >= 0 ? "+" : "-"
                self.utcOffset = "GMT\(sign)\(abs(hours)):\(String(format: "%02d", minutes))"
            }
        }
    }
    
    func getGroupedTimezones(searchQuery: String = "") -> [TimezoneGroup] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cachedTimezoneGroups
        }

        var groups: [TimezoneGroup] = []
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check if query is an abbreviation
        if !query.isEmpty, let resolvedId = ClockConfig.timezoneIdentifier(fromAbbreviation: query) {
            if let base = AppState.timezoneInfoCache[resolvedId] ?? AppState.makeTimezoneInfoBase(identifier: resolvedId) {
                let info = TimezoneInfo(
                    identifier: resolvedId,
                    displayName: base.displayName,
                    utcOffset: base.utcOffset,
                    isFavorite: isFavorite(resolvedId)
                )
                groups.append(TimezoneGroup(id: "quickadd", name: "Quick Add", timezones: [info]))
            }
        }
        
        // Favorites section
        if !favoriteTimezones.isEmpty {
            var favInfos = favoriteTimezones.compactMap { id -> TimezoneInfo? in
                guard let base = AppState.timezoneInfoCache[id] ?? AppState.makeTimezoneInfoBase(identifier: id) else { return nil }
                return TimezoneInfo(
                    identifier: id,
                    displayName: base.displayName,
                    utcOffset: base.utcOffset,
                    isFavorite: true
                )
            }
            
            if !query.isEmpty {
                favInfos = favInfos.filter { 
                    $0.displayName.lowercased().contains(query) ||
                    $0.id.lowercased().contains(query)
                }
            }
            
            if !favInfos.isEmpty {
                groups.append(TimezoneGroup(id: "favorites", name: "Favorites", timezones: favInfos.sorted { $0.displayName < $1.displayName }))
            }
        }
        
        // Regional sections
        for group in AppState.baseTimezoneGroups {
            let filtered = group.timezones.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.id.lowercased().contains(query)
            }
            if !filtered.isEmpty {
                groups.append(TimezoneGroup(id: group.id, name: group.name, timezones: filtered))
            }
        }
        
        return groups
    }

    private func buildTimezoneGroups(searchQuery: String) -> [TimezoneGroup] {
        var groups: [TimezoneGroup] = []
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)

        if !query.isEmpty, let resolvedId = ClockConfig.timezoneIdentifier(fromAbbreviation: query) {
            if let base = AppState.timezoneInfoCache[resolvedId] ?? AppState.makeTimezoneInfoBase(identifier: resolvedId) {
                let info = TimezoneInfo(
                    identifier: resolvedId,
                    displayName: base.displayName,
                    utcOffset: base.utcOffset,
                    isFavorite: isFavorite(resolvedId)
                )
                groups.append(TimezoneGroup(id: "quickadd", name: "Quick Add", timezones: [info]))
            }
        }

        if !favoriteTimezones.isEmpty {
            let favInfos = favoriteTimezones.compactMap { id -> TimezoneInfo? in
                guard let base = AppState.timezoneInfoCache[id] ?? AppState.makeTimezoneInfoBase(identifier: id) else { return nil }
                return TimezoneInfo(
                    identifier: id,
                    displayName: base.displayName,
                    utcOffset: base.utcOffset,
                    isFavorite: true
                )
            }

            if !favInfos.isEmpty {
                groups.append(TimezoneGroup(id: "favorites", name: "Favorites", timezones: favInfos.sorted { $0.displayName < $1.displayName }))
            }
        }

        groups.append(contentsOf: AppState.baseTimezoneGroups)
        return groups
    }
}
