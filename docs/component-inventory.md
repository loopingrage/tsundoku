# Tsundoku — Component Inventory

**Generated:** 2026-02-22

---

## Views

### App Shell

| Component | File | Description |
|-----------|------|-------------|
| `TsundokuApp` | `App/TsundokuApp.swift` | @main entry point. WindowGroup with SwiftData modelContainer for `Book.self` |
| `ContentView` | `App/ContentView.swift` | Root TabView with 3 tabs (Search, Scan, Library). Injects `AppNavigation` environment |
| `AppNavigation` | `App/ContentView.swift` | @Observable class for cross-tab navigation (`selectedTab`, `searchQuery`) |

### Search Tab (Tab 0)

| Component | File | Description |
|-----------|------|-------------|
| `MetadataSearchDemoView` | `Views/Search/MetadataSearchDemoView.swift` | NavigationStack with searchable text field, results list, add/remove book actions. Uses `SearchViewModel` |
| `SearchViewModel` | `Views/Search/MetadataSearchDemoView.swift` | @Observable view model. Holds query, results, isSearching, errorMessage, savedIDs. Calls `BookMetadataServiceImpl` |
| `SearchResultRowView` | `Views/Search/SearchResultRowView.swift` | Row showing book cover (AsyncImage), title, authors, year, source badge, add/remove button |

### Scan Tab (Tab 1)

| Component | File | Description |
|-----------|------|-------------|
| `ShelfScanView` | `Views/Scan/ShelfScanView.swift` | Full scanning workflow: idle (PhotosPicker + pipeline picker), processing (image + rects + progress), results (grouped by confidence), error |
| `ShelfScanViewModel` | `Views/Scan/ShelfScanView.swift` | @Observable view model. Manages `ScanState` enum, pipeline selection, stepped scanning (detect → OCR → lookup) with TaskGroup parallelism |
| `SpineResultRowView` | `Views/Scan/SpineResultRowView.swift` | Row showing cover/spine image, match details or "No match found" + OCR text, add/remove/search buttons |
| `SpineScanDetailView` | `Views/Scan/SpineScanDetailView.swift` | Debug detail view: cropped spine image, OCR observations with confidence/bbox, search query, metadata match details, segmentation info, timing |
| `SpineImageFullScreenView` | `Views/Scan/SpineImageFullScreenView.swift` | Full-screen black background spine image viewer with dismiss button |

**Supporting types in ShelfScanView:**
- `ScanState` enum (`.idle`, `.processing(ProcessingState)`, `.results([SpineScanResult])`, `.error(String)`)
- `ProcessingState` struct (image, phase, detectedRects)
- `ProcessingPhase` enum (detectingSpines, runningOCR, lookingUpMetadata)

### Library Tab (Tab 2)

| Component | File | Description |
|-----------|------|-------------|
| `LibraryView` | `Views/Library/LibraryView.swift` | SwiftData @Query sorted by dateAdded (reverse). List with swipe-to-delete. Empty state with ContentUnavailableView |

---

## Models

| Model | File | Type | Description |
|-------|------|------|-------------|
| `Book` | `Models/Book.swift` | SwiftData @Model | Primary persistence entity. 14 stored properties including title, authors, ISBNs, cover URLs, source, readingStatus |
| `BookSearchResult` | `Models/BookSearchResult.swift` | Struct (Identifiable, Sendable) | API search result. `toBook()` for SwiftData conversion (UIKit-only) |
| `BookDataSource` | `Models/BookSearchResult.swift` | Enum (String, Sendable) | `.googleBooks`, `.openLibrary` |
| `GoogleBooksResponse` | `Models/APIResponseModels.swift` | Codable | Top-level Google Books API response |
| `GoogleBooksVolume` | `Models/APIResponseModels.swift` | Codable | Volume with id + volumeInfo |
| `GoogleBooksVolumeInfo` | `Models/APIResponseModels.swift` | Codable | Title, authors, description, categories, pageCount, publishedDate, imageLinks, identifiers |
| `GoogleBooksImageLinks` | `Models/APIResponseModels.swift` | Codable | smallThumbnail, thumbnail URLs |
| `GoogleBooksIdentifier` | `Models/APIResponseModels.swift` | Codable | type + identifier (ISBN_10, ISBN_13) |
| `OpenLibrarySearchResponse` | `Models/APIResponseModels.swift` | Codable | numFound + docs array |
| `OpenLibraryDoc` | `Models/APIResponseModels.swift` | Codable | key, title, authorName, firstPublishYear, isbn, subject, coverId |
| `OpenLibraryISBNResponse` | `Models/APIResponseModels.swift` | Codable | ISBN lookup result with authors, description, covers |
| `OpenLibraryDescription` | `Models/APIResponseModels.swift` | Codable (enum) | Handles OL description as either plain string or `{value: string}` object |

---

## Services

### Metadata Services

| Service | File | Protocol | Description |
|---------|------|----------|-------------|
| `BookMetadataServiceImpl` | `Services/BookMetadataServiceImpl.swift` | `BookMetadataService` | Orchestrator: chains primary → fallback provider with retry (full query + long-words-only). Applies FuzzyMatcher re-ranking when ocrContext provided |
| `GoogleBooksService` | `Services/GoogleBooksService.swift` | `BookMetadataService` | Google Books API v1 volumes search/lookup. maxResults=10, API key from Secrets, http→https cover URL upgrade |
| `OpenLibraryService` | `Services/OpenLibraryService.swift` | `BookMetadataService` | Open Library search.json (`q=` param) + ISBN lookup. Custom User-Agent header |

### Detection Services

| Service | File | Protocol | Description |
|---------|------|----------|-------------|
| `SpineDetectionServiceImpl` | `Services/SpineDetectionServiceImpl.swift` | `SpineDetectionService`, `SteppedSpineDetectionService` | Composes detector + recognizer + metadata. Full pipeline: detect → OCR → lookup with parallel TaskGroup |
| `ClassicalSpineDetector` | `Services/SpineDetectionServiceImpl.swift` | `SpineDetector` | VNContours + projection profile + valley-depth filtering + edge peaks + IoU dedup. 8 calibration constants |
| `SpineOCR` | `Services/SpineDetectionServiceImpl.swift` | (enum, not protocol) | Dual-orientation Vision OCR, Latin filter, query construction (largest + 2nd largest bbox) |
| `VisionOCRRecognizer` | `Services/SpineDetectionServiceImpl.swift` | `SpineRecognizer` | Wraps SpineOCR as async SpineRecognizer for pipeline pluggability |
| `YOLOSpineDetector` | `Services/YOLOSpineDetector.swift` | `SpineDetector` | YOLO26n CoreML, parses [1,300,6] tensor, filters class 73 @ confidence≥0.25 |
| `VLMSpineRecognizer` | `Services/VLMSpineRecognizer.swift` | `SpineRecognizer` | SmolVLM2-500M via MLX Swift. Lazy model loading, temperature=0.1, maxTokens=100 |
| `FastSAMSpineDetector` | `Services/FastSAMSpineDetector.swift` | `SpineDetector` | FastSAM-s "segment everything". Parses [1,37,8400] tensor, NMS, spine aspect ratio filtering |
| `DetectionPipeline` | `Services/DetectionPipeline.swift` | — | Enum: `.classical`, `.yolo`, `.fastsam` with displayName |
| `PipelineFactory` | `Services/PipelineFactory.swift` | — | Static factory wiring detector + recognizer per pipeline |

### Spine Detection Result Types (in SpineDetectionService.swift)

| Type | Kind | Description |
|------|------|-------------|
| `SpineScanResult` | Struct | Final result: spineImage, rawOCRText, metadataMatch, confidence, debug info |
| `SpineOCROutput` | Struct | Intermediate: cgImage, searchQuery, allText, observations, normalizedRect |
| `SpineRecognition` | Struct | Recognizer output: searchQuery, fullText, observations |
| `OCRObservationInfo` | Struct | Per-observation: text, confidence, boundingBox, area, isSearchCandidate |
| `SpineDebugInfo` | Struct | Debug: spineRect, pixel dimensions, searchQuery, observations, timing, error |
| `MatchConfidence` | Enum | `.low`, `.medium`, `.high` (based on FuzzyMatcher score thresholds: 0, 20, 50) |
| `SpineDetectionError` | Enum | `.imageConversionFailed`, `.noSpinesDetected`, `.visionRequestFailed(Error)` |
| `BookMetadataError` | Enum | `.noResults`, `.networkError`, `.decodingError`, `.invalidURL` |

---

## Utilities

| Utility | File | Description |
|---------|------|-------------|
| `ImageProcessing` | `Utilities/ImageProcessing.swift` | **preprocessForSpineDetection()** — grayscale + contrast + Sobel-X edges. **computeColumnSums()** — renders CIImage to L8 buffer, sums columns. **findPeaks()** — local maxima with min distance + threshold. **crop()** — normalized rect cropping with optional horizontal padding |
| `FuzzyMatcher` | `Utilities/FuzzyMatcher.swift` | **score()** — scores a BookSearchResult against OCR text: title word overlap (0-60 pts) + author match (0-30 pts) + exact substring bonus (10 pts) - short title penalty (0.7×). **rerank()** — sorts results by score descending |
| `HTMLStripper` | `Utilities/HTMLStripper.swift` | Regex-based HTML stripping: `<br>` → newline, removes all tags, decodes 6 HTML entities (&amp; &lt; &gt; &quot; &#39; &nbsp;) |
| `PlatformImage` | `Utilities/PlatformImage.swift` | `typealias PlatformImage = UIImage` (iOS) or `NSImage` (macOS). NSImage extensions: `.cgImage`, `.scale`, `CIImage(image:)` |
| `Secrets` | `Config/Secrets.swift` | Reads `GOOGLE_BOOKS_API_KEY` from Bundle.main info dictionary (app) or ProcessInfo.environment (CLI) |

---

## CoreML Models

| Model | File | Size | Architecture | Input | Output |
|-------|------|------|-------------|-------|--------|
| `YOLOBookDetector` | `Models/YOLOBookDetector.mlpackage` | 4.8 MB | YOLO26n (Ultralytics) | 640×640 RGB | `[1, 300, 6]` — NMS-free detections |
| `FastSAMBookSegmenter` | `Models/FastSAMBookSegmenter.mlpackage` | 23.7 MB | YOLOv8-seg (FastSAM-s) | 640×640 RGB | `[1, 37, 8400]` — segment proposals |

---

## Test Components

| Component | File | Tests |
|-----------|------|-------|
| `FindPeaksTests` | `SpineDetectionServiceTests.swift` | 7 tests: simple peaks, min distance, threshold, short/empty profile, sorted output, plateau handling |
| `ShelfScanViewModelTests` | `SpineDetectionServiceTests.swift` | 2 tests: initial idle state, reset returns to idle |
| `BookMetadataServiceImplTests` | `BookMetadataServiceTests.swift` | 4 tests: primary success, fallback, both fail, ISBN fallback |
| `HTMLStripperTests` | `BookMetadataServiceTests.swift` | 4 tests: basic tags, entities, plain text, br tags |
| — | `BookMetadataServiceTests.swift` | 1 test: BookSearchResult.toBook() conversion |
| `MockSuccessService` | `BookMetadataServiceTests.swift` | Test double returning configured results |
| `MockFailureService` | `BookMetadataServiceTests.swift` | Test double always throwing .noResults |
| `MockSpineDetectionService` | `SpineDetectionServiceTests.swift` | Test double with configurable Result |
