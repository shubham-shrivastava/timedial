//
//  TimezoneSearchPicker.swift
//  timedial
//
//  Timezone picker trigger buttons and panel content.
//  Buttons open a native NSPanel via PickerPanelController,
//  avoiding crash-prone nested SwiftUI popovers.
//

import SwiftUI

// MARK: - Inline Picker Button (clock card header)

struct TimezoneInlinePicker: View {
    let timezoneIdentifier: String
    let clockId: UUID

    @EnvironmentObject private var appState: AppState
    @StateObject private var frameRef = ScreenFrameRef()

    var body: some View {
        Button(action: {
            appState.showPickerPanel(
                mode: .changeTimezone(clockId: clockId),
                from: frameRef.screenFrame
            )
        }) {
            HStack(spacing: 3) {
                Text(ClockConfig.displayName(for: timezoneIdentifier))
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .background(ScreenFrameCapture(ref: frameRef))
    }
}

// MARK: - Add Clock Button

struct AddClockPicker: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var frameRef = ScreenFrameRef()

    var body: some View {
        Button(action: {
            appState.showPickerPanel(mode: .addClock, from: frameRef.screenFrame)
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
        .background(ScreenFrameCapture(ref: frameRef))
    }
}

// MARK: - Picker Panel Content (hosted by NSPanel)

struct TimezonePickerPanel: View {
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var groupedTimezones: [AppState.TimezoneGroup] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Select Timezone")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            TextField("Search city, region, or abbreviation...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)

            Divider()

            listView
        }
        .padding(14)
        .frame(width: 340, height: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            searchText = ""
            groupedTimezones = appState.cachedTimezoneGroups
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onChange(of: searchText) { _, _ in
            groupedTimezones = appState.getGroupedTimezones(searchQuery: searchText)
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
                                onSelect(info.id)
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
}

// MARK: - Timezone Row

struct TimezoneRow: View {
    let info: AppState.TimezoneInfo
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(info.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        if !info.localizedName.isEmpty {
                            Text(info.localizedName)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(info.utcOffset)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        if !info.abbreviation.isEmpty {
                            Text(info.abbreviation)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
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
    ZStack {
        Color.gray.opacity(0.2)
        TimezonePickerPanel(onSelect: { _ in }, onDismiss: {})
    }
    .frame(width: 600, height: 500)
    .environmentObject(AppState.shared)
}
