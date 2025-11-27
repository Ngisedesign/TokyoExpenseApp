import SwiftUI
import SwiftData
import PhotosUI
import PDFKit

// MARK: - REFACTORING OPPORTUNITY
// ============================================================================
// This view shares significant code with AddEntryView. Consider extracting:
//
// 1. SHARED COMPONENTS (identical or nearly identical):
//    - ExpenseFormHeader: Header with X and checkmark buttons (lines 42-58)
//    - ExpenseImageSection: Receipt image display (lines 71-95)
//    - ExpenseCategoryAndDatePicker: Category pills + date picker (lines 98-127)
//    - ExpenseMerchantField: Merchant text field (lines 134-142)
//    - ExpenseDescriptionField: Description text field (lines 145-153)
//    - ExpenseAmountField: Amount input with currency toggle (lines 156-202)
//
// 2. SHARED LOGIC (identical logic in both views):
//    - Currency conversion logic (lines 158-183) - IDENTICAL to AddEntryView
//    - Validation rules (lines 285-288)
//    - Image management (lines 325-350)
//
// 3. SHARED STATE (could be managed by @Observable ExpenseFormData):
//    - merchantName, expenseDescription, date, amountString, category
//    - currency enum and conversion state
//    - Image picker state
//
// 4. DIFFERENCES TO PRESERVE:
//    - ExpenseDetailView: Shows read-only additional info (lines 204-256)
//    - ExpenseDetailView: Updates existing expense vs AddEntryView creates new
//    - AddEntryView: Has OCR/AI processing
//    - AddEntryView: Has PDF import
//
// BENEFITS:
//    - Guaranteed UI consistency between add and edit
//    - Single place to fix bugs or add features
//    - ~60% reduction in code duplication
//    - Easier to test with shared components
// ============================================================================

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let expense: Expense

    @State private var merchantName: String
    @State private var expenseDescription: String
    @State private var date: Date
    @State private var category: ExpenseCategory
    @State private var amountString: String
    
    enum Currency {
        case jpy
        case usd
    }
    @State private var currency: Currency = .jpy
    @State private var showReplaceOptions = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var showDocumentPicker = false

    @State private var capturedImage: UIImage? = nil
    @State private var imageToReplacePath: String? = nil
    @State private var originalPDFData: Data? = nil

    init(expense: Expense) {
        self.expense = expense
        _merchantName = State(initialValue: expense.merchantName)
        _expenseDescription = State(initialValue: expense.expenseDescription)
        _date = State(initialValue: expense.date)
        _category = State(initialValue: ExpenseCategory(rawValue: expense.category) ?? .food)
        _amountString = State(initialValue: String(describing: expense.amountJPY))
        _currency = State(initialValue: .jpy)
    }

    var body: some View {
        VStack(spacing: 0) {
            // REFACTOR: Extract to ExpenseFormHeader component (see AddEntryView lines 104-128)
            // This is nearly identical except for the save action (synchronous vs async)
            // Header
            HStack {
                LargeIconButton(icon: "xmark") {
                    dismiss()
                }
                Spacer()
                LargeIconButton(
                    icon: "checkmark",
                    color: canSave ? .black : .secondary
                ) {
                    saveChanges()
                    dismiss()
                }
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Edit Expense")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        // Top Section: Image + Categories
                        HStack(alignment: .top, spacing: 16) {
                            // Left: Receipt Image
                            if let firstPath = expense.receiptImagePaths.first,
                               let image = ImageManager.shared.loadImage(firstPath) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: geometry.size.width * 0.45)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        imageToReplacePath = firstPath
                                        showReplaceOptions = true
                                    }
                            } else {
                                // Placeholder if no image
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.black.opacity(0.05))
                                    .frame(width: 120, height: 160)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                    )
                                    .onTapGesture {
                                        showReplaceOptions = true
                                    }
                            }

                            // REFACTOR: Extract to ExpenseCategoryAndDatePicker component
                            // Nearly identical to AddEntryView (lines 199-233) except label font (.subheadline vs .headline)
                            // Could be unified with a font style parameter
                            // Right: Categories (Wrapping)
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)

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

                                // Date (Moved from bottom)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)

                                    DatePicker("", selection: $date, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // REFACTOR: All fields below (Merchant, Description, Amount) can be extracted
                        // Form Fields
                        VStack(alignment: .leading, spacing: 20) {
                            // REFACTOR: Extract to ExpenseMerchantField (see AddEntryView lines 235-269)
                            // Merchant Name
                            LabeledField(label: "Merchant") {
                                TextField("Merchant name", text: $merchantName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.black.opacity(0.03))
                                    )
                            }

                            // REFACTOR: Extract to ExpenseDescriptionField (see AddEntryView lines 271-303)
                            // Description
                            LabeledField(label: "Description") {
                                TextField("What was this for?", text: $expenseDescription)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.black.opacity(0.03))
                                    )
                            }

                            // REFACTOR: Extract to ExpenseAmountField (see AddEntryView lines 305-362)
                            // Amount
                            LabeledField(label: "Amount") {
                                HStack(spacing: 8) {
                                    Button {
                                        // REFACTOR: Extract currency toggle logic to CurrencyConverter utility
                                        // This is IDENTICAL to AddEntryView (lines 364-389)
                                        // Toggle currency and convert amount
                                        let currentAmount = Decimal(string: amountString) ?? 0
                                        let rate = expense.exchangeRate
                                        
                                        withAnimation {
                                            if currency == .jpy {
                                                // Switching JPY -> USD
                                                currency = .usd
                                                if currentAmount > 0 {
                                                    let usdAmount = currentAmount / rate
                                                    amountString = usdAmount.formatted(.number.precision(.fractionLength(2)).grouping(.never))
                                                }
                                            } else {
                                                // Switching USD -> JPY
                                                currency = .jpy
                                                if currentAmount > 0 {
                                                    let jpyAmount = currentAmount * rate
                                                    // Round to whole number
                                                    let nsAmount = NSDecimalNumber(decimal: jpyAmount)
                                                    let handler = NSDecimalNumberHandler(roundingMode: .bankers, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
                                                    amountString = nsAmount.rounding(accordingToBehavior: handler).stringValue
                                                }
                                            }
                                        }
                                    } label: {
                                        Text(currency == .jpy ? "¥" : "$")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                            .frame(width: 24)
                                    }
                                    .buttonStyle(.plain)

                                    TextField("0", text: $amountString)
                                        .font(.body) // Consistent font
                                        .fontWeight(.semibold)
                                        .keyboardType(.decimalPad)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.black.opacity(0.03))
                                )
                            }

                            // NOTE: This section is unique to ExpenseDetailView (read-only data display)
                            // AddEntryView doesn't have this since there's no existing expense to show
                            // Additional Info
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Additional Information")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    Text("Original Amount:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("¥\(expense.amountJPY.formatted(.number.precision(.fractionLength(0))))")
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }

                                HStack {
                                    Text("USD Amount:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))")
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }

                                HStack {
                                    Text("Exchange Rate:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(String(format: "%.2f", NSDecimalNumber(decimal: expense.exchangeRate).doubleValue))
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }

                                if let confidence = expense.ocrConfidence {
                                    HStack {
                                        Text("OCR Confidence:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(String(format: "%.0f%%", confidence * 100))
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .confirmationDialog("Replace receipt image", isPresented: $showReplaceOptions, titleVisibility: .visible) {
            Button("Choose from Library") { showLibraryPicker = true }
            Button("Take Photo") { showCamera = true }
            Button("Import PDF") { showDocumentPicker = true }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showLibraryPicker) {
            PhotoLibraryPicker(selectedImage: $capturedImage)
                .edgesIgnoringSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePickerController(image: $capturedImage, sourceType: .camera)
                .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                if let pdfData = try? Data(contentsOf: url),
                   let document = PDFDocument(data: pdfData) {

                    // Store original PDF data
                    originalPDFData = pdfData

                    // Convert to image for display
                    let converter = PDFConverter()
                    if let stitchedImage = converter.stitchPDFPages(document: document) {
                        capturedImage = stitchedImage
                    }
                }
            }
        }
        .onChange(of: capturedImage) { oldValue, newValue in
            if let image = newValue {
                replaceReceiptImage(with: image)
                capturedImage = nil
            }
        }
    }

    // REFACTOR: Extract validation to shared utility or ExpenseFormViewModel
    // Similar logic in AddEntryView (lines 551-578) but with additional date validation
    var canSave: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amountString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // REFACTOR: Extract save logic to ExpenseFormViewModel or repository pattern
    // This updates existing expense; AddEntryView creates new (lines 770-841)
    private func saveChanges() {
        // Update expense properties
        expense.merchantName = merchantName
        expense.expenseDescription = expenseDescription
        expense.date = date
        expense.category = category.rawValue

        // Recalculate work day flag when date changes
        expense.isWorkDay = BudgetTracker.isWorkDay(date)

        // Update amount if changed
        if let newAmount = Decimal(string: amountString) {
            if currency == .usd {
                expense.amountUSD = newAmount
                expense.amountJPY = newAmount * expense.exchangeRate
                
                // Round JPY to whole number
                let nsAmount = NSDecimalNumber(decimal: expense.amountJPY)
                let handler = NSDecimalNumberHandler(roundingMode: .bankers, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
                expense.amountJPY = nsAmount.rounding(accordingToBehavior: handler).decimalValue
            } else {
                expense.amountJPY = newAmount
                expense.amountUSD = newAmount / expense.exchangeRate
            }
        }

        // Save to context
        do {
            try modelContext.save()
            print("💾 Expense updated successfully")
        } catch {
            print("❌ Error saving expense: \(error)")
        }
    }

    // REFACTOR: Extract image management to shared ImageManager or ExpenseFormViewModel
    // Similar logic in AddEntryView (lines 616-636) but for saving new image vs replacing
    private func replaceReceiptImage(with newImage: UIImage) {
        // Generate a UUID for this receipt
        let uuid = UUID().uuidString
        let jpgFilename = "\(uuid).jpg"

        // Save the image (JPG)
        guard let jpgData = newImage.jpegData(compressionQuality: 0.8),
              ImageManager.shared.saveRawData(jpgData, filename: jpgFilename) else {
            print("❌ Failed to save new receipt image")
            return
        }

        // If we have original PDF data, save it too with the same UUID
        if let pdfData = originalPDFData {
            let pdfFilename = "\(uuid).pdf"
            if ImageManager.shared.saveRawData(pdfData, filename: pdfFilename) {
                print("💾 Saved original PDF: \(pdfFilename)")
            }
        }

        if let oldPath = imageToReplacePath,
           let index = expense.receiptImagePaths.firstIndex(of: oldPath) {
            // Delete old image file (and PDF if it exists) and replace path
            ImageManager.shared.deleteImage(oldPath)

            // Also delete associated PDF if it exists
            let oldUUID = (oldPath as NSString).deletingPathExtension
            let oldPDFPath = "\(oldUUID).pdf"
            ImageManager.shared.deleteImage(oldPDFPath)

            expense.receiptImagePaths[index] = jpgFilename
        } else {
            // If no specific image selected, append
            expense.receiptImagePaths.append(jpgFilename)
        }

        do {
            try modelContext.save()
            print("💾 Receipt image updated")
        } catch {
            print("❌ Error saving updated receipt image: \(error)")
        }

        // Reset selection state
        imageToReplacePath = nil
        originalPDFData = nil
    }


}



#Preview {
    let expense = Expense(
        date: Date(),
        category: "Food",
        merchantName: "Test Merchant",
        expenseDescription: "Lunch",
        amountJPY: 1500,
        amountUSD: 10,
        exchangeRate: BudgetTracker.defaultExchangeRate,
        isWorkDay: true
    )

    return ExpenseDetailView(expense: expense)
        .modelContainer(for: Expense.self)
}
