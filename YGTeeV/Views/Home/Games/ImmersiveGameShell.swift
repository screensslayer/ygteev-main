//
//  ImmersiveGameShell.swift
//  YGTeeV
//
//  The ONE container that owns layout chrome + padding for every
//  state of the Game Night immersive flow. Stage views are pure
//  content — they never add horizontal padding, never call
//  ignoresSafeArea, never wrap themselves in a GeometryReader. The
//  shell handles all of that uniformly so the insets match across
//  every state.
//
//  Dismissal is owned by the parent presentation — the cover is a
//  `.sheet`, so iOS provides native swipe-to-dismiss that tracks
//  the finger. There is no in-shell close button.
//
//  Implementation note: every horizontal sibling is pinned to
//  `geo.size.width` via `.frame(width: …)` AFTER its own internal
//  `.padding(.horizontal, 20)`. That removes every degree of freedom
//  SwiftUI could use to drift a child past the leading edge.
//

import SwiftUI

struct ImmersiveGameShell<Content: View>: View {
    let roomCode: String?
    /// Total questions in this game — drives how many progress
    /// squares the footer renders. Nil before discovery / on error
    /// states where no game is active.
    let totalQuestions: Int?
    /// Per-question result map: index → was the user correct? A
    /// missing key means the question hasn't reached reveal yet
    /// (grey square).
    let questionResults: [Int: Bool]
    /// Index of the question currently being played. Optional —
    /// used for any future "highlight active square" decoration.
    let currentQuestionIndex: Int?
    let showFooter: Bool
    let content: Content

    init(roomCode: String?,
         totalQuestions: Int?,
         questionResults: [Int: Bool],
         currentQuestionIndex: Int?,
         showFooter: Bool,
         @ViewBuilder content: () -> Content) {
        self.roomCode = roomCode
        self.totalQuestions = totalQuestions
        self.questionResults = questionResults
        self.currentQuestionIndex = currentQuestionIndex
        self.showFooter = showFooter
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ImmersiveBackground()

                VStack(spacing: 0) {
                    // TOP CHROME — ROOM badge when relevant
                    // (lobby / error). Hidden during actual
                    // gameplay so the question stays the focal
                    // point.
                    HStack(spacing: 12) {
                        Spacer(minLength: 0)
                        if let code = roomCode, !code.isEmpty {
                            RoomCodeBadge(code: code)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .frame(width: geo.size.width)
                    .padding(.top, geo.safeAreaInsets.top + 4)
                    .padding(.bottom, 4)

                    // MAIN CONTENT — the ONE place stage views get
                    // their 20pt horizontal inset.
                    content
                        .padding(.horizontal, 20)
                        .frame(width: geo.size.width)
                        .frame(maxHeight: .infinity, alignment: .top)

                    // BOTTOM CHROME — identity + per-question
                    // progress squares (no running score). The
                    // footer has its own internal 20pt horizontal
                    // padding so the avatar lands at exactly x=20
                    // from the leading edge.
                    if showFooter {
                        GameFooter(
                            totalQuestions: totalQuestions,
                            questionResults: questionResults,
                            currentQuestionIndex: currentQuestionIndex
                        )
                        .frame(width: geo.size.width)
                        .padding(.bottom, geo.safeAreaInsets.bottom)
                    }
                }
                .frame(width: geo.size.width,
                       height: geo.size.height,
                       alignment: .top)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
