import SwiftUI
import AVFoundation

/// Main screen for practicing recitation
/// Shows real-time feedback as user recites
struct RecitationScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var quoteStore: QuoteStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var userEquivalencesStore: UserEquivalencesStore
    @EnvironmentObject var localRecordingStore: LocalRecordingStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var purchaseService: PurchaseService
    @EnvironmentObject var tutorialStore: TutorialStore

    let quote: Quote
    var isTutorialMode: Bool = false

    @StateObject private var viewModel: RecitationViewModel
    @State private var communityRecordings: [Recording] = []
    @State private var communityRecordingCount = 0
    @State private var isLoadingRecordings = true
    @State private var downloadingId: UUID?
    @State private var swipeOffset: CGFloat = 0

    // Playback mode
    @State private var isPlaybackMode = false
    @State private var playbackSource: PlaybackSource?
    @State private var playbackAudioData: Data?
    @State private var playbackPlaylist: [PlaybackSource] = []
    @State private var playbackPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackCurrentTime: TimeInterval = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var playbackTimer: Timer?
    @State private var isLoadingAudio = false
    @State private var playbackRepeat = true
    @State private var showPlaybackFlagAlert = false
    @State private var showMasterInfoPopup = false
    @State private var showRecitationTutorial = false
    @State private var showSpotlightTutorial = false
    @State private var spotlightStep = 0
    @State private var showQuoteAccuracy = false
    @State private var showSplitOverlay = false
    @State private var splitCount: Int = 3
    @State private var showLiquidFill = false
    @State private var liquidFillProgress: CGFloat = 0
    @State private var liquidWavePhase: CGFloat = 0
    @State private var liquidOpacity: Double = 1
    @State private var micFillProgress: CGFloat = 0
    @State private var wasMasterMode = false
    @State private var playbackFlagReason = ""
    @State private var showDeleteRecordingAlert = false
    @State private var showRecordingPicker = false
    @State private var pickerTab: PickerTab = .yours

    // Recording mode (reuses playback UI elements)
    @StateObject private var recorder = AudioRecorderService()
    @State private var isRecordingMode = false
    @State private var previewPlayer: AVAudioPlayer?
    @State private var isPreviewPlaying = false
    @State private var previewCurrentTime: TimeInterval = 0
    @State private var previewDuration: TimeInterval = 0
    @State private var previewTimer: Timer?
    @StateObject private var tts = TextToSpeechService.shared
    @State private var isTTSActive = false
    @State private var shareWithCommunity = false
    @State private var isUploading = false
    @State private var showSaveRecordingSheet = false
    @State private var isEditingExistingRecording = false
    @State private var recordingName = ""
    @State private var showAuthSheet = false
    @State private var showReplaceRecordingAlert = false
    @State private var existingRecording: Recording?
    @State private var showPaywall = false

    init(quote: Quote, isTutorialMode: Bool = false) {
        self.quote = quote
        self.isTutorialMode = isTutorialMode
        _viewModel = StateObject(wrappedValue: RecitationViewModel(quote: quote))
    }

    /// Quotes in the same category, sorted by explicit order (matches library)
    private var siblingQuotes: [Quote] {
        quoteStore.quotes(inCategory: viewModel.quote.categoryId)
            .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
    }

    private var currentIndexInSiblings: Int? {
        siblingQuotes.firstIndex(where: { $0.id == viewModel.quote.id })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background flash for mistakes (recitation only)
                if !isPlaybackMode && viewModel.showMistakeFlash {
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                }

                // Liquid fill animation when entering/exiting master mode
                GeometryReader { geo in
                    LiquidWaveShape(
                        progress: liquidFillProgress,
                        waveHeight: 12,
                        phase: liquidWavePhase
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.7),
                                Color.yellow.opacity(0.5),
                                Color.yellow.opacity(0.3)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()
                .opacity(showLiquidFill ? liquidOpacity : 0)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    if !isTutorialMode {
                        // Mode picker + exit button
                        HStack(spacing: 20) {
                            modePicker
                            Button {
                                exitPlaybackMode()
                                viewModel.saveSplitState()
                                viewModel.stop()
                                dismiss()
                            } label: {
                                Image("IconExit")
                                    .renderingMode(.original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 32)
                            }
                            .disabled(viewModel.showSplitPopup)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    // Progress bar
                    if !isTutorialMode {
                        if isPlaybackMode {
                            playbackProgressBar
                        } else if settingsStore.showProgressBar {
                            progressBar
                        }
                    } else {
                        progressBar
                    }

                    // Main content with footer overlay
                    ZStack(alignment: .bottom) {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 12) {
                                    // Title (dropdown in playback, chunk nav when split, plain otherwise)
                                    if isPlaybackMode {
                                        recordingDropdownButton
                                            .padding(.top)
                                            .frame(maxWidth: .infinity)
                                            .overlay(alignment: .top) {
                                                playbackTimeLabelRow
                                                    .padding(.horizontal, 4)
                                            }
                                    } else if let chunks = viewModel.splitChunks {
                                        VStack(spacing: 4) {
                                            HStack(spacing: 4) {
                                                Text("\(viewModel.activeTitle)")
                                                    .font(.title2.bold())
                                                    .lineLimit(1)

                                                if viewModel.hasTranslations {
                                                    languageTogglePill
                                                }
                                            }

                                            HStack(spacing: 4) {
                                                Button {
                                                    if viewModel.activeChunkIndex > 0 {
                                                        viewModel.switchToChunk(viewModel.activeChunkIndex - 1)
                                                    }
                                                } label: {
                                                    Image(systemName: "chevron.left")
                                                        .font(.title2.bold())
                                                        .foregroundColor(viewModel.activeChunkIndex > 0 ? .blue : Color(.systemGray4))
                                                }
                                                .disabled(viewModel.activeChunkIndex <= 0)

                                                Text(String(localized: "\(viewModel.activeChunkIndex + 1) of \(chunks.count)", comment: "Chunk X of Y navigation"))
                                                    .font(.title2.bold())

                                                Button {
                                                    if viewModel.activeChunkIndex < chunks.count - 1 {
                                                        viewModel.switchToChunk(viewModel.activeChunkIndex + 1)
                                                    }
                                                } label: {
                                                    Image(systemName: "chevron.right")
                                                        .font(.title2.bold())
                                                        .foregroundColor(viewModel.activeChunkIndex < chunks.count - 1 ? .blue : Color(.systemGray4))
                                                }
                                                .disabled(viewModel.activeChunkIndex >= chunks.count - 1)
                                            }
                                        }
                                        .multilineTextAlignment(.center)
                                        .padding(.top)
                                    } else {
                                        HStack(spacing: 8) {
                                            Text(viewModel.activeTitle)
                                                .font(.title2.bold())
                                                .lineLimit(1)

                                            if !isTutorialMode && viewModel.hasTranslations {
                                                languageTogglePill
                                            }
                                        }
                                        .padding(.top)
                                    }

                                    // Reveal slider
                                    revealSlider

                                    // Word display (always visible — full quote in playback, split/normal otherwise)
                                    if !isPlaybackMode, let chunks = viewModel.splitChunks {
                                        splitWordDisplay(chunks: chunks, proxy: proxy)
                                    } else {
                                        wordDisplay(proxy: proxy)
                                    }

                                    Spacer(minLength: 180)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                        }



                        // Control bar overlaid at bottom
                        if isTutorialMode {
                            tutorialControlBar
                        } else if isPlaybackMode {
                            playbackControlBar
                        } else {
                            controlBar
                        }
                    }
                }
                .animation(.none, value: viewModel.currentMode)

                // Mistake dispute popup (recitation only)
                if !isPlaybackMode,
                   viewModel.tappedMistakeIndex != nil,
                   let spokenWord = viewModel.tappedMistakeSpoken {
                    mistakeDisputePopup(spokenWord: spokenWord)
                }

                // Split/chunk manager popup (recitation only)
                if !isPlaybackMode && viewModel.showSplitPopup {
                    splitPopup
                }

            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.settingsStore = settingsStore
                viewModel.userEquivalencesStore = userEquivalencesStore
                viewModel.quoteStore = quoteStore
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if viewModel.applyDefaultMode() {
                        isPlaybackMode = true
                        autoSelectOrShowPicker()
                    }
                    if !isTutorialMode {
                        // Restore last practiced language if user practiced in a translation
                        if let savedLang = quote.lastPracticedLanguage {
                            viewModel.switchLanguage(savedLang)
                        }
                        viewModel.restoreSavedSplit()
                    }
                    if isTutorialMode {
                        viewModel.isTutorialMode = true
                        let isVoiceFirstLetter = viewModel.currentMode == .voice && viewModel.isFirstLetterToggle
                        if !isVoiceFirstLetter {
                            // All tutorial modes except voice+first letter: hide "Happy" (0) and "to" (2)
                            viewModel.displayLevel = 2
                            viewModel.revealPercentage = 50
                            viewModel.applyTutorialReveal(revealedIndices: [1, 3])
                        }
                    }
                }
                viewModel.requestPermissions()
                if !isTutorialMode {
                    // SHELVED: spotlight walkthrough — re-enable when ready (see KNOWN_ISSUES.md TUTORIAL-001)
                    // showRecitationTutorial = true
                    // showSpotlightTutorial = true
                }
            }
            .onDisappear {
                if !isTutorialMode { viewModel.saveSplitState() }
                viewModel.stop()
                exitPlaybackMode()
            }
            .alert(String(localized: "Microphone Access Required"), isPresented: $viewModel.showPermissionAlert) {
                Button(String(localized: "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(String(localized: "Memorezar needs microphone access to hear your recitation. Please enable it in Settings."))
            }
            .alert(String(localized: "Audio Unavailable"), isPresented: $viewModel.audioSessionFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(String(localized: "The microphone is being used by another app (e.g. a phone call). Please end the other call and try again."))
            }
            .overlay {
                if viewModel.showMasterModeHintBlock {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.showMasterModeHintBlock = false
                            }

                        VStack(spacing: 16) {
                            Image("SpriteWork1")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)

                            Text(String(localized: "No help — prove you know it!"))
                                .font(.headline)
                                .multilineTextAlignment(.center)

                            Button("Got it") {
                                viewModel.showMasterModeHintBlock = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(radius: 20)
                        .padding(.horizontal, 40)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showMasterModeHintBlock)
            .overlay {
                if showMasterInfoPopup {
                    masterInfoPopup
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showMasterInfoPopup)
            .overlay {
                if showRecitationTutorial {
                    recitationTutorialPopup
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showRecitationTutorial)
            .overlay {
                if showSplitOverlay {
                    splitMergeOverlay
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showSplitOverlay)
            .overlayPreferenceValue(SpotlightPreferenceKey.self) { anchors in
                if showSpotlightTutorial {
                    SpotlightOverlay(
                        steps: spotlightTutorialSteps,
                        anchors: anchors,
                        currentStep: $spotlightStep,
                        onDismiss: {
                            showSpotlightTutorial = false
                            spotlightStep = 0
                            tutorialStore.completeTip(TipDefinition.recitationIntro.id)
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSpotlightTutorial)
            .onChange(of: viewModel.isMasterMode) { _, isMaster in
                if isMaster {
                    wasMasterMode = true
                } else {
                    if showLiquidFill {
                        triggerLiquidDrainAnimation()
                    }
                }
            }
            .onChange(of: viewModel.currentMode) { _, _ in
                if wasMasterMode && !viewModel.isMasterMode {
                    // Coming out of master mode via mode switch — drain already handled
                    wasMasterMode = false
                    micFillProgress = 0
                }
            }
            .sheet(isPresented: $viewModel.showResults) {
                resultsSheet
            }
            .sheet(isPresented: $showSaveRecordingSheet, onDismiss: {
                isEditingExistingRecording = false
            }) {
                NavigationStack {
                    Form {
                        Section {
                            TextField(String(localized: "Recording name"), text: $recordingName)
                        } header: {
                            Text("Name")
                        } footer: {
                            if recordingName.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text("Required")
                                    .foregroundColor(.red)
                            }
                        }

                        Section {
                            if authService.isSignedIn {
                                Toggle(isOn: $shareWithCommunity) {
                                    Label(
                                        shareWithCommunity ? String(localized: "Public") : String(localized: "Private"),
                                        systemImage: shareWithCommunity ? "globe" : "lock.fill"
                                    )
                                }
                            } else {
                                Button {
                                    showAuthSheet = true
                                } label: {
                                    Label(String(localized: "Sign in to share"), systemImage: "lock.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        } header: {
                            Text("Sharing")
                        } footer: {
                            if authService.isSignedIn {
                                Text(shareWithCommunity
                                    ? String(localized: "This recording will be shared with the community.")
                                    : String(localized: "Only you can see this recording."))
                            } else {
                                Text(String(localized: "Sign in to share recordings with the community."))
                            }
                        }

                        if !isEditingExistingRecording {
                            Section {
                                HStack {
                                    Button {
                                        toggleRecordingPreview()
                                    } label: {
                                        Image(systemName: isPreviewPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)

                                    Text(formatPlaybackTime(recorder.recordingDuration))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            } header: {
                                Text("Preview")
                            }
                        }
                    }
                    .navigationTitle(isEditingExistingRecording ? String(localized: "Edit Recording") : String(localized: "Save Recording"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                if !isEditingExistingRecording {
                                    stopRecordingPreview()
                                    recorder.discardRecording()
                                    isRecordingMode = playbackSource == nil
                                    showRecordingPicker = true
                                }
                                showSaveRecordingSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                showSaveRecordingSheet = false
                                if isEditingExistingRecording {
                                    if let local = playbackSource?.localRecording {
                                        localRecordingStore.updateRecordingName(local, name: recordingName)
                                        // Update playback source in-place
                                        if let idx = playbackPlaylist.firstIndex(where: { $0.id == local.id }),
                                           case .local(var updated) = playbackPlaylist[idx] {
                                            updated.name = recordingName
                                            playbackPlaylist[idx] = .local(updated)
                                            playbackSource = .local(updated)
                                        }
                                        // Upload to community if sharing was toggled on
                                        if shareWithCommunity {
                                            Task {
                                                guard let data = localRecordingStore.loadAudioData(for: local) else { return }
                                                let quoteHash = RecordingService.shared.hashQuoteText(viewModel.activeText)
                                                do {
                                                    let filePath = try await RecordingService.shared.uploadAudio(data: data)
                                                    let recording = try await RecordingService.shared.createRecording(
                                                        quoteTextHash: quoteHash,
                                                        quoteTitle: viewModel.activeTitle,
                                                        uploaderName: recordingName,
                                                        filePath: filePath,
                                                        durationSeconds: local.durationSeconds,
                                                        language: local.language
                                                    )
                                                    communityRecordings.insert(recording, at: 0)
                                                } catch {
                                                    print("[RecitationScreen] Upload error: \(error)")
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    stopRecordingPreview()
                                    Task { await saveNewRecording(name: recordingName) }
                                }
                            }
                            .disabled(recordingName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .sheet(isPresented: $showAuthSheet) {
                    AuthSheet()
                        .environmentObject(authService)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showRecordingPicker) {
                recordingPickerSheet
                    .presentationDetents([.medium, .large])
            }
            .alert(String(localized: "Replace Recording?"), isPresented: $showReplaceRecordingAlert) {
                Button("Replace", role: .destructive) {
                    Task { await performUpload() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(String(localized: "You already have a recording for this quote in this language. Uploading will replace it."))
            }
            .onChange(of: showRecordingPicker) { _, showing in
                if !showing {
                    DispatchQueue.main.async {
                        if playbackSource == nil && !isRecordingMode && downloadingId == nil && !isTTSActive {
                            exitPlaybackMode()
                        }
                    }
                }
            }
            .sheet(isPresented: $showQuoteAccuracy) {
                NavigationStack {
                    QuoteAccuracyDetailView(
                        quoteId: viewModel.quote.id,
                        onScissors: {
                            splitCount = max(2, viewModel.splitCount)
                            showQuoteAccuracy = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSplitOverlay = true
                                }
                            }
                        },
                        onReset: {
                            viewModel.displayLevel = 1
                        }
                    )
                        .environmentObject(quoteStore)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showQuoteAccuracy = false }
                            }
                        }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
            .alert(String(localized: "Delete Recording"), isPresented: $showDeleteRecordingAlert) {
                Button("Delete", role: .destructive) {
                    if case .local(let recording) = playbackSource {
                        playbackPlayer?.stop()
                        playbackPlayer = nil
                        isPlaying = false
                        playbackSource = nil
                        localRecordingStore.deleteRecording(recording)
                        playbackPlaylist = buildPlaylist()
                        if let first = playbackPlaylist.first {
                            selectRecording(first)
                        } else {
                            isRecordingMode = true
                            showRecordingPicker = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(String(localized: "Are you sure you want to delete this recording? This cannot be undone."))
            }
            .alert(String(localized: "Flag Recording"), isPresented: $showPlaybackFlagAlert) {
                TextField(String(localized: "Reason (optional)"), text: $playbackFlagReason)
                Button("Flag", role: .destructive) {
                    flagCurrentRecording()
                }
                Button("Cancel", role: .cancel) {
                    playbackFlagReason = ""
                }
            } message: {
                Text(String(localized: "Report this recording as inappropriate?"))
            }
            .task(id: viewModel.quote.id) {
                let hash = RecordingService.shared.hashQuoteText(viewModel.activeText)
                communityRecordingCount = await RecordingService.shared.fetchRecordingCount(forHash: hash)
                communityRecordings = await RecordingService.shared.fetchRecordings(forHash: hash)
                isLoadingRecordings = false
            }
        }
    }

    // MARK: - Playback / Recording Progress Bar

    private var playbackProgressBar: some View {
        let barColor: Color = isRecordingMode ? .red : (isTTSActive ? .orange : .green)
        let currentTime: TimeInterval
        let totalDuration: TimeInterval

        if isTTSActive {
            // TTS: full bar when speaking, empty when idle/loading
            currentTime = tts.isSpeaking ? 1 : 0
            totalDuration = 1
        } else if isRecordingMode {
            if recorder.hasRecording {
                currentTime = previewCurrentTime
                totalDuration = previewDuration
            } else {
                currentTime = recorder.recordingDuration
                totalDuration = recorder.recordingDuration
            }
        } else {
            currentTime = playbackCurrentTime
            totalDuration = playbackDuration
        }

        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))

                Rectangle()
                    .fill(barColor)
                    .frame(width: totalDuration > 0
                        ? geometry.size.width * (currentTime / totalDuration)
                        : (isRecordingMode && recorder.isRecording ? geometry.size.width : 0))
                    .animation(isTTSActive ? .easeInOut(duration: 0.3) : .none, value: tts.isSpeaking)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isTTSActive else { return }
                        guard !isRecordingMode || recorder.hasRecording else { return }
                        let fraction = max(0, min(1, value.location.x / geometry.size.width))
                        if isRecordingMode {
                            previewCurrentTime = previewDuration * fraction
                            previewPlayer?.currentTime = previewCurrentTime
                        } else {
                            playbackCurrentTime = playbackDuration * fraction
                            playbackPlayer?.currentTime = playbackCurrentTime
                        }
                    }
            )
        }
        .frame(height: 4)
    }

    // MARK: - Playback / Recording Control Bar

    private var playbackControlBar: some View {
        VStack(spacing: 8) {
            if isRecordingMode {
                recordingControlBar
            } else if isTTSActive {
                ttsControlBar
            } else {
                normalPlaybackControlBar
            }
        }
    }

    private var ttsControlBar: some View {
        let lang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode

        return VStack(spacing: 8) {
            // Error message
            if let error = tts.error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 32)
            }

            // Play/Stop button
            Button {
                if tts.isLoading { return }
                if tts.isSpeaking {
                    tts.stop()
                } else {
                    guard purchaseService.canUseTTS else { showPaywall = true; return }
                    tts.speak(viewModel.activeText, language: lang)
                }
            } label: {
                Group {
                    if tts.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: tts.isSpeaking ? "stop.fill" : "play.fill")
                            .font(.system(size: 34))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color.orange)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .disabled(tts.isLoading)
            .frame(height: 80, alignment: .bottom)

            // Dark pill with controls matching recording playback style
            ttsPillBar(lang: lang)

            Spacer().frame(height: 0)
        }
        .onAppear {
            tts.onFinish = { [self] in
                if playbackRepeat && isTTSActive && purchaseService.canUseTTS {
                    let lang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
                    tts.speak(viewModel.activeText, language: lang)
                }
            }
        }
    }

    private func ttsPillBar(lang: String) -> some View {
        HStack(spacing: 0) {
            // REPEAT
            Button {
                playbackRepeat.toggle()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "repeat")
                        .font(.system(size: 18))
                        .frame(height: 24)
                    Text("REPEAT")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(height: 14)
                }
                .foregroundColor(playbackRepeat ? .green : .white.opacity(0.7))
                .frame(width: 50)
            }

            Spacer()

            // BROWSE
            Button {
                showRecordingPicker = true
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                        .frame(height: 24)
                    Text("BROWSE")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(height: 14)
                }
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 36).fill(Color(hex: 0x333333))
        )
        .padding(.horizontal, 8)
    }

    private var normalPlaybackControlBar: some View {
        let isCommunitySource = playbackSource?.isCommunity == true
        let isAlreadySaved = isCurrentRecordingSaved()

        return VStack(spacing: 8) {
            // PREV / Play / NEXT row
            HStack(spacing: 16) {
                // PREV
                Button {
                    navigatePlayback(direction: .backward)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 44, height: 44)
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(playbackPlaylist.count <= 1 ? .white.opacity(0.3) : .white)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
                .disabled(playbackPlaylist.count <= 1)

                // Play/Pause
                Button {
                    togglePlayback()
                } label: {
                    Group {
                        if isLoadingAudio {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 34))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .disabled(isLoadingAudio)

                // NEXT
                Button {
                    navigatePlayback(direction: .forward)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 44, height: 44)
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(playbackPlaylist.count <= 1 ? .white.opacity(0.3) : .white)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
                .disabled(playbackPlaylist.count <= 1)
            }
            .frame(height: 80, alignment: .bottom)

            // Dark pill: REPEAT | SAVE/DELETE | BROWSE
            HStack(spacing: 0) {
                // REPEAT
                Button {
                    playbackRepeat.toggle()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "repeat")
                            .font(.system(size: 18))
                            .frame(height: 24)
                        Text("REPEAT")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(height: 14)
                    }
                    .foregroundColor(playbackRepeat ? .green : .white.opacity(0.7))
                    .frame(width: 50)
                }

                Spacer()

                if isCommunitySource {
                    // FLAG (community only)
                    Button {
                        playbackFlagReason = ""
                        showPlaybackFlagAlert = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "flag")
                                .font(.system(size: 18))
                                .frame(height: 24)
                            Text("FLAG")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(height: 14)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50)
                    }

                    Spacer()

                    // HEART / SAVE (community only)
                    Button {
                        if isAlreadySaved {
                            unsaveCurrentRecording()
                        } else {
                            saveCurrentRecording()
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: isAlreadySaved ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .frame(height: 24)
                            Text("SAVE")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(height: 14)
                        }
                        .foregroundColor(isAlreadySaved ? .red : .white.opacity(0.7))
                        .frame(width: 50)
                    }
                } else {
                    // EDIT (personal only)
                    Button {
                        if let local = playbackSource?.localRecording {
                            recordingName = local.name ?? ""
                            shareWithCommunity = false
                            isEditingExistingRecording = true
                            showSaveRecordingSheet = true
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18))
                                .frame(height: 24)
                            Text("EDIT")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(height: 14)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50)
                    }

                    Spacer()

                    // DELETE (personal only)
                    Button {
                        showDeleteRecordingAlert = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .frame(height: 24)
                            Text("DELETE")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(height: 14)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50)
                    }
                }

                Spacer()

                // BROWSE
                Button {
                    showRecordingPicker = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18))
                            .frame(height: 24)
                        Text("BROWSE")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(height: 14)
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 50)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color(hex: 0x333333))
            )
            .padding(.horizontal, 8)

            Spacer().frame(height: 0)
        }
    }

    // MARK: - Recording Control Bar

    private var recordingControlBar: some View {
        VStack(spacing: 8) {
            if recorder.isRecording {
                // Red stop button while recording
                Button {
                    recorder.stopRecording()
                    recordingName = ""
                    showSaveRecordingSheet = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }

                // Pill: cancel + elapsed time
                HStack(spacing: 0) {
                    // CANCEL
                    Button {
                        recorder.stopRecording()
                        recorder.discardRecording()
                        isRecordingMode = playbackSource == nil
                        showRecordingPicker = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18))
                                .frame(height: 24)
                            Text("CANCEL")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(height: 14)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 60)
                    }

                    Spacer()

                    // Elapsed time
                    Text(formatPlaybackTime(recorder.recordingDuration))
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.red)

                    Spacer()

                    // Spacer to balance layout
                    Color.clear.frame(width: 60, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 36)
                        .fill(Color(hex: 0x333333))
                )
                .padding(.horizontal, 8)

            } else {
                // Pre-recording: red record button
                Button {
                    do {
                        try recorder.startRecording()
                    } catch {
                        viewModel.audioSessionFailed = true
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }

                // Pill: cancel on left, 0:00 timer in center
                HStack(spacing: 0) {
                    Button {
                        showRecordingPicker = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18))
                                .frame(height: 24)
                            Text("CANCEL")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(height: 14)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 60)
                    }

                    Spacer()

                    Text("0:00")
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    // BROWSE
                    Button {
                        showRecordingPicker = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 18))
                                .frame(height: 24)
                            Text("BROWSE")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(height: 14)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 36)
                        .fill(Color(hex: 0x333333))
                )
                .padding(.horizontal, 8)
            }

            Spacer().frame(height: 2)
        }
    }

    // MARK: - Recording Dropdown Button (replaces title in playback mode)

    private var playbackTimeLabels: (current: String, remaining: String) {
        if isTTSActive {
            return ("", "")
        }

        let currentTime: TimeInterval
        let totalDuration: TimeInterval

        if isRecordingMode {
            if recorder.hasRecording {
                currentTime = previewCurrentTime
                totalDuration = previewDuration
            } else {
                currentTime = recorder.recordingDuration
                totalDuration = recorder.recordingDuration
            }
        } else {
            currentTime = playbackCurrentTime
            totalDuration = playbackDuration
        }

        return (
            formatPlaybackTime(currentTime),
            formatPlaybackTime(-(totalDuration - currentTime))
        )
    }

    private var playbackTimeLabelRow: some View {
        let times = playbackTimeLabels

        return HStack {
            Text(times.current)
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Spacer()
            Text(times.remaining)
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .allowsHitTesting(false)
    }

    private var recordingDropdownButton: some View {
        Group {
            if isRecordingMode {
                if recorder.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("Recording...")
                            .font(.title2.bold())
                            .foregroundColor(.red)
                    }
                } else if recorder.hasRecording {
                    Text("Preview")
                        .font(.title2.bold())
                } else {
                    HStack(spacing: 8) {
                        Text(viewModel.activeTitle)
                            .font(.title2.bold())
                            .lineLimit(1)
                        if viewModel.hasTranslations {
                            recordingLanguagePill(interactive: true)
                        }
                    }
                }
            } else if isTTSActive {
                HStack(spacing: 8) {
                    Text(viewModel.activeTitle)
                        .font(.title2.bold())
                        .lineLimit(1)
                    if viewModel.hasTranslations {
                        ttsLanguagePill
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text(playbackSource?.name ?? viewModel.activeTitle)
                        .font(.title2.bold())
                        .lineLimit(1)
                    playbackLanguagePill
                }
            }
        }
    }

    // MARK: - Recording Picker Modal

    /// All text hashes for this quote (original + every translation)
    private var allQuoteHashes: Set<String> {
        var hashes: Set<String> = [RecordingService.shared.hashQuoteText(quote.text)]
        if let translations = quote.translations {
            for translated in translations.values {
                hashes.insert(RecordingService.shared.hashQuoteText(translated.text))
            }
        }
        return hashes
    }

    private var recordingPickerSheet: some View {
        let allLocalRecs = localRecordingStore.recordings(forQuoteId: quote.id, allHashes: allQuoteHashes)
        let localSourceIds = Set(allLocalRecs.compactMap(\.sourceRecordingId))
        let visibleCommunity = communityRecordings.filter { !localSourceIds.contains($0.id) }

        return VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { pickerTab = .yours }
                } label: {
                    Text("Yours")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundColor(pickerTab == .yours ? .primary : Color(.systemGray))
                        .overlay(alignment: .bottom) {
                            if pickerTab == .yours {
                                Rectangle().frame(height: 2).foregroundColor(.primary)
                            }
                        }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { pickerTab = .community }
                } label: {
                    Text("Community")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundColor(pickerTab == .community ? .primary : Color(.systemGray))
                        .overlay(alignment: .bottom) {
                            if pickerTab == .community {
                                Rectangle().frame(height: 2).foregroundColor(.primary)
                            }
                        }
                }
            }

            Divider()

            // Tab content
            Group {
                if pickerTab == .yours {
                    pickerYoursTab(localRecs: allLocalRecs)
                } else {
                    pickerCommunityTab(visibleCommunity: visibleCommunity)
                }
            }
            .frame(minHeight: 160, alignment: .top)
            .animation(.easeInOut(duration: 0.2), value: pickerTab)

            Spacer()

            Divider()

            // Text-to-Speech button
            Button {
                guard purchaseService.canUseTTS else { showPaywall = true; return }
                playbackPlayer?.stop()
                playbackPlayer = nil
                isPlaying = false
                playbackTimer?.invalidate()
                playbackSource = nil
                playbackAudioData = nil
                isRecordingMode = false
                isTTSActive = true
                isPlaybackMode = true
                showRecordingPicker = false

                let lang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
                tts.speak(viewModel.activeText, language: lang)
            } label: {
                HStack {
                    Text("Read Aloud")
                    Image(systemName: "speaker.wave.2.fill")
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Record your own button
            Button {
                playbackPlayer?.stop()
                playbackPlayer = nil
                isPlaying = false
                playbackTimer?.invalidate()
                tts.stop()
                isTTSActive = false
                showRecordingPicker = false
                isRecordingMode = true
            } label: {
                HStack {
                    Text("Record your own")
                    Image(systemName: "mic.fill")
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private func pickerYoursTab(localRecs: [LocalRecording]) -> some View {
        let currentHash = RecordingService.shared.hashQuoteText(viewModel.activeText)
        // Sort: current language first, then others
        let sorted = localRecs.sorted { a, b in
            let aMatch = a.quoteTextHash == currentHash
            let bMatch = b.quoteTextHash == currentHash
            if aMatch != bMatch { return aMatch }
            return a.createdAt > b.createdAt
        }

        return Group {
            if sorted.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No recordings yet")
                        .font(.headline)
                    Text("Record yourself reciting this quote to listen back and improve your memorization.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            } else {
                List {
                    ForEach(sorted) { recording in
                        pickerLocalRow(recording)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if playbackSource?.id == recording.id {
                                        playbackPlayer?.stop()
                                        playbackPlayer = nil
                                        isPlaying = false
                                        playbackSource = nil
                                    }
                                    localRecordingStore.deleteRecording(recording)
                                } label: {
                                    if recording.isFavorite {
                                        Label("Unsave", systemImage: "heart.slash")
                                    } else {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func pickerCommunityTab(visibleCommunity: [Recording]) -> some View {
        Group {
            if isLoadingRecordings {
                HStack {
                    Spacer()
                    ProgressView(String(localized: "Loading..."))
                        .padding(.vertical, 30)
                    Spacer()
                }
            } else if visibleCommunity.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No community recordings")
                        .font(.headline)
                    Text("Be the first to share a recording of this quote!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(visibleCommunity) { recording in
                            pickerCommunityRow(recording)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var playbackSourceLanguageLabel: String? {
        let activeLang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
        switch playbackSource {
        case .local(let r):
            return r.language != activeLang ? "(\(r.language.uppercased()))" : nil
        case .community(let r):
            return r.language != activeLang ? "(\(r.language.uppercased()))" : nil
        case nil:
            return nil
        }
    }

    private func languageLabel(for recording: LocalRecording) -> String? {
        let activeLang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
        guard recording.language != activeLang else { return nil }
        return "(\(recording.language.uppercased()))"
    }

    private func pickerLocalRow(_ recording: LocalRecording) -> some View {
        let isSelected = playbackSource?.id == recording.id
        let langLabel = languageLabel(for: recording)

        return VStack(spacing: 0) {
            Button {
                showRecordingPicker = false
                selectRecording(.local(recording))
            } label: {
                HStack(spacing: 10) {
                    // Clickable heart for favorites
                    if recording.isFavorite {
                        Button {
                            if playbackSource?.id == recording.id {
                                playbackPlayer?.stop()
                                playbackPlayer = nil
                                isPlaying = false
                                playbackSource = nil
                            }
                            localRecordingStore.deleteRecording(recording)
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.body)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(recording.isFavorite ? (recording.uploaderName ?? String(localized: "Community")) : (recording.name ?? String(localized: "Your recording")))
                                .font(.body.weight(isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .blue : .primary)
                            if let langLabel {
                                Text(langLabel)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(recording.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formatPlaybackTime(recording.durationSeconds))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)

                    if isSelected && isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 16)
        }
    }

    private func pickerCommunityRow(_ recording: Recording) -> some View {
        let isSelected = playbackSource?.id == recording.id
        let isDownloading = downloadingId == recording.id
        let activeLang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
        let showLang = recording.language != activeLang

        return VStack(spacing: 0) {
            Button {
                showRecordingPicker = false
                selectRecording(.community(recording))
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(recording.uploaderName)
                                .font(.body.weight(isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .blue : .primary)
                            if showLang {
                                Text("(\(recording.language.uppercased()))")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(recording.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(formatPlaybackTime(recording.durationSeconds ?? 0))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.secondary)

                        if isSelected && isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDownloading)

            Divider()
                .padding(.leading, 16)
        }
    }

    // MARK: - Playlist Selection

    private func selectRecording(_ source: PlaybackSource) {
        isRecordingMode = false
        tts.stop()
        isTTSActive = false


        // Switch displayed quote to the recording's language
        let recordingLang: String = {
            switch source {
            case .local(let r): return r.language
            case .community(let r): return r.language
            }
        }()
        let primaryLang = viewModel.primaryLanguageCode
        if recordingLang == primaryLang {
            viewModel.switchLanguage(nil)
        } else {
            viewModel.switchLanguage(recordingLang)
        }

        switch source {
        case .local(let recording):
            guard let data = localRecordingStore.loadAudioData(for: recording) else { return }
            playbackSource = source
            playbackAudioData = data
            playbackPlaylist = buildPlaylist()
            startPlaybackWithData(data)

        case .community(let recording):
            guard downloadingId == nil else { return }
            downloadingId = recording.id
            Task {
                do {
                    let data = try await RecordingService.shared.downloadAudio(filePath: recording.filePath)
                    await MainActor.run {
                        downloadingId = nil
                        playbackSource = source
                        playbackAudioData = data
                        playbackPlaylist = buildPlaylist()
                        startPlaybackWithData(data)
                    }
                } catch {
                    print("[RecitationScreen] Download error: \(error)")
                    await MainActor.run { downloadingId = nil }
                }
            }
        }
    }

    private func buildPlaylist() -> [PlaybackSource] {
        let allLocal = localRecordingStore.recordings(forQuoteId: quote.id, allHashes: allQuoteHashes)
        var sources: [PlaybackSource] = []
        for r in allLocal {
            sources.append(.local(r))
        }
        let localSourceIds = Set(allLocal.compactMap(\.sourceRecordingId))
        for r in communityRecordings where !localSourceIds.contains(r.id) {
            sources.append(.community(r))
        }
        return sources
    }

    // MARK: - Playback Methods

    /// Auto-select first personal recording or show picker if none exist
    private func autoSelectOrShowPicker() {
        let localRecs = localRecordingStore.recordings(forQuoteId: quote.id, allHashes: allQuoteHashes)
        let localSourceIds = Set(localRecs.compactMap(\.sourceRecordingId))
        let visibleCommunity = communityRecordings.filter { !localSourceIds.contains($0.id) }

        if let first = localRecs.first {
            // Auto-select first personal recording
            selectRecording(.local(first))
        } else {
            // No personal recordings — default to recording mode and show modal
            isRecordingMode = true
            showRecordingPicker = true
        }
    }

    private func exitPlaybackMode() {
        playbackPlayer?.stop()
        playbackPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        isPlaybackMode = false
        playbackSource = nil
        playbackAudioData = nil
        playbackPlaylist = []
        playbackCurrentTime = 0
        playbackDuration = 0
        isLoadingAudio = false
        downloadingId = nil
        showRecordingPicker = false

        // Clean up TTS
        tts.stop()
        isTTSActive = false
        // Clean up recording state
        stopRecordingPreview()
        recorder.cleanup()
        isRecordingMode = false
        isUploading = false
    }

    private func startPlaybackWithData(_ data: Data) {
        playbackPlayer?.stop()
        playbackTimer?.invalidate()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(data: data)
            player.delegate = RecitationPlaybackDelegate.shared
            RecitationPlaybackDelegate.shared.onFinish = { [self] in
                Task { @MainActor in
                    if self.playbackRepeat {
                        self.playbackPlayer?.currentTime = 0
                        self.playbackPlayer?.play()
                    } else {
                        self.isPlaying = false
                        self.playbackTimer?.invalidate()
                    }
                }
            }

            player.play()
            playbackPlayer = player
            playbackDuration = player.duration
            isPlaying = true
            startPlaybackTimer()
        } catch {
            print("[RecitationScreen] Playback error: \(error)")
        }
    }

    private func togglePlayback() {
        guard let player = playbackPlayer else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            playbackTimer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startPlaybackTimer()
        }
    }

    private func navigatePlayback(direction: SwipeDirection) {
        guard playbackPlaylist.count > 1,
              let current = playbackSource else { return }

        guard let currentIndex = playbackPlaylist.firstIndex(where: { $0.id == current.id }) else { return }

        let nextIndex: Int
        switch direction {
        case .forward:
            nextIndex = (currentIndex + 1) % playbackPlaylist.count
        case .backward:
            nextIndex = (currentIndex - 1 + playbackPlaylist.count) % playbackPlaylist.count
        }

        let nextSource = playbackPlaylist[nextIndex]
        playbackPlayer?.stop()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackCurrentTime = 0
        playbackSource = nextSource

        switch nextSource {
        case .local(let recording):
            guard let data = localRecordingStore.loadAudioData(for: recording) else { return }
            playbackAudioData = data
            startPlaybackWithData(data)

        case .community(let recording):
            isLoadingAudio = true
            Task {
                do {
                    let data = try await RecordingService.shared.downloadAudio(filePath: recording.filePath)
                    await MainActor.run {
                        isLoadingAudio = false
                        playbackAudioData = data
                        startPlaybackWithData(data)
                    }
                } catch {
                    print("[RecitationScreen] Download error: \(error)")
                    await MainActor.run { isLoadingAudio = false }
                }
            }
        }
    }

    private func saveCurrentRecording() {
        guard let source = playbackSource,
              let recording = source.communityRecording,
              let data = playbackAudioData else { return }

        let quoteHash = RecordingService.shared.hashQuoteText(viewModel.activeText)
        localRecordingStore.saveRecording(
            audioData: data,
            quoteTextHash: quoteHash,
            quoteTitle: viewModel.activeTitle,
            duration: recording.durationSeconds ?? 0,
            isFavorite: true,
            sourceRecordingId: recording.id,
            uploaderName: recording.uploaderName,
            originalDate: recording.createdAt
        )
    }

    private func unsaveCurrentRecording() {
        guard let source = playbackSource else { return }
        // Find the community recording ID — either from a .community source or a saved .local
        let communityId: UUID?
        switch source {
        case .community(let r): communityId = r.id
        case .local(let r): communityId = r.sourceRecordingId
        }
        guard let id = communityId else { return }
        let quoteHash = RecordingService.shared.hashQuoteText(viewModel.activeText)
        if let localCopy = localRecordingStore.recordings(forHash: quoteHash)
            .first(where: { $0.sourceRecordingId == id }) {
            localRecordingStore.deleteRecording(localCopy)
            // Switch back to the community source if available
            if let communityRec = communityRecordings.first(where: { $0.id == id }) {
                playbackSource = .community(communityRec)
            }
        }
    }

    private func isCurrentRecordingSaved() -> Bool {
        guard let source = playbackSource else { return false }
        switch source {
        case .community(let r):
            let quoteHash = RecordingService.shared.hashQuoteText(viewModel.activeText)
            return localRecordingStore.recordings(forHash: quoteHash)
                .contains { $0.sourceRecordingId == r.id }
        case .local(let r):
            return r.sourceRecordingId != nil
        }
    }

    private func flagCurrentRecording() {
        guard let source = playbackSource,
              let recording = source.communityRecording else { return }
        Task {
            try? await RecordingService.shared.flagRecording(
                recordingId: recording.id,
                reason: playbackFlagReason
            )
        }
        playbackFlagReason = ""
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = playbackPlayer {
                playbackCurrentTime = player.currentTime
                playbackDuration = player.duration
            }
        }
    }

    // MARK: - Recording Methods

    private func toggleRecordingPreview() {
        if isPreviewPlaying {
            previewPlayer?.pause()
            isPreviewPlaying = false
            previewTimer?.invalidate()
            return
        }

        if let player = previewPlayer {
            player.play()
            isPreviewPlaying = true
            startPreviewTimer()
            return
        }

        guard let data = recorder.getRecordingData() else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(data: data)
            player.delegate = RecitationPlaybackDelegate.shared
            RecitationPlaybackDelegate.shared.onFinish = {
                Task { @MainActor in
                    self.isPreviewPlaying = false
                    self.previewTimer?.invalidate()
                }
            }
            player.play()
            previewPlayer = player
            previewDuration = player.duration
            isPreviewPlaying = true
            startPreviewTimer()
        } catch {
            print("[RecitationScreen] Preview error: \(error)")
        }
    }

    private func stopRecordingPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPreviewPlaying = false
        previewTimer?.invalidate()
        previewCurrentTime = 0
        previewDuration = 0
    }

    private func startPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = self.previewPlayer, self.isPreviewPlaying {
                self.previewCurrentTime = player.currentTime
                self.previewDuration = player.duration
            }
        }
    }

    private func saveNewRecording(name: String) async {
        guard let data = recorder.getRecordingData() else { return }

        // Enforce 3-recording cap for free users
        guard purchaseService.canAddRecording(recordingStore: localRecordingStore) else {
            await MainActor.run { showPaywall = true }
            return
        }

        let quoteHash = RecordingService.shared.hashQuoteText(viewModel.activeText)

        // Always save locally
        localRecordingStore.saveRecording(
            audioData: data,
            quoteTextHash: quoteHash,
            quoteTitle: viewModel.activeTitle,
            duration: recorder.recordingDuration,
            name: name,
            quoteId: quote.id,
            language: viewModel.activeLanguage ?? viewModel.primaryLanguageCode
        )

        if shareWithCommunity {
            // Check if user already has a recording for this quote+language
            let lang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
            let existing = await RecordingService.shared.fetchMyRecording(forHash: quoteHash, language: lang)
            if existing != nil {
                // Store context and show replace confirmation
                existingRecording = existing
                showReplaceRecordingAlert = true
            } else {
                await performUpload()
            }
        }

        stopRecordingPreview()
        recorder.discardRecording()
        isRecordingMode = false

        // Auto-select the newly saved recording
        let localRecs = localRecordingStore.recordings(forHash: quoteHash)
        if let newest = localRecs.last {
            selectRecording(.local(newest))
        }
    }

    private func performUpload() async {
        let quoteHash = RecordingService.shared.hashQuoteText(viewModel.activeText)
        // Get audio data from the most recently saved local recording
        let localRecs = localRecordingStore.recordings(forHash: quoteHash)
        guard let newest = localRecs.last,
              let data = localRecordingStore.loadAudioData(for: newest) else { return }

        isUploading = true
        do {
            let filePath = try await RecordingService.shared.uploadAudio(data: data)
            let recording = try await RecordingService.shared.createRecording(
                quoteTextHash: quoteHash,
                quoteTitle: viewModel.activeTitle,
                uploaderName: recordingName,
                filePath: filePath,
                durationSeconds: newest.durationSeconds,
                language: newest.language
            )
            // Replace existing in local list or insert
            if let existingIdx = communityRecordings.firstIndex(where: { $0.userId == AuthService.shared.currentUser?.id && $0.language == newest.language }) {
                communityRecordings[existingIdx] = recording
            } else {
                communityRecordings.insert(recording, at: 0)
            }
        } catch {
            print("[RecitationScreen] Upload error: \(error)")
        }
        isUploading = false
    }

    private func formatPlaybackTime(_ seconds: TimeInterval) -> String {
        let isNegative = seconds < 0
        let absSeconds = abs(seconds)
        let mins = Int(absSeconds) / 60
        let secs = Int(absSeconds) % 60
        let prefix = isNegative ? "-" : ""
        return String(format: "%@%d:%02d", prefix, mins, secs)
    }

    // MARK: - Swipe Navigation

    private enum SwipeDirection { case forward, backward }

    private func navigateToQuote(direction: SwipeDirection) {
        let siblings = siblingQuotes
        guard let currentIndex = currentIndexInSiblings, siblings.count > 1 else { return }

        let nextIndex: Int
        switch direction {
        case .forward:
            nextIndex = (currentIndex + 1) % siblings.count
        case .backward:
            nextIndex = (currentIndex - 1 + siblings.count) % siblings.count
        }

        let nextQuote = siblings[nextIndex]

        // Slide out in swipe direction, then slide in from opposite side
        let slideOut: CGFloat = direction == .forward ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            swipeOffset = slideOut
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.reloadQuote(nextQuote)
            // Position off-screen on opposite side, then animate in
            swipeOffset = -slideOut
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                swipeOffset = 0
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))

                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * viewModel.progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Word Display

    private func wordDisplay(proxy: ScrollViewProxy, flatTopCorners: Bool = false) -> some View {
        let cornerShape = UnevenRoundedRectangle(
            topLeadingRadius: flatTopCorners ? 0 : 16,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: flatTopCorners ? 0 : 16
        )

        return VStack(spacing: 12) {
            FlowLayout(spacing: 8) {
                ForEach(Array(viewModel.words.enumerated()), id: \.offset) { index, wordState in
                    WordView(
                        word: wordState.word,
                        state: wordState.state,
                        isCurrentWord: index == viewModel.currentPosition,
                        fontSize: settingsStore.fontSize.pointSize,
                        isVisible: viewModel.shouldShowWord(at: index),
                        displayMode: viewModel.wordDisplayMode(at: index),
                        hideProgress: false,
                        isFlashing: index == viewModel.flashingWordIndex,
                        onTap: viewModel.isWordTappable(at: index)
                            ? { viewModel.tapWord(at: index, countAsHint: !isPlaybackMode) }
                            : nil
                    )
                    .id(index)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(cornerShape)
            .spotlightAnchor("wordGrid")

        }
        .onChange(of: viewModel.currentPosition) { _, newPosition in
            withAnimation {
                proxy.scrollTo(max(0, newPosition - 2), anchor: .center)
            }
        }
    }

    // MARK: - Mode Picker

    private enum PickerSegment: Hashable {
        case mode(MemorizationMode)
        case music
    }

    private enum PickerTab: Hashable {
        case yours, community
    }

    private var modePickerSegments: [(PickerSegment, String)] {
        [
            (.mode(.voice), MemorizationMode.voice.icon),
            (.mode(.typing), MemorizationMode.typing.icon),
            (.mode(.multipleChoice), MemorizationMode.multipleChoice.icon),
            (.music, "music.note"),
        ]
    }

    private var modePickerSelectedIndex: Int {
        let current: PickerSegment = isPlaybackMode ? .music : .mode(viewModel.currentMode)
        return modePickerSegments.firstIndex(where: { $0.0 == current }) ?? 0
    }

    private var modePicker: some View {
        GeometryReader { geo in
            let segmentCount = CGFloat(modePickerSegments.count)
            let internalPadding: CGFloat = 3
            let spacing: CGFloat = 2
            let totalSpacing = spacing * (segmentCount - 1)
            let availableWidth = geo.size.width - internalPadding * 2
            let segmentWidth = (availableWidth - totalSpacing) / segmentCount
            let selectedX = internalPadding + CGFloat(modePickerSelectedIndex) * (segmentWidth + spacing)

            ZStack(alignment: .leading) {
                // Sliding selection indicator
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                    .frame(width: segmentWidth, height: geo.size.height - internalPadding * 2)
                    .offset(x: selectedX)
                    .frame(maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: modePickerSelectedIndex)

                // Buttons
                HStack(spacing: spacing) {
                    ForEach(Array(modePickerSegments.enumerated()), id: \.offset) { index, item in
                        let (segment, icon) = item
                        Button {
                            switch segment {
                            case .mode(let mode):
                                exitPlaybackMode()
                                viewModel.switchMode(to: mode)
                            case .music:
                                viewModel.pause()
                                isPlaybackMode = true
                                autoSelectOrShowPicker()
                            }
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(index == modePickerSelectedIndex ? .primary : .secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(internalPadding)
            }
        }
        .frame(height: 42)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .disabled(viewModel.showSplitPopup)
        .spotlightAnchor("modeTabs")
    }

    // MARK: - Reveal Slider

    /// Full display name for a language code (e.g. "es" → "Spanish")
    private static func languageDisplayName(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    /// Adaptive text color for readability on the language pill background
    private static func languageTextColor(_ code: String) -> Color {
        switch code {
        case "es", "it", "de", "pt": return .black   // light backgrounds
        default:                      return .white   // dark backgrounds (en blue, fr red, ar green, etc.)
        }
    }

    /// Flag-inspired color for a language code
    private static func languageColor(_ code: String) -> Color {
        switch code {
        case "en": return .blue
        case "es": return .yellow
        case "fr": return .red
        case "it": return .green
        case "de": return .orange
        case "pt": return .green
        case "ar": return .green
        default:   return .indigo
        }
    }

    /// Greyed-out language pill for recording playback (shows recording's language, not interactive)
    private var playbackLanguagePill: some View {
        let recordingLang: String = {
            switch playbackSource {
            case .local(let r): return r.language
            case .community(let r): return r.language
            case nil: return viewModel.activeLanguage ?? viewModel.primaryLanguageCode
            }
        }()
        return HStack(spacing: 3) {
            Image(systemName: "globe")
                .font(.caption2)
            Text(recordingLang.uppercased())
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray3))
        .cornerRadius(12)
    }

    /// Language pill for recording mode — interactive before recording, greyed out during
    @ViewBuilder
    private func recordingLanguagePill(interactive: Bool) -> some View {
        let currentLang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
        if interactive {
            let primary = viewModel.primaryLanguageCode
            Menu {
                Button {
                    viewModel.switchLanguage(nil)
                } label: {
                    Label(Self.languageDisplayName(primary), systemImage: viewModel.activeLanguage == nil ? "checkmark.circle.fill" : "circle")
                }
                ForEach(viewModel.availableLanguages, id: \.self) { lang in
                    Button {
                        viewModel.switchLanguage(lang)
                    } label: {
                        Label(Self.languageDisplayName(lang), systemImage: viewModel.activeLanguage == lang ? "checkmark.circle.fill" : "circle")
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "globe")
                        .font(.caption2)
                    Text(currentLang.uppercased())
                        .font(.caption.bold())
                }
                .foregroundColor(Self.languageTextColor(currentLang))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Self.languageColor(currentLang))
                .cornerRadius(12)
            }
        } else {
            HStack(spacing: 3) {
                Image(systemName: "globe")
                    .font(.caption2)
                Text(currentLang.uppercased())
                    .font(.caption.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray3))
            .cornerRadius(12)
        }
    }

    /// Interactive language pill for TTS — switches language, quote text, and TTS voice
    private var ttsLanguagePill: some View {
        let currentLang = viewModel.activeLanguage ?? viewModel.primaryLanguageCode
        let primary = viewModel.primaryLanguageCode
        return Menu {
            Button {
                guard purchaseService.canUseTTS else { showPaywall = true; return }
                viewModel.switchLanguage(nil)
                let lang = viewModel.primaryLanguageCode
                tts.stop()
                tts.speak(viewModel.activeText, language: lang)
            } label: {
                Label(Self.languageDisplayName(primary), systemImage: viewModel.activeLanguage == nil ? "checkmark.circle.fill" : "circle")
            }
            ForEach(viewModel.availableLanguages, id: \.self) { lang in
                Button {
                    guard purchaseService.canUseTTS else { showPaywall = true; return }
                    viewModel.switchLanguage(lang)
                    tts.stop()
                    tts.speak(viewModel.activeText, language: lang)
                } label: {
                    Label(Self.languageDisplayName(lang), systemImage: viewModel.activeLanguage == lang ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "globe")
                    .font(.caption2)
                Text(currentLang.uppercased())
                    .font(.caption.bold())
            }
            .foregroundColor(Self.languageTextColor(currentLang))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Self.languageColor(currentLang))
            .cornerRadius(12)
        }
    }

    /// Language toggle pill — tapping opens a menu to pick any available language
    private var languageTogglePill: some View {
        let primary = viewModel.primaryLanguageCode
        return Menu {
            Button {
                viewModel.switchLanguage(nil)
            } label: {
                Label(Self.languageDisplayName(primary), systemImage: viewModel.activeLanguage == nil ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(Self.languageColor(primary))
            }
            ForEach(viewModel.availableLanguages, id: \.self) { lang in
                Button {
                    viewModel.switchLanguage(lang)
                } label: {
                    Label(Self.languageDisplayName(lang), systemImage: viewModel.activeLanguage == lang ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(Self.languageColor(lang))
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "globe")
                    .font(.caption2)
                Text(viewModel.activeLanguage?.uppercased() ?? primary.uppercased())
                    .font(.caption.bold())
            }
            .foregroundColor(Self.languageTextColor(viewModel.activeLanguage ?? primary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Self.languageColor(viewModel.activeLanguage ?? primary))
            .cornerRadius(12)
            .spotlightAnchor("languageButton")
        }
    }

    private var revealSlider: some View {
        let isLetterMode = viewModel.currentMode == .firstLetter || (viewModel.isFirstLetterToggle && viewModel.currentMode == .voice)
        return LevelRevealSlider(
            level: Binding(
                get: { viewModel.displayLevel },
                set: { newLevel in
                    viewModel.setLevel(newLevel)
                }
            ),
            isLetterMode: isLetterMode
        )
        .spotlightAnchor("revealSlider")
        .padding(.horizontal, 4)
        .disabled(viewModel.isMasterMode)
        .opacity(viewModel.isMasterMode ? 0.3 : 1)
    }

    // MARK: - Master Crown Button

    private var masterCrownButton: some View {
        Button {
            if viewModel.isMasterMode {
                viewModel.exitMasterMode()
            } else {
                showMasterInfoPopup = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 44, height: 44)

                LiquidWaveShape(
                    progress: micFillProgress,
                    waveHeight: 2,
                    phase: liquidWavePhase
                )
                .fill(Color.yellow)
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isMasterMode ? .black : .white)
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .spotlightAnchor("crownButton")
        }
    }

    /// First letter toggle button (left of mic) — shows streak counter in master mode
    private var infoOrStreakButton: some View {
        Button {
            if viewModel.isMasterMode { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                viewModel.toggleFirstLetterMode()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isFirstLetterToggle && !viewModel.isMasterMode
                          ? Color.indigo.opacity(0.8)
                          : Color(.systemGray4))
                    .frame(width: 44, height: 44)

                LiquidWaveShape(
                    progress: micFillProgress,
                    waveHeight: 2,
                    phase: liquidWavePhase
                )
                .fill(Color.yellow)
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                // First letter icon — fades out in master mode
                Image(systemName: "a.square")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .opacity(viewModel.isMasterMode ? 0 : 1)
                    .scaleEffect(viewModel.isMasterMode ? 0.5 : 1)

                // Streak text — fades in for master mode
                Text(String(localized: "\(viewModel.quote.masteryStreak)/3", comment: "Mastery streak progress X/3"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .opacity(viewModel.isMasterMode ? 1 : 0)
                    .scaleEffect(viewModel.isMasterMode ? 1 : 0.5)
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .animation(.easeInOut(duration: 0.35), value: viewModel.isMasterMode)
        }
        .allowsHitTesting(!viewModel.isMasterMode)
        .spotlightAnchor("firstLetterButton")
    }

    // MARK: - Spotlight Tutorial Steps

    private var spotlightTutorialSteps: [TutorialStep] {
        [
            TutorialStep(anchorId: "modeTabs", text: "Switch between **Voice**, **Typing**, and other practice modes", position: .below, cornerRadius: 9),
            TutorialStep(anchorId: "revealSlider", text: "Slide to **reveal or hide** words as you memorize", position: .below),
            TutorialStep(anchorId: "wordGrid", text: "Tap any **hidden word** to peek — it counts as a hint", position: .below, cornerRadius: 16),
            TutorialStep(anchorId: "firstLetterButton", text: "Toggle **first letter mode** — shows just the first letter of each word", position: .above, padding: 4, cornerRadius: 22),
            TutorialStep(anchorId: "crownButton", text: "Enter **mastery mode** — get 3 perfect recitations in a row", position: .above, padding: 4, cornerRadius: 22),
            TutorialStep(anchorId: "languageButton", text: "Practice in a **different language**", position: .below, padding: 4, cornerRadius: 12),
            TutorialStep(anchorId: "infoBar", text: "Track your **correct words**, **mistakes**, and **hints** used", position: .above, cornerRadius: 36),
            TutorialStep(anchorId: "micButton", text: "Tap to **start reciting** — speak loud and clear!", position: .above, padding: 4, cornerRadius: 40),
        ]
    }

    // MARK: - Recitation Tutorial Popup

    private var recitationTutorialPopup: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showRecitationTutorial = false
                    tutorialStore.completeTip(TipDefinition.recitationIntro.id)
                }

            VStack(spacing: 16) {
                BrainCharacterView(
                    character: .speech,
                    size: 140
                )
                .offset(x: 12)

                Text("Speak Clearly")
                    .font(.title3.bold())

                Text("Tap the **microphone button** to start, then recite **loud and clear**.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                Button {
                    showRecitationTutorial = false
                    tutorialStore.completeTip(TipDefinition.recitationIntro.id)
                } label: {
                    HStack {
                        Text("Got it")
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .padding(.horizontal)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }

    private func tutorialStep(number: String, icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.indigo)
                .frame(width: 28)
            Text(.init(text))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var masterInfoPopup: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showMasterInfoPopup = false
                }

            VStack(spacing: 16) {
                BrainCharacterView(
                    character: .random(from: BrainCharacter.success),
                    size: 120
                )

                Text("Master This Quote")
                    .font(.title3.bold())

                Text("Get **3 consecutive** perfect recitations with no hints or reveals.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Crown progress
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { i in
                        CrownFillView(
                            fillLevel: i < viewModel.quote.masteryStreak ? 1.0 : 0.0,
                            size: 36
                        )
                    }
                }

                Text("Miss one and you start over.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    showMasterInfoPopup = false
                    triggerLiquidFillAnimation()
                    viewModel.enterMasterMode()
                } label: {
                    HStack {
                        Text("Let's Go")
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .padding(.horizontal)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Split/Merge Overlay

    private var splitMergeOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showSplitOverlay = false }
                }

            VStack(spacing: 16) {
                Text("Quote Splitting")
                    .font(.headline)

                if viewModel.isSplit {
                    VStack(spacing: 10) {
                        Button {
                            viewModel.mergeChunks(at: viewModel.activeChunkIndex - 1)
                            withAnimation(.easeInOut(duration: 0.2)) { showSplitOverlay = false }
                        } label: {
                            HStack {
                                Text("Merge with previous part")
                                Image(systemName: "arrow.merge")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(viewModel.activeChunkIndex <= 0)

                        Button {
                            viewModel.unsplit()
                            withAnimation(.easeInOut(duration: 0.2)) { showSplitOverlay = false }
                        } label: {
                            HStack {
                                Text("Back to full quote")
                                Image(systemName: "text.quote")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                } else {
                    let wordsPerSection = max(1, viewModel.quote.wordCount / splitCount)

                    VStack(spacing: 16) {
                        Text("How many parts?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            Button {
                                if splitCount > 2 { splitCount -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.title2.bold())
                                    .foregroundColor(splitCount > 2 ? .primary : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(10)
                            }

                            Text("\(splitCount)")
                                .font(.system(size: 42, weight: .bold))
                                .monospacedDigit()

                            Button {
                                if splitCount < 10 { splitCount += 1 }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundColor(splitCount < 10 ? .primary : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(10)
                            }
                        }

                        Text(String(localized: "~\(wordsPerSection) words each", comment: "Approximate words per section"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button {
                            viewModel.splitActiveChunk(into: splitCount)
                            withAnimation(.easeInOut(duration: 0.2)) { showSplitOverlay = false }
                        } label: {
                            HStack {
                                Text("Split")
                                Image(systemName: "scissors")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    }
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Liquid Fill Animation

    private func triggerLiquidFillAnimation() {
        // Reset state
        liquidFillProgress = 0
        micFillProgress = 0
        liquidOpacity = 1
        liquidWavePhase = 0
        showLiquidFill = true

        // Continuous wave motion
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            liquidWavePhase = .pi * 2
        }

        // Fill mic first (faster, smaller)
        withAnimation(.easeInOut(duration: 0.5)) {
            micFillProgress = 1.15
        }

        // Fill background slightly after mic starts
        withAnimation(.easeInOut(duration: 0.7)) {
            liquidFillProgress = 1.15
        }

        // After fill completes, soften for comfortable reading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            withAnimation(.easeOut(duration: 0.5)) {
                liquidOpacity = isDark ? 0.85 : 0.6
            }
        }

    }

    private func triggerLiquidDrainAnimation() {
        // Drain both down
        withAnimation(.easeInOut(duration: 0.6)) {
            liquidFillProgress = 0
            micFillProgress = 0
            liquidOpacity = 1
        }

        // Clean up after drain completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            showLiquidFill = false
            liquidWavePhase = 0
            liquidOpacity = 1
        }
    }

    // MARK: - Mistake Popup

    @State private var mistakeCharacters: [Int: BrainCharacter] = [:]

    private var resultsSheet: some View {
        // In master mode with split, show aggregate stats across all chunks
        let session = (viewModel.isSplit && !viewModel.isMasterMode) ? viewModel.createChunkSession() : viewModel.createSession()
        let usedChars = Set(mistakeCharacters.values)
        return ResultsView(
            session: session,
            quote: viewModel.quote,
            onDismiss: {
                if isTutorialMode {
                    dismiss()
                    return
                }
                if viewModel.isSplit {
                    DispatchQueue.main.async {
                        viewModel.saveSplitState()
                        if !viewModel.advanceToNextChunk() {
                            dismiss()
                        }
                    }
                } else {
                    dismiss()
                }
            },
            onRetry: {
                if viewModel.isMasterMode {
                    viewModel.reset(recalculateReveal: false)
                    viewModel.enterMasterMode()
                } else {
                    viewModel.reset(recalculateReveal: true)
                }
            },
            isMasterMode: viewModel.isMasterMode,
            usedMistakeCharacters: usedChars,
            onMasteryResult: viewModel.isMasterMode ? { passed in
                viewModel.recordMasteryResult(passed: passed)
            } : nil,
            activeLanguage: viewModel.activeLanguage,
            isTutorialMode: isTutorialMode
        )
        .presentationDetents([.fraction(0.68)])
    }

    private func mistakeCharacter(for index: Int?) -> BrainCharacter {
        guard let idx = index else {
            return .random(from: BrainCharacter.mistakes)
        }
        if let existing = mistakeCharacters[idx] {
            return existing
        }
        let used = Set(mistakeCharacters.values)
        let available = BrainCharacter.mistakes.filter { !used.contains($0) }
        let newChar = available.randomElement() ?? .random(from: BrainCharacter.mistakes)
        DispatchQueue.main.async { mistakeCharacters[idx] = newChar }
        return newChar
    }

    private func mistakeDisputePopup(spokenWord: String) -> some View {
        let expectedWord = viewModel.tappedMistakeIndex.flatMap { idx in
            idx < viewModel.words.count ? viewModel.words[idx].word : nil
        }
        let character = mistakeCharacter(for: viewModel.tappedMistakeIndex)

        return ZStack {
            // Dimmed background — tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissMistakePopup()
                }

            VStack(spacing: 16) {
                BrainCharacterView(character: character, size: 150)

                (Text(String(localized: "I heard you say "))
                    .foregroundColor(.secondary)
                + Text("\"\(spokenWord)\"")
                    .font(.headline)
                    .foregroundColor(.red))

                Button {
                    viewModel.overrideMistake()
                } label: {
                    HStack {
                        Text(String(localized: "No, I said the right word"))
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
        .onAppear {
            // Assign a stable unique sprite per word index
            if let idx = viewModel.tappedMistakeIndex, mistakeCharacters[idx] == nil {
                let used = Set(mistakeCharacters.values)
                let available = BrainCharacter.mistakes.filter { !used.contains($0) }
                mistakeCharacters[idx] = available.randomElement() ?? .random(from: BrainCharacter.mistakes)
            }
        }
    }

    // MARK: - Tutorial Control Bar (simplified — no crown, no info, no reset)

    private var tutorialControlBar: some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                if viewModel.currentMode == .typing {
                    if viewModel.isFirstLetterToggle {
                        Text("Type the first letter of each word in")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Complete the blanks in the phrase")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    Text("\"\(quote.text)\"")
                        .font(.callout.bold().italic())
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap the microphone and try saying")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("\"\(quote.text)\"")
                        .font(.callout.bold().italic())
                        .foregroundColor(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            if viewModel.currentMode == .typing {
                TypingInputField(
                    text: $viewModel.typingInput,
                    onSubmitWord: { viewModel.submitTypingInput() },
                    isMasterMode: false,
                    isFirstLetterMode: viewModel.isFirstLetterToggle
                )
                .padding(.horizontal)
            } else {
                Button {
                    if viewModel.isListening {
                        viewModel.pause()
                    } else {
                        viewModel.start()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 80, height: 80)
                        Group {
                            if viewModel.isListening {
                                VoiceWaveformView(level: viewModel.audioLevel, showPause: viewModel.showPauseIcon)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 34))
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
            }

            // Dark stats pill (no INFO or RESET in tutorial)
            HStack(spacing: 0) {
                Spacer()

                HStack(spacing: 20) {
                    VStack(spacing: 3) {
                        Text("\(viewModel.correctCount)")
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.green)
                            .frame(height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green.opacity(0.7))
                            .frame(height: 14)
                    }
                    .frame(width: 40)

                    VStack(spacing: 3) {
                        Text("\(viewModel.mistakeCount)")
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.red)
                            .frame(height: 24)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red.opacity(0.7))
                            .frame(height: 14)
                    }
                    .frame(width: 40)

                    VStack(spacing: 3) {
                        Text("\(viewModel.hintCount)")
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.yellow)
                            .frame(height: 24)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow.opacity(0.7))
                            .frame(height: 14)
                    }
                    .frame(width: 40)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color(hex: 0x333333))
            )
            .padding(.horizontal, 8)

            Spacer().frame(height: 0)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 8) {
            // MC choices above everything
            if viewModel.currentMode == .multipleChoice {
                multipleChoiceGrid
            }

            // Input area above the pill
            Group {
                if viewModel.currentMode == .typing {
                    // Typing mode: info/streak left, text input center, crown right
                    HStack(spacing: 12) {
                        infoOrStreakButton
                        TypingInputField(
                            text: $viewModel.typingInput,
                            onSubmitWord: { viewModel.submitTypingInput() },
                            isMasterMode: viewModel.isMasterMode,
                            isFirstLetterMode: viewModel.isFirstLetterToggle
                        )
                        masterCrownButton
                    }
                    .padding(.horizontal)
                } else if viewModel.currentMode != .multipleChoice {
                    // Voice/first-letter: left button, mic centered, crown right
                    HStack(spacing: 16) {
                        // Left: streak counter in master mode, info button otherwise
                        infoOrStreakButton

                        // Mic button — always centered, blue with yellow liquid fill in master mode
                        Button {
                            if viewModel.isListening {
                                viewModel.pause()
                            } else {
                                viewModel.start()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 80, height: 80)

                                // Yellow liquid fill overlay for master mode
                                LiquidWaveShape(
                                    progress: micFillProgress,
                                    waveHeight: 4,
                                    phase: liquidWavePhase
                                )
                                .fill(Color.yellow)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())

                                Group {
                                    if viewModel.isListening {
                                        VoiceWaveformView(level: viewModel.audioLevel, showPause: viewModel.showPauseIcon)
                                    } else {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 34))
                                    }
                                }
                                .foregroundColor(.white)
                            }
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                            .spotlightAnchor("micButton")
                        }

                        // Crown button
                        masterCrownButton
                    }
                }
            }
            .frame(height: 80, alignment: .bottom)

            // Dark pill
            HStack(spacing: 0) {
                // Left: Info
                Button {
                    showQuoteAccuracy = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                        Text("INFO")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 50)
                }

                Spacer()

                // Center: Stats
                HStack(spacing: 20) {
                    VStack(spacing: 3) {
                        Text("\(viewModel.correctCount)")
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.green)
                            .frame(height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green.opacity(0.7))
                            .frame(height: 14)
                    }
                    .frame(width: 40)

                    VStack(spacing: 3) {
                        Text("\(viewModel.mistakeCount)")
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.red)
                            .frame(height: 24)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red.opacity(0.7))
                            .frame(height: 14)
                    }
                    .frame(width: 40)

                    VStack(spacing: 3) {
                        Text("\(viewModel.hintCount)")
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.yellow)
                            .frame(height: 24)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow.opacity(0.7))
                            .frame(height: 14)
                    }
                    .frame(width: 40)
                }

                Spacer()

                // Right: Reset
                Button {
                    viewModel.reset()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18))
                        Text("RESET")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 50)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color(hex: 0x333333))
            )
            .padding(.horizontal, 8)
            .spotlightAnchor("infoBar")
            .offset(y: viewModel.isMasterMode ? 60 : 0)
            .animation(.easeInOut(duration: 0.4), value: viewModel.isMasterMode)

            Spacer().frame(height: 0)
        }
        .offset(y: viewModel.isMasterMode ? 65 : 0)
        .animation(.easeInOut(duration: 0.4), value: viewModel.isMasterMode)
    }

    // MARK: - Multiple Choice Grid

    private var multipleChoiceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(viewModel.mcChoices.enumerated()), id: \.offset) { index, word in
                Button {
                    viewModel.selectChoice(at: index)
                } label: {
                    Text(word)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.mcWrongIndex == index ? Color.red : Color.blue)
                        )
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func previewText(chunk: ChunkState, index: Int) -> String {
        let wordStrings = chunk.words.map(\.word)
        let isDirectlyBefore = index == viewModel.activeChunkIndex - 1

        if isDirectlyBefore {
            // Show trailing words with leading ellipsis
            let preview = Array(wordStrings.suffix(8))
            return (wordStrings.count > 8 ? "..." : "") + preview.joined(separator: " ")
        } else {
            // All other chunks: show leading words with trailing ellipsis
            let preview = Array(wordStrings.prefix(8))
            return preview.joined(separator: " ") + (wordStrings.count > 8 ? "..." : "")
        }
    }

    // MARK: - Split Popup

    private var splitPopup: some View {
        ZStack {
            // Dimmed background — tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showSplitPopup = false
                }

            Group {
                if viewModel.isSplit {
                    mergeModalView
                } else {
                    initialSplitView
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    private var initialSplitView: some View {
        let sourceWordCount = viewModel.quote.wordCount
        let wordsPerSection = max(1, sourceWordCount / viewModel.splitCount)

        return VStack(spacing: 16) {
            Text("How many parts?")
                .font(.headline)

            HStack(spacing: 20) {
                Button {
                    if viewModel.splitCount > 2 { viewModel.splitCount -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.bold())
                        .foregroundColor(viewModel.splitCount > 2 ? .primary : .secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                }

                Text("\(viewModel.splitCount)")
                    .font(.system(size: 42, weight: .bold))
                    .monospacedDigit()

                Button {
                    if viewModel.splitCount < 10 { viewModel.splitCount += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(viewModel.splitCount < 10 ? .primary : .secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                }
            }

            Text(String(localized: "~\(wordsPerSection) words each", comment: "Approximate words per section"))
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                viewModel.splitActiveChunk(into: viewModel.splitCount)
            } label: {
                HStack {
                    Text("Split")
                    Image(systemName: "scissors")
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(24)
    }

    private var mergeModalView: some View {
        let isFirst = viewModel.activeChunkIndex <= 0

        return VStack(spacing: 16) {
            Text("Ready to combine?")
                .font(.headline)

            VStack(spacing: 10) {
                // Merge with previous part
                Button {
                    viewModel.mergeChunks(at: viewModel.activeChunkIndex - 1)
                    viewModel.showSplitPopup = false
                } label: {
                    HStack {
                        Text("Only with previous part")
                        Image(systemName: "arrow.merge")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(isFirst)

                // Merge all back into full quote
                Button {
                    viewModel.unsplit()
                    viewModel.showSplitPopup = false
                } label: {
                    HStack {
                        Text("Back to full quote")
                        Image(systemName: "text.quote")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding(24)
    }

    // MARK: - Split Word Display

    private func splitWordDisplay(chunks: [ChunkState], proxy: ScrollViewProxy) -> some View {
        let active = viewModel.activeChunkIndex
        let maxVisible = 2

        let peeksAbove = Array(max(0, active - maxVisible)..<active)
        let peeksBelow: [Int] = active + 1 < chunks.count
            ? Array((active + 1)...min(chunks.count - 1, active + maxVisible))
            : []

        return VStack(spacing: 4) {
            ForEach(peeksAbove, id: \.self) { index in
                peekContainer(chunk: chunks[index], index: index)
            }

            activeChunkContainer(chunk: chunks[active], index: active, proxy: proxy)

            ForEach(peeksBelow, id: \.self) { index in
                peekContainer(chunk: chunks[index], index: index)
            }
        }
    }

    private func activeChunkContainer(chunk: ChunkState, index: Int, proxy: ScrollViewProxy) -> some View {
        wordDisplay(proxy: proxy)
    }

    /// Get the accuracy for a chunk — checks persisted data first, then in-session completion
    private func chunkAccuracy(chunk: ChunkState, index: Int) -> Double? {
        // Persisted accuracy
        if let accuracies = viewModel.quote.chunkAccuracies,
           index < accuracies.count,
           accuracies[index] > 0 {
            return accuracies[index]
        }
        // In-session completion
        let totalWords = chunk.words.count
        let completedWords = chunk.words.filter { $0.state == .correct || $0.state == .incorrect }.count
        if completedWords >= totalWords && totalWords > 0 {
            return Double(max(0, totalWords - chunk.mistakes.count)) / Double(totalWords)
        }
        return nil
    }

    private func peekContainer(chunk: ChunkState, index: Int) -> some View {
        return Button {
            viewModel.switchToChunk(index)
        } label: {
            HStack(spacing: 6) {
                Text(previewText(chunk: chunk, index: index))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                if let accuracy = chunkAccuracy(chunk: chunk, index: index) {
                    Text(String(format: "%.0f%%", accuracy * 100))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundColor(accuracy >= 0.9 ? .green : accuracy >= 0.7 ? .orange : .red)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

}

// MARK: - Voice Waveform View

struct VoiceWaveformView: View {
    let level: Float
    let showPause: Bool

    private let barCount = 5
    private let barWidth: CGFloat = 8
    private let barSpacing: CGFloat = 5
    private let minHeight: CGFloat = 11
    private let maxHeight: CGFloat = 53

    // Each bar gets a different scale factor for visual variety
    private let barScales: [CGFloat] = [0.5, 0.85, 1.0, 0.75, 0.45]

    var body: some View {
        ZStack {
            // Pause icon — visible after 2s of silence
            Image(systemName: "pause.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
                .opacity(showPause ? 1 : 0)
                .scaleEffect(showPause ? 1 : 0.5)

            // Waveform bars — visible when voice detected or within 2s silence window
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    let scale = barScales[i]
                    let height = minHeight + (maxHeight - minHeight) * CGFloat(level) * scale
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(Color.white)
                        .frame(width: barWidth, height: max(minHeight, height))
                }
            }
            .frame(height: maxHeight)
            .opacity(showPause ? 0 : 1)
            .scaleEffect(showPause ? 0.5 : 1)
        }
        .animation(.easeInOut(duration: 0.6), value: showPause)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}

// MARK: - Level Reveal Slider

/// 3-step slider that looks like the old unified slider (eye icon, same track)
/// but snaps to 3 discrete levels. Level 1 (90%) on the RIGHT, level 3 (10%) on the LEFT.
struct LevelRevealSlider: View {
    @Binding var level: Int  // 1, 2, or 3
    var isLetterMode: Bool

    @State private var isDragging = false
    @State private var showNumber = false
    @State private var hideTimer: Timer?

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 26
    private let stepCount = 3

    /// Normalized thumb position 0-1 (level 1 = right, level 3 = left)
    private var normalizedPosition: CGFloat {
        CGFloat(stepCount - level) / CGFloat(stepCount - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - thumbSize
            let offsetX = normalizedPosition * width

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                // Thumb
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

                    if showNumber {
                        Text(thumbLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .transition(.opacity)
                    } else {
                        Image(systemName: "eye")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showNumber)
                .offset(x: offsetX)
                .animation(.easeInOut(duration: 0.35), value: normalizedPosition)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            if !isDragging {
                                isDragging = true
                                showNumber = true
                                hideTimer?.invalidate()
                            }
                            let raw = (drag.location.x - thumbSize / 2) / width
                            let clamped = min(max(raw, 0), 1)
                            // Invert: left = level 3, right = level 1
                            let snapped = stepCount - Int(round(clamped * CGFloat(stepCount - 1)))
                            let newLevel = min(max(snapped, 1), stepCount)
                            if newLevel != level {
                                level = newLevel
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            hideTimer?.invalidate()
                            hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showNumber = false
                                    }
                                }
                            }
                        }
                )
            }
            .frame(height: thumbSize)
        }
        .frame(height: 26)
    }

    private var thumbLabel: String {
        if isLetterMode {
            // Show letter count for this level
            switch level {
            case 1: return "3"
            case 2: return "2"
            case 3: return "1"
            default: return "3"
            }
        } else {
            // Show reveal percentage for this level
            switch level {
            case 1: return "90"
            case 2: return "50"
            case 3: return "20"
            default: return "90"
            }
        }
    }
}

// MARK: - Typing Input Field

struct TypingInputField: View {
    @Binding var text: String
    let onSubmitWord: () -> Void
    var isMasterMode: Bool = false
    var isFirstLetterMode: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(isFirstLetterMode ? String(localized: "Type the first letter...") : String(localized: "Type the word..."), text: $text)
            .textFieldStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isFocused)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isMasterMode ? Color.yellow : Color.blue, lineWidth: 3)
            )
            .onAppear {
                isFocused = true
            }
            .onChange(of: text) { _, newValue in
                if isFirstLetterMode {
                    // In first-letter mode, submit immediately on any character
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onSubmitWord()
                    }
                    return
                }
                if newValue.hasSuffix(" ") {
                    onSubmitWord()
                }
                if newValue.hasSuffix("\n") {
                    // Enter key — submit but keep focus
                    text = text.trimmingCharacters(in: .newlines)
                    onSubmitWord()
                }
            }
            .onSubmit {
                // Submit the word but immediately re-focus to keep keyboard open
                onSubmitWord()
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
    }
}

struct SteppedLetterSlider: View {
    @Binding var step: Int  // 0=hidden, 1-5=number of letters revealed

    @State private var showNumber = false
    @State private var hideTimer: Timer?

    private let maxStep = 5
    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - thumbSize
            let progress = width > 0 ? CGFloat(step) / CGFloat(maxStep) : 0
            let offsetX = progress * width

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                // Thumb with number / eye icon
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

                    if showNumber && step > 0 {
                        Text("\(step)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .transition(.opacity)
                    } else {
                        Image(systemName: "eye")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showNumber)
                .offset(x: offsetX)
                .animation(.easeInOut(duration: 0.35), value: step)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            showNumber = true
                            hideTimer?.invalidate()
                            let newX = gesture.location.x - thumbSize / 2
                            let rawStep = Int(round(newX / width * CGFloat(maxStep)))
                            step = min(max(rawStep, 0), maxStep)
                        }
                        .onEnded { _ in
                            hideTimer?.invalidate()
                            hideTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    showNumber = false
                                }
                            }
                        }
                )
            }
            .frame(height: thumbSize)
        }
        .frame(height: 26)
    }
}

// MARK: - Supporting Views

struct WordView: View {
    let word: String
    let state: WordState
    let isCurrentWord: Bool
    let fontSize: CGFloat
    var isVisible: Bool = true
    var displayMode: WordDisplayMode = .full
    var hideProgress: Bool = false
    var isFlashing: Bool = false
    var onTap: (() -> Void)? = nil

    /// Whether the word text should be visible in the current state
    private var showWordText: Bool {
        // Flashing hint — always show the word
        if isFlashing { return true }
        // Already spoken words are always revealed
        if state == .correct || state == .incorrect { return true }
        // In letter reveal modes, the letter count controls display — not isVisible
        switch displayMode {
        case .firstLetter, .firstTwoLetters, .letters: return false
        case .full: return true
        case .hidden: return false
        }
    }

    var body: some View {
        // Always use the actual word with consistent weight for sizing to prevent layout jumps
        Text(word)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundColor(showWordText ? foregroundColor : .clear)
            .overlay(alignment: .leading) {
                if !showWordText {
                    switch displayMode {
                    case .firstLetter:
                        firstLetterOverlay(revealCount: 1)
                    case .firstTwoLetters:
                        firstLetterOverlay(revealCount: 2)
                    case .letters(let count):
                        firstLetterOverlay(revealCount: count)
                    default:
                        // Hidden placeholder overlay
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            .background(Color(.systemGray5).cornerRadius(4))
                            .padding(.horizontal, -4)
                            .padding(.vertical, -2)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isFlashing ? Color.yellow.opacity(0.2) : backgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFlashing ? Color.yellow : (isCurrentWord ? Color.blue : Color.clear), lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.4), value: isFlashing)
            .onTapGesture {
                onTap?()
            }
    }

    private func firstLetterOverlay(revealCount: Int = 1) -> some View {
        // Separate trailing punctuation so it's always visible
        let chars = Array(word)
        var letterChars = chars
        var trailingPunctuation = ""
        while let last = letterChars.last, !last.isLetter && !last.isNumber {
            trailingPunctuation = String(last) + trailingPunctuation
            letterChars.removeLast()
        }

        let actualReveal = min(revealCount, letterChars.count)
        let revealed = String(letterChars.prefix(actualReveal))
        let blanks = String(repeating: "_", count: max(0, letterChars.count - actualReveal))

        return HStack(spacing: 0) {
            Text(revealed)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(foregroundColor)
            Text(blanks)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(.secondary.opacity(0.4))
            if !trailingPunctuation.isEmpty {
                Text(trailingPunctuation)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .fixedSize()
    }

    private var foregroundColor: Color {
        if hideProgress && (state == .correct || state == .incorrect) {
            return .primary
        }
        switch state {
        case .pending: return .primary.opacity(0.5)
        case .correct: return .green
        case .incorrect: return .red
        case .current: return .primary
        }
    }

    private var backgroundColor: Color {
        if !isVisible && state == .pending {
            return .clear
        }
        if hideProgress && (state == .correct || state == .incorrect) {
            return .clear
        }
        switch state {
        case .pending: return .clear
        case .correct: return .green.opacity(0.2)
        case .incorrect: return .red.opacity(0.2)
        case .current: return .blue.opacity(0.2)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposedWidth = proposal.replacingUnspecifiedDimensions().width
        let result = FlowResult(
            in: proposedWidth,
            subviews: subviews,
            spacing: spacing
        )
        return CGSize(width: proposedWidth, height: result.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    private let colors: [Color] = [.yellow, .orange, .red, .blue, Color(red: 1.0, green: 0.84, blue: 0.0)]

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let speed: CGFloat
        let rotation: Double
        let rotationSpeed: Double
        let color: Color
        let size: CGFloat
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let elapsed = time.truncatingRemainder(dividingBy: 4.0)
                    let yPos = particle.y + elapsed * particle.speed * 100
                    let xPos = particle.x + sin(elapsed * particle.rotationSpeed) * 30

                    guard yPos < size.height + 20 else { continue }

                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: xPos, y: yPos)
                    transform = transform.rotated(by: elapsed * particle.rotationSpeed)

                    let rect = CGRect(x: -particle.size / 2, y: -particle.size / 2,
                                     width: particle.size, height: particle.size * 0.6)
                    let path = Path(rect).applying(transform)
                    context.fill(path, with: .color(particle.color))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            particles = (0..<50).map { _ in
                ConfettiParticle(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: -100...(-10)),
                    speed: CGFloat.random(in: 1.5...3.5),
                    rotation: Double.random(in: 0...360),
                    rotationSpeed: Double.random(in: 1...4),
                    color: colors.randomElement()!,
                    size: CGFloat.random(in: 6...12)
                )
            }
        }
    }
}

// MARK: - Results View

struct ResultsView: View {
    let session: PracticeSession
    let quote: Quote
    let onDismiss: () -> Void
    let onRetry: () -> Void
    var isMasterMode: Bool = false
    var usedMistakeCharacters: Set<BrainCharacter> = []
    var onMasteryResult: ((Bool) -> Void)? = nil
    var activeLanguage: String? = nil
    var isTutorialMode: Bool = false

    private func dismiss() {
        AlertManager.shared.stopResultSound()
        onDismiss()
    }

    private func retry() {
        AlertManager.shared.stopResultSound()
        onRetry()
    }

    @EnvironmentObject var quoteStore: QuoteStore
    @State private var resultCharacter: BrainCharacter = .random(from: BrainCharacter.success)
    @State private var failCharacter: BrainCharacter = .mistake1 // placeholder, set in onAppear

    private var masteryPassed: Bool {
        session.accuracy >= 0.95
    }

    private var newStreak: Int {
        if masteryPassed {
            return min(3, quote.masteryStreak + 1)
        } else {
            return 0
        }
    }

    @State private var sessionRecorded = false
    @State private var showCrownSlam = false
    @State private var drainedCrowns: Int = 0  // How many crowns have been drained (animates 0→streak)
    @State private var drainScales: [CGFloat] = [1.0, 1.0, 1.0]

    var body: some View {
        ZStack {
            if isMasterMode {
                masterResultsBody
            } else {
                normalResultsBody
            }
        }
        .onAppear {
            // Pick a fail character that wasn't used in any per-word mistake popup
            let available = BrainCharacter.mistakes.filter { !usedMistakeCharacters.contains($0) }
            failCharacter = available.randomElement() ?? .random(from: BrainCharacter.mistakes)

            if !sessionRecorded && !isTutorialMode {
                quoteStore.recordSession(session)
                // Save the language the user practiced in as their preference
                if var updated = quoteStore.getQuote(byId: quote.id) {
                    let practicedLang = activeLanguage
                    if updated.lastPracticedLanguage != practicedLang {
                        updated.lastPracticedLanguage = practicedLang
                        quoteStore.updateQuote(updated)
                    }
                }
                sessionRecorded = true
            }
        }
    }

    // MARK: - Normal Results Body

    private var normalResultsBody: some View {
        VStack(spacing: 0) {
            // Accuracy number
            Text(String(format: "%.0f%%", session.accuracy * 100))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(scoreColor)
                .padding(.top, 24)
                .padding(.bottom, 14)

            // Score circle with character inside
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: session.accuracy)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                BrainCharacterView(
                    character: session.accuracy >= 0.7
                        ? resultCharacter
                        : failCharacter,
                    size: 120
                )
            }
            .frame(width: 160, height: 160)
            .padding(.bottom, 20)

            // Stats
            HStack(spacing: 32) {
                let tested = session.testedWords > 0 ? session.testedWords : session.totalWords

                VStack {
                    Text("\(tested)")
                        .font(.title3.bold())
                    Text("Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(max(0, tested - session.mistakes.count))")
                        .font(.title3.bold())
                        .foregroundColor(.green)
                    Text("Correct")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(session.mistakes.count)")
                        .font(.title3.bold())
                        .foregroundColor(.red)
                    Text("Mistakes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            }
            .padding(.bottom, 28)

            // Message
            Text(motivationalMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 28)

            // Buttons
            VStack(spacing: 10) {
                if !isTutorialMode {
                    Button {
                        retry()
                    } label: {
                        HStack {
                            Text("Try Again")
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Text(isTutorialMode ? String(localized: "Continue") : String(localized: "Done"))
                        Image(systemName: isTutorialMode ? "arrow.right" : "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(isTutorialMode ? .indigo : Color(.systemGray4))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Master Mode Results Body

    private var masterResultsBody: some View {
        ZStack {
            // Confetti layer for mastery (3/3)
            if newStreak >= 3 {
                ConfettiView()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                if newStreak >= 3 {
                    // MASTERED — celebration!
                    masteredLayout
                } else if masteryPassed {
                    // PASSED — show progress
                    masterPassedLayout
                } else {
                    // FAILED
                    masterFailedLayout
                }
            }
            .padding(.horizontal)
        }
    }

    private var masterFailedLayout: some View {
        let previousStreak = quote.masteryStreak

        return VStack(spacing: 12) {
            Spacer().frame(height: 16)

            BrainCharacterView(
                character: failCharacter,
                size: 140
            )

            Text("Not quite!")
                .font(.system(size: 28, weight: .bold))

            Text("Keep practicing!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Crown progress — shows previous crowns draining one by one
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { i in
                    CrownFillView(
                        fillLevel: i < previousStreak - drainedCrowns ? 1.0 : 0.0,
                        size: 36
                    )
                    .scaleEffect(drainScales[i])
                }
            }
            .padding(.top, 8)
            .onAppear {
                // Drain crowns one by one: bounce large → drain → shrink small
                for i in 0..<previousStreak {
                    let crownIndex = previousStreak - 1 - i  // drain from right to left
                    let baseDelay = 0.8 + Double(i) * 0.7

                    // 1. Bounce large
                    DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            drainScales[crownIndex] = 1.3
                        }
                    }
                    // 2. Drain the fill
                    DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 0.2) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            drainedCrowns = i + 1
                        }
                    }
                    // 3. Shrink down
                    DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            drainScales[crownIndex] = 0.85
                        }
                    }
                }
            }

            Spacer().frame(height: 8)

            VStack(spacing: 10) {
                Button {
                    onMasteryResult?(false)
                    retry()
                } label: {
                    HStack {
                        Text("Try Again")
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundColor(.black)

                Button {
                    onMasteryResult?(false)
                    dismiss()
                } label: {
                    HStack {
                        Text("Done")
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemGray4))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    @State private var animatedPassStreak: Int = 0
    @State private var crownBounceScale: CGFloat = 1.0

    private var masterPassedLayout: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 16)

            BrainCharacterView(
                character: resultCharacter,
                size: 140
            )

            Text("Nice!")
                .font(.system(size: 28, weight: .bold))

            // Crown progress row — animates the new crown filling in
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    let isNewCrown = index == newStreak - 1
                    CrownFillView(
                        fillLevel: index < animatedPassStreak ? 1.0 : 0.0,
                        size: 36
                    )
                    .scaleEffect(isNewCrown ? crownBounceScale : 1.0)
                }
            }
            .padding(.top, 8)
            .onAppear {
                // Start with previous crowns already filled
                animatedPassStreak = quote.masteryStreak
                // Animate the new crown filling in, then bounce
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        animatedPassStreak = newStreak
                    }
                }
                // Bounce large after fill completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                        crownBounceScale = 1.4
                    }
                }
                // Settle to slightly larger
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        crownBounceScale = 1.15
                    }
                }
            }

            Text(String(localized: "\(3 - newStreak) more to go!"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer().frame(height: 8)

            VStack(spacing: 10) {
                Button {
                    onMasteryResult?(true)
                    retry()
                } label: {
                    HStack {
                        Text("Try Again")
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundColor(.black)

                Button {
                    onMasteryResult?(true)
                    dismiss()
                } label: {
                    HStack {
                        Text("Done")
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemGray4))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var masteredLayout: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            // Crown slam animation
            Image(systemName: "crown.fill")
                .font(.system(size: 70))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.6), radius: 12)
                .scaleEffect(showCrownSlam ? 1.0 : 3.0)
                .offset(y: showCrownSlam ? 0 : -300)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCrownSlam)

            Text("Congratulations!")
                .font(.system(size: 30, weight: .bold))
                .opacity(showCrownSlam ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.6), value: showCrownSlam)

            Text("You've mastered this quote!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .opacity(showCrownSlam ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.7), value: showCrownSlam)

            // 3 filled golden crowns
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    CrownFillView(fillLevel: 1.0, size: 36)
                }
            }
            .padding(.top, 8)
            .opacity(showCrownSlam ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.8), value: showCrownSlam)

            Spacer().frame(height: 32)

            Button {
                onMasteryResult?(true)
                dismiss()
            } label: {
                HStack {
                    Text("Done")
                    Image(systemName: "checkmark")
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundColor(.black)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .opacity(showCrownSlam ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.9), value: showCrownSlam)
        }
        .onAppear {
            // Delay crown slam so confetti starts first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCrownSlam = true
            }
        }
    }


    private var scoreColor: Color {
        if session.accuracy >= 0.9 { return .green }
        if session.accuracy >= 0.7 { return .orange }
        return .red
    }

    private var motivationalMessage: String {
        if session.accuracy >= 0.95 { return String(localized: "Perfect! Outstanding recall!") }
        if session.accuracy >= 0.9 { return String(localized: "Excellent work! Almost perfect!") }
        if session.accuracy >= 0.8 { return String(localized: "Great job! Keep practicing!") }
        if session.accuracy >= 0.7 { return String(localized: "Good progress! You're getting there!") }
        if session.accuracy >= 0.5 { return String(localized: "Nice effort! Practice makes perfect!") }
        return String(localized: "Keep trying! Every attempt helps!")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(localized: "\(minutes):\(String(format: "%02d", seconds))", comment: "Duration in minutes:seconds format")
        }
        return String(localized: "\(seconds)s", comment: "Duration in seconds")
    }
}

/// Delegate to detect playback completion in RecitationScreen
private class RecitationPlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = RecitationPlaybackDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}

// MARK: - Liquid Wave Shape

/// A crown icon that fills/drains with a vertical liquid-style mask.
/// fillLevel 0 = empty outline, fillLevel 1 = fully filled yellow.
struct CrownFillView: View, Animatable {
    var fillLevel: CGFloat  // 0…1
    var size: CGFloat = 36

    var animatableData: CGFloat {
        get { fillLevel }
        set { fillLevel = newValue }
    }

    var body: some View {
        ZStack {
            // Empty crown outline — fades out as fill increases
            Image(systemName: "crown")
                .font(.system(size: size))
                .foregroundColor(Color(.systemGray4).opacity(1 - fillLevel))

            // Filled crown masked by fill level (bottom to top)
            Image(systemName: "crown.fill")
                .font(.system(size: size))
                .foregroundColor(.yellow)
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(height: geo.size.height * fillLevel)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                )
        }
    }
}

/// A shape that draws a filled region from the bottom of the rect up to a
/// wavy line whose vertical position is controlled by `progress` (0 = bottom, 1 = top).
struct LiquidWaveShape: Shape {
    var progress: CGFloat   // 0…1+ how full the "glass" is
    var waveHeight: CGFloat // amplitude of the sine wave
    var phase: CGFloat      // phase offset for animation

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Don't draw anything when empty
        guard progress > 0.01 else { return path }

        // The water line moves from bottom (progress=0) to top (progress=1)
        let waterY = rect.height * (1 - progress)

        path.move(to: CGPoint(x: 0, y: waterY))

        // Draw wavy top edge
        let step: CGFloat = 2
        var x: CGFloat = 0
        while x <= rect.width {
            let relX = x / rect.width
            let y = waterY + sin((relX * .pi * 3) + phase) * waveHeight
                           + sin((relX * .pi * 1.5) + phase * 0.7) * (waveHeight * 0.5)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        // Close the shape along the bottom
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

#Preview {
    let quote = Quote(
        title: "Test Quote",
        text: "Four score and seven years ago our fathers brought forth on this continent a new nation."
    )
    return RecitationScreen(quote: quote)
        .environmentObject(QuoteStore())
        .environmentObject(SettingsStore())
        .environmentObject(UserEquivalencesStore())
        .environmentObject(LocalRecordingStore())
}

