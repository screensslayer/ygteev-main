//
//  PastorPlanSetupView.swift
//  YGTeeV
//
//  Screen 1 of the pastor "Publish a Bible plan" flow:
//  title, days stepper, header gradient/photo chooser, scoring callout.
//

import SwiftUI
import PhotosUI

struct PastorPlanSetupView: View {
    let groupId: UUID
    var onContinue: (BiblePlanDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var service = PastorPlanService.shared

    @State private var title: String = ""
    @State private var days: Int = 7
    @State private var gradientIdx: Int = 0
    @State private var headerKind: HeaderKind = .gradient
    @State private var headerImageURL: String?

    @State private var pickedPhoto: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    @State private var isWorking = false
    @State private var errorMessage: String?

    @State private var pastorGroups: [PastorGroup] = []
    /// Ordered list of selected groups; index 0 is the **primary** (the
    /// one that goes into `_group_id`). The rest become
    /// `_additional_group_ids`. At least one must be selected to build.
    @State private var selectedGroupIds: [UUID]

    @FocusState private var titleFocused: Bool
    @State private var isKeyboardVisible = false

    init(groupId: UUID, onContinue: @escaping (BiblePlanDraft) -> Void) {
        self.groupId = groupId
        self.onContinue = onContinue
        self._selectedGroupIds = State(initialValue: [groupId])
    }

    private let dayPresets = [3, 5, 7, 14, 21, 30]

    /// "Build day 1 →" is disabled while we're saving OR the pastor
    /// hasn't given us a title OR they've unchecked every group.
    private var buildBlocked: Bool {
        isWorking
            || title.trimmingCharacters(in: .whitespaces).isEmpty
            || selectedGroupIds.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 12) {
                    headerPreview
                    titleCard
                    if pastorGroups.count > 1 { groupPickerCard }
                    daysCard
                    headerChooserCard
                    scoringCallout
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, isKeyboardVisible ? 120 : 200)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .background(
            YGColors.paper
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { titleFocused = false }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("STEP 1 OF 3")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(YGColors.ink.opacity(0.5))
                    Text("Create a Bible plan")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(YGColors.ink)
                }
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPickedPhoto(item) }
        }
        .task {
            // Only show the picker if the pastor leads more than one group.
            if pastorGroups.isEmpty {
                pastorGroups = await service.loadMyPastorGroups()
                // Drop any seeded ids that aren't actually in the pastor's
                // group list (stale default or revoked role).
                let valid = Set(pastorGroups.map(\.id))
                selectedGroupIds = selectedGroupIds.filter { valid.contains($0) }
                // If nothing valid remains, fall back to the first group
                // so the picker isn't empty on first paint.
                if selectedGroupIds.isEmpty, let first = pastorGroups.first {
                    selectedGroupIds = [first.id]
                }
            }
        }
    }

    // MARK: - Sections

    private var headerPreview: some View {
        ZStack(alignment: .bottomLeading) {
            if headerKind == .photo, let pickedImage {
                Image(uiImage: pickedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                PlanHeaderGradient.gradient(at: gradientIdx)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(days)-DAY PLAN")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(title.isEmpty ? "Untitled plan" : title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.2), radius: 12)
            }
            .padding(16)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: YGColors.ink.opacity(0.10), radius: 12, y: 6)
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLAN TITLE")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))
            TextField("Plan title", text: $title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(YGColors.ink)
                .focused($titleFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    /// Only rendered when the pastor leads more than one youth group.
    /// Multi-select: each ticked card is sent to the server; the first
    /// one in selection order is the primary `_group_id` and the rest
    /// go into `_additional_group_ids`.
    private var groupPickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("YOUTH GROUPS")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(YGColors.ink.opacity(0.55))
                Spacer()
                Text(selectedGroupIds.isEmpty
                     ? "Pick at least one"
                     : "\(selectedGroupIds.count) selected")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(selectedGroupIds.isEmpty
                                     ? Color(hex: "D11149")
                                     : YGColors.violet)
            }

            VStack(spacing: 8) {
                ForEach(pastorGroups) { group in
                    groupRow(group)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private func groupRow(_ group: PastorGroup) -> some View {
        let isSelected = selectedGroupIds.contains(group.id)
        let isPrimary  = selectedGroupIds.first == group.id

        return Button { toggle(group: group) } label: {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? YGColors.violet : YGColors.ink.opacity(0.25),
                            lineWidth: 2
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? YGColors.violet : Color.clear)
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                        if isPrimary {
                            Text("PRIMARY")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.4)
                                .foregroundStyle(YGColors.violet)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(YGColors.violet.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                        .font(.system(size: 11.5))
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                }

                Spacer()

                // "Make primary" pill — only shows when the row is
                // selected, not already primary, and the user has more
                // than one selection (otherwise primary swap is moot).
                if isSelected && !isPrimary && selectedGroupIds.count > 1 {
                    Button { makePrimary(group: group) } label: {
                        Text("Make primary")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(YGColors.violet)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(YGColors.violet.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? YGColors.violet.opacity(0.06) : Color.black.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? YGColors.violet.opacity(0.4) : .clear,
                                  lineWidth: isSelected ? 1.5 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection helpers

    private func toggle(group: PastorGroup) {
        if let idx = selectedGroupIds.firstIndex(of: group.id) {
            // Remove. If we just dropped the primary and there's still
            // something selected, the next item (now at index 0)
            // becomes the new primary automatically.
            selectedGroupIds.remove(at: idx)
        } else {
            // Append at the end — never auto-promote a freshly-added
            // group to primary; only an explicit "Make primary" tap or
            // a fresh-from-empty selection should do that.
            if selectedGroupIds.isEmpty {
                selectedGroupIds = [group.id]
            } else {
                selectedGroupIds.append(group.id)
            }
        }
    }

    private func makePrimary(group: PastorGroup) {
        guard let idx = selectedGroupIds.firstIndex(of: group.id) else { return }
        selectedGroupIds.remove(at: idx)
        selectedGroupIds.insert(group.id, at: 0)
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAYS IN PLAN")
                        .font(.system(size: 10.5, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(YGColors.ink.opacity(0.55))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(days)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                        Text("days")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(YGColors.ink.opacity(0.45))
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    stepperButton("−", filled: false) { days = max(1, days - 1) }
                    stepperButton("+", filled: true) { days = min(60, days + 1) }
                }
            }

            HStack(spacing: 6) {
                ForEach(dayPresets, id: \.self) { n in
                    let on = n == days
                    Button { days = n } label: {
                        Text("\(n)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(on ? .white : YGColors.ink.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(on ? YGColors.ink : YGColors.ink.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private func stepperButton(_ label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(filled ? .white : YGColors.ink)
                .frame(width: 38, height: 38)
                .background(filled ? YGColors.ink : Color.white)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(.black.opacity(0.08), lineWidth: filled ? 0 : 1) }
        }
        .buttonStyle(.plain)
    }

    private var headerChooserCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PLAN HEADER")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(YGColors.ink.opacity(0.55))

            // Photo tile (single — using PhotosPicker)
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                HStack(spacing: 6) {
                    Text("⬆")
                    Text(headerKind == .photo && pickedImage != nil ? "Change photo" : "Upload image")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(YGColors.ink.opacity(0.65))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(YGColors.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            headerKind == .photo ? YGColors.violet : Color.black.opacity(0.15),
                            style: .init(lineWidth: headerKind == .photo ? 2 : 1, dash: [4, 4])
                        )
                }
            }

            Text("Or pick a gradient")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(YGColors.ink.opacity(0.5))
                .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(0..<PlanHeaderGradient.palette.count, id: \.self) { i in
                    let on = headerKind == .gradient && i == gradientIdx
                    Button {
                        headerKind = .gradient
                        gradientIdx = i
                    } label: {
                        PlanHeaderGradient.gradient(at: i)
                            .frame(height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(on ? YGColors.ink : .clear, lineWidth: 2.5)
                            }
                            .scaleEffect(on ? 1.04 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
    }

    private var scoringCallout: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("⚡")
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "FFD60A"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("💧")
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "3DAEFF"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Standard scoring.")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                Text("500 XP + 4 Water per day · 50 XP per correct answer.")
                    .font(.system(size: 12))
                    .foregroundStyle(YGColors.ink.opacity(0.75))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(hex: "FFD60A").opacity(0.12), Color(hex: "3DAEFF").opacity(0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(YGColors.ink.opacity(0.06), lineWidth: 0.5) }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                // Save-as-draft behaves like the primary CTA — same RPC,
                // pastor just exits the flow afterward.
                Task { await createAndContinue(exitAfter: true) }
            } label: {
                Text("Save as draft")
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(YGColors.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(0.08), lineWidth: 0.5) }
            }
            .disabled(isWorking)
            .buttonStyle(.plain)

            Button {
                Task { await createAndContinue(exitAfter: false) }
            } label: {
                HStack(spacing: 6) {
                    if isWorking { ProgressView().tint(.white) }
                    else { Text("Build day 1 →").font(.system(size: 15, weight: .heavy, design: .rounded)) }
                }
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
            .disabled(buildBlocked)
            .opacity(buildBlocked ? 0.6 : 1)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, isKeyboardVisible ? 12 : 90)
        .background(
            LinearGradient(
                colors: [YGColors.paper.opacity(0), YGColors.paper.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: isKeyboardVisible ? 90 : 170, alignment: .bottom)
        )
    }

    // MARK: - Actions

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                pickedImage = img
                headerKind = .photo
            }
        } catch {
            errorMessage = "Couldn't load that photo."
        }
    }

    private func createAndContinue(exitAfter: Bool) async {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil

        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            // Defensive: the disabled-state on the CTA already blocks
            // this path when nothing's selected, but bail explicitly to
            // keep the error message friendly if something slips past.
            guard let primaryGroupId = selectedGroupIds.first else {
                errorMessage = "Pick at least one youth group."
                return
            }
            let extras = Array(selectedGroupIds.dropFirst())
            let planId = try await service.createPlan(
                groupId: primaryGroupId,
                title: trimmedTitle,
                days: days,
                gradientIdx: gradientIdx,
                additionalGroupIds: extras
            )

            // Header treatment — gradient unless a photo was picked.
            if headerKind == .photo, let img = pickedImage {
                let resized = Self.downscale(img, maxSide: 1600)
                if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                    let url = try await service.uploadHeaderImage(planId: planId, jpegData: jpeg)
                    headerImageURL = url
                    try await service.updateBasics(
                        planId: planId, headerKind: .photo, headerImageURL: url)
                }
            }

            let draft = BiblePlanDraft(
                id: planId,
                groupId: primaryGroupId,
                additionalGroupIds: extras,
                title: trimmedTitle,
                totalDays: days,
                headerKind: headerKind,
                headerImageURL: headerImageURL,
                gradientIndex: gradientIdx,
                status: "draft",
                visibility: .private,
                days: []
            )
            service.draft = draft

            if exitAfter {
                dismiss()
            } else {
                onContinue(draft)
            }
        } catch {
            errorMessage = "Couldn't create plan. \(error.localizedDescription)"
        }
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let original = image.size
        let largest = max(original.width, original.height)
        guard largest > maxSide else { return image }
        let scale = maxSide / largest
        let newSize = CGSize(width: original.width * scale, height: original.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
