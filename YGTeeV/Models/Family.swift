//
//  Family.swift
//  YGTeeV
//
//  Parent/Family flow models. Backed by the family RPCs:
//    list_my_families, start_family, remove_family,
//    create_family_invite, accept_family_invite.
//

import Foundation

struct Family: Decodable, Identifiable, Hashable {
    let familyId: UUID
    let familyName: String
    /// "parent" | "child"
    let myRole: String
    let members: [FamilyMember]
    let createdAt: Date

    var id: UUID { familyId }

    enum CodingKeys: String, CodingKey {
        case familyId   = "family_id"
        case familyName = "family_name"
        case myRole     = "my_role"
        case members
        case createdAt  = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.familyId   = try c.decode(UUID.self, forKey: .familyId)
        self.familyName = (try? c.decode(String.self, forKey: .familyName)) ?? "My Family"
        self.myRole     = (try? c.decode(String.self, forKey: .myRole)) ?? "parent"
        self.members    = (try? c.decode([FamilyMember].self, forKey: .members)) ?? []
        self.createdAt  = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

struct FamilyMember: Decodable, Identifiable, Hashable {
    let userId: UUID
    /// "parent" | "child"
    let role: String
    let joinedAt: Date
    let displayName: String?
    let avatarURL: String?
    let email: String?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case role
        case joinedAt    = "joined_at"
        case displayName = "display_name"
        case avatarURL   = "avatar_url"
        case email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId      = try c.decode(UUID.self, forKey: .userId)
        self.role        = (try? c.decode(String.self, forKey: .role)) ?? "child"
        self.joinedAt    = (try? c.decode(Date.self, forKey: .joinedAt)) ?? Date()
        self.displayName = try? c.decode(String.self, forKey: .displayName)
        self.avatarURL   = try? c.decode(String.self, forKey: .avatarURL)
        self.email       = try? c.decode(String.self, forKey: .email)
    }
}

/// Returned by the `create-child-account` Edge Function. Contains the
/// freshly-provisioned child profile plus the one-time pairing token /
/// 8-digit fallback code the kid will redeem on their device.
struct CreateChildResult: Decodable, Identifiable, Hashable {
    let childUserId: UUID
    let displayName: String
    let pairingToken: String
    let numericCode: String
    let expiresAt: Date

    /// `sheet(item:)` requires Identifiable. Tie the identity to the
    /// pairing token so a second create call (with a different result)
    /// re-presents the sheet rather than reusing the previous instance.
    var id: String { pairingToken }

    enum CodingKeys: String, CodingKey {
        case childUserId  = "child_user_id"
        case displayName  = "display_name"
        case pairingToken = "pairing_token"
        case numericCode  = "numeric_code"
        case expiresAt    = "expires_at"
    }
}

/// Returned by the `redeem-child-pairing-token` Edge Function on the
/// kid's fresh-install device. The session tokens are immediately handed
/// to `auth.setSession(...)`.
struct RedeemChildPairingResult: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Double?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt    = "expires_at"
    }
}

struct FamilyInviteResult: Decodable, Hashable {
    let inviteId: UUID
    let pairingCode: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case inviteId    = "invite_id"
        case pairingCode = "pairing_code"
        case expiresAt   = "expires_at"
    }
}

/// A family invite addressed to the current user. Powers the banner on the
/// invited side ("Jacob wants to add you to My Family — Accept · Decline").
struct PendingFamilyInvite: Decodable, Identifiable, Hashable {
    let inviteId: UUID
    let familyId: UUID
    let familyName: String
    let pairingCode: String
    let inviterId: UUID
    let inviterName: String?
    let inviterAvatar: String?
    let createdAt: Date
    let expiresAt: Date

    var id: UUID { inviteId }

    enum CodingKeys: String, CodingKey {
        case inviteId       = "invite_id"
        case familyId       = "family_id"
        case familyName     = "family_name"
        case pairingCode    = "pairing_code"
        case inviterId      = "inviter_id"
        case inviterName    = "inviter_name"
        case inviterAvatar  = "inviter_avatar"
        case createdAt      = "created_at"
        case expiresAt      = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.inviteId      = try c.decode(UUID.self, forKey: .inviteId)
        self.familyId      = try c.decode(UUID.self, forKey: .familyId)
        self.familyName    = (try? c.decode(String.self, forKey: .familyName)) ?? "My Family"
        self.pairingCode   = (try? c.decode(String.self, forKey: .pairingCode)) ?? ""
        self.inviterId     = (try? c.decode(UUID.self, forKey: .inviterId)) ?? UUID()
        self.inviterName   = try? c.decode(String.self, forKey: .inviterName)
        self.inviterAvatar = try? c.decode(String.self, forKey: .inviterAvatar)
        self.createdAt     = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        self.expiresAt     = (try? c.decode(Date.self, forKey: .expiresAt)) ?? Date()
    }
}
