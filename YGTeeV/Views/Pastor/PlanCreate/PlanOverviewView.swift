//
//  PlanOverviewView.swift
//  YGTeeV
//
//  Screen 7: multi-day overview with totals, day cards, and Publish CTA.
//

import SwiftUI

struct PlanOverviewView: View {
    @Binding var draft: BiblePlanDraft
    /// Called when the pastor taps a day card. The parent builder updates
    /// its `currentDay` so popping back lands on that day's editor.
    var onSelectDay: ((Int) -> Void)? = nil
    /// Called when the plan has been successfully published. Hosted at the
    /// plans-list level so it can pop the entire builder/overview chain.
    var onPublished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var service = PastorPlanService.shared
    @State private var showPublishSheet = false
    @State private var emptyDayHighlight: Set<Int> = []
    @State private var inlineError: String?
    @State private var groupName: String?

    private var dayRows: [DayRow] {
        (1...draft.totalDays).map { dayNumber in
            let blocks = service.blocksByDay[dayNumber] ?? []
            let qCount = blocks.reduce(0) { acc, b in
                if case .question = b { return acc + 1 } else { return acc }
            }
            let status: DayStatus = {
                if blocks.isEmpty { return .empty }
                if blocks.allSatisfy(\.hasContent) { return .ready }
                return .draft
            }()
            return DayRow(
                dayNumber: dayNumber,
                title: "Day \(dayNumber)",
                scriptureRef: "",
                blockCount: blocks.count,
                questionCount: qCount,
                status: status
            )
        }
    }

    private var totalBlocks: Int { dayRows.reduce(0) { $0 + $1.blockCount } }
    private var totalQuestions: Int { dayRows.reduce(0) { $0 + $1.questionCount } }
    private var readyCount: Int { dayRows.filter { $0.status == .ready }.count }
    private var totalXP: Int { draft.totalDays * 500 + totalQuestions * 50 }
    private var totalWater: Int { draft.totalDays * 4 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 12) {
                    totalsCard

                    Text("ALL DAYS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        ForEach(dayRows) { row in
                            Button {
                                onSelectDay?(row.dayNumber)
                                dismiss()
                            } label: {
                                dayCard(row)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let inlineError {
                        Text(inlineError)
                            .font(.system(size: 12.5, weight: .heavy))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 200)
            }
            footer
        }
        .background(YGColors.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("STEP 3 OF 3")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                    Text("\(draft.title) · \(draft.totalDays) days")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                        .lineLimit(1)
                }
            }
        }
        .sheet(isPresented: $showPublishSheet) {
            PlanPublishSheet(
                draft: draft,
                totalXP: totalXP,
                totalWater: totalWater,
                totalQuestions: totalQuestions,
                groupName: groupName
            ) { chosenVisibility in
                await publish(visibility: chosenVisibility)
            }
            .presentationDetents([.large])
        }
        .task {
            // Resolve the human-readable group name for the visibility
            // sheet's "Just members of …" subtitle.
            if groupName == nil {
                let groups = await service.loadMyPastorGroups()
                groupName = groups.first { $0.id == draft.groupId }?.name
            }
        }
    }

    // MARK: - Totals

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOTAL PLAN REWARDS")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("⚡")
                        Text("\(totalXP)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    Text("XP across plan")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 50)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("💧")
                        Text("\(totalWater)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    Text("Water drops")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
            }
            HStack(spacing: 14) {
                stat("\(totalBlocks) blocks")
                stat("\(totalQuestions) questions")
                stat("\(readyCount) of \(draft.totalDays) days ready")
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(0.18)).frame(height: 0.5)
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: YGColors.violet.opacity(0.5), radius: 14, y: 8)
    }

    private func stat(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
    }

    // MARK: - Day card

    private func dayCard(_ row: DayRow) -> some View {
        let isHighlighted = emptyDayHighlight.contains(row.dayNumber)
        return HStack(spacing: 12) {
            Text(String(format: "%02d", row.dayNumber))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !row.scriptureRef.isEmpty { Text(row.scriptureRef) }
                    Text("\(row.blockCount) blocks")
                    if row.questionCount > 0 { Text("\(row.questionCount) Q") }
                }
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.55))
            }
            Spacer()
            Text(row.status.label.uppercased())
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(row.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(row.status.tint)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(YGColors.ink.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isHighlighted ? Color.red : Color.black.opacity(0.06),
                              lineWidth: isHighlighted ? 2 : 0.5)
        }
        .shadow(color: YGColors.ink.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Save draft")
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(0.08), lineWidth: 0.5) }
            }
            .buttonStyle(.plain)

            Button {
                showPublishSheet = true
            } label: {
                Text("Publish plan")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: YGColors.violet.opacity(0.5), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 90)
        .background(
            LinearGradient(colors: [YGColors.paper.opacity(0), YGColors.paper.opacity(0.95)],
                           startPoint: .top, endPoint: .bottom)
            .frame(height: 170, alignment: .bottom)
        )
    }

    // MARK: - Publish

    private func publish(visibility: PlanVisibility) async {
        emptyDayHighlight.removeAll()
        inlineError = nil
        do {
            // If the pastor changed visibility in the sheet, persist that
            // change before flipping status to published.
            if visibility != draft.visibility {
                try await service.updateBasics(planId: draft.id, visibility: visibility)
                draft.visibility = visibility
            }
            try await service.publish(planId: draft.id)
            showPublishSheet = false
            draft.status = "published"
            // Take the pastor all the way back to the plans list rather
            // than dropping them onto the day builder mid-stack.
            if let onPublished {
                onPublished()
            } else {
                dismiss()
            }
        } catch {
            let msg = error.localizedDescription
            if msg.contains("day(s) with no blocks") || msg.contains("no blocks") {
                // Highlight empty day cards.
                emptyDayHighlight = Set(dayRows.filter { $0.status == .empty }.map(\.dayNumber))
                inlineError = "Some days are empty — finish them before publishing."
            } else {
                inlineError = "Couldn't publish. \(msg)"
            }
            showPublishSheet = false
        }
    }
}

// MARK: - Local row model

private struct DayRow: Identifiable {
    var id: Int { dayNumber }
    let dayNumber: Int
    let title: String
    let scriptureRef: String
    let blockCount: Int
    let questionCount: Int
    let status: DayStatus
}
