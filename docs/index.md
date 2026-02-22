# Tsundoku — Documentation Index

**Last Updated:** 2026-02-22
**Scan Level:** Deep (all source files read)

---

## Project Overview

- **Type:** iOS Native Mobile App (monolith with companion CLI)
- **Language:** Swift (strict concurrency)
- **UI Framework:** SwiftUI (iOS 17+, @Observable)
- **Persistence:** SwiftData (@Model)
- **Architecture:** MVVM, protocol-based services, pluggable detection pipelines

### Quick Reference

- **Bundle ID:** `com.joyinc.Tsundoku`
- **Deployment Target:** iOS 17.0+ (iPhone only)
- **Entry Point:** `TsundokuApp.swift` → `ContentView.swift` (TabView)
- **Primary Patterns:** @Observable view models, protocol-based DI, async/await + TaskGroup
- **External Dependencies:** `mlx-swift-lm` v2.30.6 (MLXVLM, MLXLMCommon)
- **CoreML Models:** YOLO26n (4.8 MB), FastSAM-s (23.7 MB)

---

## Generated Documentation

- [Project Overview](./project-overview.md) — Purpose, capabilities, tech stack, phase history
- [Architecture](./architecture.md) — High-level architecture, data model, service layer, data flow, navigation, concurrency
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory structure, file statistics, shared files
- [Component Inventory](./component-inventory.md) — All views, models, services, utilities, test components
- [Development Guide](./development-guide.md) — Prerequisites, setup, build commands, CLI usage, calibration values

---

## Existing Documentation

- [Classical Pipeline Architecture](../PIPELINE.md) — Detection pipeline design, 8-round iteration history, benchmark results (14/21 matches), calibration parameters, failure analysis
- [YOLO + VLM Pipeline](../YOLO.md) — ML pipeline learnings, YOLO26n + SmolVLM2 integration, benchmark comparison (5/21 vs 36 classical), key learnings

---

## Reference Data

- `docs/samples/mybooks-001.json` — Ground truth: 21 books on reference bookshelf
- `docs/samples/iteration-log.json` — Full calibration iteration history (8 rounds)

---

## Getting Started

1. Install XcodeGen: `brew install xcodegen`
2. Create `Config.xcconfig` with your `GOOGLE_BOOKS_API_KEY`
3. Run `xcodegen generate` to create the Xcode project
4. Open `Tsundoku.xcodeproj`, select iPhone simulator, build and run
5. See [Development Guide](./development-guide.md) for full setup details
