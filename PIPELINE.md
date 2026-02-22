# Spine Detection Pipeline — Architecture, Tuning, and Lessons Learned

## Overview

The classical pipeline detects book spines in a bookshelf photo, OCRs each spine, and looks up book metadata via search APIs. It was iterated over 8 rounds against a 21-book reference shelf (`docs/samples/mybooks-001.heic` with ground truth in `mybooks-001.json`).

**Final score: 14/21 correct metadata matches (67%)** with Google Books enabled.

---

## Pipeline Architecture

```
Bookshelf Photo
    │
    ▼
┌─────────────────────────────────────┐
│  1. SPINE DETECTION                 │
│  ┌──────────────┐ ┌──────────────┐  │
│  │ VNContours   │ │ Projection   │  │
│  │ (dark/light) │ │ Profile      │  │
│  └──────┬───────┘ └──────┬───────┘  │
│         └──────┬─────────┘          │
│           Dedup (IoU)               │
│           Sort left→right           │
└─────────────────┬───────────────────┘
                  │  [normalizedRect]
                  ▼
┌─────────────────────────────────────┐
│  2. OCR PER SPINE                   │
│  • Crop (with padding for narrow)   │
│  • Dual orientation (.right/.left)  │
│  • Non-Latin filter                 │
│  • Query = largest bbox + 2nd bbox  │
└─────────────────┬───────────────────┘
                  │  searchQuery, allText
                  ▼
┌─────────────────────────────────────┐
│  3. METADATA LOOKUP                 │
│  • Google Books (primary)           │
│  • Open Library (fallback)          │
│  • Retry with cleaned query         │
│  • Take first result                │
└─────────────────────────────────────┘
```

### Key Files

| File | Role |
|------|------|
| `ImageProcessing.swift` | Preprocessing (grayscale, contrast, Sobel-X edges), column projection profile, peak detection, cropping |
| `SpineDetectionServiceImpl.swift` | `ClassicalSpineDetector` (contour + projection + dedup), `SpineOCR` (dual-orientation OCR, query construction, Latin filter), `SpineDetectionServiceImpl` (orchestration) |
| `BookMetadataServiceImpl.swift` | Chains Google Books → Open Library with retry strategy |
| `GoogleBooksService.swift` | Google Books API v1 (maxResults=10, API key from Secrets) |
| `OpenLibraryService.swift` | Open Library search.json with `q=` parameter |

---

## Detection Stage

### Step 1: Contour Detection (`VNDetectContoursRequest`)

- `contrastAdjustment = 1.5`, `detectsDarkOnLight = true`
- Extracts bounding boxes of all contours
- Filters by: `aspectRatio >= 2.0`, `heightFraction >= 0.15`, `widthFraction <= 0.20`
- Converts Vision bottom-left origin to top-left origin

**Strengths:** Good at finding well-separated books with clear outlines.
**Weaknesses:** Produces overly wide rects for leaning/angled books. One wide contour can span multiple books.

### Step 2: Projection Profile Detection

1. **Preprocess**: Desaturate → boost contrast (1.5×) → Sobel-X edge detection (intensity 5.0)
2. **Column sums**: Render edge image to 8-bit grayscale buffer, sum each column's intensity → 1D signal of width = image pixel width
3. **Peak detection**: Find local maxima above `threshold = maxSum × 0.05`, with `minPeakDistance = imageWidth × 0.015`. Greedy selection: strongest peaks first, skip if too close to already-selected peak.
4. **Valley-depth filtering**: For each pair of adjacent peaks, find the valley minimum between them. If `valleyMin / avgPeakHeight >= 0.50`, the valley is too shallow → merge segments (drop the peak). This prevents internal spine features (text, logos) from being mistaken for boundaries.
5. **Edge peaks**: Insert synthetic peaks at x=0 and x=imageWidth if the first/last detected peak is >2% from the image edge. This ensures the leftmost and rightmost books get rects even when their outer edges don't produce strong edge peaks.
6. **Width filtering**: Skip spines narrower than 1% or wider than 20% of image width.

**Strengths:** Finds boundaries between adjacent books reliably. Edge peaks ensure full shelf coverage.
**Weaknesses:** Cannot separate books in a tight cluster where there's no clear vertical edge between them (e.g. three thin paperbacks pressed together).

### Step 3: Merge and Deduplicate

- Combine candidates from both methods
- IoU deduplication at threshold 0.5 (if two rects overlap >50%, keep the first)
- Sort left-to-right by x-coordinate

---

## OCR Stage

### Dual Orientation

Vision's `VNRecognizeTextRequest` needs an orientation hint for rotated text on book spines. We run OCR twice:
- `.right` — text reads top-to-bottom (common for English spines)
- `.left` — text reads bottom-to-top (some publishers)

Selection logic:
1. If one orientation produces Latin text and the other doesn't → pick the Latin one
2. Otherwise → pick the one with higher average confidence across observations

**This was the single biggest OCR quality improvement.** Books like "The Sol Majestic" went from garbled to perfectly readable.

### Horizontal Padding

For spines under 200px wide, the crop is expanded by 30% on each side (clamped to image bounds). This gives Vision more context and dramatically improved OCR on narrow spines.

**Impact:** God Equation, Can American Capitalism Survive?, Reverberation all went from garbled to readable.

### Non-Latin Filter

Vision sometimes hallucinates Thai, Arabic, or CJK text on certain spine images. We check that >50% of Unicode scalars fall in the Latin range (0x0020–0x024F). Non-Latin results are rejected.

### Query Construction

From the OCR observations, we:
1. Filter to observations with `confidence >= 0.3` and `text.count >= 3`
2. Sort by bounding box area (descending) — largest text is usually the title
3. Combine the top 2 observations: `title + " " + author`
4. Fallback to the single largest-area observation if only one passes the filter

The `allText` field separately captures ALL observations joined by `\n` (no filtering), for use in future fuzzy re-ranking.

---

## Metadata Lookup Stage

### Search Strategy

`BookMetadataServiceImpl` chains providers with retry:

```
For each query strategy:
    Try Google Books → return if results found
    Try Open Library → return if results found
    Next strategy...
```

Query strategies:
1. Full cleaned query (punctuation removed, whitespace normalized)
2. Long-words-only query (words ≥4 chars, removing likely OCR noise like "ord", "oN")

### Open Library Fix

**Critical discovery:** Open Library's `search.json` endpoint has two search parameters:
- `title=` — exact title matching, fails when query includes author names or OCR noise
- `q=` — general full-text search, handles messy queries gracefully

Switching from `title=` to `q=` was the single biggest metadata improvement, going from near-zero Open Library matches to 9/21.

### Google Books API

**Critical discovery:** The Google Books API was disabled on the GCP project (403 error). All lookups were falling through to Open Library. Enabling it jumped results from 12/21 to 14/21. Google Books handles OCR typos much better than Open Library (e.g. "tomic Habits" → Atomic Habits, "Tell Me Everythina" → Tell Me Everything).

---

## Iteration History

### Baseline (Iteration 0)

| Parameter | Value |
|-----------|-------|
| peakThresholdFraction | 0.08 |
| valleyDepthThreshold | 0.40 |
| minPeakDistanceFraction | 0.025 |
| maxWidthFraction | 0.30 |
| OCR orientation | .right only |
| Crop padding | None |
| Non-Latin filter | No |
| Edge peaks | No |
| OL search param | `title=` |

**Result:** 7/21 OCR queries matchable, 3/21 metadata matches.

**Problems:** Merged spines (Monte Cristo + 2 books in one rect), single-observation query selection picking wrong text, garbled OCR on narrow/dark spines, single orientation missing rotated text.

### Iteration 1: Aggressive Peak Sensitivity

Changed: `peakThreshold=0.03, valleyDepth=0.60, minPeakDist=0.012`, all-text concatenation for query.

**Result:** 48 spines detected (too many), ~10/21 matchable.
**Lesson:** Going too sensitive on peak detection causes massive false splits. Every internal spine feature (text block, logo, color band) becomes a "boundary." Concatenating all OCR text into the query floods it with garbage.

### Iteration 2: Middle Ground + Dual OCR

Changed: `peakThreshold=0.05, valleyDepth=0.50, minPeakDist=0.015`, dual orientation OCR, largest-bbox query with author.

**Result:** 36 detected, ~13/21 matchable.
**Lesson:** Dual OCR orientation was a huge win. Vision hallucinates Thai/CJK text with wrong orientation — need Latin filter.

### Iteration 3: Padding + Width Limits

Changed: `maxWidthFraction=0.12`, 30% horizontal padding for narrow crops, non-Latin filter, contour width filter.

**Result:** 35 detected, ~15/21 matchable.
**Lesson:** Padding was the biggest single detection improvement — many narrow spines went from garbled to readable. But `maxWidth=0.12` was too tight — lost Count of Monte Cristo entirely (it's a wide leaning book at ~17% of image width).

### Iteration 4: Relaxed Width

Changed: `maxWidthFraction=0.15`.

**Result:** Similar to iteration 3, Monte Cristo still missing.
**Lesson:** The Monte Cristo area doesn't have projection profile peaks within it — it's a single leaning book with no internal vertical edges to detect. Need a different approach for the image edges.

### Iteration 5: Edge Peaks

Changed: `maxWidthFraction=0.20`, added synthetic peaks at x=0 and x=imageWidth.

**Result:** 36 detected, ~16/21 matchable, Monte Cristo recovered.
**Lesson:** Edge peaks are a simple, effective way to ensure full shelf coverage. Books at the far edges of the photo often lack detectable boundary peaks on their outer side.

### Iteration 6: First Metadata Test

Changed: No detection changes. First test with `--lookup` flag.

**Result:** 9/21 metadata matches (Google Books disabled, OL using `title=`).
**Critical finding:** Google Books API returned 403 — all lookups fell through to Open Library. OL's `title=` parameter fails on combined title+author queries. Fixed to `q=`.

### Iteration 7: Title-Only Queries (Reverted)

Changed: Search query = title only (largest bbox, no author).

**Result:** 7/21 metadata matches — WORSE.
**Lesson:** Title-only queries are too generic for search APIs. "GENIUS" returns Pascal's Pensées, "ACCELERATE" returns Brave New World. The author text, despite sometimes being garbled, provides crucial disambiguation. Reverted to combined title+author queries.

### Iteration 8: Search Retry Strategy

Changed: Combined title+author query, with retry (clean punctuation, remove short words ≥4 chars), try both cleaned and original on both providers.

**Result:** 12/21 with Open Library only, 14/21 with Google Books enabled.
**Lesson:** Retry with cleaned queries catches cases where punctuation or short garbled words break the search. The retry was cheap (one extra API call) and caught Accelerate and Sol Majestic.

---

## Current Parameters (as of Iteration 8)

```swift
// ClassicalSpineDetector calibration constants
minimumAspectRatio: 2.0
minimumHeightFraction: 0.15
minPeakDistanceFraction: 0.015
peakThresholdFraction: 0.05
iouDeduplicationThreshold: 0.5
maxWidthFraction: 0.20
valleyDepthThreshold: 0.50

// Image preprocessing
saturation: 0.0 (full grayscale)
contrast: 1.5
sobelIntensity: 5.0

// OCR
orientations: .right + .left (pick higher avg confidence, prefer Latin)
minimumTextHeight: 0.01
cropPadding: 30% horizontal for spines < 200px wide
nonLatinFilter: >50% Latin scalars required
queryMinLength: 3 characters
queryMaxLength: 60 characters

// Edge peaks
insertLeftEdge: if first peak > 2% from left
insertRightEdge: if last peak > 2% from right
```

---

## Final Results Against Reference Shelf (21 books)

### Correctly Matched (14/21)

| Book | Search Query | Source |
|------|-------------|--------|
| The Count of Monte Cristo | ALEXANDRE COUNT OF | Google Books |
| Nervous Energy | HARNESS THE POWER OF YOUR ANXIETY | Google Books |
| Accelerate | ACCELERATE Jez Humble, ord Gene Kim | Open Library (retry) |
| Atomic Habits | tomic Habits James | Google Books |
| East of Eden | JOHN STEINBECK EAST OF EDEN | Google Books |
| The God Equation | MICHIO KAKU THE GOD EQUATION | Google Books |
| The Blue Machine | THE BLUE MACHINE HELEN | Google Books |
| Abundance | Abundance Derek Thompson | Google Books |
| The Sol Majestic | THE SOL MAJESTIC FERRETT STEINMETZ | Google Books |
| Can American Capitalism Survive? | CAN AMERICAN CAPITALISM SURVIVE? PEARLSTEIN | Open Library |
| The Orbital Perspective | ORBITAL PERSPECTIVE RON GARAN | Google Books |
| Tell Me Everything | Tell Me Everythina Elizabeth Strout | Google Books |
| Sophie's World | SOPHIE'S WORLD lostein Gaarder | Google Books |
| A Hacker's Mind | A Hacker's Mind \| Bruce Schneier | Google Books |
| The Rust Programming Language | THE RUST KLABNIK | Google Books |

(Note: Some books detected in multiple adjacent rects — count is by unique book.)

### Failed (7/21)

| Book | Failure Type | Details |
|------|-------------|---------|
| Talking to My Daughter About the Economy | Merged spine | Thin book merged with Nervous Energy and Meditations into one rect |
| Meditations | Merged spine | Same merged rect as above — three thin books with no clear edge boundaries between them |
| This Boy's Life | Undetectable | Gold/yellow cover with minimal visible spine text; OCR produced non-Latin garbage |
| The Box | OCR error | OCR reads "DOX" / "DAY" instead of "BOX" — narrow dark spine |
| Genius | Wrong result | Query "GENIUS JAMES" too generic — returns wrong books. allText has "GLEICK" which could disambiguate |
| Reverberation | OCR error | OCR reads "REVERRERATIONI" — close but too garbled for any API |
| This Boy's Life | Undetectable | Gold cover, essentially no readable spine text in the photo |

---

## What Works Well

1. **Projection profile + contour hybrid** — catches both edge-detected and contour-detected spines
2. **Valley-depth filtering** — effectively merges false internal peaks while keeping real boundaries
3. **Dual OCR orientation** — critical for reading rotated spine text correctly
4. **Horizontal crop padding** — massive OCR quality improvement for narrow spines, essentially free
5. **Edge peaks** — simple trick that ensures full shelf coverage
6. **Google Books fuzzy search** — handles OCR typos remarkably well (missing first letters, character substitutions)
7. **Search retry with cleaned query** — catches cases where punctuation or noise words break the search

## What Doesn't Work

1. **Tightly packed thin books** — projection profile cannot find boundaries when there's no vertical edge between books pressed together
2. **Single-word title queries** — "GENIUS", "ACCELERATE" are too generic for search APIs without additional context
3. **Non-Latin spine text** — books with minimal Latin characters on the spine (decorative covers, non-English editions) are filtered out
4. **Garbled OCR on dark/narrow spines** — when the first letter is cut off ("tomic" for "Atomic") or characters are substituted, the query may not match. Google Books handles this better than Open Library, but both fail on severely garbled text.
5. **Leaning/angled books** — the projection profile assumes vertical spines. Angled books produce wide, merged edge zones.
6. **Combined title+author queries** — help with disambiguation but hurt when the author text is garbled. Title-only queries are too generic. This is a fundamental tension.

---

## Next Steps

### Completed: Phase 2.6 — Fuzzy Re-ranking

`FuzzyMatcher.swift` scores API results against full OCR text (title overlap + author match). BookMetadataService protocol extended with `ocrContext` param.

### Completed: Phase 3 — ML Pipeline (YOLO26n + SmolVLM2)

Added pluggable pipeline architecture via `SpineDetector` + `SpineRecognizer` protocols, `DetectionPipeline` enum, and `PipelineFactory`. Integrated YOLO26n CoreML for detection and SmolVLM2-500M via MLX Swift for recognition. **Result: disappointing — YOLO26n only detected 5 spines vs 36 classical.** COCO class 73 "book" is not trained for individual spine segmentation.

Full details: [YOLO.md](YOLO.md)

### In Progress: FastSAM-s Instance Segmentation

Replace YOLO26n detection with FastSAM-s "segment everything" mode. FastSAM segments all visually distinct regions without class labels — should find individual spines by color/edge boundaries. See plan file for architecture.

### Future Ideas

- Fine-tune YOLO on a book spine dataset (Roboflow has some)
- VNRecognizeTextRequest revision3 — may improve OCR accuracy on newer iOS
- Post-OCR spell correction — correct common substitutions (l→J, v→e)
- Barcode/ISBN scanning — some books have barcodes visible on the spine
- Multiple crop widths — try 2-3 widths per spine, pick highest confidence OCR
- Perspective correction — dewarp image before detection if shelf is angled
