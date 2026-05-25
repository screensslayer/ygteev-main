//
//  CreateSmallGroupSheet.swift
//  YGTeeV
//
//  Pastor sheet for creating a small group. Writes directly to
//  `public.small_groups` via PostgREST (the existing RLS policy
//  `small_groups: pastor manage` gates the insert on `is_group_pastor`).
//  The `tg_chat_on_small_group_member_insert` trigger handles chat
//  thread creation downstream when members are added, so we don't
//  touch chat_threads here.
//

import SwiftUI
import Supabase

struct CreateSmallGroupSheet: View {
    let youthGroupId: UUID
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var description = ""
    @State private var meetingDay  = ""
    @State private var meetingTime = ""
    @State private var isSaving    = false
    @State private var error: String?

    @FocusState private var focusedField: Field?
    enum Field { case name, description, day, time }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        ZStack {
            YGColors.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    basicsCard
                    meetingCard
                    if let error {
                        Text(error)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 130)
            }

            VStack {
                topBar
                Spacer()
            }

            VStack {
                Spacer()
                createBar
            }
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(YGColors.ink.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(YGColors.ink.opacity(0.06))
                    .clipShape(Circle())
            }
            .disabled(isSaving)
            .buttonStyle(.plain)

            Spacer()

            Text("Small group")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(YGColors.ink.opacity(0.55))

            Spacer()

            // Spacer-equivalent so the title stays centered.
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New small group")
                .font(.lilitaOne(size: 26))
                .tracking(-0.6)
                .foregroundStyle(YGColors.ink)
            Text("Smaller circles inside your youth group — leaders, weekly nights, the works.")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.6))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 36)
    }

    private var basicsCard: some View {
        VStack(spacing: 0) {
            sectionLabel("BASICS")
            VStack(spacing: 0) {
                field(label: "NAME",
                      placeholder: "7th Grade Boys",
                      text: $name,
                      capitalization: .words,
                      field: .name)
                Divider().padding(.leading, 14)
                multilineField(label: "DESCRIPTION (OPTIONAL)",
                               placeholder: "What's the vibe? Who's it for?",
                               text: $description,
                               field: .description)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
        }
    }

    private var meetingCard: some View {
        VStack(spacing: 0) {
            sectionLabel("MEETING (OPTIONAL)")
            VStack(spacing: 0) {
                field(label: "DAY",
                      placeholder: "Wednesday",
                      text: $meetingDay,
                      capitalization: .words,
                      field: .day)
                Divider().padding(.leading, 14)
                field(label: "TIME",
                      placeholder: "6:30 PM",
                      text: $meetingTime,
                      capitalization: .characters,
                      field: .time)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(color: YGColors.ink.opacity(0.04), radius: 8, y: 2)
        }
    }

    private var createBar: some View {
        Button { Task { await save() } } label: {
            HStack(spacing: 8) {
                if isSaving { ProgressView().tint(.white) }
                Text(isSaving ? "Creating…" : "Create small group")
                    .font(.lilitaOne(size: 16))
                    .tracking(-0.2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [YGColors.violet, Color(hex: "FF3DA5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: YGColors.violet.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .opacity(canSave ? 1 : 0.5)
        .disabled(!canSave)
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    // MARK: - Building blocks

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .black))
            .tracking(1)
            .foregroundStyle(YGColors.ink.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
            .padding(.leading, 4)
    }

    private func field(label: String,
                       placeholder: String,
                       text: Binding<String>,
                       capitalization: TextInputAutocapitalization,
                       field: Field) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func multilineField(label: String,
                                placeholder: String,
                                text: Binding<String>,
                                field: Field) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField(placeholder, text: text, axis: .vertical)
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .lineLimit(2...5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Save

    private func save() async {
        struct Row: Encodable {
            let youth_group_id: UUID
            let name: String
            let description: String?
            let meeting_day: String?
            let meeting_time: String?
        }

        isSaving = true
        error = nil
        defer { isSaving = false }

        let body = Row(
            youth_group_id: youthGroupId,
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmedOrNil,
            meeting_day: meetingDay.trimmedOrNil,
            meeting_time: meetingTime.trimmedOrNil
        )
        do {
            _ = try await SupabaseManager.shared.client
                .from("small_groups")
                .insert(body)
                .execute()
            onCreated()
            dismiss()
        } catch {
            self.error = "Couldn't create. \(error.localizedDescription)"
        }
    }
}

private extension String {
    /// Trim whitespace; collapse empty-after-trim to nil so optional DB
    /// columns aren't written as zero-length strings.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
