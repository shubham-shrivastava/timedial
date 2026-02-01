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
    @State private var groupedTimezones: [AppState.TimezoneGroup] = []
    
    init(selectedTimezone: Binding<String>, onSelect: ((String) -> Void)? = nil) {
        self._selectedTimezone = selectedTimezone
        self.onSelect = onSelect
    }
    
    private var displayName: String {
        if let lastComponent = selectedTimezone.split(separator: "/").last {
            return String(lastComponent).replacingOccurrences(of: "_", with: " ")
        }
        return selectedTimezone
    }
    
    var body: some View {
        Menu {
            ForEach(groupedTimezones) { group in
                Section(header: Text(group.name)) {
                    ForEach(group.timezones) { info in
                        Button(action: {
                            selectedTimezone = info.id
                            onSelect?(info.id)
                        }) {
                            HStack {
                                Text(info.displayName)
                                Spacer()
                                Text(info.utcOffset)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11))
                            }
                        }
                    }
                }
            }
        } label: {
            Text(displayName)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .onAppear {
            groupedTimezones = appState.getGroupedTimezones()
        }
        .onChange(of: appState.favoriteTimezones) { _, _ in
            groupedTimezones = appState.getGroupedTimezones()
        }
    }
}

// MARK: - Inline Picker Variant (for clock cards)

struct TimezoneInlinePicker: View {
    @Binding var selectedTimezone: String
    
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var groupedTimezones: [AppState.TimezoneGroup] = []
    
    init(selectedTimezone: Binding<String>) {
        self._selectedTimezone = selectedTimezone
    }
    
    private var displayName: String {
        if let lastComponent = selectedTimezone.split(separator: "/").last {
            return String(lastComponent).replacingOccurrences(of: "_", with: " ")
        }
        return selectedTimezone
    }
    
    var body: some View {
        Menu {
            TextField("Search timezones...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            
            Divider()
            
            ForEach(groupedTimezones) { group in
                Section(header: Text(group.name)) {
                    ForEach(group.timezones) { info in
                        Button(action: {
                            selectedTimezone = info.id
                            searchText = ""
                        }) {
                            HStack {
                                Text(info.displayName)
                                Spacer()
                                Text(info.utcOffset)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11))
                            }
                        }
                    }
                }
            }
        } label: {
            Text(displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .onAppear {
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
        }
        .onChange(of: searchText) { _, _ in
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
        }
        .onChange(of: appState.favoriteTimezones) { _, _ in
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
        }
    }
}

// MARK: - Add Clock Picker

struct AddClockPicker: View {
    let onAdd: (String) -> Void
    
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var groupedTimezones: [AppState.TimezoneGroup] = []
    
    var body: some View {
        Menu {
            TextField("Search timezones...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            
            Divider()
            
            ForEach(groupedTimezones) { group in
                Section(header: Text(group.name)) {
                    ForEach(group.timezones) { info in
                        Button(action: {
                            onAdd(info.id)
                            searchText = ""
                        }) {
                            HStack {
                                Text(info.displayName)
                                Spacer()
                                Text(info.utcOffset)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11))
                            }
                        }
                    }
                }
            }
        } label: {
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
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(!appState.canAddMoreClocks)
        .opacity(appState.canAddMoreClocks ? 1 : 0.5)
        .onAppear {
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
        }
        .onChange(of: searchText) { _, _ in
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
        }
        .onChange(of: appState.favoriteTimezones) { _, _ in
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
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
}
