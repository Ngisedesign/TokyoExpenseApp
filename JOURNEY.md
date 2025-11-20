# Tokyo Expense Tracker - Development Journey

This document chronicles the development journey of the Tokyo Expense Tracker, including V1 learnings, parser evolution, technical challenges overcome, and architectural decisions made along the way.

**Purpose:** Archival record and technical reference for future development decisions.

---

## Table of Contents

1. [V1 Learnings - What Actually Worked](#v1-learnings---what-actually-worked)
2. [V2 Redesign Game Plan](#v2-redesign-game-plan)
3. [Receipt Parsing Challenges - SOLVED](#receipt-parsing-challenges---solved)
4. [Transition to Claude API](#transition-to-claude-api)
5. [Framework Limitations Discovered](#framework-limitations-discovered)
6. [Features Implemented History](#features-implemented-history)
7. [Budget Tracking Evolution](#budget-tracking-evolution)

---

## V1 Learnings - What Actually Worked

After iterating on the first version, here's what proved successful:

### Proven Technologies

#### 1. HybridParser (Spatial + LLM) - The Winning Approach

The hybrid approach combined Vision Framework spatial coordinates with Foundation Models semantic understanding:

- **Architecture**: Spatial analysis for amounts (deterministic, reliable) + LLM for merchant names and categorization (smart, flexible)
- **Success**: Successfully parsed complex Japanese receipts
  - BOOKOFF: ¥400 (correctly identified total vs payment section)
  - Yodobashi: ¥159,810 (handled split amounts across lines)
- **Requirement**: iOS 26+, macOS 26+ for development

**Why It Worked:**
- Spatial analysis provided deterministic amount extraction using bounding box coordinates
- LLM added semantic understanding for merchant categorization
- Combining both approaches covered each other's weaknesses

#### 2. Vision Framework OCR - Excellent Japanese Text Recognition

- Horizontal text worked extremely well
- Bounding box coordinates were key to spatial parsing
- Typical confidence scores: 0.85-0.98 for printed receipts
- Recognition level: `.accurate` (slower but better quality)

#### 3. SwiftData - Clean Persistence

- Simple, effective for single-user app
- Works well for local-first data storage
- No sync complexity needed

#### 4. Image Storage System

- Receipt photo management in documents directory
- High-quality image retention
- Organized file structure

#### 5. Budget Tracking Logic

- Work days vs personal days distinction
- Per diem calculations
- Category-based budget tracking

### What We Simplified in V2

**Parser Count Reduction:**
- V1 had 4 parsers with complex fallback chains:
  1. HybridParser (Spatial + LLM)
  2. SpatialReceiptParser (coordinate-based)
  3. AppleIntelligenceParser (pattern-based)
  4. Basic ReceiptParser (regex fallback)
- **V2 Plan**: Use only HybridParser + SpatialParser fallback
- **Current Reality**: Transitioned to Claude API for simplicity and reliability

**UX Refinement:**
- V1 accumulated features without cohesive design
- V2 started with visual design first, then added functionality
- Component-based architecture from the start

### Technical Requirements (V1)

- **iOS 26.0+** for Foundation Models (HybridParser)
- **macOS 26.0+** for development with Foundation Models
- Swift 6, SwiftUI
- Vision Framework for OCR

---

## V2 Redesign Game Plan

### Original V2 Vision

The V2 redesign followed a phased approach:

#### Phase 1: Visual Design & Core UX ✅

**Objective:** Design the experience in Xcode with clean, focused UI

**Screens designed:**
1. **Add Expense Screen** - The workhorse (80% of daily interaction)
   - Quick photo capture
   - OCR processing button
   - Manual entry fields
   - Date/category/amount inputs

2. **Expense List Screen** - Verification before export
   - All expenses at a glance
   - Quick filters (day/category)
   - Tap to view/edit details

**Approach:**
- Built static UI in SwiftUI with placeholder data
- Focused on interaction flow and visual hierarchy
- Validated UX before implementing backend functionality

#### Phase 2: Componentization ✅

**Objective:** Break down designed screens into reusable components

- Identified repeated UI patterns
- Extracted into SwiftUI components
- Established consistent design system
- Created component library:
  - `LargeIconButton`
  - `LabeledField`
  - `CategoryPill`
  - `TotalBudgetBar`
  - `CategoryBudgetCard`

#### Phase 3: Functionality Migration ⚠️ (Evolved)

**Original Plan:** Harvest working code from V1 and integrate
- HybridParser + SpatialParser
- OCRService (Vision Framework)
- ImageManager
- SwiftData models
- Budget tracking logic
- CSVExporter

**What Actually Happened:**
- **Transitioned to Claude API** instead of on-device parsing
- Simplified architecture by using cloud-based AI
- Maintained SwiftData models, ImageManager, CSVExporter
- Built fresh view models with MVVM pattern

#### Phase 4: Remaining Screens & Polish 🔄 (In Progress)

- Dashboard ✅
- Export screen with date range selection ✅
- Settings/configuration ⏳
- Error handling and edge cases ⏳

---

## Receipt Parsing Challenges - SOLVED

These challenges were encountered and successfully solved in V1 with HybridParser:

### Issue 1: BOOKOFF Receipt (¥400 vs ¥1,660) ✅ SOLVED

**Problem:** Pure LLM extracted ¥1,660 (wrong) instead of ¥400 (correct total)

**Receipt Structure:**
```
合計          ¥400
お預り      ¥1,000
お釣り        ¥600
```

**Root Cause:**
- Without spatial layout, LLM received flat text
- Confused payment section with total section
- LLM saw multiple numbers and made incorrect inference

**Solution:**
- Spatial parser finds "合計" keyword using coordinates
- Only extracts nearby numbers using bounding box proximity
- Uses spatial distance to determine which number is the total

**Result:** HybridParser correctly extracts ¥400

**Spatial Logic:**
```
"合計" at (x: 0.1, y: 0.5)
"400" at (x: 0.8, y: 0.5)
→ Same Y coordinate = Same line = This is the total! ✅

"お預り" at (x: 0.1, y: 0.3)
"1,000" at (x: 0.8, y: 0.3)
→ Different Y coordinate = Different section = Ignore
```

### Issue 2: Yodobashi Split Amount (¥159,810) ✅ SOLVED

**Problem:** Amount split across lines:
- Line 23: "159,"
- Line 24: "810"

**Challenge:**
- Simple text extraction would miss the relationship
- Needed to understand that these were continuation

**Solution:**
- Spatial parser checks if current line ends with comma
- Validates vertical alignment of next line
- Reconstructs full amount: "159" + "810" = "159810"

**Detection Algorithm:**
```swift
if text.hasSuffix(",") {
    let nextLine = elements[index + 1]
    if nextLine.text.matches("^[0-9]+$") {
        // Verify vertical alignment (similar x coordinate)
        // Combine: "159" + "810" = "159810"
    }
}
```

**Result:** HybridParser correctly reconstructs ¥159,810

### Issue 3: Points vs Totals ✅ SOLVED

**Problem:** Japanese receipts show both:
- 合計 (total amount to pay)
- ポイント (loyalty points balance)

**Challenge:**
- Both have numbers after them
- Need to distinguish which is the purchase total

**Solution:**
- Spatial parser prioritizes "合計" keyword
- Uses spatial distance to ignore "ポイント" lines
- Points section typically appears below total section

**Result:** Correctly extracts total, ignores point balances

### Test Receipts Used

1. **Yodobashi Camera Receipt**
   - Amount: ¥159,810
   - Tests: Split amount handling across lines
   - Result: ✅ Passed

2. **BOOKOFF Receipt**
   - Amount: ¥400
   - Tests: Payment vs total disambiguation
   - Result: ✅ Passed

---

## Transition to Claude API

### Why We Moved Away from Hybrid Parser

**Decision Date:** Late 2024 / Early 2025

**Reasons for Transition:**

1. **Development Complexity**
   - Maintaining 4 different parsers was complex
   - Fallback chains added cognitive overhead
   - Testing across iOS versions was time-consuming

2. **macOS/iOS Version Requirements**
   - Foundation Models required iOS 26+ and macOS 26+
   - Limited development flexibility
   - Device compatibility concerns

3. **Simplicity & Reliability**
   - Claude API provided consistent results
   - No need to manage multiple parser fallbacks
   - Easier to update and improve prompts

4. **Better Results**
   - Claude API could process full receipt context
   - Better semantic understanding
   - More accurate merchant name extraction

### What We Kept from V1

**Data Architecture:**
- SwiftData models (Expense, categories)
- Image storage system
- Budget tracking logic
- CSV export functionality

**UI Components:**
- Component-based design system
- Visual hierarchy and interactions
- Budget visualizations

**Core Features:**
- Manual entry
- Receipt photo capture
- Filtering and sorting
- Export functionality

### New Architecture

```
Receipt Image → Claude API → Structured Response → SwiftData
                   ↑
            (includes image and context)
```

**Benefits:**
- Single parsing pipeline
- No fallback complexity
- Cloud-based processing
- Easier to debug and improve

**Trade-offs:**
- Requires network connection
- API costs (minimal for personal use)
- Privacy consideration (sending receipt images to cloud)

---

## Framework Limitations Discovered

### Vision Framework

**Strengths:**
- ✅ Excellent Japanese OCR for horizontal text
- ✅ High confidence scores (0.85-0.98 typical)
- ✅ Accurate bounding box coordinates
- ✅ Fast processing (1-2 seconds on iPhone 16 Pro)

**Limitations:**
- ❌ Vertical text has limited support
- ❌ Handwriting recognition poor
- ⚠️ Faded/blurry images reduce confidence
- 📍 Coordinates: Normalized 0-1, origin at bottom-left (requires mental model shift)

**Recommendation:** Still useful for future on-device processing if desired

### Foundation Models (iOS 26+)

**Capabilities:**
- ✅ Semantic text understanding
- ✅ Structured data extraction via @Generable
- ✅ Japanese language support
- ✅ On-device processing (privacy)

**Limitations:**
- ❌ **NO image input** (text-only API!)
- ❌ Cannot see spatial layout
- ❌ Cannot process bounding boxes directly
- ⚠️ Requires iOS 26.0+ and macOS 26.0+
- ⚠️ macOS < 26 cannot develop with Foundation Models

**What It Was Good For:**
- ✅ Merchant name extraction
- ✅ Business type classification
- ✅ Semantic disambiguation

**What It Was NOT Good For:**
- ❌ Amount extraction (confused by multiple numbers)
- ❌ Spatial relationships
- ❌ Layout understanding

**Why Spatial + LLM Hybrid Made Sense:**
- Foundation Models excelled at semantic tasks
- Spatial parser handled structural tasks
- Together = reliable structure + smart semantics

**Why We Eventually Moved to Claude API:**
- Claude can process images directly
- Better accuracy with full context
- Simpler architecture

---

## Features Implemented History

### Core Functionality Evolution

**Phase 1 (Manual Entry Era):**
- Manual expense entry with all required fields
- Date, category, merchant, amount (JPY/USD), exchange rate
- Receipt photo capture (camera or library)
- Image storage in app documents directory
- Basic expense list view
- CSV export

**Phase 2 (OCR Integration Era - V1):**
- Vision Framework OCR integration
- Multiple parser implementations:
  - HybridParser (Spatial + LLM)
  - SpatialReceiptParser
  - AppleIntelligenceParser
  - Basic ReceiptParser
- Translation service (keyword-based)
- Category classifier
- Quick Add Transport feature
- Edit & Archive functionality
- Incomplete expense indicators

**Phase 3 (UI Redesign Era - V2):**
- Complete UI redesign with component-based architecture
- Enhanced dashboard with budget visualization
- Category breakdown cards
- Total budget bar with over-budget indicators
- Improved expense list with search and filters
- Report view with detailed analysis

**Phase 4 (Claude API Era - Current):**
- Transition to Claude API for parsing
- Simplified parsing pipeline
- Enhanced exchange rate integration
- Better error handling
- Improved CSV export with filtering

### User Interface History

**Dashboard Evolution:**
1. **V1 Simple Dashboard:**
   - Basic stats display
   - Simple budget remaining counter
   - Category list

2. **V2 Enhanced Dashboard:**
   - Visual budget bar
   - Category breakdown cards
   - Quick stats (total expenses, average per day)
   - Work vs personal day tracking
   - Over-budget visual indicators

**Expense List Evolution:**
1. **V1 Basic List:**
   - Simple text display
   - Swipe to delete
   - Basic sorting

2. **V2 Enhanced List:**
   - Search by merchant
   - Filter by category
   - Multiple sort options (date, amount)
   - Visual category indicators
   - Incomplete expense badges

**Add Expense Evolution:**
1. **V1 Form:**
   - Traditional form layout
   - OCR button
   - Multiple parser options

2. **V2 Modern Form:**
   - Clean, component-based design
   - Labeled fields with custom styling
   - Category pills
   - Photo picker integration
   - Claude API integration

---

## Budget Tracking Evolution

### Initial Approach

**V1 Simple Budget:**
- Fixed total budget: $5,925
- Simple remaining calculation
- No category breakdown

### Enhanced Approach (Current)

**Budget Structure:**
- **Total Budget**: $5,925 (includes committed flights and hotel)
- **Per Diem Budget**: $400 for work days (Dec 1-5)
- **Transport Budget**: $200
- **Work Days**: Dec 1-5, 2025 (automatically detected)

**Visual Indicators:**
- Total budget bar with color-coded sections
- Category budget cards
- Over-budget dark overlay visualization
- Progress percentages

**Calculations:**
- Average daily spending
- Work day vs personal day expense counts
- Category spending vs budget comparison
- Exchange rate integration for accurate USD tracking

---

## Lessons Learned

### Technical Decisions

1. **Parser Strategy**
   - Started with 4 parsers → Too complex
   - Hybrid approach worked well → But still complex to maintain
   - Claude API → Best balance of simplicity and accuracy

2. **UI Design**
   - V1: Features first, design later → Accumulated cruft
   - V2: Design first, features second → Cleaner architecture

3. **Framework Selection**
   - Vision Framework: Great for OCR, limited by text-only output to LLM
   - Foundation Models: Great for semantics, but no image support
   - Claude API: Best of both worlds

### Development Process

1. **Start with UI/UX design** - Saves refactoring later
2. **Build components early** - Reusability from the start
3. **Validate assumptions quickly** - Test with real data (BOOKOFF, Yodobashi receipts)
4. **Don't over-engineer** - 4 parsers → 2 parsers → 1 API call
5. **Document learnings** - This file proves the value

### Future Considerations

1. **On-Device Processing**
   - Could return to Vision Framework + Claude for offline mode
   - Keep parser learnings for future reference

2. **Hybrid Approach**
   - Could use Claude API as primary, Vision Framework as offline fallback
   - Best of both: accuracy when online, functionality when offline

3. **Architecture Evolution**
   - Current: Cloud-first
   - Future: Hybrid cloud + on-device?
   - Keep architecture flexible

---

## File Structure Evolution

### V1 Structure
```
TokyoExpenseTracker/
├── Models/
│   └── Expense.swift (with isArchived, isIncomplete)
├── Views/
│   ├── AddExpenseView.swift
│   ├── EditExpenseView.swift
│   ├── ExpenseDetailView.swift
│   ├── ExpenseListView.swift
│   ├── QuickAddTransportView.swift
│   ├── DashboardView.swift
│   ├── ExportView.swift
│   └── ImagePicker.swift
├── Utilities/
│   ├── OCRService.swift (Vision Framework)
│   ├── HybridParser.swift
│   ├── SpatialReceiptParser.swift
│   ├── AppleIntelligenceParser.swift
│   ├── ReceiptParser.swift
│   ├── TranslationService.swift
│   ├── CategoryClassifier.swift
│   ├── ImageManager.swift
│   └── CSVExporter.swift
├── TokyoExpenseTrackerApp.swift
└── Info.plist
```

### V2/Current Structure
```
TokyoExpenseApp/
├── Models/
│   └── Expense.swift
├── Views/
│   ├── AddEntryView.swift
│   ├── ExpenseListView.swift
│   ├── ReportView.swift
│   ├── DashboardView.swift (ContentView)
│   └── Components/
│       ├── LargeIconButton.swift
│       ├── LabeledField.swift
│       ├── CategoryPill.swift
│       ├── TotalBudgetBar.swift
│       └── CategoryBudgetCard.swift
├── Services/
│   ├── AnthropicService.swift (Claude API)
│   ├── ImageManager.swift
│   └── CSVExporter.swift
├── TokyoExpenseApp.swift
└── Info.plist
```

**Key Changes:**
- Simplified utilities → services
- Component-based UI organization
- Removed multiple parsers
- Added Claude API service

---

## CSV Format

**Current Export Format:**
```csv
Number,Date,Time,Category,Merchant,Description,Amount_JPY,Amount_USD,Receipt_Filename
001,2025-12-01,12:30,Food/Per Diem,Ichiran Ramen,Lunch,¥1200,$8.50,UUID.jpg
```

**Features:**
- Numbered entries
- Separate date and time columns
- Category-based organization
- Dual currency (JPY/USD)
- Receipt filename reference

---

## Summary

This journey document captures the evolution of the Tokyo Expense Tracker from initial concept through V1 experimentation, V2 redesign, and current Claude API implementation.

**Key Takeaways:**
1. Hybrid on-device parsing taught us valuable lessons about spatial analysis and LLM limitations
2. Claude API provided the right balance of simplicity and accuracy
3. UI-first design approach (V2) created a more cohesive experience
4. Component-based architecture made development faster and more maintainable

**For Future Reference:**
- All V1 parser learnings preserved in ARCHITECTURE.md
- Migration plan documented in MIGRATION_PLAN.md
- This journey document captures the "why" behind decisions
- Current README focuses on "what is" and "what's next"

---

**Document Version:** 1.0
**Last Updated:** 2025-01-XX
**Status:** Archival reference and technical learning document
