//
//  NewGameSheet.swift
//  YGTeeV
//
//  Configuration sheet shown when the pastor taps "Play Live Game"
//  from the Games Library. Lets them pick format, game style, rounds,
//  timer, and start-now vs scheduled, then fires the launch via
//  `GamesLibraryService.launchMajorityRules`. Only the sheet's
//  "Create & start" button actually creates a room — the hub button
//  no longer creates one on tap.
//
//  Layout mirrors the games.jsx web mock: dark #0C0916 background,
//  purple→pink accents, format cards, segmented style pill, stepper
//  pair, and an inline DatePicker that appears when "Schedule for
//  later" is chosen.
//

import SwiftUI

struct NewGameSheet: View {
    let groupId: UUID
    let groupName: String
    /// Called after a successful create (and start, when not
    /// scheduled) so the presenter can surface the room-code
    /// confirmation. `scheduledStartAt` is nil for start-now games.
    var onLaunched: (_ code: String, _ scheduledStartAt: Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var service = GamesLibraryService.shared

    // MARK: - Config state

    @State private var format: GameFormat = .majorityRules
    @State private var style: GameStyle = .points
    @State private var rounds: Int = 5
    @State private var timer: Int = 20
    @State private var when: WhenToStart = .now
    @State private var scheduledAt: Date = NewGameSheet.defaultScheduledDate()

    @State private var launchError: String?

    private static func defaultScheduledDate() -> Date {
        // 1 hour from now, rounded to the next 5 minutes — feels like
        // a "this evening" anchor rather than the literal current
        // second when the sheet opens.
        let cal = Calendar.current
        let date = cal.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let minute = cal.component(.minute, from: date)
        let bump = (5 - (minute % 5)) % 5
        return cal.date(byAdding: .minute, value: bump, to: date) ?? date
    }

    var body: some View {
        ZStack {
            Color(hex: "0C0916").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    formatCards
                    styleToggle
                    steppersRow
                    whenToStart
                    if when == .scheduled {
                        datePickerCard
                    }
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                launchBar
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .alert("Couldn't start game",
               isPresented: Binding(
                get: { launchError != nil },
                set: { if !$0 { launchError = nil } }
               ),
               presenting: launchError) { _ in
            Button("OK", role: .cancel) { launchError = nil }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEW GAME")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(Color(hex: "B79FFF"))
                Text(groupName)
                    .font(.lilitaOne(size: 26))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            Button { dismiss() } label: {
                Text("Close")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    // MARK: - Format cards

    private enum GameFormat: String, CaseIterable, Identifiable {
        case majorityRules, spend15, chainLink
        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .majorityRules: return "🗳️"
            case .spend15:       return "🛒"
            case .chainLink:     return "🔗"
            }
        }
        var name: String {
            switch self {
            case .majorityRules: return "Majority Rules"
            case .spend15:       return "Spend $15"
            case .chainLink:     return "Chain Link"
            }
        }
        var sub: String {
            switch self {
            case .majorityRules: return "Guess the crowd"
            case .spend15, .chainLink: return "Coming soon"
            }
        }
        var live: Bool { self == .majorityRules }
    }

    private var formatCards: some View {
        HStack(spacing: 10) {
            ForEach(GameFormat.allCases) { f in
                formatCard(f)
            }
        }
    }

    private func formatCard(_ f: GameFormat) -> some View {
        let on = format == f
        return Button {
            if f.live { format = f }
        } label: {
            VStack(spacing: 8) {
                Text(f.emoji)
                    .font(.system(size: 30))
                    .saturation(f.live ? 1 : 0)
                Text(f.name)
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(f.sub)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(on ? Color(hex: "6B2BFF").opacity(0.16) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        on ? Color(hex: "8E5BFF") : .white.opacity(0.08),
                        lineWidth: on ? 1.5 : 1
                    )
            )
            .opacity(f.live ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!f.live)
    }

    // MARK: - Style toggle

    private enum GameStyle: String { case points, elimination }

    private var styleToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("GAME STYLE")
            HStack(spacing: 0) {
                styleSegment(emoji: "💯", label: "Points", value: .points)
                styleSegment(emoji: "💀", label: "Elimination", value: .elimination)
            }
            .padding(4)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
        }
    }

    private func styleSegment(emoji: String, label: String, value: GameStyle) -> some View {
        let on = style == value
        return Button { style = value } label: {
            HStack(spacing: 7) {
                Text(emoji).font(.system(size: 15))
                Text(label)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(on ? .white : .white.opacity(0.6))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Group {
                    if on {
                        LinearGradient(
                            colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Steppers

    private var steppersRow: some View {
        HStack(spacing: 14) {
            stepperCard(label: "ROUNDS",
                        value: rounds,
                        canDecrement: rounds > 3,
                        canIncrement: rounds < 15,
                        onDecrement: { rounds -= 1 },
                        onIncrement: { rounds += 1 })
            stepperCard(label: "TIMER (SEC)",
                        value: timer,
                        canDecrement: timer > 10,
                        canIncrement: timer < 60,
                        onDecrement: { timer -= 5 },
                        onIncrement: { timer += 5 })
        }
    }

    private func stepperCard(label: String,
                             value: Int,
                             canDecrement: Bool,
                             canIncrement: Bool,
                             onDecrement: @escaping () -> Void,
                             onIncrement: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(label)
            HStack {
                stepperButton(symbol: "minus", enabled: canDecrement, action: onDecrement)
                Spacer(minLength: 0)
                Text("\(value)")
                    .font(.lilitaOne(size: 24))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Spacer(minLength: 0)
                stepperButton(symbol: "plus", enabled: canIncrement, action: onIncrement)
            }
            .padding(5)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepperButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.07))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    // MARK: - When to start

    private enum WhenToStart { case now, scheduled }

    private var whenToStart: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("WHEN TO START")
            HStack(spacing: 12) {
                whenCard(value: .now,
                         emoji: "🚀",
                         title: "Start now",
                         sub: "Game goes live immediately")
                whenCard(value: .scheduled,
                         emoji: "📅",
                         title: "Schedule for later",
                         sub: "Pick a date & time")
            }
        }
    }

    private func whenCard(value: WhenToStart, emoji: String, title: String, sub: String) -> some View {
        let on = when == value
        return Button { when = value } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(emoji).font(.system(size: 16))
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text(sub)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(on ? Color(hex: "6B2BFF").opacity(0.14) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        on ? Color(hex: "8E5BFF") : .white.opacity(0.08),
                        lineWidth: on ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var datePickerCard: some View {
        DatePicker("",
                   selection: $scheduledAt,
                   in: Date()...,
                   displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.graphical)
            .colorScheme(.dark)
            .tint(Color(hex: "8E5BFF"))
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Launch bar

    private var launchBar: some View {
        Button(action: launch) {
            HStack(spacing: 8) {
                if service.isLaunching {
                    ProgressView().tint(.white)
                }
                Text(launchLabel)
                    .font(.system(size: 17, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color(hex: "6B2BFF"), Color(hex: "FF3DA5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color(hex: "6B2BFF").opacity(0.45), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(service.isLaunching)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(colors: [Color(hex: "0C0916").opacity(0), Color(hex: "0C0916")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var launchLabel: String {
        when == .now ? "Create & start →" : "Schedule game →"
    }

    // MARK: - Action

    private func launch() {
        launchError = nil
        let settings = GameStartSettings(
            gameStyle: style.rawValue,
            rounds: rounds,
            timerSeconds: timer
        )
        let when = when
        let scheduled = when == .scheduled ? scheduledAt : nil
        Task {
            do {
                let code = try await service.launchMajorityRules(
                    groupId: groupId,
                    settings: settings,
                    scheduledStartAt: scheduled
                )
                onLaunched(code, scheduled)
                dismiss()
            } catch {
                launchError = error.localizedDescription
            }
        }
    }

    // MARK: - Bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.45))
    }
}
