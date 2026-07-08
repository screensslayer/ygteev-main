//
//  ChildSettingsSheet.swift
//  YGTeeV
//
//  Parent-side per-child settings, reached by tapping a child row in
//  the My Family carousel. Currently surfaces a single Messaging
//  section that drives `get_child_dm_setting` / `set_child_staff_dms`.
//  If the pastor has flipped the group-wide kill switch off, the
//  toggle is forced to OFF + non-tappable with a "locked by pastor"
//  caption — the parent can't override at that point.
//

import SwiftUI

struct ChildSettingsSheet: View {
    let child: FamilyMember

    @Environment(\.dismiss) private var dismiss
    @State private var setting: ChildDmSetting?
    @State private var loadError: String?
    @State private var dmsLocal: Bool = true
    @State private var saveError: String?
    @State private var saveTask: Task<Void, Never>?

    private var firstName: String {
        let name = child.displayName ?? ""
        return name.split(separator: " ").first.map(String.init) ?? (name.isEmpty ? "They" : name)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(child.displayName ?? "Child")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                // `.task` lives on the always-alive NavigationStack so
                // a body re-render mid-load doesn't surface as a
                // "cancelled" error toast.
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let setting {
            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { dmsLocal },
                        set: { newVal in
                            // Guard against accidental writes when the
                            // pastor's kill switch is on — the disabled
                            // modifier should already block this, but
                            // belt-and-suspenders.
                            guard !setting.lockedByPastor else { return }
                            dmsLocal = newVal
                            scheduleWrite(newVal)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow 1-on-1 messages with leader & pastor")
                                .font(.body.weight(.semibold))
                            Text(captionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .disabled(setting.lockedByPastor)
                    .tint(YGColors.violet)
                } header: {
                    Text("Messaging")
                }
                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        } else if let loadError {
            VStack(spacing: 12) {
                Text(loadError).font(.subheadline).foregroundStyle(.secondary)
                Button("Reload") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var captionText: String {
        guard let setting else { return "" }
        if setting.lockedByPastor {
            let group = setting.groupName.map { "\($0)'s pastor" } ?? "the group's pastor"
            return "Turned off by \(group) for the whole group."
        }
        if dmsLocal {
            return "\(firstName) can privately message their leader and pastor."
        }
        return "\(firstName) can only use group and small-group chats."
    }

    // MARK: - Network

    private func load() async {
        loadError = nil
        do {
            let s = try await FamilyService.shared.getChildDmSetting(childId: child.userId)
            if Task.isCancelled { return }
            setting = s
            // If the pastor has the kill switch on, force the visible
            // value to false regardless of the per-child override.
            dmsLocal = s.lockedByPastor ? false : s.enabled
        } catch is CancellationError {
            return
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            loadError = "Couldn't load settings. \(error.localizedDescription)"
        }
    }

    /// Debounced write so rapid tapping coalesces to a single PATCH.
    /// Refreshes chat threads after the write so a now-disabled DM
    /// drops off the parent's list.
    private func scheduleWrite(_ value: Bool) {
        saveTask?.cancel()
        saveError = nil
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            do {
                try await FamilyService.shared.setChildStaffDms(
                    childId: child.userId, enabled: value)
                await ChatService.shared.loadThreads()
            } catch {
                if !Task.isCancelled {
                    saveError = "Couldn't save. \(error.localizedDescription)"
                    // Reload truth from server so the visible switch
                    // matches what's actually persisted.
                    await load()
                }
            }
        }
    }
}
