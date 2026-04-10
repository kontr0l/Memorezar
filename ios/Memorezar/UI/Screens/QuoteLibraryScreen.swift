import SwiftUI
import PhotosUI

struct QuoteLibraryScreen: View {
    @EnvironmentObject var quoteStore: QuoteStore
    @State private var showingQuoteInput = false
    @State private var showingNewCategory = false
    @State private var categoryToDelete: QuoteCategory?
    @State private var navigationPath = NavigationPath()
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Large inline title + add quote
                    HStack {
                        Text("Library")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)

                        Spacer()

                        Button {
                            showingQuoteInput = true
                        } label: {
                            Image("IconAddQuote").renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 32)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(quoteStore.categories) { category in
                            NavigationLink(value: category) {
                                CategoryCard(
                                    category: category,
                                    quoteCount: quoteStore.quotes(inCategory: category.id).count
                                )
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale(scale: 0.5).combined(with: .opacity)
                            ))
                            .contextMenu {
                                if quoteStore.categories.count > 1 {
                                    Button(role: .destructive) {
                                        categoryToDelete = category
                                    } label: {
                                        Label(category.sourcePackId != nil ? String(localized: "Remove Pack") : String(localized: "Delete Category"), image: "IconTrash")
                                    }
                                }
                            }
                        }

                        // Add new category tile
                        Button {
                            showingNewCategory = true
                        } label: {
                            Image("IconAddFolder").renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 80)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        }
                        .buttonStyle(.plain)
                        .actionTip(.addCategory)
                    }
                }
                .padding()
            }
            .tipOverlay(.addCategory, verticalOffset: 55)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: QuoteCategory.self) { category in
                CategoryDetailView(category: category)
            }
            .sheet(isPresented: $showingQuoteInput) {
                QuoteInputView()
            }
            .sheet(isPresented: $showingNewCategory) {
                CategoryEditView()
            }
            .alert(
                categoryToDelete?.sourcePackId != nil
                    ? String(localized: "Remove \(categoryToDelete?.name ?? "")?")
                    : String(localized: "Delete \(categoryToDelete?.name ?? "")?"),
                isPresented: Binding(
                    get: { categoryToDelete != nil },
                    set: { if !$0 { categoryToDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
                Button(categoryToDelete?.sourcePackId != nil ? String(localized: "Remove") : String(localized: "Delete"), role: .destructive) {
                    if let cat = categoryToDelete {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            quoteStore.deleteCategory(cat)
                        }
                        categoryToDelete = nil
                    }
                }
            } message: {
                if let cat = categoryToDelete {
                    let count = quoteStore.quotes(inCategory: cat.id).count
                    if cat.sourcePackId != nil {
                        Text(String(localized: "This will remove the pack and its \(count) \(count == 1 ? "quote" : "quotes"). You can re-add it anytime from Browse."))
                    } else if count > 0 {
                        Text(String(localized: "This will permanently delete \(count) \(count == 1 ? "quote" : "quotes") in this category."))
                    } else {
                        Text("This category has no quotes.")
                    }
                }
            }
            .onAppear {
                if let category = quoteStore.pendingCategoryNavigation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            navigationPath.append(category)
                        }
                        quoteStore.pendingCategoryNavigation = nil
                    }
                }
            }
        }
    }
}


// MARK: - Category Card

struct CategoryCard: View {
    @EnvironmentObject var quoteStore: QuoteStore
    let category: QuoteCategory
    let quoteCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image or gradient placeholder
            categoryImage
                .frame(height: 200)
                .clipped()

            // Dark gradient overlay at bottom
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Category name and quote count
            VStack(alignment: .leading, spacing: 4) {
                Spacer()

                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(String(localized: "\(quoteCount) \(quoteCount == 1 ? "quote" : "quotes")"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(12)
        }
        .frame(height: 200)
        .clipped()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
    }

    @ViewBuilder
    private var categoryImage: some View {
        switch category.imageSource {
        case .local(let filename):
            if let image = quoteStore.loadCategoryImage(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.white
            }
        case .unsplash(let info):
            AsyncImage(url: URL(string: info.smallURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    gradientPlaceholder
                case .empty:
                    Color.white
                @unknown default:
                    Color.white
                }
            }
        case .none:
            gradientPlaceholder
        }
    }

    private var gradientPlaceholder: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        let palettes = QuoteCategory.gradientPalettes
        let index = category.gradientIndex ?? 0
        return palettes[index % palettes.count]
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    let category: QuoteCategory

    @State private var searchText = ""
    @State private var selectedQuote: Quote?
    @State private var quoteToEdit: Quote?
    @State private var showingQuoteInput = false
    @State private var showingCategorySettings = false
    @State private var showNavTitle = false
    @State private var editedName: String
    @FocusState private var titleFieldFocused: Bool

    private var isPack: Bool { category.sourcePackId != nil }

    init(category: QuoteCategory) {
        self.category = category
        _editedName = State(initialValue: category.name)
    }

    /// Always read the latest category from the store so thumbnail reflects changes
    private var currentCategory: QuoteCategory {
        quoteStore.categories.first { $0.id == category.id } ?? category
    }

    private var filteredQuotes: [Quote] {
        var quotes = quoteStore.quotes(inCategory: category.id)
            .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }

        if !searchText.isEmpty {
            quotes = quotes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }

        return quotes
    }

    var body: some View {
        List {
            // Scrollable header (thumbnail + title + search)
            Section {
                categoryHeader
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if filteredQuotes.isEmpty {
                Section {
                    emptyStateView
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredQuotes) { quote in
                    QuoteListRow(quote: quote) {
                        selectedQuote = quote
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isPack {
                            Button(role: .destructive) {
                                quoteStore.deleteQuote(quote)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                quoteToEdit = quote
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
            }
        }
        .listStyle(.plain)
        .coordinateSpace(name: "categoryList")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.backward")
                        Text(showNavTitle ? "" : String(localized: "Library"))
                            .animation(nil, value: showNavTitle)
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Text(currentCategory.name)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showNavTitle ? 1 : 0)
                    .animation(nil, value: showNavTitle)
            }

            if !isPack {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingQuoteInput = true
                    } label: {
                        Image("IconAddQuote").renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 32)
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuoteInput) {
            QuoteInputView(initialCategoryId: category.id)
        }
        .sheet(item: $quoteToEdit) { quote in
            QuoteInputView(quoteToEdit: quote)
        }
        .sheet(isPresented: $showingCategorySettings) {
            CategorySettingsView(
                category: currentCategory,
                onDeleted: { dismiss() }
            )
        }
        .onAppear {
            editedName = currentCategory.name
        }
        .fullScreenCover(item: $selectedQuote) { quote in
            RecitationScreen(quote: quote)
        }
    }

    // MARK: - Category Header (thumbnail + title + search)

    private var categoryHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            // Cover photo thumbnail — tap to open category settings
            Button {
                showingCategorySettings = true
            } label: {
                CategoryThumbnail(category: currentCategory, size: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: 0x777777), lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: 8) {
                // Inline-editable category title — always a TextField to avoid layout jiggle
                TextField("Category name", text: $editedName)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                    .textInputAutocapitalization(.words)
                    .focused($titleFieldFocused)
                    .onSubmit { saveTitleEdit() }
                    .onChange(of: titleFieldFocused) { _, focused in
                        if !focused { saveTitleEdit() }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .named("categoryList")).minY) { _, newValue in
                                    showNavTitle = newValue < 0
                                }
                        }
                    )

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    TextField(String(localized: "Search in \(currentCategory.name)..."), text: $searchText)
                        .font(.subheadline)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
    }

    private func saveTitleEdit() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != currentCategory.name else {
            editedName = currentCategory.name
            return
        }
        var updated = currentCategory
        updated.name = trimmed
        quoteStore.updateCategory(updated)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if searchText.isEmpty {
                BrainCharacterView(character: .work1, size: 120)

                Text("No quotes in this category")
                    .font(.headline)
                Text(isPack ? String(localized: "This pack appears to be empty") : String(localized: "Add a new quote to get started"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if !isPack {
                    Button("Add Quote") {
                        showingQuoteInput = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("No results found")
                    .font(.headline)
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 40)
    }
}

// MARK: - Quote List Row

struct QuoteListRow: View {
    @EnvironmentObject var quoteStore: QuoteStore
    let quote: Quote
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(quote.displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)

                if !quote.titleMatchesPreview {
                    Text(quote.preview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    MasteryBadge(level: quote.masteryLevel)

                    if quote.isSplit, let chunks = quote.chunks {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(String(localized: "\(chunks.count) parts"))
                        }
                        .font(.caption2.bold())
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.12))
                        .cornerRadius(6)
                    }

                    if quote.practiceCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                            Text(String(localized: "\(quote.practiceCount) attempts \(String(format: "%.0f%%", quote.bestAccuracy * 100))"))
                        }
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }

                    Spacer()

                    Text(String(localized: "\(quote.wordCount) words"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.7 { return .orange }
        return .red
    }
}

// MARK: - Category Thumbnail (small preview)

struct CategoryThumbnail: View {
    @EnvironmentObject var quoteStore: QuoteStore
    let category: QuoteCategory
    let size: CGFloat

    var body: some View {
        Group {
            switch category.imageSource {
            case .local(let filename):
                if let image = quoteStore.loadCategoryImage(filename: filename) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    gradientPlaceholder
                }
            case .unsplash(let info):
                AsyncImage(url: URL(string: info.smallURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        gradientPlaceholder
                    }
                }
            case .none:
                gradientPlaceholder
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(8)
    }

    private var gradientPlaceholder: some View {
        LinearGradient(
            colors: placeholderColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var placeholderColors: [Color] {
        let palettes = QuoteCategory.gradientPalettes
        let index = category.gradientIndex ?? 0
        return palettes[index % palettes.count]
    }
}

// MARK: - Category Settings View

struct CategorySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore

    let category: QuoteCategory
    var onDeleted: (() -> Void)?

    @State private var name: String
    @State private var imageSource: CategoryImageSource
    @State private var showingCamera = false
    @State private var showingUnsplashSearch = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDeleteConfirmation = false

    init(category: QuoteCategory, onDeleted: (() -> Void)? = nil) {
        self.category = category
        self.onDeleted = onDeleted
        _name = State(initialValue: category.name)
        _imageSource = State(initialValue: category.imageSource)
    }

    private var isPack: Bool { category.sourcePackId != nil }

    var body: some View {
        NavigationStack {
            List {
                if !isPack {
                    // Category Name
                    Section {
                        TextField("Category Name", text: $name)
                            .textInputAutocapitalization(.words)
                    } header: {
                        Text("Name")
                    }

                    // Cover Photo
                    Section {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Choose from Photo Library", systemImage: "photo.on.rectangle")
                        }

                        Button {
                            showingUnsplashSearch = true
                        } label: {
                            Label("Search Unsplash", systemImage: "magnifyingglass")
                        }

                        if case .none = imageSource {} else {
                            Button(role: .destructive) {
                                imageSource = .none
                            } label: {
                                Label("Remove Photo", systemImage: "xmark.circle")
                            }
                        }
                    } header: {
                        Text("Cover Photo")
                    }

                    if case .unsplash(let info) = imageSource {
                        Section {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                Text(String(localized: "Photo by \(info.photographerName)"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } header: {
                            Text("Current Photo")
                        }
                    }
                }

                // Delete / Remove
                if quoteStore.categories.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(isPack ? String(localized: "Remove Pack") : String(localized: "Delete Category"), systemImage: "trash.fill")
                        }
                    } footer: {
                        let count = quoteStore.quotes(inCategory: category.id).count
                        if isPack {
                            Text(String(localized: "This will remove the pack and its \(count) \(count == 1 ? "quote" : "quotes"). You can re-add it anytime from Browse."))
                        } else if count > 0 {
                            Text(String(localized: "This will permanently delete \(count) \(count == 1 ? "quote" : "quotes") in this category."))
                        }
                    }
                }
            }
            .navigationTitle(isPack ? String(localized: "Pack Settings") : String(localized: "Category Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isPack ? String(localized: "Done") : String(localized: "Cancel")) {
                        dismiss()
                    }
                }

                if !isPack {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
                        if let url = URL(string: info.regularURL),
                           let (data, _) = try? await URLSession.shared.data(from: url) {
                            await MainActor.run {
                                handleLocalImage(data)
                            }
                        } else {
                            await MainActor.run {
                                imageSource = .unsplash(info)
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
            .alert(
                isPack ? String(localized: "Remove \(category.name)?") : String(localized: "Delete \(category.name)?"),
                isPresented: $showingDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button(isPack ? String(localized: "Remove") : String(localized: "Delete"), role: .destructive) {
                    quoteStore.deleteCategory(category)
                    dismiss()
                    onDeleted?()
                }
            } message: {
                let count = quoteStore.quotes(inCategory: category.id).count
                if isPack {
                    Text(String(localized: "This will remove the pack and its \(count) \(count == 1 ? "quote" : "quotes"). You can re-add it anytime from Browse."))
                } else if count > 0 {
                    Text(String(localized: "This will permanently delete \(count) \(count == 1 ? "quote" : "quotes") in this category."))
                } else {
                    Text("This category has no quotes.")
                }
            }
        }
    }

    private func handleLocalImage(_ data: Data) {
        if let filename = quoteStore.saveCategoryImage(data, for: category.id) {
            imageSource = .local(filename)
        }
    }

    private func saveChanges() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var updated = quoteStore.categories.first { $0.id == category.id } ?? category
        updated.name = trimmed
        updated.imageSource = imageSource
        quoteStore.updateCategory(updated)
        dismiss()
    }
}

// MARK: - Mastered Quotes View

struct MasteredQuotesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    @State private var selectedQuote: Quote?

    private var masteredQuotes: [Quote] {
        quoteStore.quotes.filter { $0.masteryLevel == .mastered }
    }

    var body: some View {
        List {
            // Header
            Section {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                            .frame(width: 70, height: 70)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mastered")
                            .font(.title2.bold())
                        Text(String(localized: "\(masteredQuotes.count) \(masteredQuotes.count == 1 ? "quote" : "quotes")"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if masteredQuotes.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        BrainCharacterView(character: .work1, size: 120)

                        Text("No mastered quotes yet")
                            .font(.headline)
                        Text("Keep practicing to master your quotes!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.top, 40)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(masteredQuotes) { quote in
                    QuoteListRow(quote: quote) {
                        selectedQuote = quote
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
            }
        }
        .listStyle(.plain)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.backward")
                        Text("Home")
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Mastered")
                    .font(.headline)
            }
        }
        .fullScreenCover(item: $selectedQuote) { quote in
            RecitationScreen(quote: quote)
        }
    }
}

// MARK: - Category Edit View

struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    @FocusState private var nameFieldFocused: Bool

    @State private var name: String
    @State private var imageSource: CategoryImageSource
    @State private var showingPhotoSourcePicker = false

    private let existingCategory: QuoteCategory?

    init(category: QuoteCategory? = nil) {
        self.existingCategory = category
        _name = State(initialValue: category?.name ?? "")
        _imageSource = State(initialValue: category?.imageSource ?? .none)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFieldFocused)
                } header: {
                    Text("Name")
                }

                Section {
                    // Photo preview
                    HStack {
                        Spacer()
                        coverPhotoPreview
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    Button {
                        showingPhotoSourcePicker = true
                    } label: {
                        Label(
                            imageSource == .none ? String(localized: "Add Cover Photo") : String(localized: "Change Cover Photo"),
                            systemImage: "photo.on.rectangle"
                        )
                    }
                } header: {
                    Text("Cover Photo")
                }
            }
            .navigationTitle(existingCategory == nil ? String(localized: "New Category") : String(localized: "Edit Category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingPhotoSourcePicker) {
                PhotoSourcePicker(
                    imageSource: $imageSource,
                    onImageDataSelected: { data in
                        let categoryId = existingCategory?.id ?? UUID()
                        return quoteStore.saveCategoryImage(data, for: categoryId)
                    }
                )
            }
            .onAppear {
                // Auto-focus name field to avoid keyboard hang on first tap
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    nameFieldFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var coverPhotoPreview: some View {
        switch imageSource {
        case .local(let filename):
            if let image = quoteStore.loadCategoryImage(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 160)
                    .cornerRadius(12)
            } else {
                placeholderPreview
            }
        case .unsplash(let info):
            AsyncImage(url: URL(string: info.smallURL)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 160)
                        .cornerRadius(12)
                } else {
                    placeholderPreview
                }
            }
        case .none:
            placeholderPreview
        }
    }

    private var placeholderPreview: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.tertiarySystemBackground))
            .frame(width: 120, height: 160)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No Photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = existingCategory {
            var updated = existing
            updated.name = trimmedName
            updated.imageSource = imageSource
            quoteStore.updateCategory(updated)
        } else {
            let newCategory = QuoteCategory(
                name: trimmedName,
                imageSource: imageSource,
                gradientIndex: quoteStore.nextAvailableGradientIndex()
            )
            quoteStore.addCategory(newCategory)
        }

        dismiss()
    }
}

#Preview {
    QuoteLibraryScreen()
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
}
