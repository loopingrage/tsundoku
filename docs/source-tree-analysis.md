# Tsundoku — Source Tree Analysis

**Generated:** 2026-02-22

---

## Directory Structure

```
Tsundoku/                          # Project root
├── project.yml                    # XcodeGen project definition (generates .xcodeproj)
├── Config.xcconfig                # Build config: GOOGLE_BOOKS_API_KEY (gitignored)
├── PIPELINE.md                    # Classical pipeline architecture & iteration history
├── YOLO.md                        # YOLO + VLM pipeline learnings & benchmarks
│
├── Tsundoku/                      # iOS App Source (main target)
│   ├── Info.plist                 # Generated plist (API key injection, camera/photo permissions)
│   │
│   ├── App/                       # App entry point & root navigation
│   │   ├── TsundokuApp.swift      # @main, WindowGroup, modelContainer(for: Book.self)
│   │   └── ContentView.swift      # TabView (Search/Scan/Library), AppNavigation @Observable
│   │
│   ├── Models/                    # Data models & API response types
│   │   ├── Book.swift             # SwiftData @Model — primary persistence entity
│   │   ├── BookSearchResult.swift # API search result value type, toBook() conversion
│   │   ├── APIResponseModels.swift# Codable types for Google Books & Open Library JSON
│   │   ├── YOLOBookDetector.mlpackage    # YOLO26n CoreML model (4.8 MB)
│   │   └── FastSAMBookSegmenter.mlpackage # FastSAM-s CoreML model (23.7 MB)
│   │
│   ├── Services/                  # Business logic & external integrations
│   │   ├── BookMetadataService.swift      # Protocol + error types
│   │   ├── BookMetadataServiceImpl.swift  # Orchestrator: primary→fallback, retry, FuzzyMatcher
│   │   ├── GoogleBooksService.swift       # Google Books API v1 client
│   │   ├── OpenLibraryService.swift       # Open Library search.json client
│   │   ├── SpineDetectionService.swift    # Protocols: SpineDetectionService, SpineDetector,
│   │   │                                 #   SpineRecognizer, + result types
│   │   ├── SpineDetectionServiceImpl.swift# ClassicalSpineDetector, VisionOCRRecognizer,
│   │   │                                 #   SpineDetectionServiceImpl (orchestration)
│   │   ├── DetectionPipeline.swift        # Pipeline enum (.classical, .yolo, .fastsam)
│   │   ├── PipelineFactory.swift          # Wires detector + recognizer per pipeline
│   │   ├── YOLOSpineDetector.swift        # YOLO26n CoreML inference + tensor parsing
│   │   ├── VLMSpineRecognizer.swift       # SmolVLM2-500M via MLX Swift
│   │   └── FastSAMSpineDetector.swift     # FastSAM-s instance segmentation + spine filtering
│   │
│   ├── Views/                     # SwiftUI views organized by feature
│   │   ├── Search/                # Tab 0: Manual book search
│   │   │   ├── MetadataSearchDemoView.swift  # Search bar, results list, add/remove
│   │   │   └── SearchResultRowView.swift     # Book cover + metadata + add button
│   │   │
│   │   ├── Scan/                  # Tab 1: Shelf photo scanning
│   │   │   ├── ShelfScanView.swift           # Photo picker, processing UI, results by confidence
│   │   │   ├── SpineResultRowView.swift      # Spine result row (cover/spine image, actions)
│   │   │   ├── SpineScanDetailView.swift     # Debug detail: OCR observations, search query, rects
│   │   │   └── SpineImageFullScreenView.swift# Full-screen spine image viewer
│   │   │
│   │   └── Library/               # Tab 2: Saved books
│   │       └── LibraryView.swift  # SwiftData @Query, swipe-to-delete
│   │
│   ├── Config/                    # Configuration
│   │   └── Secrets.swift          # API key access (Bundle or environment variable)
│   │
│   └── Utilities/                 # Shared utility code
│       ├── PlatformImage.swift    # Cross-platform UIImage/NSImage typealias + extensions
│       ├── ImageProcessing.swift  # Edge detection preprocessing, column sums, peak detection, cropping
│       ├── FuzzyMatcher.swift     # Scores API results against OCR text (title overlap + author match)
│       └── HTMLStripper.swift     # Regex-based HTML tag stripping & entity decoding
│
├── TsundokuCLI/                   # macOS CLI Tool (shares source files from Tsundoku/)
│   └── main.swift                 # CLI entry point: --lookup, --pipeline, --vlm flags
│                                  # Outputs JSON with spine detection + OCR + metadata results
│
├── TsundokuTests/                 # Unit Tests (iOS scheme)
│   ├── SpineDetectionServiceTests.swift  # findPeaks (7 tests), ShelfScanViewModel (2 tests)
│   └── BookMetadataServiceTests.swift    # Service impl (4 tests), toBook (1), HTMLStripper (4)
│
├── docs/                          # Project documentation
│   ├── project-overview.md        # This project overview
│   ├── architecture.md            # Technical architecture
│   ├── source-tree-analysis.md    # This file
│   ├── component-inventory.md     # Component catalog
│   ├── development-guide.md       # Build, run, test instructions
│   ├── project-scan-report.json   # Workflow state file
│   └── samples/                   # Reference data
│       ├── mybooks-001.json       # Ground truth: 21 books on reference shelf
│       └── iteration-log.json     # Full calibration iteration history
│
└── _bmad/                         # BMAD workflow framework (project management)
    └── ...
```

---

## File Statistics

| Directory | Swift Files | Purpose |
|-----------|------------|---------|
| `Tsundoku/App/` | 2 | App entry, root navigation |
| `Tsundoku/Models/` | 3 + 2 mlpackage | Data models, API types, CoreML models |
| `Tsundoku/Services/` | 11 | All business logic and external API clients |
| `Tsundoku/Views/` | 6 | SwiftUI views across 3 features |
| `Tsundoku/Config/` | 1 | API key management |
| `Tsundoku/Utilities/` | 4 | Cross-cutting utilities |
| `TsundokuCLI/` | 1 | CLI tool entry point |
| `TsundokuTests/` | 2 | Unit tests |
| **Total** | **30** | |

---

## Shared Source Files (CLI ↔ App)

The CLI target includes specific source files from the iOS app target (not the entire directory). These shared files are listed in `project.yml` under `TsundokuCLI.sources`:

| Shared File | Reason |
|-------------|--------|
| `PlatformImage.swift` | Cross-platform image abstraction (UIImage vs NSImage) |
| `ImageProcessing.swift` | Edge detection, column sums, peak detection, cropping |
| `HTMLStripper.swift` | Strip HTML from Google Books descriptions |
| `FuzzyMatcher.swift` | Re-rank search results against OCR text |
| `SpineDetectionService.swift` | Protocol definitions and result types |
| `SpineDetectionServiceImpl.swift` | Classical detector, OCR, service orchestration |
| `DetectionPipeline.swift` | Pipeline enum |
| `PipelineFactory.swift` | Pipeline wiring |
| `YOLOSpineDetector.swift` | YOLO CoreML detector |
| `VLMSpineRecognizer.swift` | VLM recognizer |
| `FastSAMSpineDetector.swift` | FastSAM detector |
| `BookMetadataService.swift` | Protocol + errors |
| `BookMetadataServiceImpl.swift` | Orchestrator with retry |
| `GoogleBooksService.swift` | Google Books client |
| `OpenLibraryService.swift` | Open Library client |
| `BookSearchResult.swift` | API result type |
| `APIResponseModels.swift` | Codable response types |
| `Secrets.swift` | API key access |
| `YOLOBookDetector.mlpackage` | YOLO CoreML model |
| `FastSAMBookSegmenter.mlpackage` | FastSAM CoreML model |

**Important:** When adding new `.swift` files to shared pipeline code, they must be added to BOTH the `Tsundoku` and `TsundokuCLI` source lists in `project.yml`.
