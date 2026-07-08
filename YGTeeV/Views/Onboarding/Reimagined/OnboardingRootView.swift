//
//  OnboardingRootView.swift
//  YGTeeV
//
//  Driver for the reimagined 20-moment onboarding flow. Owns the
//  `ReimaginedOnboardingState` instance and swaps in the right
//  screen for the current step. Each screen advances by calling
//  `advance()` which consults the state (isUnder13, etc.) to pick
//  the next step.
//
//  Design principles baked in here:
//    • Group-first — the group-picker (M3) runs BEFORE demographics.
//    • Under-13 order swap — the COPPA branch signs in FIRST so the
//      pairing token can be created against an authenticated user,
//      THEN pairs with parent, THEN picks name / avatar.
//    • Idempotent by design — every RPC the flow calls is
//      idempotent, so a user killing + relaunching mid-flow re-runs
//      cleanly without double-awarding XP or duplicating rows.
//
//  Presented from `YGTeeVApp` when the launch argument
//  `-UseReimaginedOnboarding YES` is passed (Phase 1 debug gate).
//  Once Phase 6 lands, this replaces `OnboardingCoordinatorView`
//  outright.
//

import SwiftUI

struct OnboardingRootView: View {
    let onComplete: () -> Void

    @State private var state = ReimaginedOnboardingState()
    @State private var service = OnboardingService.shared

    var body: some View {
        ZStack {
            // Slot the screen for the current step. Transition on
            // step change so each screen slides in from the trailing
            // edge — matches the design HTML's "advance" motion.
            currentScreen
                .id(state.step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .animation(.easeInOut(duration: 0.35), value: state.step)
        .onChange(of: state.step) { _, newStep in
            if newStep == .done {
                onComplete()
            }
        }
    }

    // MARK: - Screen router

    @ViewBuilder
    private var currentScreen: some View {
        switch state.step {
        case .splash:
            OnbSplashView(state: state, advance: advance)
        case .sourceBranch:
            OnbSourceBranchView(state: state, advance: advance)
        case .groupPicker:
            OnbGroupPickerView(state: state, advance: advance)
        case .gradeYear:
            OnbGradeYearView(state: state, advance: advance)
        case .birthYear:
            OnbBirthYearView(state: state, advance: advance)
        case .birthDoubleCheck:
            OnbBirthDoubleCheckView(state: state, advance: advance, goBack: goBackToBirthYear)
        case .parentPair:
            OnbParentPairView(state: state, advance: advance)
        case .nameAvatar:
            OnbNameAvatarView(state: state, advance: advance)
        case .authChoice:
            OnbAuthChoiceView(state: state, advance: advance)
        case .colorReveal:
            OnbColorRevealView(state: state, advance: advance)
        case .quickCheck:
            OnbQuickCheckView(state: state, service: service, advance: advance)
        case .day1SneakPeek:
            OnbDay1SneakPeekView(state: state, service: service, advance: advance)
        case .day1Complete:
            OnbDay1CompleteView(state: state, service: service, advance: advance)
        case .notifPermission:
            OnbNotifPermissionView(state: state, advance: advance)
        case .feedback:
            OnbFeedbackView(state: state, service: service, advance: advance)
        case .done:
            // Terminal state — `.onChange(of: state.step)` above
            // fires `onComplete` and the parent unmounts us. Show
            // a blank card in the meantime.
            Color.clear
        }
    }

    // MARK: - Routing

    /// Central "next step" function. Consulted by every screen's
    /// advance closure. The router handles all the branch conditions
    /// (under-13 order swap, feedback skip, etc.) in one place so
    /// individual screens don't need to know about the flow shape.
    private func advance() {
        switch state.step {
        case .splash:
            state.step = .sourceBranch
        case .sourceBranch:
            state.step = .groupPicker
        case .groupPicker:
            state.step = .gradeYear
        case .gradeYear:
            state.step = .birthYear
        case .birthYear:
            state.step = .birthDoubleCheck
        case .birthDoubleCheck:
            // Under-13 signs in first so the pairing token can be
            // created against an authenticated account. 13+ picks
            // name + avatar before auth.
            state.step = state.isUnder13 ? .authChoice : .nameAvatar
        case .authChoice:
            // Post-auth: under-13 flows into parent-pair; 13+ goes
            // straight to color reveal (their profile is ready).
            state.step = state.isUnder13 ? .parentPair : .colorReveal
        case .parentPair:
            state.step = .nameAvatar
        case .nameAvatar:
            // 13+ path: auth already happened before name entry, so
            // this jumps to color reveal. Under-13 path: name entry
            // happens post-parent-pair; also jump to color reveal.
            state.step = .colorReveal
        case .colorReveal:
            state.step = .quickCheck
        case .quickCheck:
            state.step = .day1SneakPeek
        case .day1SneakPeek:
            state.step = .day1Complete
        case .day1Complete:
            state.step = .notifPermission
        case .notifPermission:
            state.step = .feedback
        case .feedback:
            state.step = .done
        case .done:
            break
        }
    }

    /// Only two "back" edges are supported in this flow, and only one
    /// of them is a real user-driven action (the birth-year double-
    /// check → birth-year picker). Every other screen advances
    /// forward-only.
    private func goBackToBirthYear() {
        state.step = .birthYear
    }
}
