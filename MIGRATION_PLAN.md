# V1 → V2 Backend Integration Migration Plan

**Created:** 2025-01-16
**Status:** ⚠️ **HISTORICAL REFERENCE ONLY** - Project transitioned to Claude API instead
**Context:** This plan was created to migrate proven receipt parsing backend from V1 (TokyoExpenseTracking) into V2's redesigned UI (TokyoExpenseTracking_02)

> **Note:** The project has evolved beyond this migration plan. We transitioned from the hybrid on-device parser approach (Vision Framework + Foundation Models) to using the **Claude API** for receipt parsing. This document is preserved for historical reference and technical learning. See [JOURNEY.md](JOURNEY.md) for the full development story and [README.md](README.md) for current status.

---

## Key Decisions Made

✅ **Remove Shopping category** - Keep only Food, Transport, Other
✅ **macOS 26+ available** - Use HybridParser (Spatial + LLM) as primary
✅ **Keep V2 views** - Build additional views as needed in V2's component style
✅ **Photo flow:**
- Dashboard camera icon → Quick camera capture (auto-save)
- + button → AddEntryView (library primary, camera secondary)

---

## Reference: What Works in V1

### Proven Technologies (Copy These):
1. **HybridParser** - ✅ BOOKOFF ¥400, Yodobashi ¥159,810 parsed correctly
2. **SpatialReceiptParser** - Deterministic fallback, no LLM needed
3. **OCRService** - Vision Framework, Japanese text recognition
4. **ImageManager** - Receipt storage in Documents/receipts/
5. **SwiftData Expense model** - With isArchived, isIncomplete
6. **CSVExporter** - Proper CSV formatting
7. **CategoryClassifier** - Keyword-based auto-categorization

### V1 File Locations:
```
/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/
├── Models/Expense.swift
└── Utilities/
    ├── OCRService.swift
    ├── HybridParser.swift
    ├── SpatialReceiptParser.swift
    ├── ImageManager.swift
    ├── CSVExporter.swift
    ├── CategoryClassifier.swift
    └── TranslationService.swift
```

---

## Phase 1: Core Backend Migration

### Step 1.1: Create Folder Structure
```bash
cd /Users/claudiang/Projects/TokyoExpenseTracking_02/TokyoExpenseApp_02
mkdir -p Models Utilities
```

### Step 1.2: Migrate Data Model
**Copy:** `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Models/Expense.swift`
**To:** `/Users/claudiang/Projects/TokyoExpenseTracking_02/TokyoExpenseApp_02/Models/Expense.swift`

**Modifications needed in Expense.swift:**
```swift
// REMOVE Shopping category
enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food/Per Diem"
    case transport = "Transport"
    // case shopping = "Shopping/Personal"  // REMOVE THIS
    case other = "Other"
}
```

**Ensure these properties exist:**
- `var isIncomplete: Bool` (computed property for missing data)
- `var isArchived: Bool?` (for archiving expenses)
- `var ocrConfidence: Float?` (OCR quality tracking)

### Step 1.3: Migrate Core Utilities

**Copy these files AS-IS (no changes needed):**

1. **OCRService.swift**
   - From: `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Utilities/OCRService.swift`
   - To: `Utilities/OCRService.swift`
   - Purpose: Vision Framework OCR with Japanese support
   - No modifications needed

2. **HybridParser.swift**
   - From: `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Utilities/HybridParser.swift`
   - To: `Utilities/HybridParser.swift`
   - Purpose: Combines spatial parsing + Foundation Models LLM
   - No modifications needed

3. **SpatialReceiptParser.swift**
   - From: `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Utilities/SpatialReceiptParser.swift`
   - To: `Utilities/SpatialReceiptParser.swift`
   - Purpose: Deterministic spatial analysis fallback
   - No modifications needed

4. **ImageManager.swift**
   - From: `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Utilities/ImageManager.swift`
   - To: `Utilities/ImageManager.swift`
   - Purpose: Receipt image storage in Documents/receipts/
   - No modifications needed

5. **CSVExporter.swift**
   - From: `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Utilities/CSVExporter.swift`
   - To: `Utilities/CSVExporter.swift`
   - Purpose: Export expenses to CSV format
   - No modifications needed

6. **TranslationService.swift**
   - From: `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Utilities/TranslationService.swift`
   - To: `Utilities/TranslationService.swift`
   - Purpose: Keyword-based Japanese translation
   - No modifications needed

**Copy and MODIFY this file:**

7. **CategoryClassifier.swift**
   - From: `/Users/claudiang/Projects/TokyoExpenseTracking/TokyoExpenseTracker/Utilities/CategoryClassifier.swift`
   - To: `Utilities/CategoryClassifier.swift`
   - **Modifications needed:**
     ```swift
     // Remove all Shopping category logic
     // Update to return only: .food, .transport, or .other

     // In classifyMerchant() function:
     // Remove shopping keywords (コンビニ, 店, store, etc.)
     // Map those to .other instead
     ```

**DO NOT copy these files (unnecessary):**
- ❌ `FoundationModelsParser.swift` - Functionality absorbed into HybridParser
- ❌ `AppleIntelligenceParser.swift` - Over-engineered, not needed
- ❌ `ReceiptParser.swift` - Basic fallback, not needed

### Step 1.4: Configure SwiftData

**Update `TokyoExpenseApp_02App.swift`:**
```swift
import SwiftUI
import SwiftData

@main
struct TokyoExpenseApp_02App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Expense.self)  // ADD THIS
    }
}
```

**In views that need data access, add:**
```swift
@Environment(\.modelContext) private var modelContext
@Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
```

---

## Phase 2: OCR Integration in AddEntryView

### Step 2.1: Add OCR State Variables

**In `AddEntryView.swift`, add these @State properties:**
```swift
@State private var isProcessingOCR: Bool = false
@State private var ocrConfidence: Float? = nil
@State private var ocrError: String? = nil
```

### Step 2.2: Create OCR Processing Function

**Add this function to `AddEntryView`:**
```swift
private func processReceiptImage(_ image: UIImage) async {
    isProcessingOCR = true
    ocrError = nil

    do {
        // Step 1: Run OCR
        let ocrResult = await OCRService.shared.recognizeText(in: image)

        // Step 2: Parse with HybridParser
        if #available(iOS 26.0, *) {
            do {
                let parsed = try await HybridParser.shared.parseReceipt(
                    from: ocrResult.textElements,
                    confidence: ocrResult.confidence
                )

                // Step 3: Auto-fill form
                await MainActor.run {
                    if let merchantName = parsed.merchantName {
                        merchant = merchantName
                    }
                    if let amount = parsed.totalAmountYen {
                        amountYen = String(format: "%.0f", amount)
                    }
                    if let parsedDate = parsed.date {
                        date = parsedDate
                    }
                    if let categoryStr = parsed.category,
                       let parsedCategory = ExpenseCategory(rawValue: categoryStr) {
                        category = parsedCategory
                    }
                    ocrConfidence = parsed.confidence
                }
            } catch {
                // Fallback to SpatialParser
                let parsed = SpatialReceiptParser.shared.parseReceipt(
                    from: ocrResult.textElements,
                    confidence: ocrResult.confidence
                )

                await MainActor.run {
                    if let amount = parsed.totalAmountYen {
                        amountYen = String(format: "%.0f", amount)
                    }
                    ocrConfidence = parsed.confidence
                }
            }
        } else {
            // Older iOS: Use SpatialParser only
            let parsed = SpatialReceiptParser.shared.parseReceipt(
                from: ocrResult.textElements,
                confidence: ocrResult.confidence
            )

            await MainActor.run {
                if let amount = parsed.totalAmountYen {
                    amountYen = String(format: "%.0f", amount)
                }
                ocrConfidence = parsed.confidence
            }
        }
    } catch {
        await MainActor.run {
            ocrError = "OCR failed: \(error.localizedDescription)"
        }
    }

    isProcessingOCR = false
}
```

### Step 2.3: Trigger OCR When Image Selected

**Update the `onChange(of: selectedItem)` handler:**
```swift
.onChange(of: selectedItem) { newItem in
    Task {
        await loadImage(from: newItem)

        // Trigger OCR after image loads
        if let image = selectedImageUI {
            await processReceiptImage(image)
        }
    }
}
```

### Step 2.4: Add OCR Feedback UI

**Add this above the form fields in AddEntryView:**
```swift
// OCR Processing Indicator
if isProcessingOCR {
    HStack {
        ProgressView()
        Text("Processing receipt...")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .padding()
}

// OCR Confidence Score
if let confidence = ocrConfidence {
    HStack {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        Text("OCR Confidence: \(Int(confidence * 100))%")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal)
}

// OCR Error
if let error = ocrError {
    HStack {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        Text(error)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal)
}
```

### Step 2.5: Save Expense to SwiftData

**Add environment variable at top of AddEntryView:**
```swift
@Environment(\.modelContext) private var modelContext
```

**Update the save button action:**
```swift
LargeIconButton(
    icon: "checkmark",
    color: canSave ? .black : .secondary
) {
    saveExpense()
    dismiss()
}
.disabled(!canSave)
```

**Create saveExpense() function:**
```swift
private func saveExpense() {
    // Convert amountYen string to Decimal
    let amountJPY = Decimal(string: amountYen) ?? 0

    // Calculate USD (exchange rate: ¥150 = $1)
    let exchangeRate: Decimal = 150
    let amountUSD = amountJPY / exchangeRate

    // Save receipt image
    var imagePaths: [String] = []
    if let image = selectedImageUI {
        if let savedPath = ImageManager.shared.saveImage(image) {
            imagePaths.append(savedPath)
        }
    }

    // Create expense
    let expense = Expense(
        date: date,
        category: category.rawValue,
        merchantName: merchant.isEmpty ? "Untitled" : merchant,
        expenseDescription: "",
        amountJPY: amountJPY,
        amountUSD: amountUSD,
        exchangeRate: exchangeRate,
        receiptImagePaths: imagePaths,
        isWorkDay: false, // TODO: Calculate based on date (Dec 1-5, 2025)
        isManualEntry: ocrConfidence == nil,
        ocrConfidence: ocrConfidence
    )

    modelContext.insert(expense)

    do {
        try modelContext.save()
    } catch {
        print("Error saving expense: \(error)")
    }
}
```

---

## Phase 3: Camera Integration

### Step 3.1: Update Info.plist Permissions

**Add to `Info.plist`:**
```xml
<key>NSCameraUsageDescription</key>
<string>Tokyo Expense Tracker needs camera access to photograph receipts for automatic expense entry.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Tokyo Expense Tracker needs photo library access to import receipt images.</string>
```

### Step 3.2: Main Dashboard Camera (Quick Capture)

**In `ContentView.swift`, add state:**
```swift
@State private var showQuickCamera: Bool = false
@State private var capturedImage: UIImage? = nil
@Environment(\.modelContext) private var modelContext
```

**Update camera button:**
```swift
LargeIconButton(icon: "camera", size: 48) {
    showQuickCamera = true
}
```

**Add sheet modifier:**
```swift
.sheet(isPresented: $showQuickCamera) {
    QuickCameraView(capturedImage: $capturedImage)
}
.onChange(of: capturedImage) { newImage in
    if let image = newImage {
        Task {
            await processQuickCapture(image)
        }
    }
}
```

**Create quick capture handler:**
```swift
private func processQuickCapture(_ image: UIImage) async {
    // Run OCR
    let ocrResult = await OCRService.shared.recognizeText(in: image)

    // Parse receipt
    var parsedReceipt: ParsedReceipt?
    if #available(iOS 26.0, *) {
        parsedReceipt = try? await HybridParser.shared.parseReceipt(
            from: ocrResult.textElements,
            confidence: ocrResult.confidence
        )
    }

    // Fallback to spatial if needed
    if parsedReceipt == nil {
        parsedReceipt = SpatialReceiptParser.shared.parseReceipt(
            from: ocrResult.textElements,
            confidence: ocrResult.confidence
        )
    }

    // Save image
    guard let imagePath = ImageManager.shared.saveImage(image) else { return }

    // Create expense
    let amountJPY = Decimal(parsedReceipt?.totalAmountYen ?? 0)
    let exchangeRate: Decimal = 150
    let expense = Expense(
        date: parsedReceipt?.date ?? Date(),
        category: parsedReceipt?.category ?? "Other",
        merchantName: parsedReceipt?.merchantName ?? "Quick Capture",
        expenseDescription: "",
        amountJPY: amountJPY,
        amountUSD: amountJPY / exchangeRate,
        exchangeRate: exchangeRate,
        receiptImagePaths: [imagePath],
        isWorkDay: false,
        isManualEntry: false,
        ocrConfidence: parsedReceipt?.confidence
    )

    await MainActor.run {
        modelContext.insert(expense)
        try? modelContext.save()
        capturedImage = nil // Reset
    }
}
```

### Step 3.3: Create QuickCameraView

**Create new file: `QuickCameraView.swift`**
```swift
import SwiftUI
import UIKit

struct QuickCameraView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var capturedImage: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        VStack {
            HStack {
                LargeIconButton(icon: "xmark") {
                    dismiss()
                }
                Spacer()
            }
            .padding()

            Spacer()

            Button {
                showImagePicker = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(.black.opacity(0.3))

                    Text("Tap to capture receipt")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerController(image: $capturedImage, sourceType: .camera)
                .onDisappear {
                    if capturedImage != nil {
                        dismiss()
                    }
                }
        }
    }
}

// UIImagePickerController wrapper for camera
struct ImagePickerController: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController

        init(_ parent: ImagePickerController) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}
```

### Step 3.4: Update AddEntryView Camera Button

**Replace `CameraPickerView` with real camera:**
```swift
.sheet(isPresented: $showCamera) {
    ImagePickerController(image: $selectedImageUI, sourceType: .camera)
}
```

---

## Phase 4: Additional Views (Build As Needed)

### Step 4.1: Create ExpenseListView

**Create new file: `ExpenseListView.swift`**
```swift
import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var searchText = ""
    @State private var selectedCategory: ExpenseCategory? = nil

    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            let matchesSearch = searchText.isEmpty ||
                expense.merchantName.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                expense.category == selectedCategory?.rawValue
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Expenses")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            // Category filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryPill(text: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        CategoryPill(text: cat.rawValue, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Search
            TextField("Search merchants...", text: $searchText)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.03))
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

            // List
            List {
                ForEach(filteredExpenses) { expense in
                    ExpenseRow(expense: expense)
                }
                .onDelete(perform: deleteExpenses)
            }
            .listStyle(.plain)
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredExpenses[index])
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchantName)
                    .font(.headline)
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(expense.amountJPY.formatted())")
                    .font(.headline)
                Text("$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### Step 4.2: Create ExportView

**Create new file: `ExportView.swift`**
```swift
import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]

    @State private var startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 1))!
    @State private var endDate = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 5))!
    @State private var selectedCategories: Set<String> = Set(ExpenseCategory.allCases.map { $0.rawValue })
    @State private var showShareSheet = false
    @State private var csvURL: URL?

    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            expense.date >= startDate &&
            expense.date <= endDate &&
            selectedCategories.contains(expense.category)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Export Expenses")
                .font(.largeTitle)
                .fontWeight(.bold)

            LabeledField(label: "Date Range") {
                HStack {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("to")
                        .foregroundStyle(.secondary)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            LabeledField(label: "Categories") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Toggle(category.rawValue, isOn: Binding(
                            get: { selectedCategories.contains(category.rawValue) },
                            set: { isSelected in
                                if isSelected {
                                    selectedCategories.insert(category.rawValue)
                                } else {
                                    selectedCategories.remove(category.rawValue)
                                }
                            }
                        ))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(.headline)
                Text("\(filteredExpenses.count) expenses")
                    .foregroundStyle(.secondary)
                let total = filteredExpenses.reduce(Decimal(0)) { $0 + $1.amountUSD }
                Text("Total: $\(total.formatted(.number.precision(.fractionLength(2))))")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            Button {
                exportCSV()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 24, weight: .bold))
                    Text("Export CSV")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.black)
                )
            }
        }
        .padding()
        .sheet(isPresented: $showShareSheet) {
            if let url = csvURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportCSV() {
        let csvString = CSVExporter.shared.generateCSV(from: filteredExpenses)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("expenses.csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            csvURL = tempURL
            showShareSheet = true
        } catch {
            print("Error writing CSV: \(error)")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

---

## Phase 5: Testing & Validation

### Test Cases with Real Receipts

**1. Yodobashi Camera Receipt (¥159,810)**
- [ ] OCR extracts all text
- [ ] Amount correctly parsed: ¥159,810 (not ¥159)
- [ ] Merchant name extracted
- [ ] Auto-categorized correctly
- [ ] Saves to SwiftData
- [ ] Appears in expense list

**2. BOOKOFF Receipt (¥400)**
- [ ] OCR extracts all text
- [ ] Amount correctly parsed: ¥400 (not ¥1,660)
- [ ] Merchant name extracted
- [ ] Auto-categorized correctly
- [ ] Saves to SwiftData

**3. Quick Camera Flow**
- [ ] Dashboard camera button works
- [ ] Camera captures image
- [ ] OCR processes automatically
- [ ] Expense auto-saves
- [ ] Confirmation shown briefly

**4. Manual Entry Flow**
- [ ] + button opens AddEntryView
- [ ] Library picker works
- [ ] Camera button works (secondary)
- [ ] OCR auto-fills fields
- [ ] User can edit OCR results
- [ ] Save button works

**5. End-to-End**
- [ ] Multiple expenses save correctly
- [ ] Expense list shows all expenses
- [ ] Search/filter works
- [ ] Budget tracking updates
- [ ] CSV export generates correct file
- [ ] All works offline

---

## Common Issues & Solutions

### Issue: Foundation Models "assetsUnavailable" Error
**Solution:** Verify macOS 26+ installed. If not, SpatialParser fallback should activate automatically.

### Issue: OCR Returns No Text
**Solution:** Check image quality, ensure receipt is visible and in focus. May need better lighting.

### Issue: Wrong Amount Extracted
**Solution:** Check OCR confidence score. If low (<0.7), prompt user to verify. May need manual entry.

### Issue: Camera Permission Denied
**Solution:** Show alert directing user to Settings > Privacy > Camera

---

## Success Metrics
- ✅ 90%+ accuracy on test receipts (BOOKOFF, Yodobashi)
- ✅ <3 second OCR processing time
- ✅ All expenses persist correctly
- ✅ CSV export works
- ✅ Budget tracking accurate
- ✅ Works completely offline

---

## Next Steps After Migration
1. Test with real receipts in Photos library
2. Test camera capture flow
3. Validate CSV export format
4. Calculate work day logic (Dec 1-5, 2025)
5. Fine-tune budget calculations
6. Add error handling polish
7. Final UX testing before Tokyo trip

---

**Ready to execute! Start with Phase 1, Step 1.1.**
