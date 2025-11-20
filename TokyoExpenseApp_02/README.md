# Tokyo Expense Tracking App

A SwiftUI iOS app for tracking business trip expenses to Tokyo with AI-powered receipt parsing, real-time exchange rates, and budget tracking.

## Features

### Current Features ✅

#### Smart Receipt Parsing
- 📸 **AI-Powered OCR** - Claude Vision API extracts merchant, amount, date, and category from receipts
- 🎨 **Whimsical Placeholders** - AI generates creative Japanese-style names when merchant not visible
- 🎯 **High Accuracy** - Handles Japanese and English receipts with confidence scoring
- 📅 **Date Intelligence** - Supports multiple date formats (yyyy-MM-dd, yyyy/MM/dd, Japanese formats)

#### Budget Management
- 💰 **Multi-Category Budgets** - Food, Transport, Flight, Hotel
- 📊 **Visual Budget Bar** - Multi-segment progress bar showing spending by category
- ⚡ **Rollover Tracking** - Unused daily budget rolls over to next day
- 🔄 **Work Days Toggle** - Include/exclude travel days from budget calculations
- 📈 **Daily Breakdown** - Expandable view showing spending per day

#### Currency & Exchange Rates
- 💱 **Live Exchange Rates** - Fetches real JPY↔USD rates from frankfurter.app API
- 🪙 **Flipping Coin Toggle** - Beautiful animated coin to switch between ¥/$ display
- 💾 **Rate Caching** - Stores exchange rates to minimize API calls
- ⚠️ **Fallback Handling** - Uses default rate (¥150 = $1) when offline, flags for update

#### Export & Reporting
- 📋 **CSV Export** - ShareSheet integration with date range and category filtering
- 📑 **In-App Reports** - Grouped by category with totals and remaining budget
- 🔍 **Search & Filter** - Search by merchant, filter by category

#### UI/UX
- 🖼️ **Masked Text Images** - Sushi image for Food, Train image for Transport
- 🎨 **Material Design** - Ultra-thin material backgrounds, clean typography
- 📱 **Native iOS** - SwiftUI with SwiftData persistence
- 📷 **Quick Capture** - Camera button on home screen for fast expense entry

---

### Planned Features 🚧

See [ROADMAP.md](#roadmap) for detailed implementation plan.

#### Phase 1: AI-Generated Descriptions
- 🤖 **Simple Descriptions** - AI generates "Lunch", "Dinner", "Coffee", "Train", etc.
- ✍️ **Editable Field** - Description field in add/edit forms
- 👁️ **Display Everywhere** - Show descriptions in list and report views

#### Phase 2: Expense Editing
- ✏️ **Edit Existing Expenses** - Tap to edit merchant, amount, date, category, description
- 🖼️ **View Receipts** - Full-screen receipt images with zoom
- 💾 **Update in Place** - Modify expenses without deleting and re-creating

#### Phase 3: Bulk Operations
- ✅ **Edit Mode** - Toggle selection mode with checkboxes
- 🗑️ **Bulk Delete** - Select multiple expenses to delete at once
- 🏷️ **Bulk Categorize** - Change category for multiple expenses
- 📤 **Bulk Export** - Export selected expenses to CSV
- 👆 **Swipe to Delete** - Quick delete for individual expenses

#### Phase 4: Enhanced Export
- ⏸️ **Cancellable Export** - Cancel button during CSV generation
- 📊 **Progress Indicator** - Show export progress for large datasets
- 📄 **PDF Export** - (Optional) Visual reports with charts

---

## Project Structure

```
TokyoExpenseApp_02/
├── Models/
│   ├── Expense.swift              # Core expense data model
│   ├── BudgetTracker.swift        # Budget calculations & rollover logic
│   └── ParsedReceipt.swift        # AI-parsed receipt data structure
├── Services/
│   ├── AnthropicService.swift     # Claude AI receipt parsing
│   ├── ExchangeRateService.swift  # Live exchange rate fetching
│   ├── ImageManager.swift         # Receipt image persistence
│   └── OCRService.swift           # Legacy Vision OCR (fallback)
├── Utilities/
│   ├── CurrencyFormatter.swift    # USD/JPY display formatting
│   └── DateFormatters.swift       # Date formatting utilities
├── Components/
│   ├── BudgetCategoryCard.swift   # Category budget display card
│   ├── DailyBudgetCard.swift      # Daily spending breakdown
│   ├── TotalBudgetBar.swift       # Multi-segment progress bar
│   └── FlippingCoinView.swift     # Animated currency toggle
├── Views/
│   ├── ContentView.swift          # Home screen
│   ├── AddEntryView.swift         # New expense entry form
│   ├── BudgetCarouselView.swift   # Tabbed budget/expenses/report view
│   ├── ExpenseListView.swift      # Searchable expense list
│   ├── ReportView.swift           # Category-grouped report
│   └── ExportView.swift           # CSV export with filters
├── Config/
│   └── APIKeys.swift              # API keys (gitignored)
└── Assets.xcassets/
    ├── sushi.imageset/            # Food category image
    └── JRTrain.imageset/          # Transport category image
```

---

## Setup

### Prerequisites
- Xcode 15+
- iOS 17+ (iOS 26+ for hybrid OCR features)
- Anthropic API key ([Get one here](https://console.anthropic.com/))

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd TokyoExpenseApp_02
   ```

2. **Configure API Keys**
   - Open `Config/APIKeys.swift`
   - Add your Anthropic API key:
     ```swift
     enum APIKeys {
         static let anthropic = "sk-ant-api03-YOUR_KEY_HERE"
     }
     ```
   - See [ANTHROPIC_SETUP.md](ANTHROPIC_SETUP.md) for detailed instructions

3. **Build and Run**
   - Open `TokyoExpenseApp_02.xcodeproj` in Xcode
   - Select your target device/simulator
   - Press ⌘R to build and run

---

## Configuration

### Budget Settings
Edit `Models/BudgetTracker.swift` to customize budgets:

```swift
// Daily budgets
static let perDiemDaily: Decimal = 80      // $80/day for food
static let transportDaily: Decimal = 50    // $50/day for transport

// Trip dates (2025)
static let tripStartDate = Date(2025, 11, 28)  // Travel starts
static let firstWorkDay = Date(2025, 12, 1)    // Work begins
static let lastWorkDay = Date(2025, 12, 5)     // Work ends
static let tripEndDate = Date(2025, 12, 7)     // Travel ends
```

### Exchange Rate
- **Default rate**: ¥150 = $1 USD (fallback when offline)
- **Live rates**: Fetched from [frankfurter.app](https://www.frankfurter.app/)
- **Caching**: Rates cached per date to minimize API calls

---

## Usage

### Adding an Expense

1. **Tap the + button** on home screen
2. **Capture receipt** - Camera or photo library
3. **Review auto-filled data** - AI extracts merchant, amount, date, category
4. **Edit if needed** - Correct any mistakes (merchant shown in red if AI-generated)
5. **Save** - Exchange rate fetched automatically for the date

### Viewing Budget

1. **Tap menu button** (三) on home screen
2. **Budget tab** - See spending by category with progress bars
3. **Expand categories** - Tap Food/Transport to see daily breakdown
4. **Toggle work days** - Include/exclude travel days
5. **Toggle currency** - Tap coin to switch ¥/$

### Exporting Data

1. **Navigate to Report tab**
2. **Tap export button** (↑)
3. **Select date range** - All, work days, or travel days
4. **Select categories** - Food, Transport, Flight, Hotel
5. **Share CSV** - AirDrop, email, save to Files

---

## Documentation

- **[ANTHROPIC_SETUP.md](ANTHROPIC_SETUP.md)** - Claude API setup guide
- **[AUDIT_REPORT.md](AUDIT_REPORT.md)** - Code audit and fixes (9 issues resolved)
- **[ROADMAP.md](#roadmap)** - Upcoming features (see below)

---

## Roadmap

### Phase 1: AI-Generated Descriptions ⏳

**Goal**: Auto-generate simple expense descriptions like "Lunch", "Dinner", "Coffee"

**Tasks**:
1. Extend `ParsedReceipt` model with `expenseDescription` field
2. Update Anthropic prompt to infer meal type from:
   - Receipt items (coffee, rice, train ticket, etc.)
   - Merchant type (restaurant, convenience store, station)
   - Timestamp (morning = breakfast, noon = lunch, evening = dinner)
3. Add description text field to `AddEntryView` (below merchant)
4. Display descriptions in `ExpenseListView` and `ReportView`
5. Show "AI-generated" indicator with edit capability

**Success Criteria**:
- ✅ AI generates: "Breakfast", "Lunch", "Dinner", "Snack", "Coffee", "Groceries", "Taxi", "Train"
- ✅ User can override AI suggestion
- ✅ Descriptions visible in all expense views

---

### Phase 2: Individual Expense Editing ⏳

**Goal**: Allow users to edit expenses after creation

**Tasks**:
1. Create `ExpenseDetailView.swift`:
   - Full-screen edit form
   - All fields editable (merchant, amount, date, category, description)
   - Receipt image display with zoom gesture
   - Save/Cancel buttons
   - SwiftData update logic
2. Add navigation from `ExpenseListView`:
   - Wrap expense rows in NavigationLink or sheet
   - Pass selected expense to detail view
3. Add navigation from `ReportView`:
   - Make expense rows tappable
   - Present detail view

**Success Criteria**:
- ✅ Tap any expense to view/edit details
- ✅ Changes persist to SwiftData
- ✅ Receipt images viewable full-screen
- ✅ Cancel discards changes

---

### Phase 3: Edit Mode with Bulk Operations ⏳

**Goal**: Enable multi-select for batch operations

**Tasks**:
1. Add "Edit" button to `ExpenseListView` toolbar
2. Toggle selection mode:
   - Show checkboxes on expense rows
   - Multi-select enabled
   - Action bar appears at bottom
3. Bulk operations:
   - **Delete** - Remove selected expenses (with confirmation)
   - **Change Category** - Picker to reassign category
   - **Export** - Generate CSV of selected items
4. Wire up swipe-to-delete:
   - Connect existing `deleteExpenses(at:)` method
   - Add `.onDelete()` modifier
   - Confirmation dialog
5. "Done" button exits edit mode

**Success Criteria**:
- ✅ Edit mode toggles selection UI
- ✅ Can select multiple expenses
- ✅ Bulk delete with confirmation
- ✅ Bulk categorize
- ✅ Swipe-to-delete works

---

### Phase 4: Enhanced Export UI ⏳

**Goal**: Improve export UX with cancellation and progress

**Tasks**:
1. Add cancel button to `ExportView`:
   - Button visible during CSV generation
   - Cancels async Task
   - Returns to view without exporting
2. Add progress indicator:
   - Show "Processing X of Y expenses..."
   - Progress bar for large datasets (>50 expenses)
3. Test with edge cases:
   - Large exports (100+ items)
   - Filtered exports (date range, categories)
   - Empty selection handling

**Success Criteria**:
- ✅ Cancel button stops export mid-process
- ✅ Progress indicator for large datasets
- ✅ Graceful handling of cancellation
- ✅ No performance issues with 100+ expenses

---

## Architecture

### Data Flow

```
User captures receipt
    ↓
AddEntryView
    ↓
AnthropicService.parseReceipt()
    ↓ (Sends image to Claude API)
Claude extracts: merchant, amount, date, category, [description]
    ↓
Form auto-filled
    ↓
User reviews & saves
    ↓
ExchangeRateService.fetchRate() (async)
    ↓
Expense + receipt image saved to SwiftData
    ↓
UI updates (BudgetTracker recalculates)
```

### Key Technologies

- **SwiftUI** - Declarative UI framework
- **SwiftData** - Model-driven persistence (@Model, @Query)
- **Anthropic Claude API** - Vision-based receipt parsing (Haiku 3.5)
- **URLSession** - Async networking for APIs
- **@AppStorage** - UserDefaults wrapper for settings
- **Vision Framework** - Legacy OCR fallback (iOS 17+)
- **PhotosUI** - PhotosPicker and UIImagePickerController
- **Decimal** - Precise currency arithmetic

### Budget Calculation Logic

```swift
// Per-diem example (Food)
totalBudget = perDiemDaily * workDays  // $80 × 5 = $400
spentToday = expenses[today].sum()
previousDaysRollover = (budget - spent) for each previous day
availableToday = perDiemDaily + previousDaysRollover
```

**Rollover Rules**:
- ✅ Positive rollover (under-budget) → increases next day's budget
- ❌ Negative rollover (over-budget) → reduces next day's budget
- 📊 Displayed in green (+¥1,200) or red (-¥800)

---

## API Costs

### Anthropic
- **Model**: Claude 3.5 Haiku
- **Cost**: ~$0.0003 per receipt (vision API)
- **Estimate**: 1000 receipts ≈ $0.30

### Exchange Rates
- **API**: [frankfurter.app](https://www.frankfurter.app/)
- **Cost**: Free (no API key required)
- **Limits**: Unlimited for reasonable use

---

## Privacy & Security

### API Keys
- Stored in `Config/APIKeys.swift` (gitignored)
- Never committed to version control
- Replace placeholder before building

### Receipt Images
- Stored locally in app Documents folder
- Sent to Anthropic for parsing (not stored by API per their policy)
- Deleted from app if expense deleted

### Personal Data
- All data stored locally on device (SwiftData)
- No cloud sync (currently)
- User controls all data export/deletion

---

## Testing

### Manual Test Checklist

**Receipt Parsing**:
- [ ] Japanese receipt → extracts correctly
- [ ] English receipt → extracts correctly
- [ ] Blurry receipt → shows low confidence
- [ ] Non-receipt image → shows error

**Budget Tracking**:
- [ ] Daily spending updates correctly
- [ ] Rollover calculates positive/negative correctly
- [ ] Work days toggle filters expenses
- [ ] Progress bar shows overflow (>100%)

**Currency & Exchange**:
- [ ] Coin flip toggles ¥/$
- [ ] Live exchange rate fetched on save
- [ ] Warning shown if fallback rate used
- [ ] Currency persists across app launches (@AppStorage)

**Export**:
- [ ] CSV includes all expense fields
- [ ] Date filtering works
- [ ] Category filtering works
- [ ] ShareSheet presents correctly

---

## Troubleshooting

### "Failed to parse receipt: API Error (401)"
- Check API key in `Config/APIKeys.swift`
- Ensure key starts with `sk-ant-api03-`
- See [ANTHROPIC_SETUP.md](ANTHROPIC_SETUP.md)

### "Failed to fetch exchange rate"
- App uses fallback rate (¥150 = $1)
- Expense flagged with ⚠️ in report view
- Check internet connection
- API may be temporarily down

### Receipt not parsing correctly
- Ensure receipt is clear and well-lit
- Check all text is visible (not cropped)
- Manually edit any incorrect fields
- Confidence score shown (0-100%)

### Budget not updating
- Check if expense date falls within trip dates (Nov 28 - Dec 7, 2025)
- Verify `isWorkDay` flag is set correctly
- Toggle "Include travel days" setting

---

## Contributing

### Code Style
- SwiftUI best practices
- Prefer composition over inheritance
- Extract reusable components to `Components/`
- Use `// MARK: -` for section organization
- Emoji-tagged console logs (📸 📤 📥 ✅ ❌ ⚠️)

### Before Committing
1. Test on physical device (not just simulator)
2. Check console logs for errors/warnings
3. Verify no API keys committed
4. Update documentation if adding features

---

## License

[Your license here]

---

## Acknowledgments

- **Anthropic** - Claude API for receipt parsing
- **Frankfurter** - Free exchange rate API
- **SF Symbols** - Apple's icon library

---

## Contact

[Your contact info]

---

**Last Updated**: 2025-01-19
**App Version**: 1.0 (in development)
**Target iOS**: 17.0+
