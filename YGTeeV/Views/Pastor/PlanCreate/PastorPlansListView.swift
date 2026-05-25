//
//  PastorPlansListView.swift
//  YGTeeV
//
//  Entry point for the pastor "Publish a Bible plan" surface.
//  Lists every plan the pastor's group owns with a draft/published status
//  pill, lets the pastor tap to edit, and a top-right + button starts the
//  new-plan creation flow.
//

import SwiftUI

struct PastorPlansListView: View {
    let groupId: UUID
    /// Called when the back button is tapped at the root of the navigation
    /// stack (i.e. there's nothing left to pop). Hosted by a sibling overlay
    /// rather than a modal, so we can't rely on `@Environment(\.dismiss)`.
    var onClose: (() -> Void)? = nil

    @State private var service = PastorPlanService.shared

    @State private var isLoading = true
    @State private var showNewPlanFlow = false
    @State private var openDraft: BiblePlanDraft?
    @State private var planPendingDelete: PastorPlanSummary?

    private var plans: [PastorPlanSummary] { service.myPlans }

    var body: some View {
        Group {
            if plans.isEmpty && !isLoading {
                ScrollView {
                    emptyState
                        .padding(.top, 12)
                        .padding(.bottom, 60)
                }
            } else if plans.isEmpty && isLoading {
                ProgressView()
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List {
                    ForEach(plans) { plan in
                        planRow(plan)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    planPendingDelete = plan
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(YGColors.paper.ignoresSafeArea())
        .navigationTitle("All Bible plans")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this plan?",
            isPresented: Binding(
                get: { planPendingDelete != nil },
                set: { if !$0 { planPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: planPendingDelete
        ) { plan in
            Button("Delete \"\(plan.title)\"", role: .destructive) {
                Task { await delete(plan: plan) }
            }
            Button("Cancel", role: .cancel) {
                planPendingDelete = nil
            }
        } message: { _ in
            Text("This will permanently remove the plan and all of its days. This can't be undone.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { onClose?() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewPlanFlow = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(isPresented: $showNewPlanFlow) {
            PastorPlanSetupView(groupId: groupId) { draft in
                openDraft = draft
                showNewPlanFlow = false
            }
        }
        .navigationDestination(item: $openDraft) { draft in
            // Once the pastor opens (or finishes setup for) a plan, push
            // them into the day builder for day 1.
            PlanDayBuilderViewWrapper(initialDraft: draft) {
                // Publish succeeded — unmount the entire builder/overview
                // destination by clearing `openDraft`, then refresh so the
                // newly-published plan shows its updated state.
                openDraft = nil
                Task { await service.listMyPlans() }
            }
        }
        .task {
            isLoading = true
            await service.listMyPlans()
            isLoading = false
        }
        .refreshable {
            await service.listMyPlans()
        }
    }

    private func delete(plan: PastorPlanSummary) async {
        do {
            try await service.deletePlan(planId: plan.id)
            await service.listMyPlans()
        } catch {
            print("[PastorPlansListView] deletePlan failed:", error)
        }
        planPendingDelete = nil
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("📖").font(.system(size: 44))
            Text("No plans yet")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text("Tap + to publish your first Bible plan.")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.6))
                .multilineTextAlignment(.center)

            Button { showNewPlanFlow = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 13, weight: .heavy))
                    Text("Create a new plan")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Capsule())
                .shadow(color: YGColors.violet.opacity(0.4), radius: 10, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Plan row

    @ViewBuilder
    private func planRow(_ plan: PastorPlanSummary) -> some View {
        Button {
            // Promote the summary into an editable draft, then open the
            // builder for day 1. The builder pushes to the overview, which
            // can publish. The RPC provides the plan's real group_id;
            // only fall back to the view's groupId if it's missing.
            var draft = plan.asDraft
            if plan.groupId == nil { draft.groupId = groupId }
            openDraft = draft
        } label: {
            HStack(spacing: 12) {
                // Header preview swatch (gradient or photo).
                Group {
                    if plan.headerKind == .photo,
                       let s = plan.headerImageURL,
                       !s.isEmpty,
                       let url = URL(string: s) {
                        CachedRemoteImage(url: url) {
                            PlanHeaderGradient.gradient(at: plan.gradientIdx ?? 0)
                        }
                    } else {
                        PlanHeaderGradient.gradient(at: plan.gradientIdx ?? 0)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                            .lineLimit(1)
                        // "+N group" pill when this plan is also assigned
                        // to additional groups beyond its primary.
                        if !plan.additionalGroupIds.isEmpty {
                            Text("+\(plan.additionalGroupIds.count) group\(plan.additionalGroupIds.count == 1 ? "" : "s")")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(0.2)
                                .foregroundStyle(YGColors.violet)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(YGColors.violet.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }

                    HStack(spacing: 8) {
                        if let groupName = plan.groupName, !groupName.isEmpty {
                            Text(groupName).lineLimit(1)
                            Text("·")
                        }
                        Text("\(plan.daysTotal) day\(plan.daysTotal == 1 ? "" : "s")")
                        if let date = plan.updatedAt ?? plan.createdAt {
                            Text("·")
                            Text(Self.relativeDate.localizedString(for: date, relativeTo: Date()))
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(YGColors.ink.opacity(0.55))

                    if plan.status == "published" {
                        Text("\(plan.startedCount) started · \(plan.completedCount) completed")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(YGColors.ink.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                Spacer(minLength: 8)

                statusPill(for: plan.status)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.04), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func statusPill(for status: String) -> some View {
        let (label, color, bg): (String, Color, Color) = {
            switch status {
            case "published":
                return ("PUBLISHED", Color(hex: "2B8A3E"), Color(hex: "B4FF3C").opacity(0.18))
            case "archived":
                return ("ARCHIVED", YGColors.ink.opacity(0.55), YGColors.ink.opacity(0.06))
            default:
                return ("DRAFT", Color(hex: "B8860B"), Color(hex: "FFD60A").opacity(0.20))
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}

// MARK: - Day-builder wrapper
//
// `PlanDayBuilderView` takes a `Binding<BiblePlanDraft>`. We need a state
// owner that holds the draft locally so the binding stays alive while the
// pastor navigates between day builder ↔ overview ↔ publish sheet.

private struct PlanDayBuilderViewWrapper: View {
    @State var draft: BiblePlanDraft
    @State private var hydrating = true
    @State private var service = PastorPlanService.shared
    let onPublished: () -> Void

    init(initialDraft: BiblePlanDraft, onPublished: @escaping () -> Void) {
        self._draft = State(initialValue: initialDraft)
        self.onPublished = onPublished
    }

    var body: some View {
        Group {
            if hydrating {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(YGColors.paper)
            } else {
                PlanDayBuilderView(
                    draft: $draft,
                    currentDay: 1,
                    onPublished: onPublished
                )
            }
        }
        .task {
            // Warm the day-blocks cache so the builder & overview show
            // the right counts and existing blocks for editing.
            await service.loadDaysIntoCache(planId: draft.id)
            hydrating = false
        }
    }
}
