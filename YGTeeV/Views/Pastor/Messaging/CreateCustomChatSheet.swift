//
//  CreateCustomChatSheet.swift
//  YGTeeV
//
//  Compose surface for a pastor/leader-authored custom chat. Wraps
//  the MemberPickerSheet for the member-selection step and calls
//  `ChatService.createCustomThread` on Create.
//

import SwiftUI

struct CreateCustomChatSheet: View {
    let groupId: UUID
    /// Returns the freshly-created thread to the caller so the parent
    /// can refresh + navigate into it.
    let onCreated: (ChatThreadSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chat = ChatService.shared
    @State private var dashboard = PastorDashboardService.shared

    @State private var name: String = ""
    @State private var selectedUserIds: Set<UUID> = []
    @State private var showMemberPicker = false
    @State private var isCreating = false
    @State private var errorText: String?

    /// Cap matches the backend CHECK constraint on `chat_threads.title`.
    /// Keep the value here and on the server in sync.
    private let maxTitle = 60

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    nameField
                    membersBlock
                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(YGColors.paper.ignoresSafeArea())
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await create() }
                    } label: {
                        HStack(spacing: 6) {
                            if isCreating { ProgressView().scaleEffect(0.7) }
                            Text(isCreating ? "Creating…" : "Create chat")
                                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        }
                    }
                    .tint(YGColors.violet)
                    .disabled(!canCreate)
                }
            }
            .sheet(isPresented: $showMemberPicker) {
                MemberPickerSheet(
                    groupId: groupId,
                    excludedUserIds: callerExclusion,
                    initialSelection: selectedUserIds,
                    onDone: { ids in
                        selectedUserIds = ids
                    }
                )
            }
        }
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chat name")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(YGColors.ink.opacity(0.55))

            TextField("e.g. Summer Camp Planning", text: $name)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.08), lineWidth: 1) }
                .onChange(of: name) { _, newValue in
                    if newValue.count > maxTitle {
                        name = String(newValue.prefix(maxTitle))
                    }
                }

            Text("\(name.count)/\(maxTitle)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Members

    private var membersBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Members")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(YGColors.ink.opacity(0.55))

            Button {
                showMemberPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(selectedUserIds.isEmpty ? "Add members" : "Edit members")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(YGColors.ink.opacity(0.35))
                }
                .foregroundStyle(YGColors.ink)
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.08), lineWidth: 1) }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Text("Selected:")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                Text("you + \(selectedUserIds.count)")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
            }
            .padding(.top, 2)

            if !selectedUserIds.isEmpty {
                selectedRosterList
            }
        }
    }

    private var selectedMembers: [PastorMember] {
        // Order-stable, alphabetical for legibility — the picker uses
        // an unordered Set so we sort here.
        dashboard.allMembers
            .filter { selectedUserIds.contains($0.userId) }
            .sorted { a, b in
                (a.displayName ?? "") < (b.displayName ?? "")
            }
    }

    private var selectedRosterList: some View {
        VStack(spacing: 6) {
            ForEach(selectedMembers) { member in
                HStack(spacing: 10) {
                    Text(String((member.displayName ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                    Text(member.displayName ?? "—")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(YGColors.ink)
                    Spacer()
                    Button {
                        selectedUserIds.remove(member.userId)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(YGColors.ink.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
            }
        }
    }

    // MARK: - Validation / create

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "You + at least 1" → selection.count >= 1 (the caller is added
    /// implicitly below).
    private var canCreate: Bool {
        !isCreating
        && !trimmedName.isEmpty
        && selectedUserIds.count >= 1
    }

    private var currentUserId: UUID? {
        guard let raw = SupabaseManager.shared.currentUser?.id else { return nil }
        return UUID(uuidString: raw)
    }

    private var callerExclusion: Set<UUID> {
        guard let me = currentUserId else { return [] }
        return [me]
    }

    private func create() async {
        guard canCreate else { return }
        guard let me = currentUserId else {
            errorText = "Couldn't identify your account — try again."
            return
        }
        isCreating = true
        errorText  = nil
        defer { isCreating = false }

        // Caller is always part of their own custom chat. Union here
        // so the server doesn't have to special-case the creator.
        let ids = selectedUserIds.union([me])

        do {
            let thread = try await chat.createCustomThread(
                groupId:        groupId,
                title:          trimmedName,
                initialUserIds: Array(ids),
                eventId:        nil
            )
            onCreated(thread)
            dismiss()
        } catch {
            errorText = "Couldn't create chat — try again"
            print("[CreateCustomChatSheet] create failed:", error)
        }
    }
}
