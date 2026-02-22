# Tsundoku — Project Overview

**Generated:** 2026-02-22
**Project Type:** iOS Native Mobile App
**Repository Type:** Monolith (single codebase with companion CLI)

---

## Purpose

Tsundoku is an iOS app for cataloging physical book collections by photographing bookshelves. The app detects individual book spines in shelf photos, reads the text via OCR, and looks up book metadata from online databases — then lets users build a personal digital library.

The name "tsundoku" (積ん読) is a Japanese word meaning "the act of acquiring books and letting them pile up unread."

---

## Key Capabilities

1. **Manual Search** — Type a book title and search Google Books / Open Library. Add results to your SwiftData-backed library.
2. **Shelf Photo Scanning** — Pick a bookshelf photo, detect individual spines using computer vision, OCR the text on each spine, and automatically look up book metadata.
3. **Library Management** — View, browse, and delete saved books. Deduplication prevents adding the same book twice.
4. **Pluggable Detection Pipelines** — Three interchangeable spine detection approaches: Classical (edge detection + projection profiles), YOLO (CoreML object detection), and FastSAM (instance segmentation).

---

## Tech Stack Summary

| Category | Technology | Version / Details |
|----------|-----------|-------------------|
| **Language** | Swift | Strict concurrency enabled |
| **UI** | SwiftUI | iOS 17+ APIs (@Observable, NavigationStack) |
| **Persistence** | SwiftData | `@Model` for `Book` entity |
| **Computer Vision** | Apple Vision | VNDetectContoursRequest, VNRecognizeTextRequest |
| **Image Processing** | CoreImage | Edge detection, grayscale, column projection |
| **ML Models** | CoreML | YOLO26n (4.8 MB), FastSAM-s (23.7 MB) |
| **VLM** | MLX Swift | SmolVLM2-500M via `mlx-swift-lm` v2.30.6 |
| **APIs** | Google Books API v1 | maxResults=10, API key via xcconfig |
| **APIs** | Open Library Search | `q=` general search, limit=10 |
| **Project Gen** | XcodeGen | `project.yml` at root |
| **Testing** | Swift Testing | `@Test`, `#expect`, `@Suite` |
| **Target** | iOS 17.0+ | iPhone only (portrait) |

---

## Architecture

**Pattern:** MVVM with @Observable, protocol-based services

- **Views** use `@State` with `@Observable` view models (no `ObservableObject` / `@StateObject`)
- **Services** are protocol-defined and struct-based (`BookMetadataService`, `SpineDetectionService`, `SpineDetector`, `SpineRecognizer`)
- **Models** use SwiftData `@Model` for persistence (`Book`)
- **No dependency injection container** — services are instantiated with default parameters, overridable for testing

---

## Targets

| Target | Type | Platform | Description |
|--------|------|----------|-------------|
| `Tsundoku` | iOS App | iOS 17.0+ | Main app with SwiftUI views, all services and models |
| `TsundokuCLI` | macOS Tool | macOS 14.0+ | Command-line tool sharing pipeline source files for benchmarking and iteration |
| `TsundokuTests` | Unit Tests | iOS 17.0+ | Swift Testing tests for services, utilities, and view models |

---

## Development Phase History

| Phase | Description | Outcome |
|-------|-------------|---------|
| **1** | Metadata API pipeline (text search → Google Books/Open Library → SwiftData) | Working search + library |
| **2** | Shelf photo spine detection (PhotosPicker → edge detection + projection profile → OCR → metadata) | 14/21 books matched on reference shelf |
| **2.5** | CLI tool + calibration iteration (8 rounds, PlatformImage cross-platform abstraction) | 3/21 → 14/21 improvement |
| **2.6** | Fuzzy re-ranking (FuzzyMatcher scores API results against full OCR text) | Better match accuracy |
| **3** | ML pipeline (pluggable architecture, YOLO26n + SmolVLM2 + FastSAM) | YOLO: 5/21 (disappointing), FastSAM in progress |

---

## Links to Detailed Documentation

- [Architecture](./architecture.md) — Full technical architecture, component details, data flow
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory structure
- [Development Guide](./development-guide.md) — Build, run, test instructions
- [Component Inventory](./component-inventory.md) — All views, services, models, utilities
- [Classical Pipeline](../PIPELINE.md) — Detection pipeline architecture, tuning history, benchmark results
- [YOLO + VLM Pipeline](../YOLO.md) — ML pipeline learnings and benchmark comparison
