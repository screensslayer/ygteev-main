//
//  EditProfileView.swift
//  YGTeeV
//
//  Sheet for editing the current user's profile.
//  - Member / Parent: display name only (title: "Edit Name")
//  - Leader / Pastor: display name + avatar upload + About Me bio
//
//  Driven by `allowExtendedFields`, which the Settings sheet sets based on
//  the active role. Persists via SupabaseManager.updateProfileBasics +
//  uploadAvatar.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    /// When true, surface the avatar + bio fields (leader / pastor).
    let allowExtendedFields: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var supabase = SupabaseManager.shared

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var existingAvatarURL: String?

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let bioLimit = 280

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
    }

    private var initialFor: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if allowExtendedFields {
                        avatarSection
                    }

                    nameField

                    if allowExtendedFields {
                        bioField
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "FF3B30"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(YGColors.paper)
            .navigationTitle(allowExtendedFields ? "Edit Profile" : "Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                    }
                }
            }
            .task { hydrateFromCurrentUser() }
            .onChange(of: photoItem) { _, newItem in
                Task { await loadPickedPhoto(newItem) }
            }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                avatarCircle
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(YGColors.violet)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(YGColors.paper, lineWidth: 3))
                }
                .disabled(isSaving)
                .offset(x: 4, y: 4)
            }
            .frame(width: 112, height: 112)

            Text("Tap the camera to change your photo")
                .font(.system(size: 12))
                .foregroundStyle(YGColors.ink.opacity(0.55))
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var avatarCircle: some View {
        if let pickedImage {
            Image(uiImage: pickedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: YGColors.ink.opacity(0.1), radius: 8, y: 2)
        } else if let urlString = existingAvatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    avatarFallback
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(color: YGColors.ink.opacity(0.1), radius: 8, y: 2)
        } else {
            avatarFallback
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: YGColors.ink.opacity(0.1), radius: 8, y: 2)
        }
    }

    private var avatarFallback: some View {
        ZStack {
            LinearGradient(
                colors: [YGColors.violet.opacity(0.85), YGColors.violet.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Text(initialFor)
                .font(.lilitaOne(size: 42))
                .foregroundStyle(.white)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Name")
                .font(.lilitaOne(size: 14))
                .tracking(-0.2)
                .foregroundStyle(YGColors.ink.opacity(0.7))

            TextField("Your name", text: $displayName)
                .font(.system(size: 16))
                .foregroundStyle(YGColors.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
        }
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("About Me")
                    .font(.lilitaOne(size: 14))
                    .tracking(-0.2)
                    .foregroundStyle(YGColors.ink.opacity(0.7))
                Spacer()
                Text("\(bio.count) / \(bioLimit)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(bio.count > bioLimit
                                     ? Color(hex: "FF3B30")
                                     : YGColors.ink.opacity(0.45))
            }

            TextEditor(text: $bio)
                .font(.system(size: 15))
                .foregroundStyle(YGColors.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: 180)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                }
                .onChange(of: bio) { _, newValue in
                    if newValue.count > bioLimit {
                        bio = String(newValue.prefix(bioLimit))
                    }
                }
        }
    }

    // MARK: - Actions

    /// Scale `image` down so the longest side is at most `maxDimension` (in
    /// points). Aspect ratio preserved; no-op if already small enough.
    private static func resizedForAvatar(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let original = image.size
        let largest = max(original.width, original.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = CGSize(width: original.width * scale, height: original.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func hydrateFromCurrentUser() {
        guard let user = supabase.currentUser else { return }
        displayName = user.displayName ?? ""
        bio = user.bio ?? ""
        existingAvatarURL = user.avatarUrl
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run { self.pickedImage = img }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't load that photo. Try another one."
            }
        }
    }

    private func save() async {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        defer { Task { @MainActor in isSaving = false } }

        // Try the avatar upload first, but DO NOT let it block the name/bio save.
        // If Storage fails (e.g. 400), we still persist the text edits and
        // surface a non-blocking inline error explaining only the photo failed.
        var avatarUrlToSave: String?
        var photoUploadFailed = false
        if allowExtendedFields, let pickedImage {
            // Resize before encoding. Original camera-roll photos are often
            // 4032×3024 (10+ MB) which can trip storage size limits and is
            // overkill for an avatar. Cap the longest side at 1024px.
            let resized = Self.resizedForAvatar(pickedImage, maxDimension: 1024)
            if let jpegData = resized.jpegData(compressionQuality: 0.85) {
                NSLog("[EditProfileView] resized avatar to %.0f×%.0f, %d bytes",
                      resized.size.width, resized.size.height, jpegData.count)
                do {
                    avatarUrlToSave = try await supabase.uploadAvatar(imageData: jpegData)
                } catch {
                    NSLog("[EditProfileView] avatar upload failed: %@", String(reflecting: error))
                    print("[EditProfileView] avatar upload failed:", error)
                    photoUploadFailed = true
                }
            } else {
                NSLog("[EditProfileView] jpegData encode returned nil")
                photoUploadFailed = true
            }
        }

        do {
            try await supabase.updateProfileBasics(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: allowExtendedFields ? bio.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                avatarUrl: avatarUrlToSave
            )

            if photoUploadFailed {
                // Name + bio saved, but the picture didn't. Tell the user
                // and leave the sheet open so they can retry the photo.
                await MainActor.run {
                    self.pickedImage = nil
                    self.errorMessage = "Couldn't upload photo — try again. Your name and bio were saved."
                }
            } else {
                await MainActor.run { dismiss() }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't save your changes. \(error.localizedDescription)"
            }
        }
    }
}

#Preview("Leader / Pastor — extended") {
    EditProfileView(allowExtendedFields: true)
}

#Preview("Member / Parent — name only") {
    EditProfileView(allowExtendedFields: false)
}
