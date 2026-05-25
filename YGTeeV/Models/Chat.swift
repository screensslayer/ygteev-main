//
//  Chat.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/11/26.
//

import Foundation

enum ThreadKind: String, Codable, Hashable {
    case groupMain      = "group_main"
    case smallGroup     = "small_group"
    case parentChat     = "parent_chat"
    case dmPastor       = "dm_pastor"
    case dmLeader       = "dm_leader"
    case dmParentPastor = "dm_parent_pastor"
    case dmParentLeader = "dm_parent_leader"

    var isDm: Bool {
        self == .dmPastor || self == .dmLeader
        || self == .dmParentPastor || self == .dmParentLeader
    }
}

struct ChatThreadSummary: Identifiable, Decodable, Hashable {
    var id: UUID { threadId }

    let threadId: UUID
    let kind: ThreadKind
    let groupId: UUID
    let groupName: String?
    let groupGradientFrom: String?
    let groupGradientTo: String?
    let smallGroupId: UUID?
    let smallGroupName: String?
    let dmOtherUserId: UUID?
    let dmOtherDisplay: String?
    let dmOtherAvatarUrl: String?
    let dmOtherRole: String?
    let lastMessageBody: String?
    let lastMessageSender: String?
    let lastMessageAt: Date?
    var unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case threadId          = "thread_id"
        case kind
        case groupId           = "group_id"
        case groupName         = "group_name"
        case groupGradientFrom = "group_gradient_from"
        case groupGradientTo   = "group_gradient_to"
        case smallGroupId      = "small_group_id"
        case smallGroupName    = "small_group_name"
        case dmOtherUserId     = "dm_other_user_id"
        case dmOtherDisplay    = "dm_other_display"
        case dmOtherAvatarUrl  = "dm_other_avatar_url"
        case dmOtherRole       = "dm_other_role"
        case lastMessageBody   = "last_message_body"
        case lastMessageSender = "last_message_sender"
        case lastMessageAt     = "last_message_at"
        case unreadCount       = "unread_count"
    }

    var displayTitle: String {
        switch kind {
        case .groupMain:    return groupName ?? "Group chat"
        case .smallGroup:   return smallGroupName ?? "Small group"
        case .parentChat:   return "\(groupName ?? "Group") · Parents"
        case .dmPastor, .dmLeader, .dmParentPastor, .dmParentLeader:
            return dmOtherDisplay ?? "Direct message"
        }
    }

    var displaySubtitle: String? {
        guard let body = lastMessageBody else { return nil }
        if let sender = lastMessageSender { return "\(sender): \(body)" }
        return body
    }
}

enum ModerationStatus: String, Codable, Hashable {
    case clean
    case flagged_allowed
    case flagged_blocked
}

struct ChatMessage: Identifiable, Decodable, Hashable {
    let id: UUID
    let threadId: UUID
    let senderId: UUID
    let body: String
    let moderationStatus: ModerationStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case threadId         = "thread_id"
        case senderId         = "sender_id"
        case moderationStatus = "moderation_status"
        case createdAt        = "created_at"
    }
}

struct ChatMessageWithSender: Identifiable, Hashable {
    let message: ChatMessage
    let senderDisplayName: String
    let senderAvatarUrl: String?
    var id: UUID { message.id }
}
