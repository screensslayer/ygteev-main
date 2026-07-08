//
//  MemberPickerSheet.swift
//  YGTeeV
//
//  Reusable multi-select picker for youth-group members. Used by
//  CreateCustomChatSheet to seed a new custom chat and (later) by the
//  add-member-to-existing-chat flow.
//
//  Pulls rows from PastorDashboardService.allMembers (the same payload
//  that powers the Members tab). Filters out the caller — they're
//  added to the chat implicitly by CreateCustomChatSheet before the
//  RPC call.
//

import SwiftUI

struct MemberPickerSheet: View {
    let groupId: UUID
    /// User IDs the caller already excludes (typically just the caller
    /// themselves). The picker hides these rows entirely.
    let excludedUserIds: Set<UUID>
    /// Pre-selected IDs when re-opening the picker. The sheet seeds
    /// its local selection set from this so a user can refine instead
    /// of starting over.
    let initialSelection: Set<UUID>
    /// Final selection — emitted on Done.
    let onDone: (Set<UUID>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dashboard = PastorDashboardService.shared
    @State private var search: String = ""
    @State private var selected: Set<UUID>
    @State private var isLoading = false

    init(groupId: UUID,
         excludedUserIds: Set<UUID> = [],
         initialSelection: Set<UUID> = [],
         onDone: @escaping (Set<UUID>) -> Void) {
        self.groupId          = groupId
        self.excludedUserIds  = excludedUserIds
        self.initialSelection = initialSelection
        self.onDone           = onDone
        _selected = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if isLoading && dashboard.allMembers.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    Text(search.isEmpty ? "No members yet" : "No matches")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { member in
                            row(member)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(YGColors.paper.ignoresSafeArea())
            .navigationTitle("Add members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDone(selected)
                        dismiss()
                    } label: {
                        Text(selected.isEmpty ? "Done" : "Done (\(selected.count))")
                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    }
                    .tint(YGColors.violet)
                }
            }
            .task { await loadIfNeeded() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search members", text: $search)
                .textInputAutocapitalization(.never)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var filtered: [PastorMember] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return dashboard.allMembers
            .filter { !excludedUserIds.contains($0.userId) }
            .filter { member in
                guard !q.isEmpty else { return true }
                let name  = (member.displayName ?? "").lowercased()
                let email = (member.email ?? "").lowercased()
                return name.contains(q) || email.contains(q)
            }
    }

    private func row(_ member: PastorMember) -> some View {
        Button {
            if selected.contains(member.userId) {
                selected.remove(member.userId)
            } else {
                selected.insert(member.userId)
            }
        } label: {
            HStack(spacing: 12) {
                avatar(for: member)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: member))
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                    HStack(spacing: 6) {
                        roleBadge(member.role)
                        if let g = member.gradeYear {
                            Text("\(g)\(g.ordinalSuffix) grade")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: selected.contains(member.userId)
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected.contains(member.userId)
                                     ? YGColors.violet
                                     : YGColors.ink.opacity(0.25))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
    }

    private func displayName(for member: PastorMember) -> String {
        if let name = member.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let email = member.email,
           let local = email.split(separator: "@").first, !local.isEmpty {
            return String(local)
        }
        return "—"
    }

    @ViewBuilder
    private func roleBadge(_ role: MemberRole) -> some View {
        let (label, color): (String, Color) = {
            switch role {
            case .pastor: return ("PASTOR", YGColors.violet)
            case .leader: return ("LEADER", Color(hex: "0066FF"))
            case .parent: return ("PARENT", YGColors.lime)
            case .member: return ("MEMBER", YGColors.ink.opacity(0.55))
            }
        }()
        Text(label)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .tracking(0.4)
    }

    @ViewBuilder
    private func avatar(for member: PastorMember) -> some View {
        if let urlString = member.avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    initialsFallback(for: member)
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
        } else {
            initialsFallback(for: member)
        }
    }

    private func initialsFallback(for member: PastorMember) -> some View {
        Text(String(displayName(for: member).prefix(1)).uppercased())
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
    }

    private func loadIfNeeded() async {
        // Re-fetch when the cached list is empty or scoped to a
        // different group. The service flushes its cache on
        // activeGroupId change, so the second condition catches stale
        // post-archive states.
        let needsFetch = dashboard.allMembers.isEmpty
            || dashboard.activeGroupId != groupId
        guard needsFetch else { return }

        if dashboard.activeGroupId != groupId {
            dashboard.activeGroupId = groupId
        }
        isLoading = true
        await dashboard.loadAllMembers()
        isLoading = false
    }
}
