//
//  AddSmallGroupMemberSheet.swift
//  YGTeeV
//
//  Picker that lists every youth-group member NOT already in the small
//  group. Tapping "Add" inserts the row into `small_group_members` with
//  `role = 'member'` — the `tg_chat_on_small_group_member_insert`
//  trigger auto-subscribes them to the small-group chat thread.
//

import SwiftUI
import Supabase

struct AddSmallGroupMemberSheet: View {
    let youthGroupId: UUID
    let smallGroupId: UUID
    let alreadyIn: Set<UUID>
    let onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [PastorMember] = []
    @State private var isLoading = true
    @State private var savingFor: UUID?
    @State private var error: String?

    @State private var query: String = ""

    private var eligible: [PastorMember] {
        let pool = candidates.filter { !alreadyIn.contains($0.userId) }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return pool }
        let q = query.lowercased()
        return pool.filter { m in
            (m.displayName ?? "").lowercased().contains(q)
                || (m.email ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            YGColors.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    searchField
                    contentBlock
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
                .padding(.bottom, 40)
            }

            VStack {
                topBar
                Spacer()
            }
        }
        .task { await loadCandidates() }
    }

    // MARK: - Top chrome

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(YGColors.ink.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Add member")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.55))

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pick a member")
                .font(.lilitaOne(size: 26))
                .tracking(-0.6)
                .foregroundStyle(YGColors.ink)
            Text("They'll be added to this small group with member role. You can promote them to leader from the detail view.")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.6))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 36)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(YGColors.ink.opacity(0.45))
            TextField("Search by name or email", text: $query)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(YGColors.ink.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var contentBlock: some View {
        if isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading members…")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if eligible.isEmpty {
            emptyCard
        } else {
            LazyVStack(spacing: 8) {
                ForEach(eligible) { m in
                    row(for: m)
                }
            }
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Text("👥").font(.system(size: 40))
            Text(query.isEmpty ? "Everyone's already in" : "No matches")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text(query.isEmpty
                 ? "Add new members to the youth group first, then come back here."
                 : "Try a different name or email.")
                .font(.system(size: 12.5))
                .foregroundStyle(YGColors.ink.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
    }

    private func row(for m: PastorMember) -> some View {
        HStack(spacing: 12) {
            Text(String((m.displayName ?? m.email ?? "?").prefix(1)).uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(
                        colors: [YGColors.violet, Color(hex: "FF3DA5")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(m.displayName ?? m.email ?? "Member")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                rolePill(role: m.role)
            }

            Spacer(minLength: 0)

            if savingFor == m.userId {
                ProgressView().scaleEffect(0.85)
                    .frame(width: 60, height: 28)
            } else {
                Button { Task { await add(m) } } label: {
                    Text("Add")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: YGColors.violet.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
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

    private func rolePill(role: MemberRole) -> some View {
        let (label, color, bg): (String, Color, Color) = {
            switch role {
            case .pastor: return ("PASTOR", YGColors.violet, YGColors.violet.opacity(0.14))
            case .leader: return ("LEADER", Color(hex: "0066FF"), Color(hex: "0066FF").opacity(0.12))
            case .parent: return ("PARENT", Color(hex: "2B8A3E"), Color(hex: "B4FF3C").opacity(0.22))
            case .member: return ("MEMBER", YGColors.ink.opacity(0.55), YGColors.ink.opacity(0.06))
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Data

    private func loadCandidates() async {
        isLoading = true
        defer { isLoading = false }

        struct Params: Encodable {
            let _group_id: UUID
            let _role_filter: String
            let _active_only: Bool
        }
        do {
            let rows: [PastorMember] = try await SupabaseManager.shared.client
                .rpc("pastor_list_group_members",
                     params: Params(
                        _group_id: youthGroupId,
                        _role_filter: "all",
                        _active_only: false
                     ))
                .execute().value
            candidates = rows
        } catch {
            self.error = "Couldn't load members. \(error.localizedDescription)"
        }
    }

    private func add(_ m: PastorMember) async {
        struct Row: Encodable {
            let small_group_id: UUID
            let user_id: UUID
            let role: String
        }
        savingFor = m.userId
        defer { savingFor = nil }
        do {
            _ = try await SupabaseManager.shared.client
                .from("small_group_members")
                .insert(Row(
                    small_group_id: smallGroupId,
                    user_id: m.userId,
                    role: "member"
                ))
                .execute()
            // Drop the just-added row from the picker without a server
            // round-trip so the user sees instant feedback.
            candidates.removeAll { $0.userId == m.userId }
            onAdded()
        } catch {
            self.error = "Couldn't add. \(error.localizedDescription)"
        }
    }
}
