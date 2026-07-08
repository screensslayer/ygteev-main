//
//  NotificationSettingsView.swift
//  YGTeeV
//
//  Per-category + per-kind notification preferences screen reachable
//  from the Settings sheet. Layout:
//
//    • Bible-reading reminder time (hour-of-day wheel)
//    • One section per server-returned category, each with a master
//      Toggle plus per-kind Toggles inside. Disabling the master
//      grays out the children but preserves their individual state
//      so re-enabling the master restores the prior config.
//
//  Save flow: every toggle / hour change kicks off a 500 ms-debounced
//  background write to `notification_preferences`. The nav bar shows
//  a "Saved" indicator once the last write lands.
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = NotificationSettingsService.shared

    /// Server-fetched config. While `nil` we render a ProgressView;
    /// on load failure we surface an inline error + Reload button.
    @State private var settings: NotificationSettings?
    @State private var loadError: String?

    /// Editable local mirror of the data — toggling a category or
    /// kind mutates these sets, NOT the (immutable) `settings` struct.
    @State private var disabledCategories: Set<String> = []
    @State private var disabledKinds: Set<String> = []
    @State private var dailyReadingHour: Int = 8

    /// Debounce. Each toggle flip cancels the previous task so we
    /// only POST once per quiet 500 ms window.
    @State private var saveTask: Task<Void, Never>?
    @State private var lastSavedAt: Date?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) { savedIndicator }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let settings, !settings.categories.isEmpty {
            Form {
                reminderTimeSection
                ForEach(settings.categories.sorted(by: { $0.sortOrder < $1.sortOrder })) { cat in
                    categorySection(cat)
                }
                if let saveError {
                    Section { Text(saveError).font(.footnote).foregroundStyle(.red) }
                }
            }
        } else if settings != nil {
            ContentUnavailableView(
                "No notification options",
                systemImage: "bell.slash",
                description: Text("No notification categories are configured for your account yet.")
            )
        } else if let loadError {
            VStack(spacing: 12) {
                Text(loadError).font(.subheadline).foregroundStyle(.secondary)
                Button("Reload") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await load() }
        }
    }

    // MARK: - Sections

    private var reminderTimeSection: some View {
        Section {
            Picker("Reminder time", selection: Binding(
                get: { dailyReadingHour },
                set: { newValue in
                    dailyReadingHour = newValue
                    scheduleSave()
                }
            )) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(Self.format(hour: hour)).tag(hour)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Bible reading reminder")
        } footer: {
            Text("We'll send a daily reading reminder around this time, in your current device timezone.")
        }
    }

    @ViewBuilder
    private func categorySection(_ category: NotificationCategory) -> some View {
        let categoryEnabled = !disabledCategories.contains(category.key)
        Section {
            // Master toggle for the whole category.
            Toggle(category.label, isOn: Binding(
                get: { categoryEnabled },
                set: { isOn in
                    if isOn {
                        disabledCategories.remove(category.key)
                    } else {
                        disabledCategories.insert(category.key)
                    }
                    scheduleSave()
                }
            ))
            .font(.body.weight(.semibold))

            // Per-kind toggles inside the category. They stay
            // interactive at the data level but visually grayed when
            // the master is off — so a user who re-enables the
            // master gets their previous per-kind config back.
            ForEach(category.kinds) { kind in
                kindRow(kind, categoryEnabled: categoryEnabled)
            }
        }
    }

    private func kindRow(_ kind: NotificationKind, categoryEnabled: Bool) -> some View {
        let kindEnabled = !disabledKinds.contains(kind.key)
        return Toggle(isOn: Binding(
            get: { kindEnabled },
            set: { isOn in
                if isOn {
                    disabledKinds.remove(kind.key)
                } else {
                    disabledKinds.insert(kind.key)
                }
                scheduleSave()
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.label).font(.body)
                if let desc = kind.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!categoryEnabled)
        .opacity(categoryEnabled ? 1 : 0.45)
    }

    // MARK: - Saved indicator

    @ViewBuilder
    private var savedIndicator: some View {
        if saveTask != nil {
            ProgressView().controlSize(.small)
        } else if let lastSavedAt {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(Self.savedAgo(from: lastSavedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Loading + saving

    private func load() async {
        loadError = nil
        do {
            let s = try await service.load()
            settings = s
            // Seed the editable mirrors from server truth.
            disabledCategories = Set(s.categories.filter { !$0.enabled }.map(\.key))
            var kindsOff: Set<String> = []
            for cat in s.categories {
                for k in cat.kinds where !k.enabled {
                    kindsOff.insert(k.key)
                }
            }
            disabledKinds = kindsOff
            dailyReadingHour = max(0, min(23, s.dailyReadingHour))
        } catch {
            loadError = "Couldn't load notification settings. \(error.localizedDescription)"
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveError = nil
        saveTask = Task { [disabledCategories, disabledKinds, dailyReadingHour] in
            // Quiet-window debounce. Cancelled by the next toggle if
            // the user keeps flipping things within 500 ms.
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            do {
                try await service.save(
                    disabledCategories: Array(disabledCategories).sorted(),
                    disabledKinds: Array(disabledKinds).sorted(),
                    dailyReadingHour: dailyReadingHour,
                    dailyReadingTimezone: TimeZone.current.identifier
                )
                if !Task.isCancelled {
                    lastSavedAt = Date()
                }
            } catch {
                if !Task.isCancelled {
                    saveError = "Couldn't save changes. \(error.localizedDescription)"
                }
            }
            saveTask = nil
        }
    }

    // MARK: - Formatting helpers

    private static func format(hour: Int) -> String {
        let comps = DateComponents(hour: hour, minute: 0)
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private static func savedAgo(from date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 5 { return "Saved" }
        if secs < 60 { return "Saved \(secs)s ago" }
        let mins = secs / 60
        return "Saved \(mins)m ago"
    }
}
