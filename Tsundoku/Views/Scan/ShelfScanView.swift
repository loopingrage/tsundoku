import PhotosUI
import SwiftData
import SwiftUI

struct ShelfScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var appNav
    @Query private var libraryBooks: [Book]
    @State private var viewModel = ShelfScanViewModel()
    @State private var showExistingBooks = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.scanState {
                case .idle:
                    idleView
                case .processing(let state):
                    processingView(state: state)
                case .results(let results):
                    resultsView(results: results)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Scan Shelf")
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        ContentUnavailableView {
            Label("Scan a Bookshelf", systemImage: "camera.viewfinder")
        } description: {
            Text("Pick a photo of your bookshelf to detect and identify books.")
        } actions: {
            Picker("Pipeline", selection: $viewModel.selectedPipeline) {
                ForEach(DetectionPipeline.allCases, id: \.self) { pipeline in
                    Text(pipeline.displayName).tag(pipeline)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            PhotosPicker(
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            ) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            Task { await viewModel.processSelectedPhoto(item) }
        }
    }

    // MARK: - Processing

    private func processingView(state: ProcessingState) -> some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                let imageSize = aspectFitSize(
                    for: CGSize(
                        width: CGFloat(state.image.cgImage?.width ?? 1),
                        height: CGFloat(state.image.cgImage?.height ?? 1)
                    ),
                    in: geometry.size
                )
                let offsetX = (geometry.size.width - imageSize.width) / 2
                let offsetY = (geometry.size.height - imageSize.height) / 2

                ZStack(alignment: .topLeading) {
                    Image(uiImage: state.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    ForEach(Array(state.detectedRects.enumerated()), id: \.offset) { _, rect in
                        Rectangle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .frame(
                                width: rect.width * imageSize.width,
                                height: rect.height * imageSize.height
                            )
                            .offset(
                                x: offsetX + rect.origin.x * imageSize.width,
                                y: offsetY + rect.origin.y * imageSize.height
                            )
                    }
                }
            }

            HStack(spacing: 12) {
                ProgressView()
                Text(state.phase.displayMessage)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom)
        }
    }

    // MARK: - Results

    private func resultsView(results: [SpineScanResult]) -> some View {
        let deduped = deduplicateByISBN(results)
        let filtered = filterResults(deduped)
        let high = filtered.filter { $0.confidence == .high }
        let medium = filtered.filter { $0.confidence == .medium }
        let low = filtered.filter { $0.confidence == .low }
        let hiddenCount = deduped.count - filtered.count

        return List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(resultsSummary(total: deduped.count, high: high.count, medium: medium.count, low: low.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if hiddenCount > 0 || libraryBooks.count > 0 {
                        Toggle("Show books already in library", isOn: $showExistingBooks)
                            .font(.subheadline)
                        if hiddenCount > 0 && !showExistingBooks {
                            Text("\(hiddenCount) already in your library")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if !high.isEmpty {
                confidenceSection(title: "Identified", results: high, color: .green)
            }
            if !medium.isEmpty {
                confidenceSection(title: "Possible Matches", results: medium, color: .yellow)
            }
            if !low.isEmpty {
                confidenceSection(title: "Unidentified", results: low, color: .gray)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Scan Again") {
                    viewModel.reset()
                }
            }
        }
    }

    private func confidenceSection(title: String, results: [SpineScanResult], color: Color) -> some View {
        Section {
            ForEach(results) { result in
                NavigationLink {
                    SpineScanDetailView(result: result, index: 0)
                } label: {
                    SpineResultRowView(
                        result: result,
                        isSaved: viewModel.savedIDs.contains(result.id),
                        onAdd: { addBook(result) },
                        onRemove: { removeBook(result) },
                        onSearch: { navigateToSearch(result) }
                    )
                }
            }
        } header: {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text("\(title) (\(results.count))")
            }
        }
    }

    private func resultsSummary(total: Int, high: Int, medium: Int, low: Int) -> String {
        var parts: [String] = ["Found \(total) spine\(total == 1 ? "" : "s")"]
        if high > 0 { parts.append("\(high) identified") }
        if medium > 0 { parts.append("\(medium) possible") }
        if low > 0 { parts.append("\(low) unidentified") }
        return parts.joined(separator: " — ")
    }

    // MARK: - Deduplication & Filtering

    private func deduplicateByISBN(_ results: [SpineScanResult]) -> [SpineScanResult] {
        var seenISBNs: Set<String> = []
        var deduped: [SpineScanResult] = []
        for result in results {
            if let match = result.metadataMatch {
                let isbn = match.isbn13 ?? match.isbn10
                if let isbn {
                    if seenISBNs.contains(isbn) { continue }
                    seenISBNs.insert(isbn)
                }
            }
            deduped.append(result)
        }
        return deduped
    }

    private func filterResults(_ results: [SpineScanResult]) -> [SpineScanResult] {
        guard !showExistingBooks else { return results }
        let librarySet = Set(libraryBooks.map { "\($0.title)|\($0.authors)" })
        return results.filter { result in
            guard let match = result.metadataMatch else { return true }
            return !librarySet.contains("\(match.title)|\(match.authors)")
        }
    }

    private func navigateToSearch(_ result: SpineScanResult) {
        appNav.searchQuery = result.rawOCRText
        appNav.selectedTab = 0
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Scan Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Add/Remove Book

    private func addBook(_ result: SpineScanResult) {
        guard let match = result.metadataMatch else { return }
        let title = match.title
        let authors = match.authors
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate {
            $0.title == title && $0.authors == authors
        })
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existing == 0 else {
            viewModel.savedIDs.insert(result.id)
            return
        }
        let book = match.toBook()
        modelContext.insert(book)
        viewModel.savedIDs.insert(result.id)
    }

    private func removeBook(_ result: SpineScanResult) {
        guard let match = result.metadataMatch else { return }
        let title = match.title
        let authors = match.authors
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate {
            $0.title == title && $0.authors == authors
        })
        if let books = try? modelContext.fetch(descriptor) {
            for book in books { modelContext.delete(book) }
        }
        viewModel.savedIDs.remove(result.id)
    }

    // MARK: - Helpers

    private func aspectFitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

// MARK: - Processing State

struct ProcessingState {
    let image: UIImage
    let phase: ProcessingPhase
    let detectedRects: [CGRect]
}

enum ProcessingPhase {
    case detectingSpines
    case runningOCR(completed: Int, total: Int)
    case lookingUpMetadata(spineCount: Int)

    var displayMessage: String {
        switch self {
        case .detectingSpines:
            return "Detecting spines..."
        case .runningOCR(let completed, let total):
            return "Reading spine \(completed + 1) of \(total)..."
        case .lookingUpMetadata(let count):
            return "Looking up \(count) book\(count == 1 ? "" : "s")..."
        }
    }
}

// MARK: - ScanState

enum ScanState {
    case idle
    case processing(ProcessingState)
    case results([SpineScanResult])
    case error(String)
}

// MARK: - ViewModel

@Observable
final class ShelfScanViewModel {
    var selectedPhotoItem: PhotosPickerItem?
    var scanState: ScanState = .idle
    var savedIDs: Set<UUID> = []
    var selectedPipeline: DetectionPipeline = .classical

    private var _scanService: SpineDetectionServiceImpl?

    private var scanService: SpineDetectionServiceImpl {
        get throws {
            if let existing = _scanService { return existing }
            let service = try PipelineFactory.makeService(pipeline: selectedPipeline)
            _scanService = service
            return service
        }
    }

    @MainActor
    func processSelectedPhoto(_ item: PhotosPickerItem) async {
        scanState = .processing(ProcessingState(
            image: UIImage(),
            phase: .detectingSpines,
            detectedRects: []
        ))

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            scanState = .error("Could not load the selected image.")
            return
        }

        scanState = .processing(ProcessingState(
            image: image,
            phase: .detectingSpines,
            detectedRects: []
        ))

        do {
            let service = try scanService

            // 1. Detect spine boundaries (CPU-bound)
            let rects = try await Task.detached {
                try service.detectSpines(in: image)
            }.value

            guard !rects.isEmpty else {
                throw SpineDetectionError.noSpinesDetected
            }

            // 2. OCR each spine
            var ocrOutputs: [SpineOCROutput] = []
            for (index, rect) in rects.enumerated() {
                scanState = .processing(ProcessingState(
                    image: image,
                    phase: .runningOCR(completed: index, total: rects.count),
                    detectedRects: rects
                ))

                if let output = try await Task.detached(operation: {
                    try await service.ocrSpine(in: image, rect: rect)
                }).value {
                    ocrOutputs.append(output)
                }
            }

            guard !ocrOutputs.isEmpty else {
                throw SpineDetectionError.noSpinesDetected
            }

            // 3. Look up metadata in parallel
            scanState = .processing(ProcessingState(
                image: image,
                phase: .lookingUpMetadata(spineCount: ocrOutputs.count),
                detectedRects: rects
            ))

            let results = await withTaskGroup(of: (Int, SpineScanResult).self, returning: [SpineScanResult].self) { group in
                for (index, output) in ocrOutputs.enumerated() {
                    group.addTask {
                        do {
                            let result = try await service.lookupMetadata(for: output, in: image, rect: output.normalizedRect)
                            return (index, result)
                        } catch {
                            // Create a result with no match on error
                            let debug = SpineDebugInfo(
                                spineRect: output.normalizedRect,
                                spinePixelWidth: Int(output.normalizedRect.width * CGFloat(Int(image.size.width * image.scale))),
                                spinePixelHeight: Int(output.normalizedRect.height * CGFloat(Int(image.size.height * image.scale))),
                                searchQuery: String(output.searchQuery.prefix(60)),
                                observations: output.observationDetails,
                                processingTimeMs: 0,
                                metadataError: error.localizedDescription
                            )
                            return (index, SpineScanResult(
                                id: UUID(),
                                spineImage: output.cgImage,
                                rawOCRText: output.allText,
                                metadataMatch: nil,
                                confidence: .low,
                                debug: debug
                            ))
                        }
                    }
                }

                var indexed: [(Int, SpineScanResult)] = []
                for await pair in group {
                    indexed.append(pair)
                }
                return indexed.sorted { $0.0 < $1.0 }.map(\.1)
            }

            scanState = .results(results)

        } catch let error as SpineDetectionError {
            scanState = .error(error.errorDescription ?? error.localizedDescription)
        } catch {
            scanState = .error(error.localizedDescription)
        }
    }

    func reset() {
        selectedPhotoItem = nil
        scanState = .idle
        savedIDs = []
        _scanService = nil
    }
}
