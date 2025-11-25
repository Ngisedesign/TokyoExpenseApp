# Expense Views Refactoring Guide

## Overview
This document outlines a comprehensive refactoring strategy for `AddEntryView` and `ExpenseDetailView`, which currently share ~60% of their code.

## Current State Analysis

### Code Duplication Summary
- **Total shared code**: ~60% (approximately 400+ lines)
- **Identical logic**: Currency conversion, validation, image management
- **Near-identical UI**: Header, form fields, category picker, date picker
- **Unique features**:
  - AddEntryView: OCR/AI processing, PDF import, trip date validation
  - ExpenseDetailView: Read-only additional info display

---

## Proposed Refactoring Strategy

### Phase 1: Extract Shared Components

#### 1.1 ExpenseFormHeader
**Location**: `Components/ExpenseFormHeader.swift`

```swift
struct ExpenseFormHeader: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            LargeIconButton(icon: "xmark") {
                onCancel()
            }
            Spacer()
            LargeIconButton(
                icon: "checkmark",
                color: canSave ? .black : .secondary
            ) {
                onSave()
            }
            .disabled(!canSave)
        }
    }
}
```

**Files to update**:
- AddEntryView.swift (lines 104-128)
- ExpenseDetailView.swift (lines 76-95)

---

#### 1.2 ExpenseCategoryAndDatePicker
**Location**: `Components/ExpenseCategoryAndDatePicker.swift`

```swift
struct ExpenseCategoryAndDatePicker: View {
    @Binding var category: ExpenseCategory
    @Binding var date: Date
    var labelStyle: Font = .headline // Allows customization

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category pills
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(labelStyle)
                    .foregroundStyle(.black)

                FlowLayout(spacing: 8) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        CategoryPill(
                            text: cat.rawValue,
                            isSelected: category == cat
                        ) {
                            category = cat
                        }
                    }
                }
            }

            // Date picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Date")
                    .font(.headline)
                    .foregroundStyle(.black)

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
```

**Files to update**:
- AddEntryView.swift (lines 199-233)
- ExpenseDetailView.swift (lines 134-167)

---

#### 1.3 ExpenseMerchantField
**Location**: `Components/ExpenseMerchantField.swift`

```swift
struct ExpenseMerchantField: View {
    @Binding var text: String
    var isPlaceholder: Bool = false
    var showReviewBadge: Bool = false
    var onTextChange: ((String) -> Void)? = nil

    var body: some View {
        LabeledField(label: "Merchant", spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("Where did you spend?", text: $text)
                        .font(.body)
                        .foregroundStyle(isPlaceholder ? .red : .black)
                        .onChange(of: text) { _, newValue in
                            onTextChange?(newValue)
                        }

                    if showReviewBadge && isPlaceholder {
                        Text("REVIEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.red))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isPlaceholder && showReviewBadge ? .red.opacity(0.05) : .black.opacity(0.03))
                )
            }
        }
    }
}
```

**Files to update**:
- AddEntryView.swift (lines 235-269)
- ExpenseDetailView.swift (lines 174-184)

---

#### 1.4 ExpenseDescriptionField
**Location**: `Components/ExpenseDescriptionField.swift`

```swift
struct ExpenseDescriptionField: View {
    @Binding var text: String
    var isAIGenerated: Bool = false
    var onTextChange: ((String) -> Void)? = nil

    var body: some View {
        LabeledField(label: "Description", spacing: 8) {
            HStack {
                TextField("What was this for?", text: $text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .onChange(of: text) { _, newValue in
                        onTextChange?(newValue)
                    }

                if isAIGenerated {
                    Text("AI")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.7)))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.03))
            )
        }
    }
}
```

**Files to update**:
- AddEntryView.swift (lines 271-303)
- ExpenseDetailView.swift (lines 186-196)

---

#### 1.5 ExpenseAmountField
**Location**: `Components/ExpenseAmountField.swift`

```swift
enum ExpenseCurrency {
    case jpy
    case usd
}

struct ExpenseAmountField: View {
    @Binding var amountString: String
    @Binding var currency: ExpenseCurrency
    let exchangeRate: Decimal
    let onToggleCurrency: () -> Void
    var showExchangeRate: Bool = true

    var body: some View {
        LabeledField(label: "Amount", spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Amount input
                HStack(spacing: 4) {
                    // Currency toggle button
                    Button {
                        onToggleCurrency()
                    } label: {
                        Text(currency == .jpy ? "¥" : "$")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .frame(width: 24)
                    }
                    .buttonStyle(.plain)

                    TextField("0", text: $amountString)
                        .font(.body)
                        .fontWeight(.bold)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(.black)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(0.03))
                )

                // Exchange rate display
                if showExchangeRate {
                    Text("Rate: ¥\(NSDecimalNumber(decimal: exchangeRate).stringValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
        }
    }
}
```

**Files to update**:
- AddEntryView.swift (lines 305-362)
- ExpenseDetailView.swift (lines 198-246)

---

### Phase 2: Extract Shared Logic

#### 2.1 CurrencyConverter Utility
**Location**: `Utilities/CurrencyConverter.swift`

```swift
struct CurrencyConverter {
    /// Converts an amount from one currency to another
    static func convert(
        amount: Decimal,
        from: ExpenseCurrency,
        to: ExpenseCurrency,
        rate: Decimal
    ) -> String {
        guard amount > 0 else { return "0" }

        switch (from, to) {
        case (.jpy, .usd):
            let usdAmount = amount / rate
            return usdAmount.formatted(.number.precision(.fractionLength(2)).grouping(.never))

        case (.usd, .jpy):
            let jpyAmount = amount * rate
            let nsAmount = NSDecimalNumber(decimal: jpyAmount)
            let handler = NSDecimalNumberHandler(
                roundingMode: .bankers,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
            return nsAmount.rounding(accordingToBehavior: handler).stringValue

        default:
            return amount.description
        }
    }

    /// Rounds JPY to whole number
    static func roundJPY(_ amount: Decimal) -> Decimal {
        let nsAmount = NSDecimalNumber(decimal: amount)
        let handler = NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        return nsAmount.rounding(accordingToBehavior: handler).decimalValue
    }
}
```

**Files to update**:
- AddEntryView.swift (lines 364-389)
- ExpenseDetailView.swift (lines 203-230)

---

#### 2.2 ExpenseValidator Utility
**Location**: `Utilities/ExpenseValidator.swift`

```swift
struct ExpenseValidator {
    /// Basic validation for expense form
    static func validateBasic(merchant: String, amount: String) -> String? {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMerchant.isEmpty {
            return "Please enter a merchant name."
        }

        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAmount.isEmpty {
            return "Please enter an amount."
        }

        guard let amountValue = Decimal(string: trimmedAmount) else {
            return "Amount must be a valid number."
        }

        if amountValue <= 0 {
            return "Amount must be greater than zero."
        }

        return nil
    }

    /// Validates date is within trip range (for AddEntryView)
    static func validateTripDate(_ date: Date, tripStart: Date, tripEnd: Date) -> String? {
        let calendar = Calendar.current
        let minDate = calendar.date(byAdding: .day, value: -30, to: tripStart)!
        let maxDate = calendar.date(byAdding: .day, value: 7, to: tripEnd)!

        if date < minDate || date > maxDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            return "Date must be within trip dates (\(dateFormatter.string(from: tripStart)) - \(dateFormatter.string(from: tripEnd))), allowing 30 days before for advance purchases."
        }

        return nil
    }

    /// Quick validation for save button enablement
    static func canSave(merchant: String, amount: String, date: Date? = nil, tripStart: Date? = nil, tripEnd: Date? = nil) -> Bool {
        guard !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        guard !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let amountValue = Decimal(string: amount),
              amountValue > 0 else {
            return false
        }

        // Optional trip date validation
        if let date = date, let tripStart = tripStart, let tripEnd = tripEnd {
            let calendar = Calendar.current
            let minDate = calendar.date(byAdding: .day, value: -30, to: tripStart)!
            let maxDate = calendar.date(byAdding: .day, value: 7, to: tripEnd)!

            guard date >= minDate && date <= maxDate else {
                return false
            }
        }

        return true
    }
}
```

**Files to update**:
- AddEntryView.swift (lines 551-578)
- ExpenseDetailView.swift (lines 333-338)

---

### Phase 3: Create Shared View Model (Optional but Recommended)

#### 3.1 ExpenseFormViewModel
**Location**: `ViewModels/ExpenseFormViewModel.swift`

```swift
@Observable
class ExpenseFormViewModel {
    // Form state
    var merchant: String = ""
    var expenseDescription: String = ""
    var date: Date = .now
    var amountString: String = ""
    var category: ExpenseCategory = .food
    var currency: ExpenseCurrency = .jpy

    // Image state
    var selectedImageUI: UIImage? = nil

    // Validation state
    var validationError: String? = nil

    // Exchange rate
    var exchangeRate: Decimal = BudgetTracker.defaultExchangeRate

    // For edit mode
    private var existingExpense: Expense?

    init(expense: Expense? = nil) {
        if let expense = expense {
            // Initialize for editing
            self.existingExpense = expense
            self.merchant = expense.merchantName
            self.expenseDescription = expense.expenseDescription
            self.date = expense.date
            self.category = ExpenseCategory(rawValue: expense.category) ?? .food
            self.amountString = String(describing: expense.amountJPY)
            self.exchangeRate = expense.exchangeRate
        }
    }

    // Computed property
    var canSave: Bool {
        ExpenseValidator.canSave(merchant: merchant, amount: amountString)
    }

    // Currency toggle
    func toggleCurrency() {
        let currentAmount = Decimal(string: amountString) ?? 0
        let newAmount = CurrencyConverter.convert(
            amount: currentAmount,
            from: currency,
            to: currency == .jpy ? .usd : .jpy,
            rate: exchangeRate
        )
        amountString = newAmount
        currency = currency == .jpy ? .usd : .jpy
    }

    // Validation
    func validate() -> String? {
        return ExpenseValidator.validateBasic(merchant: merchant, amount: amountString)
    }
}
```

---

## Implementation Roadmap

### Step 1: Create Component Files (Low Risk)
1. Create `Components/ExpenseFormHeader.swift`
2. Create `Components/ExpenseCategoryAndDatePicker.swift`
3. Create `Components/ExpenseMerchantField.swift`
4. Create `Components/ExpenseDescriptionField.swift`
5. Create `Components/ExpenseAmountField.swift`

**Benefit**: Components can be tested independently before integration

---

### Step 2: Create Utility Files (Low Risk)
1. Create `Utilities/CurrencyConverter.swift`
2. Create `Utilities/ExpenseValidator.swift`

**Benefit**: Pure functions, easy to test

---

### Step 3: Refactor AddEntryView (Medium Risk)
1. Replace header with `ExpenseFormHeader`
2. Replace category/date section with `ExpenseCategoryAndDatePicker`
3. Replace merchant field with `ExpenseMerchantField`
4. Replace description field with `ExpenseDescriptionField`
5. Replace amount field with `ExpenseAmountField`
6. Replace currency toggle with `CurrencyConverter.convert()`
7. Replace validation with `ExpenseValidator`

**Test thoroughly**: OCR processing, PDF import, image capture

---

### Step 4: Refactor ExpenseDetailView (Medium Risk)
1. Replace header with `ExpenseFormHeader`
2. Replace category/date section with `ExpenseCategoryAndDatePicker`
3. Replace merchant field with `ExpenseMerchantField`
4. Replace description field with `ExpenseDescriptionField`
5. Replace amount field with `ExpenseAmountField`
6. Replace currency toggle with `CurrencyConverter.convert()`
7. Replace validation with `ExpenseValidator`

**Test thoroughly**: Expense updates, image replacement

---

### Step 5: Optional - Extract View Model (Higher Risk)
1. Create `ExpenseFormViewModel`
2. Migrate state from AddEntryView to view model
3. Migrate state from ExpenseDetailView to view model
4. Update bindings

**Benefit**: Better testability, clearer separation of concerns

---

## Testing Strategy

### Unit Tests
- `CurrencyConverter`: Test JPY ↔ USD conversions with various rates
- `ExpenseValidator`: Test all validation scenarios
- `ExpenseFormViewModel`: Test state management and validation

### UI Tests
- Test add expense flow end-to-end
- Test edit expense flow end-to-end
- Test OCR processing in AddEntryView
- Test image replacement in ExpenseDetailView
- Test currency toggle in both views
- Test validation errors in both views

### Manual Testing Checklist
- [ ] Can add new expense with all fields
- [ ] Can edit existing expense
- [ ] Can toggle currency (¥ ↔ $)
- [ ] Can capture photo from camera
- [ ] Can select photo from library
- [ ] Can import PDF receipt
- [ ] OCR processing works correctly
- [ ] Validation prevents invalid submissions
- [ ] All badges display correctly (REVIEW, AI)
- [ ] Exchange rates display correctly

---

## Benefits Summary

### Code Quality
- **60% reduction** in duplicated code
- **Single source of truth** for form UI and behavior
- **Easier to test** with extracted components and utilities

### Maintainability
- **One place** to fix bugs in form validation
- **One place** to update currency conversion logic
- **One place** to adjust form field styling

### Consistency
- **Guaranteed** UI consistency between add and edit flows
- **Impossible** to have divergent behavior

### Developer Experience
- **Reusable** components for future expense-related features
- **Clearer** separation of concerns
- **Better** code organization

---

## Risks and Mitigation

### Risk 1: Breaking OCR Processing
**Mitigation**: Keep OCR logic in AddEntryView, only extract shared UI/logic

### Risk 2: Breaking Image Management
**Mitigation**: Thorough testing of image capture and replacement flows

### Risk 3: Regression in Existing Features
**Mitigation**: Comprehensive manual testing before and after refactor

### Risk 4: Time Investment
**Mitigation**: Phased approach allows stopping at any point while still gaining benefits

---

## Estimated Timeline

- **Phase 1** (Components): 2-3 hours
- **Phase 2** (Utilities): 1-2 hours
- **Phase 3** (AddEntryView refactor): 2-3 hours
- **Phase 4** (ExpenseDetailView refactor): 1-2 hours
- **Phase 5** (Optional - View Model): 2-3 hours
- **Testing**: 2-3 hours

**Total**: 8-16 hours (depending on whether view model is extracted)

---

## Conclusion

This refactoring will significantly improve code quality and maintainability while reducing the risk of inconsistencies between add and edit flows. The phased approach allows for incremental progress with testing at each stage.

**Recommendation**: Start with Phase 1 and 2 (components and utilities) as they provide immediate value with minimal risk.
