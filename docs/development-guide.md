# Tsundoku — Development Guide

**Generated:** 2026-02-22

---

## Prerequisites

- **Xcode 26.2** (or later)
- **XcodeGen** — `brew install xcodegen`
- **iOS 17.0+ Simulator** — iPhone 17 recommended (iOS 26.2, Simulator ID: `325A0192-0C53-443C-AFE8-3DC9E9453408`)
- **Google Books API key** — required for Google Books search. Get one from [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
- **Python 3 + Ultralytics** — only if re-exporting CoreML models (not needed for development)

---

## Initial Setup

### 1. Configure API Key

Create `Config.xcconfig` at the project root (gitignored):

```
GOOGLE_BOOKS_API_KEY = your_api_key_here
```

This is injected into `Info.plist` at build time and read by `Secrets.swift`.

### 2. Generate Xcode Project

```bash
cd /path/to/Tsundoku
xcodegen generate
```

This reads `project.yml` and generates `Tsundoku.xcodeproj`. **Run this after any changes to `project.yml`.**

### 3. Open and Build

```bash
open Tsundoku.xcodeproj
```

Select the `Tsundoku` scheme, pick an iPhone simulator, and build (Cmd+B).

---

## Build Commands

### iOS App

```bash
xcodebuild -project Tsundoku.xcodeproj \
  -scheme Tsundoku \
  -destination 'platform=iOS Simulator,id=325A0192-0C53-443C-AFE8-3DC9E9453408' \
  build
```

### macOS CLI Tool

```bash
xcodebuild -project Tsundoku.xcodeproj \
  -scheme TsundokuCLI \
  -destination 'platform=macOS' \
  build
```

### Run Tests

```bash
xcodebuild -project Tsundoku.xcodeproj \
  -scheme Tsundoku \
  -destination 'platform=iOS Simulator,id=325A0192-0C53-443C-AFE8-3DC9E9453408' \
  test
```

18 tests total across 2 test files.

---

## Running the CLI Tool

The CLI shares pipeline source files with the iOS app and is useful for benchmarking and iteration.

### Basic spine detection (no metadata lookup):
```bash
./TsundokuCLI path/to/bookshelf.heic
```

### With metadata lookup:
```bash
GOOGLE_BOOKS_API_KEY=your_key ./TsundokuCLI --lookup path/to/bookshelf.heic
```

### Selecting a pipeline:
```bash
./TsundokuCLI --pipeline classical path/to/bookshelf.heic
./TsundokuCLI --pipeline yolo path/to/bookshelf.heic
./TsundokuCLI --pipeline fastsam path/to/bookshelf.heic
```

### Using VLM recognizer:
```bash
./TsundokuCLI --pipeline yolo --vlm path/to/bookshelf.heic
```

**Note:** The CLI can't read `Info.plist`, so the API key must be passed as an environment variable.

**Output:** Pretty-printed JSON with detected rects, OCR text, search queries, and metadata matches.

---

## Adding New Source Files

When adding new `.swift` files that are part of the shared pipeline:

1. Add the file to `Tsundoku/` (in the appropriate subdirectory)
2. Open `project.yml`
3. Add the file path to `TsundokuCLI.sources` list
4. Run `xcodegen generate`
5. Build both targets to verify

**When NOT to add to CLI:** View files, SwiftUI-specific code, SwiftData model code, UIKit-dependent code.

---

## Protocol Changes

If you modify a protocol that has mock implementations in tests, you must update the mocks:

| Protocol | Mock Location |
|----------|---------------|
| `BookMetadataService` | `TsundokuTests/BookMetadataServiceTests.swift` (`MockSuccessService`, `MockFailureService`) |
| `SpineDetectionService` | `TsundokuTests/SpineDetectionServiceTests.swift` (`MockSpineDetectionService`) |

---

## Simulator Notes

- **Use iOS 26.2 simulators** — iOS 18.1 simulators have connectivity issues that cause network calls to fail
- **iPhone 17 (ID: 325A0192)** is the primary test device
- **VLM (SmolVLM2)** requires Metal GPU and **will not work in Simulator**. Test VLM features on a physical device only.
- **YOLO and FastSAM** CoreML models work in Simulator (CPU inference)

---

## Key Configuration Values

### Classical Spine Detector Calibration (SpineDetectionServiceImpl.swift)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `minimumAspectRatio` | 2.0 | Min height/width ratio for a spine |
| `minimumHeightFraction` | 0.15 | Min spine height as fraction of image |
| `minPeakDistanceFraction` | 0.015 | Min distance between projection peaks |
| `peakThresholdFraction` | 0.05 | Peak height threshold (fraction of max) |
| `valleyDepthThreshold` | 0.50 | Valley depth ratio for merging peaks |
| `iouDeduplicationThreshold` | 0.5 | IoU threshold for deduplicating rects |
| `maxWidthFraction` | 0.20 | Max spine width as fraction of image |

### OCR Configuration

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Orientations | `.right` + `.left` | Dual orientation, pick best |
| Crop padding | 30% horizontal | For spines < 200px wide |
| Latin filter | > 50% Latin scalars | Reject non-Latin OCR hallucinations |
| Min query length | 3 characters | Skip too-short OCR results |
| Max query length | 60 characters | Truncate for API calls |

### API Configuration

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Google Books maxResults | 10 | Optimal relevance (40 degrades quality) |
| Open Library limit | 10 | Search result count |
| Open Library search param | `q=` | General search (not `title=`) |
| FuzzyMatcher high confidence | score ≥ 50 | Green/identified |
| FuzzyMatcher medium confidence | score ≥ 20 | Yellow/possible match |

---

## Ground Truth Data

| File | Description |
|------|-------------|
| `docs/samples/mybooks-001.json` | 21 books on reference shelf with titles and authors |
| `docs/samples/iteration-log.json` | Full calibration iteration history (8 rounds) |

Reference image: `mybooks-001.heic` (not committed — provide your own shelf photo for testing).

---

## CoreML Model Re-export

Only needed if updating model weights. Requires Python environment:

```bash
pip3 install ultralytics "coremltools>=9.0" "numpy<2.0"
```

**YOLO26n:**
```python
from ultralytics import YOLO
model = YOLO("yolo26n.pt")
model.export(format="coreml", nms=True, imgsz=640)
```

**FastSAM-s:**
```python
from ultralytics import YOLO
model = YOLO("FastSAM-s.pt")
model.export(format="coreml", imgsz=640)
```

**Important:** `numpy>=2.0` causes `TypeError` with coremltools. Must use `numpy<2.0`.

---

## SDK Notes (Xcode 26.2)

- `NSAttributedString` HTML init API changed in newer SDKs — this project uses regex-based HTML stripping (`HTMLStripper.swift`) instead
- Swift Testing (`import Testing`, `@Test`, `#expect`) works correctly
- Strict concurrency is fully enabled (`SWIFT_STRICT_CONCURRENCY: complete`)
