//
//  MyFamilyCard.swift
//  YGTeeV
//
//  "My Family" section on the parent's Profile, between My Youth Groups
//  and the bottom tabs. Hidden entirely when the caller is in no family.
//

import SwiftUI

struct LiveFamilyCard: View {
    /// Optional override for the dev role-switcher's Parent fixture.
    var fixtureFamily: Family? = nil

    @State private var service = FamilyService.shared
    @State private var showAddMember = false

    private var family: Family? {
        if let fixtureFamily { return fixtureFamily }
        return service.primaryFamily
    }

    var body: some View {
        Group {
            if let family {
                VStack(alignment: .leading, spacing: 0) {
                    header(family)
                    membersCard(family)
                    addMemberButton(family)
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showAddMember) {
            if let family {
                AddFamilyMemberSheet(familyId: family.familyId)
            }
        }
    }

    private func header(_ family: Family) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("My Family")
                .font(.lilitaOne(size: 19))
                .tracking(-0.4)
                .foregroundStyle(YGColors.ink)
            Spacer()
            // "Manage" is a future surface — for v1 it falls back to the
            // add-member sheet so the link isn't dead.
            Button { showAddMember = true } label: {
                Text("Manage")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.violet)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    private func membersCard(_ family: Family) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(family.members.enumerated()), id: \.element.id) { idx, member in
                memberRow(member)
                if idx < family.members.count - 1 {
                    Divider().padding(.leading, 70)
                }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 4, y: 2)
    }

    private func memberRow(_ member: FamilyMember) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(YGColors.violet.opacity(0.10))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(YGColors.violet)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName ?? member.email ?? "Family member")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                Text(member.role.capitalized)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func addMemberButton(_ family: Family) -> some View {
        Button {
            showAddMember = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(YGColors.violet)
                }
                .frame(width: 44, height: 44)
                .overlay {
                    Circle().strokeBorder(YGColors.violet.opacity(0.45),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add another family member")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(YGColors.violet)
                    Text("Pairing code or QR")
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(YGColors.violet.opacity(0.55))
            }
            .padding(14)
            .background(YGColors.violet.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(YGColors.violet.opacity(0.45),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}
