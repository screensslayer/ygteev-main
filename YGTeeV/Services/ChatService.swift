//
//  ChatService.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/11/26.
//

import Foundation
import Supabase

@Observable
final class ChatService {
    static let shared = ChatService()
    private let client = SupabaseManager.shared.client

    var threads: [ChatThreadSummary] = []
    var messagesByThread: [UUID: [ChatMessageWithSender]] = [:]
    var rolesByGroup: [UUID: [UUID: String]] = [:]    // groupId -> userId -> role
    var groupStats: [UUID: (members: Int, active: Int)] = [:]
    var profileCache: [UUID: (name: String, avatarUrl: String?)] = [:]
    private var realtimeChannels: [UUID: RealtimeChannelV2] = [:]

    // MARK: - Thread list
    
    func loadThreads() async {
        do {
            let list: [ChatThreadSummary] = try await client
                .rpc("list_my_threads")
                .execute().value
            await MainActor.run { self.threads = list }
        } catch {
            print("[ChatService] \(#function) error:", error)
        }
    }

    // MARK: - Messages: initial fetch
    
    @discardableResult
    func loadMessages(threadId: UUID, limit: Int = 50, offset: Int = 0) async -> Int {
        struct MessageRow: Decodable {
            let id: UUID
            let thread_id: UUID
            let sender_id: UUID
            let body: String
            let moderation_status: ModerationStatus
            let created_at: Date
        }

        struct ProfileRow: Decodable {
            let id: UUID
            let display_name: String?
            let avatar_url: String?
            let email: String?
        }

        do {
            // Load messages with pagination (newest-first, then offset window)
            let messages: [MessageRow] = try await client
                .from("messages")
                .select("id, thread_id, sender_id, body, moderation_status, created_at")
                .eq("thread_id", value: threadId.uuidString.lowercased())
                .order("created_at", ascending: false)  // Newest first
                .range(from: offset, to: offset + limit - 1)
                .execute().value

            // Get unique sender IDs
            let senderIds = Set(messages.map { $0.sender_id })

            // Load profiles for all senders
            var profiles: [UUID: ProfileRow] = [:]
            if !senderIds.isEmpty {
                let profileRows: [ProfileRow] = try await client
                    .from("profiles")
                    .select("id, display_name, avatar_url, email")
                    .in("id", values: senderIds.map { $0.uuidString.lowercased() })
                    .execute().value

                for profile in profileRows {
                    profiles[profile.id] = profile
                }
            }

            // Combine messages with profiles (reverse to oldest-first for display)
            let items: [ChatMessageWithSender] = messages.reversed().map { msg in
                let profile = profiles[msg.sender_id]
                return ChatMessageWithSender(
                    message: ChatMessage(
                        id: msg.id, threadId: msg.thread_id, senderId: msg.sender_id,
                        body: msg.body, moderationStatus: msg.moderation_status,
                        createdAt: msg.created_at
                    ),
                    senderDisplayName: Self.resolvedName(displayName: profile?.display_name,
                                                        email: profile?.email),
                    senderAvatarUrl: profile?.avatar_url
                )
            }

            await MainActor.run {
                if offset == 0 {
                    // Initial load - replace all messages
                    self.messagesByThread[threadId] = items
                } else {
                    // Pagination - prepend older messages (dedupe by id)
                    let existing = self.messagesByThread[threadId] ?? []
                    let existingIds = Set(existing.map { $0.message.id })
                    let newOnly = items.filter { !existingIds.contains($0.message.id) }
                    self.messagesByThread[threadId] = newOnly + existing
                }
            }

            // Cache profiles
            for (id, profile) in profiles {
                profileCache[id] = (Self.resolvedName(displayName: profile.display_name,
                                                     email: profile.email),
                                    profile.avatar_url)
            }

            return messages.count
        } catch {
            print("[ChatService] \(#function) error:", error)
            return 0
        }
    }

    // MARK: - Roles within a group (for sender badges)
    
    func loadRolesForGroup(_ groupId: UUID) async {
        struct R: Decodable { let user_id: UUID; let role: String }
        do {
            let rows: [R] = try await client
                .from("youth_group_members")
                .select("user_id, role")
                .eq("group_id", value: groupId.uuidString.lowercased())
                .execute().value
            var map: [UUID: String] = [:]
            for r in rows {
                map[r.user_id] = r.role
                print("[ChatService] role group=\(groupId.uuidString.prefix(8)) user=\(r.user_id.uuidString.prefix(8)) → \(r.role)")
            }
            print("[ChatService] loadRolesForGroup → \(rows.count) member row(s)")
            await MainActor.run { self.rolesByGroup[groupId] = map }
        } catch {
            print("[ChatService] loadRolesForGroup error:", error)
        }
    }

    // MARK: - Header stats ("184 members · 12 active")
    
    func loadGroupStats(_ groupId: UUID) async {
        struct Row: Decodable { let member_count: Int; let active_count: Int }
        do {
            let rows: [Row] = try await client
                .rpc("get_group_header_stats",
                     params: ["_group_id": groupId.uuidString.lowercased()])
                .execute().value
            if let r = rows.first {
                await MainActor.run {
                    self.groupStats[groupId] = (r.member_count, r.active_count)
                }
            }
        } catch {
            // RLS denial or non-member — leave stats nil
        }
    }

    // MARK: - Optimistic message update
    
    func addMessageOptimistically(threadId: UUID, body: String, senderId: UUID, senderName: String) {
        let optimisticMessage = ChatMessageWithSender(
            message: ChatMessage(
                id: UUID(),
                threadId: threadId,
                senderId: senderId,
                body: body,
                moderationStatus: .clean,
                createdAt: Date()
            ),
            senderDisplayName: senderName,
            senderAvatarUrl: nil
        )
        
        var current = messagesByThread[threadId] ?? []
        current.append(optimisticMessage)
        messagesByThread[threadId] = current
    }
    
    // MARK: - Send via edge function (moderation)
    
    struct SendResult { let blocked: Bool; let reason: String? }
    
    func send(threadId: UUID, body: String) async throws -> SendResult {
        struct Payload: Encodable { let thread_id: String; let body: String }
        struct Reply: Decodable {
            let blocked: Bool?
            let reason: String?
            let error: String?
            let flagged: Bool?
        }
        let resp: Reply = try await client.functions
            .invoke("send-message",
                    options: FunctionInvokeOptions(
                        body: Payload(thread_id: threadId.uuidString.lowercased(),
                                      body: body)
                    ))
        if let e = resp.error {
            throw NSError(domain: "ChatService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: e])
        }
        return SendResult(blocked: resp.blocked == true, reason: resp.reason)
    }

    // MARK: - Mark thread read
    
    func markRead(threadId: UUID) async {
        _ = try? await client
            .rpc("mark_thread_read",
                 params: ["_thread_id": threadId.uuidString.lowercased()])
            .execute()
        await MainActor.run {
            if let i = self.threads.firstIndex(where: { $0.threadId == threadId }) {
                self.threads[i].unreadCount = 0
            }
        }
    }

    // MARK: - Realtime: subscribe per open thread
    
    func subscribe(threadId: UUID) async {
        if realtimeChannels[threadId] != nil { return }
        let channel = client.channel("thread-\(threadId.uuidString)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "thread_id=eq.\(threadId.uuidString.lowercased())"
        )
        Task { [weak self] in
            for await change in inserts {
                guard let self else { return }
                if let msg = try? Self.decodeMessage(record: change.record) {
                    await self.appendIfNew(message: msg, threadId: threadId)
                }
            }
        }
        await channel.subscribe()
        realtimeChannels[threadId] = channel
    }

    func unsubscribe(threadId: UUID) async {
        if let ch = realtimeChannels[threadId] {
            await ch.unsubscribe()
            realtimeChannels[threadId] = nil
        }
    }

    private static func decodeMessage(record: [String: AnyJSON]) throws -> ChatMessage {
        let data = try JSONEncoder().encode(record)
        let dec = JSONDecoder()
        // Use custom date decoder that handles fractional seconds
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        dec.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = withFractional.date(from: s) { return date }
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unparseable date: \(s)")
        }
        return try dec.decode(ChatMessage.self, from: data)
    }

    @MainActor
    private func appendIfNew(message: ChatMessage, threadId: UUID) async {
        var items = messagesByThread[threadId] ?? []

        // If this exact server id is already in the list, no-op.
        guard !items.contains(where: { $0.id == message.id }) else { return }

        // If there's an optimistic entry that matches (same sender + body, close in time),
        // replace it in place with the authoritative server row. This is what stops the
        // "send → duplicate appears" bug after a realtime echo.
        if let optimisticIdx = items.firstIndex(where: { existing in
            existing.message.senderId == message.senderId
                && existing.message.body  == message.body
                && existing.message.id    != message.id
                && abs(existing.message.createdAt.timeIntervalSince(message.createdAt)) < 60
        }) {
            let cached = profileCache[message.senderId]
            items[optimisticIdx] = ChatMessageWithSender(
                message: message,
                senderDisplayName: cached?.name ?? items[optimisticIdx].senderDisplayName,
                senderAvatarUrl:   cached?.avatarUrl ?? items[optimisticIdx].senderAvatarUrl
            )
            messagesByThread[threadId] = items
            return
        }

        // Otherwise this is a brand-new message (e.g. from another user). Append.
        let cached = profileCache[message.senderId]
        items.append(ChatMessageWithSender(
            message: message,
            senderDisplayName: cached?.name ?? "…",
            senderAvatarUrl:   cached?.avatarUrl
        ))
        messagesByThread[threadId] = items
        if cached == nil { Task { await fetchProfile(senderId: message.senderId) } }
    }

    private func fetchProfile(senderId: UUID) async {
        struct Row: Decodable {
            let id: UUID
            let display_name: String?
            let avatar_url: String?
            let email: String?
        }
        guard let rows: [Row] = try? await client.from("profiles")
            .select("id, display_name, avatar_url, email")
            .eq("id", value: senderId.uuidString.lowercased())
            .limit(1)
            .execute().value,
              let row = rows.first
        else { return }
        let resolved = Self.resolvedName(displayName: row.display_name, email: row.email)
        await MainActor.run {
            self.profileCache[senderId] = (resolved, row.avatar_url)
            // Backfill any already-rendered messages whose name was "…".
            for (tid, list) in self.messagesByThread {
                var changed = list
                for i in changed.indices where changed[i].message.senderId == senderId {
                    changed[i] = ChatMessageWithSender(
                        message: changed[i].message,
                        senderDisplayName: resolved,
                        senderAvatarUrl:   row.avatar_url
                    )
                }
                self.messagesByThread[tid] = changed
            }
        }
    }

    /// Mirrors the server-side preview logic: prefer `display_name`, else
    /// the email's local-part (before `@`), else a single em-dash.
    /// Keeps in-chat sender names consistent with what the message list
    /// preview shows.
    static func resolvedName(displayName: String?, email: String?) -> String {
        if let n = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            return n
        }
        if let e = email, let local = e.split(separator: "@").first, !local.isEmpty {
            return String(local)
        }
        return "—"
    }

    // MARK: - Reset on sign-out
    
    func reset() {
        threads = []
        messagesByThread = [:]
        rolesByGroup = [:]
        groupStats = [:]
        profileCache = [:]
        for ch in realtimeChannels.values { Task { await ch.unsubscribe() } }
        realtimeChannels = [:]
    }
}
