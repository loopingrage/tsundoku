# Tsundoku — Architecture

**Generated:** 2026-02-22
**Architecture Pattern:** MVVM with @Observable, protocol-based services
**Platform:** iOS 17.0+ (iPhone only), macOS 14.0+ (CLI only)

---

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────┐
│  SwiftUI Views                                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐  │
│  │ Search Tab   │ │ Scan Tab     │ │ Library Tab      │  │
│  │ (SearchVM)   │ │ (ShelfScanVM)│ │ (@Query)         │  │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────────┘  │
│         │                │                │              │
│         ▼                ▼                ▼              │
│  ┌──────────────────────────────────────────────────┐    │
│  │  SwiftData ModelContext                           │    │
│  │  Book @Model                                     │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │  Service Layer (protocol-based)                   │    │
│  │                                                   │    │
│  │  BookMetadataService                              │    │
│  │    ├── BookMetadataServiceImpl (orchestrator)     │    │
│  │    ├── GoogleBooksService                         │    │
│  │    └── OpenLibraryService                         │    │
│  │                                                   │    │
│  │  SpineDetectionService                            │    │
│  │    └── SpineDetectionServiceImpl                  │    │
│  │          ├── SpineDetector (pluggable)            │    │
│  │          ├── SpineRecognizer (pluggable, async)   │    │
│  │          └── BookMetadataService                  │    │
│  │                                                   │    │
│  │  DetectionPipeline + PipelineFactory              │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │  Utilities                                        │    │
│  │  ImageProcessing, FuzzyMatcher, HTMLStripper,     │    │
│  │  PlatformImage                                    │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

---

## Data Model

### Book (@Model, SwiftData)

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Auto-generated unique ID |
| `title` | `String` | Book title |
| `authors` | `[String]` | Author names |
| `bookDescription` | `String` | Book description (HTML stripped) |
| `categories` | `[String]` | Genre categories |
| `pageCount` | `Int?` | Page count |
| `publishedYear` | `String?` | Publication year |
| `isbn10` | `String?` | ISBN-10 |
| `isbn13` | `String?` | ISBN-13 |
| `coverImageURL` | `String?` | Full-size cover URL |
| `coverThumbnailURL` | `String?` | Thumbnail cover URL |
| `dateAdded` | `Date` | When added to library |
| `source` | `String` | "Google Books" or "Open Library" |
| `readingStatus` | `String` | Default: "unread" |

### BookSearchResult (value type)

Intermediate result from API searches. Contains same fields as Book plus `id` (API-assigned). Has `toBook()` method for SwiftData insertion. UIKit-guarded (`#if canImport(UIKit)`).

---

## Service Architecture

### BookMetadataService Protocol

```swift
protocol BookMetadataService: Sendable {
    func search(query: String, ocrContext: String?) async throws -> [BookSearchResult]
    func lookup(isbn: String) async throws -> BookSearchResult
}
```

**Implementations:**
- `BookMetadataServiceImpl` — Orchestrator with retry strategy. Chains primary → fallback with two query strategies (full query, then long-words-only). Applies `FuzzyMatcher.rerank()` when `ocrContext` is provided.
- `GoogleBooksService` — Google Books API v1. API key from `Secrets.googleBooksAPIKey`. maxResults=10.
- `OpenLibraryService` — Open Library `search.json` with `q=` parameter (general search, not `title=`).

### SpineDetectionService Protocol

```swift
protocol SpineDetectionService: Sendable {
    func scanShelf(image: PlatformImage) async throws -> [SpineScanResult]
}
```

**Implementation:** `SpineDetectionServiceImpl` — Composed from three pluggable components:

### SpineDetector Protocol

```swift
protocol SpineDetector: Sendable {
    func detect(in image: PlatformImage) throws -> [CGRect]
}
```

Returns normalized rects (0...1, top-left origin).

| Implementation | Approach | Performance |
|---------------|----------|-------------|
| `ClassicalSpineDetector` | VNContours + projection profile + valley filtering + edge peaks + IoU dedup | 36 spines detected on reference shelf |
| `YOLOSpineDetector` | YOLO26n CoreML, COCO class 73 "book" | 5 spines (COCO not suited for spine segmentation) |
| `FastSAMSpineDetector` | FastSAM-s instance segmentation, "segment everything" + spine aspect ratio filtering | In progress |

### SpineRecognizer Protocol

```swift
protocol SpineRecognizer: Sendable {
    func recognize(in image: CGImage) async throws -> SpineRecognition?
}
```

| Implementation | Approach | Notes |
|---------------|----------|-------|
| `VisionOCRRecognizer` | Apple Vision OCR, dual orientation (.right/.left), Latin filter | Reliable, literal text extraction |
| `VLMSpineRecognizer` | SmolVLM2-500M via MLX Swift | Hallucinates on small crops, requires Metal GPU |

### Pipeline Wiring (PipelineFactory)

| Pipeline | Detector | Recognizer |
|----------|----------|------------|
| `.classical` | ClassicalSpineDetector | VisionOCRRecognizer |
| `.yolo` | YOLOSpineDetector | VLMSpineRecognizer |
| `.fastsam` | FastSAMSpineDetector | VisionOCRRecognizer |

---

## Scanning Data Flow

```
User picks photo (PhotosPicker)
    │
    ▼
ShelfScanViewModel.processSelectedPhoto()
    │
    ├── 1. PipelineFactory.makeService(pipeline:)
    │       → Returns SpineDetectionServiceImpl
    │
    ├── 2. service.detectSpines(in: image)
    │       → [CGRect] (normalized spine boundaries)
    │       UI: Shows yellow overlay rects
    │
    ├── 3. For each rect: service.ocrSpine(in:rect:)
    │       → Crop (with 30% padding if narrow)
    │       → Recognizer.recognize(in: croppedImage)
    │       → SpineOCROutput (searchQuery, allText, observations)
    │       UI: Progress "Reading spine X of Y"
    │
    └── 4. Parallel: service.lookupMetadata(for:in:rect:)
            → BookMetadataServiceImpl.search(query:ocrContext:)
            → FuzzyMatcher.score() for confidence rating
            → SpineScanResult (match, confidence, debug info)
            UI: Results grouped by confidence (high/medium/low)
```

---

## Navigation Architecture

```
TabView (3 tabs)
├── Tab 0: Search
│   └── NavigationStack
│       └── MetadataSearchDemoView
│           └── SearchResultRowView (list items)
│
├── Tab 1: Scan
│   └── NavigationStack
│       └── ShelfScanView
│           ├── Idle → PhotosPicker + Pipeline Picker
│           ├── Processing → Image + yellow rects + progress
│           ├── Results → Grouped by confidence
│           │   └── NavigationLink → SpineScanDetailView
│           └── Error → Retry button
│
└── Tab 2: Library
    └── NavigationStack
        └── LibraryView (@Query sorted by dateAdded)
```

**Cross-tab navigation:** `AppNavigation` (@Observable) enables the Scan tab to send OCR text to the Search tab via `appNav.searchQuery` + `appNav.selectedTab`.

---

## Configuration & Secrets

| Item | Location | Description |
|------|----------|-------------|
| Google Books API Key | `Config.xcconfig` (gitignored) | Injected into Info.plist as `GOOGLE_BOOKS_API_KEY` |
| Key Access (App) | `Secrets.swift` | Reads from `Bundle.main.infoDictionary` |
| Key Access (CLI) | Environment variable | `GOOGLE_BOOKS_API_KEY` env var (CLI can't read Info.plist) |
| Project Config | `project.yml` | XcodeGen project definition |

---

## Concurrency Model

- **Strict concurrency enabled** (`SWIFT_STRICT_CONCURRENCY: complete`)
- All protocols are `Sendable`
- View models are `@Observable final class` with `@MainActor` async methods
- Metadata lookups run in parallel via `withTaskGroup`
- Spine detection uses `Task.detached` to avoid blocking main actor
- `VLMSpineRecognizer` is `@unchecked Sendable` (MLX model container managed internally)

---

## Testing Strategy

| Test File | Coverage |
|-----------|----------|
| `SpineDetectionServiceTests.swift` | `ImageProcessing.findPeaks()` (7 tests), `ShelfScanViewModel` state (2 tests) |
| `BookMetadataServiceTests.swift` | `BookMetadataServiceImpl` primary/fallback/both-fail/ISBN-fallback (4 tests), `BookSearchResult.toBook()` (1 test), `HTMLStripper` (4 tests) |

**Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite`)
**Mocks:** `MockSuccessService`, `MockFailureService`, `MockSpineDetectionService` — all protocol-based
**Total:** 18 tests

---

## External Dependencies

| Package | Products Used | Purpose |
|---------|--------------|---------|
| `mlx-swift-lm` v2.30.6 | `MLXVLM`, `MLXLMCommon` | SmolVLM2-500M inference for VLM spine recognition |

**CoreML Models (bundled):**
- `YOLOBookDetector.mlpackage` (4.8 MB) — YOLO26n COCO book detector
- `FastSAMBookSegmenter.mlpackage` (23.7 MB) — FastSAM-s instance segmenter
