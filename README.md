# Tokyo Expense Tracker

A SwiftUI iOS app for tracking expenses during your Tokyo trip with AI-powered receipt parsing and CSV export.

## What Is This?

This app helps you track expenses during travel by:
- Taking photos of receipts and automatically extracting merchant, amount, date, and category using Claude AI
- Manually entering expenses when needed
- Organizing expenses by category (Food/Per Diem, Transport, Other)
- Tracking budget against your trip budget
- Exporting expenses to CSV for reporting

**Perfect for:** Business trips, travel expense reporting, budget tracking

---

## Current Status

**Active Development** - Currently using **Claude API** for receipt parsing (transitioned from hybrid on-device parser approach)

### What's Working Now
- Manual expense entry with date, category, merchant, and amount
- Receipt photo capture and storage
- Budget tracking visualization (total budget bar, category breakdown)
- Expense list with filtering and sorting
- CSV export with date range and category filtering
- Exchange rate integration for JPY/USD conversion
- Report view with expense analysis

### Recent Changes
- **Switched to Claude API** for receipt parsing (abandoned hybrid Vision Framework + Foundation Models approach)
- Enhanced budget visualization with over-budget indicators
- Added comprehensive security protections (.gitignore, documentation)

---

## Next Phase: AI-Powered Descriptions & Enhanced Editing

The next phase of development focuses on four key areas:

### Phase 1: AI-Generated Descriptions (Easiest Impact)

**Goal:** Add AI-generated natural language descriptions to expenses

1. **Extend AnthropicService receipt parsing**
   - Add `expenseDescription` to ParsedReceipt model
   - Update Claude prompt to generate simple descriptions
   - Simple categories: "Breakfast", "Lunch", "Dinner", "Snack", "Coffee", "Groceries", "Taxi", "Train", etc.
   - Infer from receipt items, merchant type, and timestamp

2. **Update AddEntryView UI**
   - Add description text field below merchant name
   - Auto-populate from AI (with ability to edit)
   - Show "AI-generated" indicator like merchant field

3. **Display descriptions in list views**
   - Add description below merchant in ExpenseListView
   - Add description to ReportView expense rows
   - Use secondary text styling

### Phase 2: Individual Expense Editing

**Goal:** Allow users to edit any expense details

4. **Create ExpenseDetailView**
   - Full-screen view showing all expense details
   - Editable fields: merchant, amount, date, category, description
   - Display receipt image(s) with zoom capability
   - Save/Cancel buttons
   - Support for updating existing expense in SwiftData

5. **Add navigation to detail view**
   - Make expense rows tappable in ExpenseListView
   - Make expense rows tappable in ReportView
   - Use NavigationLink or sheet presentation

### Phase 3: Edit Mode with Bulk Operations

**Goal:** Enable bulk operations on multiple expenses

6. **Add Edit mode to ExpenseListView**
   - "Edit" button toggles selection mode
   - Checkboxes appear on expense rows
   - Action bar with: Delete Selected, Change Category, Export Selected
   - "Done" button to exit edit mode

7. **Wire up delete functionality**
   - Bulk delete in edit mode
   - Swipe-to-delete for individual expenses
   - Connect existing deleteExpenses(at:) method
   - Confirmation dialog for deletes

### Phase 4: Enhanced Export/Reports

**Goal:** Improve export user experience

8. **Improve CSV export UI**
   - Add cancel button during export generation
   - Progress indicator for large exports
   - Ensure descriptions are included in CSV
   - Test with date range and category filtering

### Success Criteria
- AI generates simple descriptions: "Lunch", "Dinner", "Coffee", "Train"
- Can tap expense to edit any field
- Edit mode enables bulk operations (delete, categorize, export)
- Can swipe to delete individual expenses
- CSV export can be cancelled mid-process
- Descriptions appear throughout the app

---

## Quick Start

### Requirements
- Xcode 16.0 or later
- iOS 18.0+ device or simulator
- Claude API key (for receipt parsing)

### Building and Running

1. Clone the repository
2. Open `TokyoExpenseApp.xcodeproj` in Xcode
3. Add your Claude API key to the project
4. Build and run (Cmd+R)

### First Time Setup

1. Grant camera and photo library permissions when prompted
2. Configure your trip budget and dates in settings
3. Start adding expenses manually or by taking receipt photos
4. View your expenses in the list or dashboard
5. Export to CSV when ready

---

## Documentation

- **[README.md](README.md)** - This file (project overview and current status)
- **[JOURNEY.md](JOURNEY.md)** - Development history, V1 learnings, and architectural decisions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture details (hybrid parser approach - historical)
- **[MIGRATION_PLAN.md](MIGRATION_PLAN.md)** - V1→V2 migration plan (historical reference)

---

## Features

### Expense Management
- **Manual Entry**: Add expenses with date, category, merchant, amount (JPY/USD), exchange rate
- **Receipt Photos**: Capture or import receipt images
- **AI Parsing**: Automatic extraction of merchant, amount, date using Claude API
- **Expense List**: View all expenses with search, filter, and sort
- **Expense Details**: View full details including receipt images

### Budget Tracking
- **Total Budget**: Track against your trip budget
- **Category Budgets**: Per diem (work days), transport, other
- **Visual Indicators**: Progress bars, over-budget warnings
- **Work Day Detection**: Automatic calculation based on trip dates

### Reporting & Export
- **CSV Export**: Export expenses with date range and category filtering
- **Report View**: Analyze expenses by category, time period
- **Exchange Rates**: JPY/USD conversion with configurable rates

---

## Technical Stack

- **Swift 6** with SwiftUI
- **SwiftData** for local persistence
- **Claude API** (Anthropic) for receipt parsing
- **Vision Framework** for OCR (potential future use)
- **iOS 18.0+** minimum deployment target

### Data Model
- **Expense**: Main model with all expense properties
- **ExpenseCategory**: Food/Per Diem, Transport, Other
- **Local Storage**: All data stored on-device, no cloud sync
- **Image Storage**: Receipt photos in app documents directory

---

## Development Journey

This project has evolved through multiple iterations:

1. **V1**: Explored hybrid on-device parsing (Vision Framework + Foundation Models)
2. **V2 Redesign**: UI-first approach with clean component architecture
3. **Current**: Simplified to Claude API for reliable, accurate parsing

For detailed learnings from V1, architectural decisions, and parser evolution, see [JOURNEY.md](JOURNEY.md).

---

## Support

For issues, questions, or feature requests:
- Check existing documentation (JOURNEY.md, ARCHITECTURE.md)
- Review Xcode console for error messages
- Check git commit history for recent changes

---

## License

Personal use only.
