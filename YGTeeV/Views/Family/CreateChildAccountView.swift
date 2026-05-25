//
//  CreateChildAccountView.swift
//  YGTeeV
//
//  Parent-side under-13 child-account creation. Collects first name,
//  optional last name, DOB (must be < 13y), optional grade, optional
//  avatar, then calls the `create-child-account` Edge Function and
//  hands off to `ChildPairingDisplaySheet` to show the QR + 8-digit
//  fallback code.
//

import SwiftUI

struct CreateChildAccountView: View {
    let familyId: UUID
    /// Bubble the pairing result up so the host sheet can swap to the
    /// pairing-display screen without needing this view to own that
    /// presentation.
    let onCreated: (CreateChildResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -10, to: .now)!
    @State private var grade: Int? = nil
    @State private var isSubmitting = false
    @State private var error: String?

    /// DOB upper bound is today (no future birthdays); lower bound is
    /// 25 years ago — enough headroom for any teen/young-adult managed
    /// account without scrolling forever.
    private var maxDOB: Date { .now }
    private var minDOB: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    }

    private var isValid: Bool {
        let f = firstName.trimmingCharacters(in: .whitespaces)
        return !f.isEmpty && dob <= maxDOB && grade != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headline
                    nameFields
                    dobField
                    gradeField

                    if let error {
                        Text(error)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            .background(YGColors.paper)
            .navigationTitle("Create Managed Account")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                submitButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
                    .padding(.top, 8)
                    .background(YGColors.paper)
            }
        }
    }

    // MARK: - Sections

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set them up")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(YGColors.ink)
            Text("We'll create a managed account they sign into with your QR.")
                .font(.system(size: 13))
                .foregroundStyle(YGColors.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameFields: some View {
        VStack(spacing: 0) {
            field(label: "FIRST NAME", placeholder: "Ezra", text: $firstName)
            Divider().padding(.leading, 16)
            field(label: "LAST NAME (optional)", placeholder: "Kim", text: $lastName)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    private func field(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(YGColors.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dobField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATE OF BIRTH")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            DatePicker("", selection: $dob,
                       in: minDOB...maxDOB,
                       displayedComponents: .date)
                .labelsHidden()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    private var gradeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("GRADE")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                Spacer()
                Text("School year \(Self.currentSchoolYearLabel)")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.3)
                    .foregroundStyle(YGColors.violet)
            }
            HStack(spacing: 6) {
                ForEach(6...12, id: \.self) { g in
                    Button {
                        grade = (grade == g) ? nil : g
                    } label: {
                        Text("\(g)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(grade == g ? .white : YGColors.ink.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(grade == g ? YGColors.ink : YGColors.ink.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
    }

    /// "2026–27" style label for the academic year that contains today.
    /// US academic year flips in August — months Aug–Dec live in the year
    /// that starts in the current calendar year; Jan–Jul live in the year
    /// that starts the previous calendar year.
    private static var currentSchoolYearLabel: String {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        let start = month >= 8 ? year : year - 1
        let endTwoDigit = String(format: "%02d", (start + 1) % 100)
        return "\(start)–\(endTwoDigit)"
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting { ProgressView().tint(.white) }
                Text("Create account")
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [YGColors.violet, Color(hex: "FF3DA5")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: YGColors.violet.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isValid || isSubmitting)
        .opacity(isValid && !isSubmitting ? 1 : 0.55)
    }

    // MARK: - Actions

    private func submit() async {
        guard isValid else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        do {
            let result = try await FamilyService.shared.createChildAccount(
                familyId: familyId,
                firstName: firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                dateOfBirth: dob,
                gradeYear: grade,
                avatarURL: nil
            )
            onCreated(result)
        } catch {
            self.error = "Couldn't create account: \(error.localizedDescription)"
        }
    }
}
