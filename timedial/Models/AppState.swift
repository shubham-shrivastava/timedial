//
//  AppState.swift
//  timedial
//
//  Persistent app state using UserDefaults
//

import Foundation
import Combine
import SwiftUI

enum TimezonePickerMode: Equatable {
    case addClock
    case changeTimezone(clockId: UUID)
}

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
    
    // MARK: - Timezone Picker
    lazy var pickerPanel = PickerPanelController()

    @Published var activePickerMode: TimezonePickerMode? {
        didSet {
            if activePickerMode == nil && pickerPanel.isVisible {
                pickerPanel.close()
            }
        }
    }
    
    // MARK: - Published State
    @Published var clocks: [ClockConfig] {
        didSet {
            saveClocks()
            updatePreferredPopoverSize()
        }
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
    
    /// Adaptive popover size: smaller for 1-3 clocks, larger for 4-6
    @Published var preferredPopoverSize: CGSize = CGSize(width: 600, height: 380)
    
    // MARK: - Constants
    static let maxClocks = 5  // 5 timezone clocks + 1 local = 6 total
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
        updatePreferredPopoverSize()
    }
    
    // MARK: - Popover Size (adaptive by clock count)
    private func updatePreferredPopoverSize() {
        let totalClocks = clocks.count + 1
        let newSize: CGSize
        if totalClocks <= 3 {
            newSize = CGSize(width: 600, height: 380)
        } else {
            newSize = CGSize(width: 720, height: 700)
        }
        preferredPopoverSize = newSize
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
        cachedTimezoneGroups = getGroupedTimezones(searchQuery: "")
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
        var updated = clocks
        updated.removeAll { $0.id == id }
        for i in updated.indices { updated[i].order = i }
        clocks = updated
    }
    
    func removeClock(at index: Int) {
        guard index >= 0 && index < clocks.count else { return }
        var updated = clocks
        updated.remove(at: index)
        for i in updated.indices { updated[i].order = i }
        clocks = updated
    }
    
    func updateClockTimezone(id: UUID, timezoneIdentifier: String) {
        guard let index = clocks.firstIndex(where: { $0.id == id }) else { return }
        var updated = clocks
        updated[index].timezoneIdentifier = timezoneIdentifier
        clocks = updated
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
    
    // MARK: - Picker Panel
    func showPickerPanel(mode: TimezonePickerMode, from sourceFrame: CGRect) {
        activePickerMode = mode
        pickerPanel.onDismiss = { [weak self] in
            self?.activePickerMode = nil
        }
        pickerPanel.show(at: sourceFrame, appState: self) { [weak self] timezoneId in
            self?.handlePickerSelection(timezoneId)
        }
    }

    private func handlePickerSelection(_ timezoneId: String) {
        switch activePickerMode {
        case .addClock:
            _ = addClock(timezoneIdentifier: timezoneId)
        case .changeTimezone(let clockId):
            updateClockTimezone(id: clockId, timezoneIdentifier: timezoneId)
        case nil:
            break
        }
        activePickerMode = nil
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
        let localizedName: String
        let abbreviation: String
        let searchableText: String
    }

    private static let regionDisplayNames: [String: String] = [
        "Africa": "Africa",
        "America": "Americas",
        "Antarctica": "Antarctica",
        "Arctic": "Arctic",
        "Asia": "Asia",
        "Atlantic": "Atlantic",
        "Australia": "Australia",
        "Europe": "Europe",
        "Indian": "Indian Ocean",
        "Pacific": "Pacific",
    ]

    private static let regionOrder: [String] = [
        "Americas", "Europe", "Asia", "Pacific", "Australia",
        "Africa", "Atlantic", "Indian Ocean", "Arctic", "Antarctica", "Other"
    ]

    private static let regionIdentifiers: [(String, [String])] = {
        var grouped: [String: [String]] = [:]
        for id in TimeZone.knownTimeZoneIdentifiers {
            let prefix = id.split(separator: "/").first.map(String.init) ?? ""
            let regionName = regionDisplayNames[prefix] ?? "Other"
            grouped[regionName, default: []].append(id)
        }
        return regionOrder.compactMap { name in
            guard let ids = grouped[name], !ids.isEmpty else { return nil }
            let sorted = ids.sorted {
                ClockConfig.displayName(for: $0) < ClockConfig.displayName(for: $1)
            }
            return (name, sorted)
        }
    }()

    /// Maps a generic localized name (e.g. "Central European Time") to all
    /// system-known abbreviations for timezones sharing that name (e.g. {"CET", "CEST"}).
    private static let genericNameAbbreviations: [String: Set<String>] = {
        var map: [String: Set<String>] = [:]
        for (abbr, id) in TimeZone.abbreviationDictionary {
            guard let tz = TimeZone(identifier: id),
                  let generic = tz.localizedName(for: .generic, locale: .current) else { continue }
            map[generic, default: []].insert(abbr)
        }
        return map
    }()

    private static func makeTimezoneInfoBase(identifier: String) -> TimezoneInfoBase? {
        guard let tz = TimeZone(identifier: identifier) else { return nil }
        let displayName = ClockConfig.displayName(for: identifier)
        let utcOffset = tz.gmtOffsetString
        let localizedName = tz.localizedName(for: .generic, locale: .current) ?? ""

        // Collect all known abbreviations for this timezone's zone group
        let zoneAbbreviations = genericNameAbbreviations[localizedName] ?? []
        let abbreviation = zoneAbbreviations.sorted().first ?? tz.abbreviation() ?? ""

        var searchParts = [displayName, identifier, localizedName, utcOffset]
        searchParts.append(contentsOf: zoneAbbreviations)
        let searchableText = searchParts.joined(separator: " ").lowercased()

        return TimezoneInfoBase(
            displayName: displayName,
            utcOffset: utcOffset,
            localizedName: localizedName,
            abbreviation: abbreviation,
            searchableText: searchableText
        )
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
                    localizedName: base.localizedName,
                    abbreviation: base.abbreviation,
                    searchableText: base.searchableText,
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
        let id: String
        let displayName: String
        let utcOffset: String
        let localizedName: String
        let abbreviation: String
        let searchableText: String
        let isFavorite: Bool

        init(identifier: String, displayName: String, utcOffset: String,
             localizedName: String, abbreviation: String,
             searchableText: String, isFavorite: Bool) {
            self.id = identifier
            self.displayName = displayName
            self.utcOffset = utcOffset
            self.localizedName = localizedName
            self.abbreviation = abbreviation
            self.searchableText = searchableText
            self.isFavorite = isFavorite
        }
    }
    
    private func matchesQuery(_ info: TimezoneInfo, query: String) -> Bool {
        info.searchableText.contains(query)
    }

    func getGroupedTimezones(searchQuery: String = "") -> [TimezoneGroup] {
        var groups: [TimezoneGroup] = []
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)

        func applyFavoriteState(to infos: [TimezoneInfo]) -> [TimezoneInfo] {
            infos.map { info in
                TimezoneInfo(
                    identifier: info.id,
                    displayName: info.displayName,
                    utcOffset: info.utcOffset,
                    localizedName: info.localizedName,
                    abbreviation: info.abbreviation,
                    searchableText: info.searchableText,
                    isFavorite: isFavorite(info.id)
                )
            }
        }

        func makeInfo(from base: TimezoneInfoBase, id: String, favorite: Bool) -> TimezoneInfo {
            TimezoneInfo(
                identifier: id,
                displayName: base.displayName,
                utcOffset: base.utcOffset,
                localizedName: base.localizedName,
                abbreviation: base.abbreviation,
                searchableText: base.searchableText,
                isFavorite: favorite
            )
        }

        // Check if query is an abbreviation
        if !query.isEmpty, let resolvedId = ClockConfig.timezoneIdentifier(fromAbbreviation: query) {
            if let base = AppState.timezoneInfoCache[resolvedId] ?? AppState.makeTimezoneInfoBase(identifier: resolvedId) {
                groups.append(TimezoneGroup(
                    id: "quickadd", name: "Quick Add",
                    timezones: [makeInfo(from: base, id: resolvedId, favorite: isFavorite(resolvedId))]
                ))
            }
        }
        
        // Favorites section
        if !favoriteTimezones.isEmpty {
            var favInfos = favoriteTimezones.compactMap { id -> TimezoneInfo? in
                guard let base = AppState.timezoneInfoCache[id] ?? AppState.makeTimezoneInfoBase(identifier: id) else { return nil }
                return makeInfo(from: base, id: id, favorite: true)
            }
            
            if !query.isEmpty {
                favInfos = favInfos.filter { matchesQuery($0, query: query) }
            }
            
            if !favInfos.isEmpty {
                groups.append(TimezoneGroup(id: "favorites", name: "Favorites", timezones: favInfos.sorted { $0.displayName < $1.displayName }))
            }
        }
        
        // Regional sections
        if query.isEmpty {
            groups.append(contentsOf: AppState.baseTimezoneGroups.map { group in
                TimezoneGroup(
                    id: group.id,
                    name: group.name,
                    timezones: applyFavoriteState(to: group.timezones)
                )
            })
        } else {
            for group in AppState.baseTimezoneGroups {
                let filtered = group.timezones.filter { matchesQuery($0, query: query) }
                if !filtered.isEmpty {
                    groups.append(
                        TimezoneGroup(
                            id: group.id,
                            name: group.name,
                            timezones: applyFavoriteState(to: filtered)
                        )
                    )
                }
            }
        }
        
        return groups
    }

}
