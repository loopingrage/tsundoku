---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: []
session_topic: 'Tsundoku - personal iOS app for cataloging physical book collections via bookshelf photos using on-device processing and local storage'
session_goals: 'Photo-based book detection, automatic metadata lookup, searchable categorized catalog, on-device ML processing, privacy-first local storage, auto-categorization/tagging'
selected_approach: 'ai-recommended'
techniques_used: ['Question Storming', 'Cross-Pollination', 'Constraint Mapping']
ideas_generated: [20]
context_file: ''
session_active: false
workflow_completed: true
---

# Brainstorming Session Results

**Facilitator:** Jose
**Date:** 2026-02-21

## Session Overview

**Topic:** Tsundoku - a personal iOS app for cataloging physical book collections through bookshelf photos, using on-device processing and local storage

**Goals:**
- Photo-based book detection and identification from bookshelf images
- Automatic metadata lookup (title, author, genre, etc.)
- Searchable, categorized local catalog
- Maximize on-device processing (computer vision, ML) to minimize costs
- Fully offline/local data storage - no cloud dependency
- Auto-categorization and tagging (fiction/non-fiction, genre, etc.)

**Key Constraints:**
- Personal use (single user)
- Cost-conscious - minimize/eliminate 3rd party service costs
- Privacy-first - all data stays on device
- iOS platform

### Session Setup

_Session initialized with clear focus on a privacy-first, on-device book cataloging app. The core challenge spans computer vision (spine/cover detection), OCR, metadata resolution, and local data management - all within iOS platform constraints and a zero-cost philosophy._

## Technique Selection

**Approach:** AI-Recommended Techniques
**Analysis Context:** Personal iOS book cataloging app with focus on on-device processing, privacy-first storage, and automatic book detection/categorization

**Recommended Techniques:**

- **Question Storming:** Map the full design space by generating questions before solutions - surface edge cases, UX decisions, and technical challenges hiding beneath the clear core concept.
- **Cross-Pollination:** Raid other domains (plant ID apps, museum catalogs, retail checkout, wine label scanners) for proven patterns that can be adapted to book detection and cataloging.
- **Constraint Mapping:** Systematically map all constraints (on-device ML, local storage, zero cost), separate real from assumed limitations, and find creative pathways through them.

**AI Rationale:** The project has a clear vision but wide-open design space with hard technical constraints. This sequence maps boundaries first, then generates creative solutions from other domains, and finally stress-tests everything against real constraints.

## Technique Execution Results

### Question Storming

**Interactive Focus:** Mapped the full design space across 6 areas - capture, identification, metadata, ownership, processing, and UX

**Key Questions Surfaced:**

**Capture & Detection:**
- What happens when books are stacked horizontally on top of vertical books?
- What if you can't fit all books in one photo? How does the app handle multi-photo sessions?
- How does the app avoid duplicating books that appear in overlapping photos or across sessions?
- Could a video/panorama approach work instead of discrete photos?
- How does lighting, angle, and shadow affect detection?

**Identification & Matching:**
- What if the spine only shows a partial title or no author?
- What if it's a common title like "Origins" with 20 possible matches?
- What about books with no text on the spine (design-only spines, manga)?
- How fuzzy can OCR matching get before it becomes unreliable?
- Where does metadata come from if trying to stay offline?

**Ownership & State:**
- How does the app handle books that aren't yours (wife's books on same shelf)?
- Does the app need to track read/unread status?
- If a book disappears from a shelf photo, does that mean anything?

**Processing:**
- What happens if the phone locks mid-processing?
- How long is acceptable to wait? (Answered: 2-minute threshold)
- Should there be progress indication or background processing?

**Key Decisions Made During Question Storming:**
- Location tracking is unnecessary - just "do I own this book?"
- Fully offline is NOT required - just no expensive cloud services. Free API calls for metadata are fine.
- On-device processing for CV/OCR, online for metadata lookup

### Cross-Pollination

**Domains Raided:** 9 industries analyzed for transferable patterns

**Domain 1 - Plant ID Apps (PlantNet, PictureThis):**
- Confidence + candidates pattern: show top matches with percentages, user taps to confirm
- Works with terrible photos - solved imperfect input problem
- Builds personal collection over time ("your garden" = "your library")

**Domain 2 - Document Scanners (Adobe Scan, Apple Notes):**
- Auto-detect boundaries in messy scenes
- Apple Vision framework does rectangle detection + text recognition natively, free, on-device
- Batch-process multiple "documents" from single photo
- Perspective correction for angled shots

**Domain 3 - Retail Shelf Scanning:**
- Vertical line detection to separate products - books are the same problem
- Handle "shelf changed since last scan" for duplicate/removal detection
- Process at section scale, not whole-store scale

**Domain 4 - Music Recognition (Shazam):**
- Works from fragments - partial signal identification
- Instant gratification UX pattern
- Graceful "I don't know" handling

**Domain 5 - Wine Label Apps (Vivino):**
- Multi-signal matching: OCR + visual fingerprint of label design
- Handle artistic/decorative typography on labels (= decorative book spines)
- Beautiful catalog UX: photo + metadata + notes

**Domain 6 - Google Lens / Apple Visual Look Up:**
- Can already identify books from covers - don't reinvent for single-book ID
- No persistent personal catalog though - that's Tsundoku's differentiator

**Domain 7 - Grocery Self-Checkout / Barcode Scanning:**
- Detect multiple barcodes in single frame at speed
- ISBN barcode as precision fallback for unidentified books
- Two-tier system: bulk photo (fast/imperfect) + barcode scan (slow/perfect)

**Domain 8 - Library Science:**
- Librarians use structured metadata systems (MARC records, subject headings)
- Open Library and Library of Congress have free APIs with millions of books
- Categories/genres already attached to book records - no need to build custom classification
- Edition handling is already solved in library metadata

**Domain 9 - Trading Card Collection Apps (TCGPlayer, Collectr):**
- "Scan binder page" mode: one photo, 9 cards detected = one photo, 15 spines detected
- Grid detection approach directly applicable to shelf scanning
- Collection overview with stats and value tracking
- Proven UX for "batch visual identification to personal catalog"

### Constraint Mapping

**Final Classified Constraints:**

| # | Constraint | Classification | Pathway |
|---|-----------|---------------|---------|
| 1 | No paid OCR/CV services | Hard Wall | Apple Vision framework (free, on-device) |
| 2 | No paid LLM API calls | Hard Wall | On-device ML only |
| 3 | No paid image segmentation | Hard Wall | MobileSAM/FastSAM (free, on-device) |
| 4 | Free API calls for book metadata | Confirmed OK | Open Library, Google Books free tiers |
| 5 | No recurring subscription costs | Hard Wall | One-time dev effort only |
| 6 | Catalog on device + iCloud backup | Hard Wall | SwiftData with standard device backup |
| 7 | Photos stay on device | Hard Wall | Never uploaded |
| 8 | Sending text queries to APIs is OK | Confirmed OK | Title/author queries to Open Library |
| 9 | No user account / zero friction | Hard Wall | Open and go |
| 10 | iOS / iPhone only | Hard Wall | No iPad, no Android, no web |
| 11 | On-device CV/OCR pipeline | Hard Wall | Core architecture decision |
| 12 | 2-minute processing threshold per photo | Soft Wall | Per-photo progress, queue multiple |
| 13 | Modern devices (iPhone 12+) | Soft Wall | Neural Engine required |
| 14 | Single user / personal use | Hard Wall | No sharing, no multi-user |
| 15 | No book location tracking | Confirmed | Just "do I own this" |
| 16 | Metadata-driven categories | Soft Preference | Pull from library APIs, simple normalization |
| 17 | Manual corrections allowed | Soft Preference | Edit wrong identifications |

**Constraints Eliminated During Session:**
- ~~Fully offline~~ → Just no expensive cloud services
- ~~Custom genre classification ML~~ → Steal from librarian metadata
- ~~Must pick one segmentation approach now~~ → Make it swappable, benchmark later
- ~~iPad support~~ → iPhone only
- ~~Cross-device sync~~ → Standard device backup is enough

**Key Constraint Insights:**
- Internet required for metadata lookup is an accepted tradeoff. App should handle offline gracefully with a "pending identification" queue.
- The segmentation layer should be architecturally swappable to allow benchmarking Apple Vision vs MobileSAM vs FastSAM against real shelf photos.
- Processing should show per-photo progress. 5 photos = 5 independent processing units, each within the 2-min threshold.

### Creative Facilitation Narrative

_Jose came in with a clear vision and strong technical instincts. The session's biggest value was in two areas: (1) eliminating assumed constraints (offline requirement, custom categorization ML) that would have added weeks of unnecessary complexity, and (2) discovering the multi-signal matching approach from cross-pollinating with wine label and retail scanning domains. The constraint mapping phase crystallized that the project is simpler than it first appears - many "hard problems" are already solved by free APIs and Apple's native frameworks._

## Idea Organization and Prioritization

### Theme 1: Capture & Detection Pipeline
_How the app sees, segments, and reads books from shelf photos_

- **Swappable Segmentation Layer** - Architecture that lets you benchmark Apple Vision vs MobileSAM vs FastSAM and swap without rewriting the pipeline. De-risks the core technical decision.
- **Vertical Edge Detection** - Use natural vertical lines between tightly packed spines as the segmentation signal. Borrowed from retail shelf scanning.
- **Multi-Photo Batch Processing** - Per-photo progress with immediate results. Each photo resolves independently within the 2-min threshold.
- **Video/Panorama Capture Mode** - Alternative to discrete photos: slow pan across shelf, app stitches and segments continuously.
- **Perspective Correction** - Borrowed from document scanners: de-skew angled shelf shots before segmentation.

### Theme 2: Identification & Matching
_How the app goes from OCR text to a confirmed book identity_

- **Multi-Signal Matching** - Combine OCR text + spine color + spine height/thickness + any visible cover art into a composite search query against book databases. Goes beyond what existing book apps do.
- **Confidence + Candidates Pattern** - "Did you mean: Sapiens (94%)? Sapientia (6%)?" Quick tap to confirm. Borrowed from plant ID apps.
- **Fuzzy OCR Tolerance** - Partial title extraction ("Sapi...") is enough to trigger a search. Treat OCR as a hint, not a requirement.
- **On-Device Confidence Scoring** - Only send API queries when OCR confidence is above threshold. Below threshold goes to "unidentified" bucket.
- **Two-Tier Capture** - Primary: bulk shelf photo (fast, imperfect). Fallback: single book barcode scan (precise). User chooses based on situation.

### Theme 3: Metadata & Categorization
_Where book data comes from and how it's organized_

- **Steal Categorization from Librarians** - Pull subject headings directly from Open Library / Google Books metadata. Don't build genre classification at all. Eliminates an entire ML problem.
- **Free API Stack** - Open Library API (free, comprehensive) + Google Books API (free tier) + Library of Congress. Multiple fallback sources.
- **Simple String Normalization** - Map verbose library categories to simple tags ("Fiction", "Sci-Fi") with basic rules, no ML.
- **Edition Agnostic** - Don't care about hardcover vs paperback vs anniversary edition. Just "I own this book." Simplifies matching enormously.

### Theme 4: UX & Interaction Model
_What it feels like to use the app_

- **Card-Collector UX Pattern** - One tap, multiple detections, swipeable review, confirm-and-add. Proven flow for batch visual identification, borrowed from TCG collector apps.
- **Graceful Degradation** - "Found 23, identified 19, 4 need your help." Honest about what it doesn't know. Turns imperfect ML into a feature.
- **Zero-Friction Onboarding** - No account, no login, open and scan. Maximum 1 tutorial screen.
- **Manual Add/Remove/Correct** - Edit wrong identifications, manually add books the camera missed, remove books that aren't yours.
- **Collection Stats** - "You own 347 books. 60% fiction, 25% non-fiction, 15% untagged." Simple dashboard.

### Theme 5: Architecture & Data
_Technical foundation and storage decisions_

- **SwiftData with Standard iCloud Backup** - No custom cloud infrastructure. Data persists through device backup automatically.
- **Offline-Capable, Online-Enhanced** - Segment + OCR works offline. Metadata lookup queues for when connected. "Pending identification" state for offline captures.
- **Modern Device Target (iPhone 12+)** - Neural Engine required. Unlocks MobileSAM/FastSAM and advanced Vision framework features.
- **Duplicate Detection Across Sessions** - When re-scanning a shelf, recognize books already in catalog. Don't create duplicates.

### Breakthrough Concepts

- **The Segmentation Benchmark Approach** - Don't argue about which model is best. Build a swappable layer, test all three against real shelf photos, let data decide. Saves weeks of premature debate.
- **Categorization is Already Solved** - The single biggest scope reduction: librarians already tagged every book. Just use their data. Eliminates an entire ML problem.
- **Multi-Signal Matching** - The compound query idea (text + color + height) is genuinely novel for a personal book app. Most existing apps do OCR-only or barcode-only.

### Prioritization Results

**Top 3 High-Impact Ideas:**
1. **Swappable Segmentation Layer** - Core architecture decision that de-risks everything else
2. **Multi-Signal Matching** - Dramatically improves identification accuracy without expensive services
3. **Steal Categorization from Librarians** - Eliminates an entire feature's worth of ML complexity

**Easiest Quick Wins:**
1. **Free API Stack** (Open Library + Google Books) - Can prototype metadata lookup in a day
2. **Zero-Friction UX** - No auth system to build means you skip weeks of work
3. **SwiftData with iCloud Backup** - Apple handles persistence and backup for you

**Most Innovative:**
1. **Multi-Signal Matching** - Goes beyond what existing book apps do
2. **Graceful Degradation UX** - Turns ML imperfection into a trustworthy user experience
3. **Card-Collector UX Pattern** - Proven interaction model adapted to a new domain

### Action Planning

**Priority 1: Swappable Segmentation Layer**
- **Why This Matters:** Everything else depends on reliably isolating individual book spines from a shelf photo
- **Next Steps:**
  1. Take 10-15 real bookshelf photos with varying conditions (lighting, density, angles)
  2. Build a minimal test harness comparing Apple Vision rectangle detection, MobileSAM, and FastSAM
  3. Measure accuracy (% of spines correctly isolated) and speed (time per photo)
  4. Select winner based on data, architect the layer to remain swappable
- **Success Indicators:** >80% spine isolation accuracy on dense shelves within 30 seconds

**Priority 2: Free API Metadata Stack**
- **Why This Matters:** Validates the full pipeline end-to-end (photo → segmentation → OCR → metadata → catalog entry)
- **Next Steps:**
  1. Prototype Open Library API integration - search by title/author
  2. Add Google Books API as fallback source
  3. Test with real OCR output (partial titles, misspellings) to see how forgiving the APIs are
  4. Map API response fields to your catalog data model (title, author, cover art, subject headings)
- **Success Indicators:** >70% correct book identification from partial OCR text

**Priority 3: Core UX Prototype**
- **Why This Matters:** Validates the user experience before investing in ML optimization
- **Next Steps:**
  1. Build camera capture → results review → catalog view flow
  2. Implement the card-collector swipe-to-confirm pattern for batch results
  3. Add graceful degradation: "identified X of Y, Z need your help"
  4. Add manual barcode scan fallback for unidentified books
- **Success Indicators:** Full capture-to-catalog flow working with mock data in under 5 taps

## Session Summary and Insights

**Key Achievements:**
- 20 organized ideas across 5 themes with clear technical pathways
- Eliminated 5 assumed constraints that would have added unnecessary complexity
- Discovered multi-signal matching approach from cross-domain analysis
- Identified that categorization is a solved problem (library metadata)
- Established clear 3-priority action plan with measurable success criteria

**Session Reflections:**
- The biggest value came from constraint mapping: several "hard requirements" (fully offline, custom genre ML) turned out to be assumptions. Eliminating them dramatically simplified the project scope.
- Cross-pollination with wine label apps and trading card collectors provided the most directly transferable UX patterns.
- The project is more feasible than it initially appears. Apple's native frameworks + free book APIs cover most of the technical surface area. The main engineering challenge is spine segmentation accuracy on dense shelves.

**Domains Referenced:** Plant ID apps, document scanners, retail shelf scanning, Shazam, wine label apps, Google Lens, barcode/grocery checkout, library science, trading card collection apps
