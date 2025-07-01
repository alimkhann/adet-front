import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var postsViewModel = PostsViewModel()

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var description = ""
    @State private var selectedPrivacy: PostPrivacy = .friends
    @State private var selectedHabit: Int? = nil
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingHabitPicker = false

    private let maxPhotos = 5
    private let maxDescriptionLength = 280

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Media Selection Section
                    mediaSelectionSection

                    // Description Section
                    descriptionSection

                    // Privacy Section
                    privacySection

                    // Habit Linking Section
                    habitLinkingSection

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        Task {
                            await createPost()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canCreatePost || postsViewModel.isCreatingPost)
                }
            }
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: $selectedPhotos,
                maxSelectionCount: maxPhotos,
                matching: .images
            )
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    selectedImages.append(image)
                }
            }
            .sheet(isPresented: $showingHabitPicker) {
                HabitPickerView(selectedHabit: $selectedHabit)
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    await loadSelectedPhotos(newValue)
                }
            }
            .alert("Error", isPresented: .constant(postsViewModel.errorMessage != nil)) {
                Button("OK") {
                    postsViewModel.clearError()
                }
            } message: {
                if let errorMessage = postsViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Media Selection Section

    private var mediaSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Media")
                .font(.headline)
                .fontWeight(.semibold)

            if selectedImages.isEmpty {
                mediaSelectionPlaceholder
            } else {
                selectedMediaGrid
            }

            mediaActionButtons
        }
    }

    private var mediaSelectionPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .frame(height: 200)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("Add photos to your post")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
            .onTapGesture {
                showingImagePicker = true
            }
    }

    private var selectedMediaGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        selectedImages.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(4)
                }
            }

            // Add more button
            if selectedImages.count < maxPhotos {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
                    .onTapGesture {
                        showingImagePicker = true
                    }
            }
        }
    }

    private var mediaActionButtons: some View {
        HStack(spacing: 16) {
            Button {
                showingImagePicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Button {
                showingCamera = true
            } label: {
                Label("Camera", systemImage: "camera")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Spacer()
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Description")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(description.count)/\(maxDescriptionLength)")
                    .font(.caption)
                    .foregroundColor(description.count > maxDescriptionLength ? .red : .secondary)
            }

            TextField("Share what you accomplished...", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(PostPrivacy.allCases, id: \.self) { privacy in
                    privacyOption(privacy)
                }
            }
        }
    }

    private func privacyOption(_ privacy: PostPrivacy) -> some View {
        Button {
            selectedPrivacy = privacy
        } label: {
            HStack(spacing: 12) {
                Image(systemName: privacy.icon)
                    .foregroundColor(Color(privacy.privacyColor))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(privacy.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(privacy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if selectedPrivacy == privacy {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedPrivacy == privacy ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Habit Linking Section

    private var habitLinkingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Link to Habit")
                .font(.headline)
                .fontWeight(.semibold)

            if let habitId = selectedHabit {
                habitSelectionView(habitId: habitId)
            } else {
                Button {
                    showingHabitPicker = true
                } label: {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.blue)

                        Text("Link to a habit (optional)")
                            .foregroundColor(.blue)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func habitSelectionView(habitId: Int) -> some View {
        HStack {
            Image(systemName: "target")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Linked Habit")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Habit #\(habitId)") // TODO: Replace with actual habit name
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                selectedHabit = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helper Properties

    private var canCreatePost: Bool {
        !selectedImages.isEmpty &&
        description.count <= maxDescriptionLength &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func loadSelectedPhotos(_ photos: [PhotosPickerItem]) async {
        selectedImages.removeAll()

        for photo in photos {
            if let data = try? await photo.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
            }
        }
    }

    private func createPost() async {
        guard canCreatePost else { return }

        // Convert images to URLs (this would typically involve uploading to a server)
        let imageUrls = selectedImages.enumerated().map { index, _ in
            "https://example.com/image_\(UUID().uuidString).jpg"
        }

        let success = await postsViewModel.createPost(
            habitId: selectedHabit,
            proofUrls: imageUrls,
            proofType: .image,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            privacy: selectedPrivacy
        )

        if success {
            dismiss()
        }
    }
}

// MARK: - Habit Picker View

struct HabitPickerView: View {
    @Binding var selectedHabit: Int?
    @Environment(\.dismiss) private var dismiss

    // Mock habits data
    private let habits = [
        (id: 1, name: "Morning Exercise", icon: "figure.run"),
        (id: 2, name: "Read Daily", icon: "book"),
        (id: 3, name: "Meditation", icon: "leaf"),
        (id: 4, name: "Drink Water", icon: "drop"),
        (id: 5, name: "Healthy Eating", icon: "apple")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(habits, id: \.id) { habit in
                    Button {
                        selectedHabit = habit.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: habit.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            Text(habit.name)
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedHabit == habit.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreatePostView()
}