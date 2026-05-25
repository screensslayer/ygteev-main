//
//  SmallGroupDetailView.swift
//  YGTeeV
//
//  Pastor-only detail screen for a single small group. Surfaces:
//    • Editable basics (name / description / meeting day & time)
//    • Roster split into Leaders + Members with per-row actions
//      (promote/demote/remove)
//    • Add-member sheet (filtered to youth-group members not already in)
//    • Destructive Delete-this-small-group action
//
//  All writes go directly to `small_groups` / `small_group_members` via
//  PostgREST — the `pastor manage` RLS policies + insert/delete chat
//  triggers handle everything else server-side.
//

import SwiftUI
import Supabase

@MainActor
struct PastorSmallGroupDetailView: View {
    let youthGroupId: UUID
    let smallGroup: PastorSmallGroup

    @State private var service = PastorDashboardService.shared
    @Environment(\.dismiss) private var dismiss

    // Roster
    @State private var roster: [PastorSmallGroupMemberRow] = []
    @State private var isLoadingRoster = false

    // Editable basics
    @State private var name = ""
    @State private var description = ""
    @State private var meetingDay = ""
    @State private var meetingTime = ""
    @State private var isSavingBasics = false
    @State private var basicsDirty = false

    // Sheets / alerts
    @State private var showAddMember = false
    @State private var showDeleteConfirm = false
    @State private var error: String?

    @FocusState private var focusedField: BasicsField?
    enum BasicsField { case name, description, day, time }

    private var leaders: [PastorSmallGroupMemberRow] {
        roster.filter { $0.role == "leader" }
    }
    private var members: [PastorSmallGroupMemberRow] {
        roster.filter { $0.role == "member" }
    }

    private var canSaveBasics: Bool {
        !isSavingBasics && basicsDirty &&
            !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            YGColors.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    heroHeader
                    basicsCard
                    leadersCard
                    membersCard
                    deleteButton
                    if let error {
                        Text(error)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 80)
            }
            .refreshable { await loadRoster() }
        }
        .navigationTitle(name.isEmpty ? smallGroup.name : name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            name        = smallGroup.name
            description = smallGroup.description ?? ""
            meetingDay  = smallGroup.meetingDay ?? ""
            meetingTime = smallGroup.meetingTime ?? ""
            basicsDirty = false
            await loadRoster()
        }
        .onChange(of: name)        { _, _ in basicsDirty = true }
        .onChange(of: description) { _, _ in basicsDirty = true }
        .onChange(of: meetingDay)  { _, _ in basicsDirty = true }
        .onChange(of: meetingTime) { _, _ in basicsDirty = true }
        .sheet(isPresented: $showAddMember) {
            AddSmallGroupMemberSheet(
                youthGroupId: youthGroupId,
                smallGroupId: smallGroup.smallGroupId,
                alreadyIn: Set(roster.map(\.userId)),
                onAdded: {
                    Task {
                        await loadRoster()
                        await service.loadSmallGroups()
                    }
                }
            )
        }
        .alert("Delete this small group?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await deleteGroup() } }
            Button("Cancel",  role: .cancel) {}
        } message: {
            Text("Members are removed from this small group but stay in the youth group. This can't be undone.")
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        HStack(spacing: 14) {
            Text(String(smallGroup.name.prefix(1)).uppercased())
                .font(.lilitaOne(size: 28))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [YGColors.violet, Color(hex: "FF3DA5")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: YGColors.violet.opacity(0.35), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(smallGroup.name)
                    .font(.lilitaOne(size: 22))
                    .tracking(-0.5)
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(2)
                Text("\(roster.count) member\(roster.count == 1 ? "" : "s")"
                     + (leaders.isEmpty ? "" : " · \(leaders.count) leader\(leaders.count == 1 ? "" : "s")"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
        .padding(.top, 8)
    }

    // MARK: - Basics

    private var basicsCard: some View {
        VStack(spacing: 0) {
            sectionLabel("BASICS")

            VStack(spacing: 0) {
                field(label: "NAME",
                      placeholder: "7th Grade Boys",
                      text: $name,
                      capitalization: .words,
                      field: .name)
                Divider().padding(.leading, 14)
                multilineField(label: "DESCRIPTION",
                               placeholder: "What's the vibe?",
                               text: $description,
                               field: .description)
                Divider().padding(.leading, 14)
                field(label: "MEETING DAY",
                      placeholder: "Wednesday",
                      text: $meetingDay,
                      capitalization: .words,
                      field: .day)
                Divider().padding(.leading, 14)
                field(label: "MEETING TIME",
                      placeholder: "6:30 PM",
                      text: $meetingTime,
                      capitalization: .characters,
                      field: .time)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)

            Button { Task { await saveBasics() } } label: {
                HStack(spacing: 6) {
                    if isSavingBasics {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    }
                    Text(isSavingBasics ? "Saving…" : "Save changes")
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [YGColors.violet, Color(hex: "FF3DA5")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: YGColors.violet.opacity(0.3), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(!canSaveBasics)
            .opacity(canSaveBasics ? 1 : 0.4)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 10)
            .padding(.trailing, 2)
        }
    }

    // MARK: - Leaders

    private var leadersCard: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Leaders",
                count: leaders.count,
                accent: Color(hex: "0066FF"),
                trailing: { EmptyView() }
            )

            VStack(spacing: 8) {
                if leaders.isEmpty {
                    emptyHint(text: "No leader yet — promote any member below.")
                } else {
                    ForEach(leaders) { row in personRow(row, isLeader: true) }
                }
            }
        }
    }

    // MARK: - Members

    private var membersCard: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Members",
                count: members.count,
                accent: YGColors.violet,
                trailing: {
                    Button { showAddMember = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .heavy))
                            Text("Add")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            )

            VStack(spacing: 8) {
                if members.isEmpty && !isLoadingRoster {
                    emptyHint(text: "No members yet — tap Add to bring people in.")
                }
                ForEach(members) { row in personRow(row, isLeader: false) }
            }
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .heavy))
                Text("Delete small group")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Color(hex: "D11149"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "D11149").opacity(0.08))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color(hex: "D11149").opacity(0.25), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Building blocks

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .black))
            .tracking(1)
            .foregroundStyle(YGColors.ink.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
            .padding(.leading, 4)
    }

    private func sectionHeader<Trailing: View>(
        title: String,
        count: Int,
        accent: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.lilitaOne(size: 16))
                .tracking(-0.3)
                .foregroundStyle(YGColors.ink)
            Text("\(count)")
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(accent.opacity(0.12))
                .clipShape(Capsule())
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
    }

    private func emptyHint(text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(YGColors.ink.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.black.opacity(0.04), lineWidth: 0.5)
            }
    }

    private func personRow(_ row: PastorSmallGroupMemberRow, isLeader: Bool) -> some View {
        HStack(spacing: 12) {
            Text(String((row.displayName ?? "?").prefix(1)).uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(
                        colors: isLeader
                            ? [Color(hex: "0066FF"), Color(hex: "00E0FF")]
                            : [YGColors.violet, Color(hex: "FF3DA5")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName ?? "Unnamed")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                rolePill(isLeader: isLeader)
            }

            Spacer(minLength: 0)

            Menu {
                if isLeader {
                    Button("Make member") { Task { await setRole(row, to: "member") } }
                } else {
                    Button("Make leader") { Task { await setRole(row, to: "leader") } }
                }
                Button("Remove from small group", role: .destructive) {
                    Task { await remove(row) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                    .frame(width: 32, height: 32)
                    .background(YGColors.ink.opacity(0.06))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
    }

    private func rolePill(isLeader: Bool) -> some View {
        let (label, color, bg): (String, Color, Color) = isLeader
            ? ("LEADER", Color(hex: "0066FF"), Color(hex: "0066FF").opacity(0.12))
            : ("MEMBER", YGColors.ink.opacity(0.55), YGColors.ink.opacity(0.06))
        return Text(label)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func field(label: String,
                       placeholder: String,
                       text: Binding<String>,
                       capitalization: TextInputAutocapitalization,
                       field: BasicsField) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func multilineField(label: String,
                                placeholder: String,
                                text: Binding<String>,
                                field: BasicsField) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField(placeholder, text: text, axis: .vertical)
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .lineLimit(2...5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data ops

    /// Two-query fetch: small_group_members rows + matching profiles.
    /// Avoids supabase-swift's nested-select decode quirks.
    private func loadRoster() async {
        isLoadingRoster = true
        defer { isLoadingRoster = false }

        struct SGMRow: Decodable {
            let id: UUID
            let userId: UUID
            let role: String
            let joinedAt: Date
            enum CodingKeys: String, CodingKey {
                case id, role
                case userId   = "user_id"
                case joinedAt = "joined_at"
            }
        }
        struct ProfileRow: Decodable {
            let id: UUID
            let displayName: String?
            let avatarUrl: String?
            enum CodingKeys: String, CodingKey {
                case id
                case displayName = "display_name"
                case avatarUrl   = "avatar_url"
            }
        }

        do {
            let rows: [SGMRow] = try await SupabaseManager.shared.client
                .from("small_group_members")
                .select("id, user_id, role, joined_at")
                .eq("small_group_id", value: smallGroup.smallGroupId.uuidString.lowercased())
                .execute().value

            guard !rows.isEmpty else {
                roster = []
                return
            }

            let userIds = rows.map { $0.userId.uuidString.lowercased() }
            let profiles: [ProfileRow] = try await SupabaseManager.shared.client
                .from("profiles")
                .select("id, display_name, avatar_url")
                .in("id", values: userIds)
                .execute().value

            let byId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            roster = rows.map { r in
                let p = byId[r.userId]
                return PastorSmallGroupMemberRow(
                    id: r.id,
                    userId: r.userId,
                    role: r.role,
                    displayName: p?.displayName,
                    avatarUrl: p?.avatarUrl,
                    joinedAt: r.joinedAt
                )
            }
            .sorted { a, b in
                if a.role != b.role { return a.role == "leader" }
                let an = (a.displayName ?? "").lowercased()
                let bn = (b.displayName ?? "").lowercased()
                return an < bn
            }
        } catch {
            self.error = "Couldn't load members. \(error.localizedDescription)"
        }
    }

    private func saveBasics() async {
        struct Patch: Encodable {
            let name: String
            let description: String?
            let meeting_day: String?
            let meeting_time: String?
        }
        isSavingBasics = true
        error = nil
        defer { isSavingBasics = false }
        do {
            _ = try await SupabaseManager.shared.client
                .from("small_groups")
                .update(Patch(
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description,
                    meeting_day:  meetingDay.trimmingCharacters(in: .whitespaces).isEmpty  ? nil : meetingDay,
                    meeting_time: meetingTime.trimmingCharacters(in: .whitespaces).isEmpty ? nil : meetingTime
                ))
                .eq("id", value: smallGroup.smallGroupId.uuidString.lowercased())
                .execute()
            await service.loadSmallGroups()
            basicsDirty = false
        } catch {
            self.error = "Couldn't save. \(error.localizedDescription)"
        }
    }

    private func setRole(_ row: PastorSmallGroupMemberRow, to role: String) async {
        struct Patch: Encodable { let role: String }
        do {
            _ = try await SupabaseManager.shared.client
                .from("small_group_members")
                .update(Patch(role: role))
                .eq("id", value: row.id.uuidString.lowercased())
                .execute()
            await loadRoster()
            await service.loadSmallGroups()
        } catch {
            self.error = "Couldn't update role. \(error.localizedDescription)"
        }
    }

    private func remove(_ row: PastorSmallGroupMemberRow) async {
        do {
            _ = try await SupabaseManager.shared.client
                .from("small_group_members")
                .delete()
                .eq("id", value: row.id.uuidString.lowercased())
                .execute()
            await loadRoster()
            await service.loadSmallGroups()
        } catch {
            self.error = "Couldn't remove. \(error.localizedDescription)"
        }
    }

    private func deleteGroup() async {
        do {
            _ = try await SupabaseManager.shared.client
                .from("small_groups")
                .delete()
                .eq("id", value: smallGroup.smallGroupId.uuidString.lowercased())
                .execute()
            await service.loadSmallGroups()
            dismiss()
        } catch {
            self.error = "Couldn't delete. \(error.localizedDescription)"
        }
    }
}

// MARK: - Roster row model

/// One row in the small-group roster — merged from `small_group_members`
/// + `profiles`. Local-only; not used by any RPC.
struct PastorSmallGroupMemberRow: Identifiable, Hashable {
    let id: UUID            // small_group_members.id
    let userId: UUID
    let role: String        // 'leader' | 'member'
    let displayName: String?
    let avatarUrl: String?
    let joinedAt: Date
}
