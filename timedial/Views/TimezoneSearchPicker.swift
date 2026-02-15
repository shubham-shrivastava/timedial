//
//  TimezoneSearchPicker.swift
//  timedial
//
//  Searchable, grouped timezone picker with favorites and quick-add
//

import SwiftUI

struct TimezoneSearchPicker: View {
    @Binding var selectedTimezone: String
    let onSelect: ((String) -> Void)?
    
    @EnvironmentObject private var appState: AppState
    @State private var isPopoverPresented = false
    @State private var popoverId = UUID()
    
    init(selectedTimezone: Binding<String>, onSelect: ((String) -> Void)? = nil) {
        self._selectedTimezone = selectedTimezone
        self.onSelect = onSelect
    }
    
    private var displayName: String {
        ClockConfig.displayName(for: selectedTimezone)
    }
    
    var body: some View {
        Button(action: {
            popoverId = UUID()
            isPopoverPresented = true
        }) {
            Text(displayName)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            TimezonePickerPopover(
                isPresented: $isPopoverPresented,
                initialGroups: appState.cachedTimezoneGroups
            ) { id in
                selectedTimezone = id
                onSelect?(id)
            }
            .id(popoverId)
            .environmentObject(appState)
        }
    }
}

// MARK: - Inline Picker Variant (for clock cards)

struct TimezoneInlinePicker: View {
    @Binding var selectedTimezone: String
    
    @EnvironmentObject private var appState: AppState
    @State private var isPopoverPresented = false
    @State private var popoverId = UUID()
    
    init(selectedTimezone: Binding<String>) {
        self._selectedTimezone = selectedTimezone
    }
    
    private var displayName: String {
        ClockConfig.displayName(for: selectedTimezone)
    }
    
    var body: some View {
        Button(action: {
            popoverId = UUID()
            isPopoverPresented = true
        }) {
            HStack(spacing: 3) {
                Text(displayName)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            TimezonePickerPopover(
                isPresented: $isPopoverPresented,
                initialGroups: appState.cachedTimezoneGroups
            ) { id in
                selectedTimezone = id
            }
            .id(popoverId)
            .environmentObject(appState)
        }
    }
}

// MARK: - Add Clock Picker

struct AddClockPicker: View {
    let onAdd: (String) -> Void
    
    @EnvironmentObject private var appState: AppState
    @State private var isPopoverPresented = false
    @State private var popoverId = UUID()
    
    var body: some View {
        Button(action: {
            popoverId = UUID()
            isPopoverPresented = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add Clock")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .cursorOnHover(.pointingHand)
        .keyboardShortcut("n", modifiers: .command)
        .disabled(!appState.canAddMoreClocks)
        .opacity(appState.canAddMoreClocks ? 1 : 0.5)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            TimezonePickerPopover(
                isPresented: $isPopoverPresented,
                initialGroups: appState.cachedTimezoneGroups
            ) { id in
                onAdd(id)
            }
            .id(popoverId)
            .environmentObject(appState)
        }
    }
}

// MARK: - Popover Content

private struct TimezonePickerPopover: View {
    @Binding var isPresented: Bool
    let onSelect: (String) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var groupedTimezones: [AppState.TimezoneGroup]

    init(isPresented: Binding<Bool>, initialGroups: [AppState.TimezoneGroup], onSelect: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.onSelect = onSelect
        self._groupedTimezones = State(initialValue: initialGroups)
    }

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search timezones (e.g. GMT, UTC, CET, JST, etc.)...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Divider()

            listView
        }
        .padding(12)
        .frame(width: 360, height: 420)
        .onAppear {
            if groupedTimezones.isEmpty {
                groupedTimezones = appState.cachedTimezoneGroups
            }
        }
        .onChange(of: searchText) { _, _ in
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
        }
        .onChange(of: appState.cachedTimezoneGroups) { _, _ in
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                groupedTimezones = appState.cachedTimezoneGroups
            }
        }
        .onChange(of: appState.favoriteTimezones) { _, _ in
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
        }
    }

    @ViewBuilder
    private var listView: some View {
        List {
            if groupedTimezones.isEmpty {
                Text("No matches")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(groupedTimezones) { group in
                    Section {
                        ForEach(group.timezones) { info in
                            TimezoneRow(info: info) {
                                handleSelect(info.id)
                            } onToggleFavorite: {
                                appState.toggleFavorite(timezoneIdentifier: info.id)
                            }
                        }
                    } header: {
                        Text(group.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func handleSelect(_ id: String) {
        onSelect(id)
        searchText = ""
        isPresented = false
    }
}

private struct TimezoneRow: View {
    let info: AppState.TimezoneInfo
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    Text(info.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(info.utcOffset)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: onToggleFavorite) {
                Image(systemName: info.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(info.isFavorite ? .yellow : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(info.isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TimezoneSearchPicker(selectedTimezone: .constant("America/New_York"))
        TimezoneInlinePicker(selectedTimezone: .constant("Asia/Tokyo"))
        AddClockPicker(onAdd: { _ in })
    }
    .padding()
    .frame(width: 400)
    .environmentObject(AppState.shared)
}
