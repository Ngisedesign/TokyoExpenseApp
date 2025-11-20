# Tokyo Expense Tracker - Technical Architecture

## Overview

This document explains the technical architecture, design decisions, and framework integration for the Tokyo Expense Tracker receipt parsing system.

**Last Updated:** 2025-01-12 (V1 Complete, V2 Redesign in Progress)
**Status:** ⚠️ **HISTORICAL REFERENCE ONLY** - Project transitioned to Claude API

> **Note:** This document describes the hybrid on-device parser approach (Vision Framework + Foundation Models) that was successfully implemented in V1. The project has since transitioned to using the **Claude API** for receipt parsing, which provides better accuracy and simpler architecture. This document is preserved for technical learning and reference. See [JOURNEY.md](JOURNEY.md) for the full development story and [README.md](README.md) for current implementation.

**V1 Outcome:** HybridParser successfully solved all receipt parsing challenges. V2 simplified to Claude API instead of maintaining multiple parsers.

---

## Receipt Processing Pipeline

```
┌─────────────┐
│ Receipt     │
│ Image       │
│ (UIImage)   │
└──────┬──────┘
       │
       ├─────────────────────────────────┐
       │ Vision Framework                │
       │ VNRecognizeTextRequest          │
       │ - Japanese OCR                  │
       │ - Extract text + bounding boxes │
       └────────┬────────────────────────┘
                │
                ↓
       ┌────────────────────────┐
       │ OCRTextElement Array   │
       │ [text, boundingBox,    │
       │  confidence]           │
       └────────┬───────────────┘
                │
                ├──────────────────────────────────┐
                │ SpatialReceiptParser             │
                │ - Find "合計" keyword            │
                │ - Search nearby using coordinates│
                │ - Extract amount + date          │
                └────────┬─────────────────────────┘
                         │
                         ↓
                ┌────────────────────────────┐
                │ Foundation Models (LLM)    │
                │ - Extract merchant name    │
                │ - Classify business type   │
                └────────┬───────────────────┘
                         │
                         ↓
                ┌────────────────────────┐
                │ HybridParser           │
                │ Combines:              │
                │ • Spatial (amounts)    │
                │ • LLM (semantics)      │
                └────────┬───────────────┘
                         │
                         ↓
                 ┌───────────────┐
                 │ ParsedReceipt │
                 └───────────────┘
```

---

## Parser Strategy Pattern

**V1 Implementation:** 4 different parsers with a fallback chain (over-engineered)
**V2 Simplification:** 2 parsers only (Hybrid + Spatial fallback)

### V1 Parsers (What We Built & Learned)

### 1. HybridParser (iOS 26+) - PRIMARY

**Purpose:** Combines deterministic spatial parsing with semantic LLM understanding

**Architecture:**
```swift
Spatial Parser → Amounts, Dates (reliable, deterministic)
LLM (Foundation Models) → Merchant, Category (semantic, flexible)
```

**When Used:**
- iOS 26.0+ available
- Foundation Models accessible
- Best accuracy

**Strengths:**
- ✅ Reliable amount extraction (uses coordinates)
- ✅ Smart merchant categorization (uses LLM)
- ✅ Handles split amounts across lines
- ✅ Distinguishes payment from total spatially

**Limitations:**
- ⚠️ Requires iOS 26+
- ⚠️ Requires macOS 26+ for development

### 2. SpatialReceiptParser (iOS 18+) - FALLBACK

**Purpose:** Pure spatial analysis without LLM

**Architecture:**
```swift
Vision OCR coordinates → Find keywords → Extract nearby numbers
```

**When Used:**
- HybridParser fails
- iOS 18-25 (no Foundation Models)
- Foundation Models unavailable

**Strengths:**
- ✅ Deterministic (same input = same output)
- ✅ Works on older iOS versions
- ✅ No API dependencies

**Limitations:**
- ⚠️ Cannot categorize merchants semantically
- ⚠️ Simple keyword matching only

### 3. AppleIntelligenceParser (iOS 18+) - PATTERN FALLBACK

**Purpose:** Pattern-based text extraction with intelligent fallbacks

**Architecture:**
```swift
Regex patterns → Extract amounts near keywords → Basic categorization
```

**When Used:**
- Spatial parser fails
- No bounding box data available
- Legacy compatibility

**Strengths:**
- ✅ No coordinate data needed
- ✅ Works with flat text
- ✅ Handles split amounts with heuristics

**Limitations:**
- ⚠️ Less accurate than spatial approach
- ⚠️ Sensitive to receipt format variations

### 4. ReceiptParser - LAST RESORT

**Purpose:** Basic regex matching for simple receipts

**When Used:**
- All other parsers fail
- Always available (minimum iOS 18)

**Strengths:**
- ✅ Always works (fallback safety net)
- ✅ Very simple implementation

**Limitations:**
- ❌ Low accuracy
- ❌ Rigid patterns
- ❌ No semantic understanding

---

### V2 Recommendation: Keep Only 2 Parsers

**For V2 Redesign, migrate only:**

1. **HybridParser** (Primary) - ✅ PROVEN WINNER
   - Successfully parsed BOOKOFF ¥400 and Yodobashi ¥159,810
   - Spatial + LLM = best accuracy
   - Use whenever iOS 26+ available

2. **SpatialReceiptParser** (Fallback) - ✅ RELIABLE FALLBACK
   - Works without Foundation Models
   - Deterministic, no API dependencies
   - Good enough for simple receipts

**Skip for V2:**
- ❌ AppleIntelligenceParser - Unnecessary, adds complexity
- ❌ Basic ReceiptParser - Too simplistic, rarely needed

**Rationale:** For a 7-day trip focused app, 2 parsers provide sufficient coverage without over-engineering.

---

## Why Hybrid Spatial + LLM Architecture?

### The Problem We Discovered

**Initial Approach (Pure LLM):**
```
Image → OCR → Text Array → Foundation Models → Result
```

**Failed on BOOKOFF Receipt:**
- **Expected:** ¥400 (total)
- **Extracted:** ¥1,660 (wrong!)
- **Root Cause:** LLM received flat text, confused payment section with total

```
Receipt text (flat):
合計 400
お預り 1,000
お釣り 600

LLM thought: "1,000 + 660 = 1,660" (payment + change ❌)
Should have been: "400" (total marked with 合計 ✅)
```

### The Solution

**Discovery:** Vision Framework ALREADY captures bounding box coordinates!

**Insight:** Spatial proximity = layout understanding
- "合計" at (x: 0.1, y: 0.5)
- "400" at (x: 0.8, y: 0.5)
→ Same Y coordinate = Same line = This is the total! ✅

- "お預り" at (x: 0.1, y: 0.3)
- "1,000" at (x: 0.8, y: 0.3)
→ Different Y coordinate = Different section = Payment, not total

**New Approach (Hybrid):**
```
Image → OCR (with coordinates) → Spatial Parser (amounts) + LLM (semantics) → Result
```

### Results

| Receipt | Pure LLM | Spatial Parser | Hybrid |
|---------|----------|----------------|--------|
| BOOKOFF ¥400 | ❌ ¥1,660 | ✅ ¥400 | ✅ ¥400 |
| Yodobashi ¥159,810 | ✅ ¥159,810 | ✅ ¥159,810 | ✅ ¥159,810 |
| Merchant name | ✅ Good | ⚠️ Basic | ✅ Best |
| Category | ✅ Smart | ❌ None | ✅ Smart |

**Conclusion:** Hybrid = Deterministic amounts + Semantic understanding

**V1 Validation:** HybridParser successfully parsed all test receipts. This is the proven solution to migrate to V2.

---

## Framework Integration Details

### Vision Framework (iOS 13+)

**What We Use:**
```swift
VNRecognizeTextRequest(completionHandler:)
request.recognitionLevel = .accurate
request.recognitionLanguages = ["ja-JP", "en-US"]
request.usesLanguageCorrection = true
```

**What We Get:**
```swift
struct OCRTextElement {
    let text: String                // "合計"
    let boundingBox: CGRect         // (x: 0.1, y: 0.5, width: 0.05, height: 0.02)
    let confidence: Float           // 0.95
}
```

**Coordinate System:**
- **Normalized:** 0.0 to 1.0 (not pixels!)
- **Origin:** Bottom-left corner (CoreGraphics coordinate system)
- **X-axis:** Left (0.0) → Right (1.0)
- **Y-axis:** Bottom (0.0) → Top (1.0)

**Example:**
```
(0,1)────────────────(1,1)  ← Top
  │                    │
  │   Receipt Image    │
  │                    │
(0,0)────────────────(1,0)  ← Bottom (origin)
```

**Language Support:**
- ✅ Japanese ("ja-JP") - Excellent for horizontal text
- ✅ English ("en-US") - Mixed language receipts
- ⚠️ Vertical text - Limited support
- ❌ Handwriting - Poor accuracy

**Performance:**
- Recognition level: `.accurate` (slower but better)
- Japanese OCR: ~1-2 seconds on iPhone 16 Pro
- Confidence scores: Typically 0.85-0.98 for printed receipts

### Foundation Models (iOS 26+)

**What We Use:**
```swift
@Generable
struct ReceiptSemantics {
    var merchantName: String?
    var category: String?
    var fallbackAmount: Double?
}

let session = LanguageModelSession()
let response = try await session.respond(
    to: prompt,
    generating: ReceiptSemantics.self
)
```

**API Characteristics:**
- **Input:** Text only (String)
- **Output:** Text or @Generable struct
- **Processing:** On-device (private)
- **Async:** All methods async/await

**Capabilities:**
- ✅ Semantic text understanding
- ✅ Structured data extraction via @Generable
- ✅ Context-aware reasoning
- ✅ Japanese language support

**Limitations:**
- ❌ **NO image input** (text-only API!)
- ❌ Cannot see spatial layout
- ❌ Cannot process bounding boxes directly
- ⚠️ Requires iOS 26.0+
- ⚠️ Requires macOS 26.0+ for development

**What It's Good For:**
- ✅ Merchant name extraction ("ヨドバシカメラ" → "Yodobashi Camera")
- ✅ Business type classification ("electronics", "food", "transport")
- ✅ Semantic disambiguation (is this a restaurant or retail?)

**What It's NOT Good For:**
- ❌ Amount extraction (no visual context → confused by similar numbers)
- ❌ Spatial relationships (can't see which text is near other text)
- ❌ Layout understanding (doesn't know what's in payment vs total section)

**Why We Still Use It:**
- Foundation Models excels at **semantic** tasks
- Spatial parser handles **structural** tasks
- Together = reliable structure + smart semantics

### Translation Framework (iOS 17+)

**Status:** Not yet fully implemented

**Current Approach:**
- Keyword-based translation in `TranslationService.swift`
- Common receipt terms mapped manually:
  - 合計 → "Total"
  - 小計 → "Subtotal"
  - 内消費税 → "Tax"

**Future Enhancement:**
- Use Translation Framework for full merchant name translation
- Requires language model download (50-100MB)
- On-device translation preserves privacy

---

## Spatial Proximity Algorithm

### Core Concept

**Problem:** Given OCR text elements with coordinates, find the amount associated with "合計" (total).

**Solution:** Search for numbers spatially near the keyword.

### Algorithm Steps

```swift
1. Find keyword: Search for "合計" or "小計" in text elements
   → Found at boundingBox (x: 0.1, y: 0.5)

2. Check same line: Is there a number on the same line?
   → Extract amount from same text element if found

3. Search nearby: Look for numbers within distance threshold
   → Calculate distance between bounding boxes
   → Distance < 0.15 (normalized units) = "nearby"

4. Spatial filtering:
   → Prefer elements to the right (higher x coordinate)
   → Prefer elements on same horizontal line (similar y coordinate)

5. Extract amount:
   → Parse number from nearby element
   → Handle commas (159,810 → 159810)
   → Return as Decimal
```

### Distance Calculation

```swift
func distanceBetween(_ rect1: CGRect, _ rect2: CGRect) -> CGFloat {
    let center1 = CGPoint(x: rect1.midX, y: rect1.midY)
    let center2 = CGPoint(x: rect2.midX, y: rect2.midY)

    let dx = center1.x - center2.x
    let dy = center1.y - center2.y

    return sqrt(dx * dx + dy * dy)
}
```

**Threshold:** 0.15 normalized units
- Horizontal receipts: typically 0.05-0.10 between keyword and amount
- Allows for spacing variations
- Filters out unrelated numbers

### Split Amount Handling

**Challenge:** Yodobashi receipt splits "¥159,810" across two lines:
```
Line 23: "159,"
Line 24: "810"
```

**Detection:**
```swift
if text.hasSuffix(",") {
    // Check next line for continuation
    let nextLine = elements[index + 1]
    if nextLine.text.matches("^[0-9]+$") {
        // Combine: "159" + "810" = "159810"
    }
}
```

**Validation:**
- Next line must be purely digits
- Vertical alignment checked (similar x coordinate)
- Combined value must be reasonable (100 < amount < 10,000,000)

### Edge Cases

**Multiple "合計" Keywords:**
- Some receipts have subtotal (小計) and total (合計)
- Priority: 合計 > 小計
- Take the largest reasonable amount

**No Nearby Number:**
- Fallback: Search next 3 lines sequentially
- Handles poor OCR spacing
- Last resort: Use largest amount in receipt

**Points vs Totals:**
- Ignore lines containing "ポイント" (points)
- Spatial separation prevents confusion
- Points section typically below total section

---

## Data Model Evolution

### Initial Design (Text Only)

```swift
struct OCRResult {
    let recognizedText: [String]
    let confidence: Float
}
```

**Problem:** Lost spatial information!

### Current Design (Spatial Data)

```swift
struct OCRTextElement {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

struct OCRResult {
    let recognizedText: [String]       // Backward compatibility
    let textElements: [OCRTextElement] // NEW: Spatial data
    let confidence: Float
    let boundingBoxes: [CGRect]        // Backward compatibility
}
```

**Benefits:**
- Preserves spatial information
- Backward compatible with old parsers
- Enables hybrid parsing approach

---

## Parser Selection Logic

### Flow in AddExpenseView.swift

```swift
Task {
    let parsedReceipt: ParsedReceipt

    if #available(iOS 26.0, *) {
        // Try HybridParser first (best accuracy)
        do {
            parsedReceipt = try await HybridParser.shared.parseReceipt(
                from: ocrResult.textElements,
                confidence: ocrResult.confidence
            )
        } catch {
            print("⚠️ Hybrid parser failed: \(error)")
            // Fallback to pure spatial parser
            parsedReceipt = SpatialReceiptParser.shared.parseReceipt(
                from: ocrResult.textElements,
                confidence: ocrResult.confidence
            )
        }
    } else {
        // iOS 18-25: Use spatial parser only (no Foundation Models)
        parsedReceipt = SpatialReceiptParser.shared.parseReceipt(
            from: ocrResult.textElements,
            confidence: ocrResult.confidence
        )
    }

    // Apply to UI...
}
```

### Decision Tree

```
Is iOS 26+ available?
├─ YES → Try HybridParser
│        ├─ Success → Use result ✅
│        └─ Error → Fallback to SpatialParser
│
└─ NO (iOS 18-25) → Use SpatialParser directly
```

---

## Known Limitations & Tradeoffs

### Vision Framework Limitations

**Vertical Text:**
- Japanese vertical text (右→左, 上→下) has reduced accuracy
- Workaround: Rotate image or use manual entry
- Future: May improve with iOS updates

**Handwritten Receipts:**
- Vision Framework optimized for printed text
- Handwriting recognition poor
- Recommendation: Manual entry for handwritten receipts

**Faded/Blurry Images:**
- OCR confidence drops below 0.7
- UI should prompt user to retake photo
- Consider showing confidence indicator

### Foundation Models Limitations

**Text-Only Input:**
- Cannot process images
- No visual layout understanding
- Requires OCR preprocessing

**iOS 26+ Requirement:**
- Not available on older devices/simulators
- Graceful degradation required
- Fallback parsers must be maintained

**Development Requirements:**
- macOS 26+ needed for Foundation Models development
- Older macOS can build but can't use Foundation Models APIs
- Testing requires actual iOS 26+ device or simulator

### Spatial Parser Limitations

**Assumes Standard Layout:**
- Works best with horizontal text
- Expects keyword + nearby amount pattern
- Complex multi-column layouts may confuse it

**No Semantic Understanding:**
- Can find amounts but can't categorize merchants
- Doesn't understand business type
- Relies on keyword matching only

### Hybrid Parser Tradeoffs

**Increased Complexity:**
- Maintains 4 different parsers
- Fallback chain adds code complexity
- More potential failure points

**But:**
- Best accuracy across iOS versions
- Graceful degradation
- Separates structural from semantic concerns

---

## Performance Characteristics

### Timing Breakdown (iPhone 16 Pro)

| Step | Time | Notes |
|------|------|-------|
| OCR (Vision) | 1-2s | Depends on image size |
| Spatial parsing | <50ms | Simple coordinate math |
| Foundation Models | 1-3s | LLM inference |
| **Total (Hybrid)** | **2-5s** | Acceptable for UX |
| **Total (Spatial only)** | **1-2s** | Faster fallback |

### Memory Usage

- OCR processing: ~50-100MB (image + Vision Framework)
- Foundation Models: ~200-500MB (model in memory)
- Spatial parsing: <1MB (minimal overhead)

### Battery Impact

- Vision Framework: Moderate (GPU usage)
- Foundation Models: Low (Neural Engine, on-device)
- Overall: Comparable to photo editing apps

---

## Testing Strategy

### Test Receipts

**1. Yodobashi Camera Receipt:**
- **Amount:** ¥159,810
- **Challenge:** Split amount across lines ("159," + "810")
- **Tests:** Split amount handling
- **Expected:** ✅ Correctly extracts ¥159,810

**2. BOOKOFF Receipt:**
- **Amount:** ¥400
- **Challenge:** Payment section (¥1,660) above total
- **Tests:** Spatial disambiguation of sections
- **Expected:** ✅ Extracts ¥400, ignores ¥1,000 payment

**3. Convenience Store (Future):**
- **Amount:** ~¥500-1,500
- **Challenge:** Many line items
- **Tests:** Multiple amounts, finds correct total
- **Expected:** Extracts 合計 line only

### Validation Criteria

**Success Criteria:**
- Amount within ±1% of actual (or exactly correct)
- Merchant name captured (Japanese or English)
- Date extracted correctly (or null if unclear)
- Category suggested (or null if ambiguous)

**Failure Modes:**
- Wrong amount (> 5% error) → Test fails
- No amount extracted → Check OCR quality
- Confidence < 0.5 → Prompt user to verify

### Console Output Guide

**Success Indicators:**
```
📍 Spatial Parser - Processing 55 text elements
📊 Searching for total amount using spatial analysis...
   Found total keyword '合計' at position ...
   ✅ Found amount near keyword: ¥400
```

**Warning Signs:**
```
⚠️ Could not find total amount
⚠️ LLM amount (1660) differs from spatial (400) by 315%
   Using spatial parsing result
```

**Error Conditions:**
```
❌ Foundation Model Error: assetsUnavailable
   → macOS < 26 or iOS < 26
   → Falling back to spatial parser

❌ No text found in image
   → OCR failed, image too blurry
   → Prompt user to retake photo
```

---

## Future Enhancements

### Short-Term (Before Tokyo Trip)

1. **Add confidence thresholds:**
   - Show warning if OCR confidence < 0.7
   - Prompt user to verify amounts

2. **Improve split amount detection:**
   - Handle more edge cases
   - Better validation of combined amounts

### Medium-Term (Post-Trip)

3. **Translation Framework integration:**
   - Replace keyword-based translation
   - Full merchant name translation

4. **Receipt templates:**
   - Learn common merchants
   - Cache extraction patterns
   - Faster parsing for repeat merchants

### Long-Term (iOS 27+?)

5. **VNRecognizeDocumentsRequest:**
   - Apple's document understanding API (if released)
   - Automatic table detection
   - Structured cell-by-cell access
   - Would simplify spatial parser significantly

6. **Foundation Models with images:**
   - If Apple adds image input to LanguageModelSession
   - Would eliminate need for spatial parser
   - Single unified LLM-based approach

---

## References

### Apple Documentation

- [Vision Framework](https://developer.apple.com/documentation/vision)
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels) (iOS 26+)
- [Translation Framework](https://developer.apple.com/documentation/translation)

### Project Documentation

- `CLAUDE.md` - Product specification
- `README.md` - User guide and quick start
- `STATUS.md` - Implementation status
- `TESTING_GUIDE.md` - Testing procedures (to be created)
- `MACOS_26_UPGRADE.md` - Upgrade testing checklist

### Key Source Files

- `OCRService.swift` - Vision Framework integration
- `SpatialReceiptParser.swift` - Spatial proximity parsing
- `HybridParser.swift` - Combines spatial + LLM
- `FoundationModelsParser.swift` - Pure LLM approach
- `AppleIntelligenceParser.swift` - Pattern-based fallback
- `ReceiptParser.swift` - Basic regex parser

---

## Conclusion

### V1 Success: Hybrid Architecture Works ✅

The Tokyo Expense Tracker V1 successfully validated a **hybrid spatial + LLM architecture** that combines:

1. **Vision Framework** for image understanding (text + coordinates)
2. **Spatial analysis** for deterministic structure extraction (amounts, dates)
3. **Foundation Models** for semantic understanding (merchants, categories)

**Key Discoveries:**
- Foundation Models cannot process images directly (text-only API)
- Vision Framework already captures valuable spatial information
- Spatial proximity is more reliable than LLM guessing for amounts
- LLMs excel at semantic tasks but struggle with numerical precision

**Validation:**
- ✅ BOOKOFF receipt: Correctly extracted ¥400 (avoided ¥1,660 confusion)
- ✅ Yodobashi receipt: Correctly reconstructed split amount ¥159,810
- ✅ Points vs totals: Spatial analysis correctly identifies 合計 line

### V2 Plan: Simplify While Keeping What Works

**Migrate to V2:**
- HybridParser (primary, proven winner)
- SpatialReceiptParser (simple fallback)
- Vision Framework OCR integration
- SwiftData models
- Image storage system
- Budget tracking logic

**Improve in V2:**
- UX-first design approach
- Cleaner navigation and state management
- Remove unnecessary parser complexity (4 parsers → 2 parsers)
- Cohesive visual design from the start

**Development Approach:**
1. Design UI first (with you and Claude)
2. Componentize the design
3. Harvest working functionality from V1
4. Build remaining features on solid foundation

The result will be a focused, well-designed app that leverages proven receipt parsing technology for reliable expense tracking during the Tokyo trip.
