import SwiftUI
import PhotosUI

/// A sheet view for selecting a category cover photo from Camera, Photo Library, or Unsplash
struct PhotoSourcePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var imageSource: CategoryImageSource
    var onImageDataSelected: ((Data) -> String?)?  // saves local image, returns filename

    @State private var showingCamera = false
    @State private var showingUnsplashSearch = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose from Gallery", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingUnsplashSearch = true
                    } label: {
                        Label("Search Online", systemImage: "magnifyingglass")
                    }
                } header: {
                    Text("Photo Source")
                }

                if case .unsplash(let info) = imageSource {
                    Section {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                            Text("Photo by \(info.photographerName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Current Photo")
                    }
                }

                if case .none = imageSource {} else {
                    Section {
                        Button(role: .destructive) {
                            imageSource = .none
                            dismiss()
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Cover Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { imageData in
                    handleLocalImage(imageData)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingUnsplashSearch) {
                UnsplashSearchView { info in
                    Task {
                        await UnsplashService.shared.triggerDownload(url: info.downloadURL)
                        // Download and save locally so it loads instantly next time
                        if let url = URL(string: info.regularURL),
                           let (data, _) = try? await URLSession.shared.data(from: url) {
                            await MainActor.run {
                                handleLocalImage(data)
                            }
                        } else {
                            // Fallback: save as unsplash URL
                            await MainActor.run {
                                imageSource = .unsplash(info)
                                dismiss()
                            }
                        }
                    }
                    showingUnsplashSearch = false
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            handleLocalImage(data)
                        }
                    }
                }
            }
        }
    }

    private func handleLocalImage(_ data: Data) {
        if let filename = onImageDataSelected?(data) {
            imageSource = .local(filename)
            dismiss()
        }
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    var onImageCaptured: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (Data) -> Void

        init(onImageCaptured: @escaping (Data) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                onImageCaptured(data)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Unsplash Search View

struct UnsplashSearchView: View {
    var onPhotoSelected: (UnsplashImageInfo) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var photos: [UnsplashImageInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Searching...")
                        .padding(.top, 40)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else if photos.isEmpty && !searchText.isEmpty && !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No photos found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(photos, id: \.smallURL) { photo in
                            UnsplashPhotoCell(photo: photo) {
                                onPhotoSelected(photo)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Unsplash Photos")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search photos...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadDefaultPhotos()
            }
        }
    }

    private func loadDefaultPhotos() async {
        isLoading = true
        do {
            let results = try await UnsplashService.shared.searchPhotos(query: "nature")
            await MainActor.run {
                photos = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let results = try await UnsplashService.shared.searchPhotos(query: searchText)
                await MainActor.run {
                    photos = results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Unsplash Photo Cell

struct UnsplashPhotoCell: View {
    let photo: UnsplashImageInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                AsyncImage(url: URL(string: photo.smallURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fill)
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .frame(height: 160)
                    @unknown default:
                        placeholder
                    }
                }
                .frame(height: 160)
                .clipped()
                .cornerRadius(8)

                Text(photo.photographerName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.secondarySystemBackground))
            .frame(height: 160)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            )
    }
}
