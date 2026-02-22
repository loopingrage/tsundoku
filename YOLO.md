# YOLO + VLM Pipeline — Learnings and Results

## Overview

Phase 3 added an ML-powered pipeline alongside the classical pipeline, using YOLO26n for detection and SmolVLM2-500M for text recognition. This document records what we built, what we learned, and why the results were disappointing.

## Architecture

```
DetectionPipeline enum (.classical | .yolo | .fastsam)
        │
   PipelineFactory
        │
   SpineDetectionServiceImpl(detector:, recognizer:, metadataService:)
        │
        ├── SpineDetector protocol
        │     ├── ClassicalSpineDetector (contours + projection profile)
        │     └── YOLOSpineDetector (YOLO26n CoreML, COCO class 73)
        │
        ├── SpineRecognizer protocol (async)
        │     ├── VisionOCRRecognizer (Apple Vision OCR, wraps SpineOCR)
        │     └── VLMSpineRecognizer (SmolVLM2-500M via MLX Swift)
        │
        └── BookMetadataService (shared — Google Books + Open Library + FuzzyMatcher)
```

### Key Files

| File | Role |
|------|------|
| `SpineDetectionService.swift` | Protocols: `SpineDetector`, `SpineRecognizer` (async), `SpineRecognition` struct |
| `SpineDetectionServiceImpl.swift` | `ClassicalSpineDetector`, `VisionOCRRecognizer`, orchestration |
| `YOLOSpineDetector.swift` | YOLO26n CoreML inference, output tensor parsing |
| `VLMSpineRecognizer.swift` | SmolVLM2-500M via MLX Swift for spine text reading |
| `DetectionPipeline.swift` | Pipeline enum (`.classical`, `.yolo`, `.fastsam`) |
| `PipelineFactory.swift` | Wires detector + recognizer per pipeline |
| `YOLOBookDetector.mlpackage` | YOLO26n CoreML model (4.8 MB) |

---

## YOLO26n Model Details

- **Architecture:** YOLO26n (Ultralytics, September 2025), 2.4M parameters
- **Training:** COCO dataset, class 73 = "book"
- **CoreML model:** 4.8 MB, exported via `ultralytics` Python package
- **Input:** 640x640 RGB image (auto-scaled via `VNCoreMLRequest.scaleFill`)
- **Output:** `var_1441` MLMultiArray `[1, 300, 6]` Float32 — NMS-free end-to-end detections
- **Output format per row:** `[x1, y1, x2, y2, confidence, class_id]` in pixel coords (0–640)
- **Confidence threshold:** 0.25
- **Compute units:** `.all` (Neural Engine when available)

### Export Command (one-time, Python)

```python
pip3 install ultralytics "coremltools>=9.0" "numpy<2.0"

from ultralytics import YOLO
model = YOLO("yolo26n.pt")
model.export(format="coreml", nms=True, imgsz=640)
# Output: yolo26n.mlpackage (~4.8 MB)
```

**Gotcha:** `numpy>=2.0` causes `TypeError` with `coremltools 9.0`. Must use `numpy<2.0`.

### Coordinate System

YOLO26n outputs pixel coordinates in model input space (640x640). We normalize to 0...1 by dividing by 640. The coordinates are already top-left origin (unlike Vision's bottom-left origin), so no Y-flip needed.

---

## SmolVLM2-500M (VLM Recognizer)

- **Model:** `HuggingFaceTB/SmolVLM2-500M-Video-Instruct-mlx`
- **Framework:** MLX Swift via `mlx-swift-lm` v2.30.6 SPM package
- **Libraries used:** `MLXVLM`, `MLXLMCommon`, `MLX`
- **Model download:** ~1 GB on first run (cached by Hugging Face Hub)
- **Inference:** Pass `CIImage` + text prompt → get text response
- **Prompt:** "Read the text on this book spine. Return only the title and author in the format: Title by Author."
- **Temperature:** 0.1 (low for deterministic reading)
- **Max tokens:** 100
- **GPU memory config:** `MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)`

### Platform Requirements

- **Metal GPU required** — will NOT work in iOS Simulator
- **Apple Silicon** — any A-series or M-series chip
- **iOS 17.0+, macOS 14.0+**
- Physical device only for testing

### Message Format for VLM

```swift
let messages: [[String: Any]] = [
    ["role": "user", "content": [
        ["type": "image"],
        ["type": "text", "text": prompt]
    ]]
]
let userInput = UserInput(messages: messages, images: [.ciImage(ciImage)], videos: [])
```

---

## Benchmark Results (mybooks-001.heic, 21 books)

### Detection Count Comparison

| Pipeline | Spines Detected | Time |
|----------|----------------|------|
| Classical | 36 | ~10s |
| YOLO + Vision OCR | 5 | ~10s |
| YOLO + VLM | 5 | ~98s |

### YOLO + VLM Detailed Results

| # | VLM Read Text | Metadata Match | Correct? |
|---|---------------|---------------|----------|
| 0 | "The Count of Monte Cristo." | The Count of Monte Cristo (Alexandre Dumas) | YES |
| 1 | "HOW THE OCEAN WORKS CERESIYT NORTON 100 YEARS" | How the Ocean Works (wrong author) | PARTIAL |
| 2 | "The Fox by David Foster Wallace" | Wallace's Dialects (wrong) | NO — VLM hallucinated |
| 3 | "Genius by James C." | Criminal Genius (wrong) | NO — merged 2 books |
| 4 | "A Hacker's Middle School Bicycle" | Wrong match | NO — VLM hallucinated |

### YOLO + Vision OCR Detailed Results (same detections)

| # | Vision OCR Text | Metadata Match | Correct? |
|---|----------------|---------------|----------|
| 0 | "ALEXANDRE DUMAS THE COUNT OF MONTE CRISTO" | Wrong match (but OCR was accurate) |
| 1 | "THE BLUE MACHINE HOW THE OCEAN WORKS HELEN CZERSKI" | The Blue Machine (Helen Czerski) | YES |
| 2 | "Abundance Derek Thompson ... THE BOX PRINCETON" | The Barrel and Box (wrong) | NO — merged books |
| 3 | "SOPHIE'S WORLD GENIUS Jostein Gaarder JAMES GLEICK" | James Watson (wrong) | NO — merged books |
| 4 | "A Hacker's Mind \| Bruce Schneier" | A Hacker's Mind (Bruce Schneier) | YES |

---

## Key Learnings

### 1. COCO "book" Class is Wrong for Bookshelves

The fundamental problem: COCO class 73 ("book") was trained on images of books as standalone objects (book lying on a table, open book, etc.) — NOT individual spines in a dense shelf. The model sees a row of books as a single "book" object or a few clusters.

**5 detections on a 21-book shelf** is not useful. Classical detection found 36 spine boundaries.

### 2. VLM Hallucination on Small/Unclear Crops

SmolVLM2-500M hallucinates text when the crop is small or unclear:
- "A Hacker's Mind" → "A Hacker's Middle School Bicycle"
- Two merged books → "The Fox by David Foster Wallace" (not a real book)

The VLM tries to be "smart" and guess rather than reading characters literally. Apple Vision OCR is more literal/reliable for text extraction, even though it makes character-level errors.

### 3. VLM Excels on Clear, Single-Spine Crops

When the detection gives a clean single-book crop, VLM reads the title correctly and formats it well:
- "The Count of Monte Cristo." — perfect, clean output

### 4. VLM is Slow

~98s total for 5 spines (model loading + 5 inferences) vs ~10s for Apple Vision OCR. Most of this is model loading overhead. Subsequent inferences are faster but still ~2-5s each.

### 5. Apple Vision OCR is Better for Dense Text

Vision OCR reads ALL text on the spine (title, author, publisher, series info). The VLM tries to summarize into "Title by Author" format and misses details. For metadata lookup, having more text is better — it feeds into FuzzyMatcher.

### 6. The Detection Step is the Bottleneck

Both recognizers (VLM and Vision OCR) work reasonably well when given good crops. The problem is **getting good crops** — the YOLO26n detector simply doesn't segment individual spines.

### 7. CoreML Export Toolchain

- Ultralytics Python package handles export cleanly: `model.export(format="coreml")`
- Must use `numpy<2.0` with `coremltools>=9.0` (numpy 2.x causes TypeError)
- YOLO26n is NMS-free (no need for `nms=True` flag, but doesn't hurt)
- Output is raw tensor `[1, 300, 6]` — need manual parsing in Swift
- YOLO11n with `nms=True` gives `VNRecognizedObjectObservation` directly (simpler but different architecture)

---

## What We'd Do Differently

1. **Don't use generic COCO detection for specialized tasks.** Book spine detection needs either:
   - A model trained/fine-tuned on bookshelf images
   - A "segment everything" approach (FastSAM) that finds visual boundaries without class labels
2. **Start with detection quality, not recognition quality.** We spent time integrating VLM when the real problem was upstream.
3. **Test detection-only first** (`--detect-only` flag) before wiring up the full pipeline.

---

## Next Steps

- **FastSAM-s**: "Segment everything" mode should find individual spine boundaries by visual edges/color changes, without needing book-specific training. See plan file for details.
- **Fine-tuning**: If FastSAM doesn't work well enough, consider fine-tuning YOLO on a book spine dataset (Roboflow has some).
- **Hybrid approach**: Use FastSAM for detection + Apple Vision OCR for recognition (best of both worlds — VLM not needed if OCR works well on good crops).
