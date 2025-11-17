# Tokyo Expense Tracker - Version 2 (Redesign in Progress)

A SwiftUI iOS app for tracking expenses during your Tokyo trip with receipt photo capture and CSV export.

**Status:** UI redesign complete (Phase 1 & 2). Ready for backend integration (Phase 3).

**Current Phase:** Backend Migration - Integrating V1's proven receipt parsing into V2's new UI.

**Next Step:** Follow the detailed migration plan in [MIGRATION_PLAN.md](MIGRATION_PLAN.md) to integrate OCR, parsers, and data models.

---

## 📚 Documentation

- **[MIGRATION_PLAN.md](MIGRATION_PLAN.md)** - Step-by-step backend integration plan (START HERE for next session)
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - V1 technical architecture and V2 simplification strategy
- **[README.md](README.md)** - This file (project overview and status)

**V1 Project Reference:**
- Location: `/Users/claudiang/Projects/TokyoExpenseTracking/`
- See V1's ARCHITECTURE.md for proven parser implementations
- See V1's README.md for complete feature list

---

## V1 Learnings - What Actually Worked ✅

After iterating on the first version, here's what proved successful and should be migrated to v2:

### Proven Technologies
1. **HybridParser (Spatial + LLM)** - The winning approach
   - Combines Vision Framework spatial coordinates with Foundation Models semantic understanding
   - Successfully parsed complex Japanese receipts (BOOKOFF ¥400, Yodobashi ¥159,810)
   - Spatial analysis for amounts (deterministic, reliable)
   - LLM for merchant names and categorization (smart, flexible)

2. **Vision Framework OCR** - Excellent Japanese text recognition
   - Horizontal text works extremely well
   - Bounding box coordinates are key to spatial parsing

3. **SwiftData** - Clean persistence, works well for single-user app

4. **Image Storage System** - Receipt photo management in documents directory

5. **Budget Tracking Logic** - Work days vs personal days, per diem calculations

### What to Simplify in V2
- **Parser count:** V1 had 4 parsers with complex fallback chains
  - V2 should use HybridParser as primary, SpatialParser as simple fallback
  - Remove unnecessary complexity (AppleIntelligenceParser, basic ReceiptParser)

- **UX refinement:** V1 accumulated features without cohesive design
  - V2 starts with visual design first, then adds functionality

### Technical Requirements Confirmed
- **iOS 26.0+** for Foundation Models (HybridParser)
- **macOS 26.0+** for development with Foundation Models
- Swift 6, SwiftUI

---

## V2 Redesign Game Plan

### Phase 1: Visual Design & Core UX (Current Phase)
**Objective:** Design the experience in Xcode with clean, focused UI

**Screens to design first:**
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
- Build static UI in SwiftUI with placeholder data
- Focus on interaction flow and visual hierarchy
- Validate UX before implementing backend functionality

### Phase 2: Componentization
**Objective:** Break down designed screens into reusable components

- Identify repeated UI patterns
- Extract into SwiftUI components
- Establish consistent design system
- Create component library for remaining screens

### Phase 3: Functionality Migration
**Objective:** Harvest working code from v1 and integrate

**Migrate from v1:**
- HybridParser + SpatialParser (receipt parsing)
- OCRService (Vision Framework integration)
- ImageManager (photo storage)
- SwiftData models (Expense, Category)
- Budget tracking logic
- CSVExporter

**Build fresh:**
- View models (MVVM pattern)
- Navigation flow
- State management

### Phase 4: Remaining Screens & Polish
- Dashboard (if needed - TBD)
- Export screen with date range selection
- Settings/configuration
- Error handling and edge cases

---

## Features Implemented (V1 Reference)

### Core Functionality
- **Manual Expense Entry**: Add expenses with all required fields (date, category, merchant, amount in JPY/USD, exchange rate)
- **Receipt Photo Capture**: Take photos with camera or import from photo library
- **Image Storage**: High-quality receipt images stored in app documents directory
- **Expense List View**: View all expenses with filtering by category and sorting options
- **CSV Export**: Export expenses to CSV format for sharing

### User Interface
- **Dashboard**: Overview of spending with budget tracking
  - Total budget remaining
  - Category breakdown (Food/Per Diem, Transport)
  - Quick stats (total expenses, average per day, work vs personal days)

- **Expense List**: Full list of all expenses
  - Search by merchant name or description
  - Filter by category
  - Sort by date or amount
  - Swipe to delete

- **Add Expense**: Comprehensive expense entry form
  - Date/time picker
  - Category selector
  - Amount fields (JPY and USD with auto-conversion)
  - Exchange rate input
  - Camera and photo library integration
  - Multiple receipt images support
  - Notes field

- **Expense Details**: View full expense information
  - All expense details
  - Receipt images
  - Work day indicator

- **Export**: Simple CSV export
  - Summary of expenses to export
  - Share sheet for exporting CSV

## Technical Details

### Technologies Used
- **Swift 6** (language mode)
- **SwiftUI** for UI
- **SwiftData** for data persistence
- **Vision Framework** for OCR (Japanese text recognition)
- **FoundationModels** for AI-powered receipt parsing (iOS 26+)
- **NaturalLanguage** for text analysis
- **AVFoundation** for camera access
- **PhotosUI** for photo library access
- **iOS 26.0+** minimum deployment target

### Architecture

**See [ARCHITECTURE.md](ARCHITECTURE.md) for comprehensive technical documentation.**

#### Receipt Processing Pipeline

```
Receipt Image → Vision OCR → Text + Coordinates → Spatial Parser → Hybrid Parser → Result
```

#### Parser Strategy (V1 Implementation)

**Winner: HybridParser** ✅
- Combines spatial analysis (for amounts) + Foundation Models LLM (for semantics)
- Successfully parsed all test receipts (BOOKOFF ¥400, Yodobashi ¥159,810)
- Requires iOS 26+

**Simple Fallback: SpatialReceiptParser**
- Uses Vision Framework bounding boxes to find amounts near keywords
- Deterministic spatial proximity analysis
- Works without Foundation Models

**V1 Note:** V1 had 4 parsers total (including AppleIntelligenceParser and basic ReceiptParser) but these added unnecessary complexity. V2 will use only HybridParser + SpatialReceiptParser fallback.

#### Why Hybrid Approach?

**Problem:** Foundation Models is text-only (no image input)
**Discovery:** Vision Framework already captures spatial coordinates
**Solution:** Use coordinates to find amounts near keywords + LLM for semantics

**Key Insight:** Spatial proximity = layout understanding
- "合計" at (0.1, 0.5) + "400" at (0.8, 0.5) = Same line = Total! ✅
- "お預り" at (0.1, 0.3) + "1,000" at (0.8, 0.3) = Different line = Payment (ignore)

#### MVVM Pattern
- **MVVM pattern** with SwiftUI
- **SwiftData models** for data persistence
- **Separate utility classes** for image management and CSV export

### Data Model
- **Expense**: Main data model with all expense properties
- **ExpenseCategory**: Enum with predefined categories (Food, Transport, Shopping, Other)

### File Structure
```
TokyoExpenseTracker/
├── Models/
│   └── Expense.swift (with isArchived, isIncomplete)
├── Views/
│   ├── AddExpenseView.swift (with OCR integration)
│   ├── EditExpenseView.swift (full edit form)
│   ├── ExpenseDetailView.swift (with edit/archive)
│   ├── ExpenseListView.swift (with archive filter)
│   ├── QuickAddTransportView.swift (Tokyo transport)
│   ├── DashboardView.swift
│   ├── ExportView.swift
│   └── ImagePicker.swift
├── Utilities/
│   ├── OCRService.swift (Vision Framework)
│   ├── FoundationModelsParser.swift (AI parsing, macOS 26+)
│   ├── AppleIntelligenceParser.swift (pattern fallback)
│   ├── ReceiptParser.swift (basic regex)
│   ├── TranslationService.swift (keyword-based)
│   ├── CategoryClassifier.swift
│   ├── ImageManager.swift
│   └── CSVExporter.swift
├── TokyoExpenseTrackerApp.swift
└── Info.plist
```

## Receipt Parsing Challenges - SOLVED ✅

These challenges were encountered and successfully solved in v1 with HybridParser:

### Issue 1: BOOKOFF Receipt (¥400 vs ¥1,660) ✅ SOLVED

**Problem:** Pure LLM extracted ¥1,660 (wrong) instead of ¥400 (correct total)
**Cause:** Without spatial layout, LLM confused payment section with total
**Solution:** Spatial parser finds "合計" keyword, only extracts nearby numbers using bounding box coordinates
**Result:** HybridParser correctly extracts ¥400

### Issue 2: Yodobashi Split Amount (¥159,810) ✅ SOLVED

**Problem:** Amount split across lines: "159," (line 23) + "810" (line 24)
**Solution:** Spatial parser checks next line when current line ends with comma, validates vertical alignment
**Result:** HybridParser correctly reconstructs ¥159,810

### Issue 3: Points vs Totals ✅ SOLVED

**Problem:** Japanese receipts show both 合計 (total) and ポイント (points)
**Solution:** Spatial parser prioritizes "合計" keyword, uses spatial distance to ignore "ポイント" lines
**Result:** Correctly extracts total, ignores point balances

### Test Receipts

- **Yodobashi Camera:** ¥159,810 (tests split amount handling)
- **BOOKOFF:** ¥400 (tests payment vs total disambiguation)

### Framework Limitations

**Foundation Models:**
- ❌ NO image input (text-only API)
- ⚠️ Requires iOS 26.0+ and macOS 26+ for development
- ✅ Best for: Merchant names, category classification
- ❌ Not ideal for: Amount extraction (no visual context)

**Vision Framework:**
- ✅ Japanese OCR excellent for horizontal text
- ⚠️ Vertical text has limited support
- ❌ Handwriting recognition poor
- 📍 Coordinates: Normalized 0-1, origin at bottom-left

## Building and Running

### Requirements
- Xcode 16.0 or later
- iOS 26.0+ device or simulator
- **macOS 26 or later** (for Foundation Models AI parsing)
  - macOS < 26 will fall back to pattern-based parser
  - OCR and manual entry still work on older macOS

### Steps to Build
1. Open `TokyoExpenseTracker.xcodeproj` in Xcode
2. Select your target device (iPhone 16 recommended) or simulator
3. Press `Cmd+R` to build and run

### First Time Setup
1. When you first run the app, grant camera and photo library permissions when prompted
2. Start adding expenses manually
3. Take photos of receipts or import existing ones
4. View your expenses in the list or dashboard
5. Export to CSV when ready

## Usage Guide

### Adding an Expense
1. Tap the "+" button in the Expense List
2. Fill in the expense details:
   - Select date and time
   - Choose category
   - Enter merchant name and description
   - Enter amount in JPY (USD will auto-calculate based on exchange rate)
   - Optionally add receipt photos (camera or library)
   - Add notes if needed
3. Tap "Save"

### Taking Receipt Photos
1. In the Add Expense screen, tap "Take Photo"
2. Allow camera access if prompted
3. Take a photo of the receipt
4. Photo is automatically saved with the expense

### Importing Photos
1. In the Add Expense screen, tap "Choose from Library"
2. Allow photo library access if prompted
3. Select one or more photos
4. Photos are saved with the expense

### Viewing Expenses
1. Open the Expenses tab
2. Use the search bar to find expenses by merchant or description
3. Tap the filter button to:
   - Sort by date (newest/oldest) or amount (high/low)
   - Filter by category
4. Tap any expense to view full details including receipt images

### Using OCR for Japanese Receipts (Phase 2)
1. In Add Expense screen, add a receipt photo
2. Tap **"Process Receipt with OCR"** button
3. Wait for processing (shows spinner)
4. Form fields auto-fill with extracted data:
   - Merchant name
   - Date
   - Amount in JPY
   - Category suggestion
5. Review and edit any incorrect data
6. OCR confidence score displayed
7. Tap "Save"

**Note:** Requires macOS 26 for best results. Falls back to pattern matching on older macOS.

### Quick Add Transport (Phase 2)
1. Tap "+" button in Expense List
2. Select **"Quick Add Transport"** from menu
3. Select From/To Tokyo stations (quick-select buttons)
4. Tap common fare amount (¥140, ¥170, ¥200, etc.)
5. Optionally add Suica balance photo
6. Tap "Add"

### Editing Expenses
1. Tap any expense in the list to view details
2. Tap **"Edit"** button at bottom
3. Modify any fields
4. Tap "Save"

### Archiving Expenses
1. Tap any expense to view details
2. Tap **"Archive"** button at bottom
3. Archived expenses hidden from main list
4. Use filter menu → "Show Archived" to view
5. Tap "Unarchive" to restore

### Exporting to CSV
1. Tap the export button (share icon) in the Expense List
2. Review the export summary
3. Tap "Export CSV"
4. Choose how to share the CSV file (AirDrop, email, save to Files, etc.)

### CSV Format
```csv
Number,Date,Time,Category,Merchant,Description,Amount_JPY,Amount_USD,Receipt_Filename
001,2025-12-01,12:30,Food/Per Diem,Ichiran Ramen,Lunch,¥1200,$8.50,UUID.jpg
```

## Budget Tracking

The app automatically tracks:
- **Total Budget**: $5,925 (includes committed flights and hotel)
- **Per Diem Budget**: $400 for work days (Dec 1-5)
- **Transport Budget**: $200
- **Work Days**: Dec 1-5, 2025 (automatically detected)

The Dashboard shows:
- Total remaining budget
- Food spending vs budget (work days only)
- Transport spending vs budget
- Average daily spending
- Work day vs personal day expense counts

## Phase 2 Implementation Status (Partial)

### ✅ Implemented
- **Japanese OCR**: Vision Framework extracts Japanese text from receipts
- **Translation**: Keyword-based translation for common receipt terms
- **Auto-categorization**: Merchant-based category suggestion
- **Receipt Parsing**: Three parser implementations (Foundation Models, pattern-based, regex)
- **Quick Add Transport**: Fast entry for Tokyo train rides
- **Edit & Archive**: Full expense editing and archiving functionality
- **Incomplete Indicators**: Visual badges for expenses missing data

### ⚠️ Pending (Requires macOS 26)
- **Foundation Models Parser**: Uses Apple's on-device LLM for smart parsing
  - Currently blocked by macOS < 26 requirement
  - Falls back to pattern-based parser
  - See `MACOS_26_UPGRADE.md` for testing after upgrade

### ❌ Not Yet Implemented
- Date range export filtering (Phase 4)
- Receipt image export with ZIP (Phase 4)
- Advanced budget visualizations (Phase 3)

## Data Storage

- All data is stored locally on your device using SwiftData
- Receipt images are stored in the app's documents directory
- No cloud sync or external servers
- All processing is on-device for privacy

## Troubleshooting

### Camera not working
- Check that camera permissions are granted in Settings > Privacy & Security > Camera

### Photo library not working
- Check that photo library permissions are granted in Settings > Privacy & Security > Photos

### CSV export fails
- Make sure you have at least one expense
- Check that you have storage space available

### App won't build
- Make sure you're using Xcode 15.0+
- Check that iOS deployment target is set to 18.0
- Clean build folder (Cmd+Shift+K) and rebuild

## Next Steps (Future Phases)

### Phase 2: Advanced OCR
- Japanese receipt OCR with Vision Framework
- Uber receipt parsing
- Translation integration
- Auto-categorization
- Confidence scoring

### Phase 3: Budget Tracking
- Daily per diem tracking details
- Enhanced budget visualizations
- Work day vs personal day logic refinement

### Phase 4: Export & Reporting
- Date range selection for export
- Flexible include/exclude settings
- Receipt image export with ZIP
- Export validation

## Documentation

- **CLAUDE.md** - Original project specification
- **README.md** - This file (feature overview and usage guide)
- **STATUS.md** - Current implementation status and blockers
- **MACOS_26_UPGRADE.md** - Checklist for after macOS 26 upgrade
- **BUILD_FIXES.md** - Build error solutions
- **UX_IMPROVEMENTS.md** - UX enhancement history

## Support

For issues or questions:
- Check **STATUS.md** for current implementation status
- Check **MACOS_26_UPGRADE.md** if Foundation Models doesn't work
- Check the specification in **CLAUDE.md**
- Review this README
- Check Xcode console for error messages

## Current Status (Nov 11, 2025)

**See STATUS.md for detailed status.**

**Summary:**
- ✅ Phase 1 complete
- 🔄 Phase 2 partial (OCR working, Foundation Models pending macOS 26)
- ⏸️ Phase 3-4 not started

**After macOS 26 upgrade:** See MACOS_26_UPGRADE.md for testing checklist.

## License

Personal use only.
