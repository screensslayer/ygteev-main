//
//  ConfettiView.swift
//  YGTeeV
//
//  Pure-SwiftUI confetti burst. ~40 rectangular pieces spawn off the
//  top edge with random horizontal positions and animate down past
//  the bottom over ~2.0–3.2s with a small horizontal drift and a
//  randomized rotation. No external dependency, no UIKit.
//
//  Lifecycle: animation kicks off in `.onAppear` and runs once. Drop
//  the view into a ZStack overlay where you want the celebration and
//  conditionally include it — when SwiftUI re-mounts the view (e.g.
//  on a re-entry into the celebrating state) the State resets and the
//  animation replays.
//

import SwiftUI

struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let driftX: CGFloat
        let color: Color
        let width: CGFloat
        let height: CGFloat
        let delay: Double
        let duration: Double
        let rotationEnd: Double
    }

    private let pieces: [Piece]
    @State private var drop = false

    init(count: Int = 40) {
        let palette: [Color] = [
            YGColors.violet,
            YGColors.pink,
            YGColors.lime,
            YGColors.yellow,
            .white,
            Color(hex: "38BDF8")
        ]
        self.pieces = (0..<count).map { _ in
            Piece(
                x: CGFloat.random(in: 0...1),
                driftX: CGFloat.random(in: -40...40),
                color: palette.randomElement() ?? .white,
                width: CGFloat.random(in: 6...12),
                height: CGFloat.random(in: 9...16),
                delay: Double.random(in: 0...0.6),
                duration: Double.random(in: 2.0...3.2),
                rotationEnd: Double.random(in: -540...540)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(drop ? piece.rotationEnd : 0))
                        .position(
                            x: piece.x * geo.size.width + (drop ? piece.driftX : 0),
                            y: drop ? geo.size.height + 80 : -40
                        )
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: drop
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { drop = true }
    }
}
