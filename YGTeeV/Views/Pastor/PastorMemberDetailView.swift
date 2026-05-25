//
//  PastorMemberDetailView.swift
//  YGTeeV
//
//  Slide-in sheet a pastor sees when tapping a member in MembersView.
//  Pulls everything from `pastor_member_profile` in a single round-trip,
//  then renders a hero + stats + small-group card + 90-day attendance
//  + RSVPed events + destructive actions (remove from small group /
//  remove from youth group).
//

import SwiftUI

struct PastorMemberDetailView: View {
    let groupId: UUID
    let userId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var service = PastorDashboardService.shared
    @State private var profile: PastorMemberProfile?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var confirmRemoveGroup = false
    @State private var confirmRemoveSmallGroup = false
    @State private var isMutating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let p = profile {
                        hero(p)
                        statsRow(p)
                        if let sg = p.smallGroup { smallGroupCard(sg) }
                        attendanceCard(p)
                        eventsCard(p)
                        actions(p)
                    } else if isLoading {
                        ProgressView()
                            .padding(.top, 60)
                            .frame(maxWidth: .infinity)
                    } else if let loadError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundStyle(Color(hex: "C53030"))
                            Text(loadError)
                                .font(.system(size: 13))
                                .foregroundStyle(YGColors.ink.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(YGColors.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(YGColors.ink)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            profile = try await service.fetchMemberProfile(groupId: groupId, userId: userId)
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Hero

    private func hero(_ p: PastorMemberProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                avatarCircle(p)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.displayName ?? p.email ?? "Unnamed")
                        .font(.lilitaOne(size: 22))
                        .foregroundStyle(YGColors.ink)
                        .lineLimit(1)
                    if let h = p.handle, !h.isEmpty {
                        Text("@\(h)")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                    } else if let e = p.email {
                        Text(e)
                            .font(.system(size: 12.5))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                            .lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        rolePill(p.role)
                        if p.role != "parent", p.isParent {
                            pill("PARENT",
                                 fg: Color(hex: "FF6B35"),
                                 bg: Color(hex: "FF6B35").opacity(0.12))
                        }
                        if let g = p.gradeYear {
                            pill("\(g)\(g.ordinalSuffix) grade",
                                 fg: Color(hex: "2B8A3E"),
                                 bg: Color(hex: "2B8A3E").opacity(0.10))
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            if p.role == "parent" || p.isParent, !p.linkedChildNames.isEmpty {
                Text("Parent of \(p.linkedChildNames.joined(separator: ", "))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
            }
            if let last = p.lastOpenedAt {
                Text("Last opened \(Self.relativeDate.localizedString(for: last, relativeTo: Date()))")
                    .font(.system(size: 12))
                    .foregroundStyle(YGColors.ink.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Stats

    private func statsRow(_ p: PastorMemberProfile) -> some View {
        HStack(spacing: 10) {
            statCard("Level", "\(p.level)")
            statCard("Lifetime XP", p.lifetimeXp.formatted())
            statCard("Streak", "\(p.streak)d")
            statCard("Water", "\(p.water)")
        }
        .padding(.horizontal, 16)
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.lilitaOne(size: 18))
                .foregroundStyle(YGColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(YGColors.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
    }

    // MARK: - Small group card

    private func smallGroupCard(_ sg: PastorMemberProfile.SmallGroupInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("SMALL GROUP")
            HStack(alignment: .center, spacing: 12) {
                Text(String(sg.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(sg.name)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                    if let ln = sg.leaderName, !ln.isEmpty {
                        Text("Led by \(ln)")
                            .font(.system(size: 12))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                    } else if let joined = sg.joinedAt {
                        Text("Joined \(Self.absoluteDate.string(from: joined))")
                            .font(.system(size: 12))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                    }
                }
                Spacer()
                Text(sg.role.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(sg.role == "leader" ? Color(hex: "0066FF") : YGColors.violet)
                    .clipShape(Capsule())
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Attendance card

    private func attendanceCard(_ p: PastorMemberProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ATTENDANCE · LAST 90 DAYS")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(p.attendance90d.attended) / \(p.attendance90d.total)")
                    .font(.lilitaOne(size: 28))
                    .foregroundStyle(YGColors.ink)
                Text("\(p.attendance90d.ratePct)% present")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                Spacer()
            }
            if p.attendance90d.events.isEmpty {
                Text("No small-group meetings recorded yet.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.45))
                    .padding(.top, 2)
            } else {
                VStack(spacing: 8) {
                    ForEach(p.attendance90d.events) { m in
                        HStack(spacing: 10) {
                            Image(systemName: m.present ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(m.present ? Color(hex: "2B8A3E") : Color(hex: "C53030"))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .lineLimit(1)
                                Text(Self.absoluteDate.string(from: m.occurredAt))
                                    .font(.system(size: 11))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                            }
                            Spacer()
                            if let sgName = m.smallGroupName, !sgName.isEmpty {
                                Text(sgName)
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(0.3)
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(YGColors.ink.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Events card

    private func eventsCard(_ p: PastorMemberProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("EVENT RSVPS")
            if p.events.isEmpty {
                Text("No events RSVPed in the last 90 days.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(YGColors.ink.opacity(0.45))
            } else {
                VStack(spacing: 8) {
                    ForEach(p.events) { e in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(YGColors.ink)
                                    .lineLimit(1)
                                Text(Self.absoluteDate.string(from: e.startsAt)
                                     + (e.location.map { " · \($0)" } ?? ""))
                                    .font(.system(size: 11))
                                    .foregroundStyle(YGColors.ink.opacity(0.55))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(e.status.uppercased())
                                .font(.system(size: 9.5, weight: .heavy))
                                .tracking(0.4)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor(e.status).opacity(0.12))
                                .foregroundStyle(statusColor(e.status))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func actions(_ p: PastorMemberProfile) -> some View {
        VStack(spacing: 10) {
            if let sg = p.smallGroup {
                Button(role: .destructive) {
                    confirmRemoveSmallGroup = true
                } label: {
                    Text("Remove from \(sg.name)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "C53030").opacity(0.85))
                .alert("Remove from \(sg.name)?", isPresented: $confirmRemoveSmallGroup) {
                    Button("Remove", role: .destructive) {
                        Task { await removeFromSmallGroup(sg.id) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("They'll stay in the youth group but lose access to this small group's chats and attendance.")
                }
            }

            if p.role != "pastor" {
                Button(role: .destructive) {
                    confirmRemoveGroup = true
                } label: {
                    Text("Remove from youth group")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "C53030"))
                .alert("Remove from this youth group?", isPresented: $confirmRemoveGroup) {
                    Button("Remove", role: .destructive) {
                        Task { await removeFromYouthGroup() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This also removes them from any small group in this youth group and from related chat threads.")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .disabled(isMutating)
        .opacity(isMutating ? 0.6 : 1)
    }

    // MARK: - Mutations

    private func removeFromSmallGroup(_ smallGroupId: UUID) async {
        isMutating = true
        defer { isMutating = false }
        do {
            try await service.removeFromSmallGroup(smallGroupId: smallGroupId, userId: userId)
            await load()
            await service.loadSmallGroups()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func removeFromYouthGroup() async {
        isMutating = true
        defer { isMutating = false }
        do {
            try await service.removeFromGroup(groupId: groupId, userId: userId)
            dismiss()
            await service.refreshDashboard()
            await service.loadAllMembers()
            await service.loadLeaders()
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(YGColors.ink.opacity(0.5))
    }

    private func rolePill(_ role: String) -> some View {
        let (color, bg): (Color, Color) = {
            switch role {
            case "pastor": return (YGColors.violet, YGColors.violet.opacity(0.14))
            case "leader": return (Color(hex: "0066FF"), Color(hex: "0066FF").opacity(0.12))
            case "parent": return (Color(hex: "2B8A3E"), Color(hex: "B4FF3C").opacity(0.22))
            default:       return (YGColors.ink.opacity(0.55), YGColors.ink.opacity(0.06))
            }
        }()
        return pill(role.uppercased(), fg: color, bg: bg)
    }

    private func pill(_ label: String, fg: Color, bg: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "going":    return Color(hex: "2B8A3E")
        case "maybe":    return Color(hex: "B7791F")
        case "declined": return Color(hex: "C53030")
        default:         return YGColors.ink.opacity(0.5)
        }
    }

    private func avatarCircle(_ p: PastorMemberProfile) -> some View {
        let seed = p.userId.uuidString.hashValue
        let hue1 = Double(abs(seed) % 360) / 360
        let hue2 = Double(abs(seed) % 307 * 53 % 360) / 360
        let gradient = LinearGradient(
            colors: [
                Color(hue: hue1, saturation: 0.75, brightness: 0.65),
                Color(hue: hue2, saturation: 0.75, brightness: 0.55),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        let initial = String((p.displayName?.first).map(String.init)
                             ?? (p.email?.first).map(String.init)
                             ?? "?").uppercased()
        return ZStack {
            gradient
            if let urlStr = p.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Text(initial)
                            .font(.lilitaOne(size: 22))
                            .foregroundStyle(.white)
                    }
                }
            } else {
                Text(initial)
                    .font(.lilitaOne(size: 22))
                    .foregroundStyle(.white)
            }
        }
        .clipShape(Circle())
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static let absoluteDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
