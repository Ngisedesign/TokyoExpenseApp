import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

// MARK: - REFACTORING OPPORTUNITY
// ============================================================================
// This view shares significant code with ExpenseDetailView. Consider extracting:
//
// 1. SHARED COMPONENTS:
//    - ExpenseFormHeader: Header with X and checkmark buttons (lines 69-90)
//    - ExpenseImageSection: Receipt image display (lines 100-130)
//    - ExpenseCategoryAndDatePicker: Category pills + date picker (lines 161-192)
//    - ExpenseMerchantField: Merchant text field with validation (lines 194-225)
//    - ExpenseDescriptionField: Description text field (lines 227-256)
//    - ExpenseAmountField: Amount input with currency toggle (lines 258-312)
//
// 2. SHARED LOGIC (extract to ExpenseFormViewModel or utility):
//    - Currency conversion logic (lines 314-335)
//    - Validation rules (lines 501-564)
//    - Image management (lines 566-586)
//    - Exchange rate handling (lines 728-744)
//
// 3. SHARED STATE (extract to @Observable class ExpenseFormData):
//    - merchant, expenseDescription, date, amountString, category
//    - currency enum and conversion state
//
// 4. DIFFERENCES TO PRESERVE:
//    - AddEntryView: OCR processing (lines 587-718)
//    - AddEntryView: PDF import (lines 447-467)
//    - AddEntryView: Trip date validation (lines 516-525, 550-561)
//    - ExpenseDetailView: Shows read-only additional info
//
// BENEFITS:
//    - Single source of truth for form UI and behavior
//    - Easier to maintain consistency between add/edit flows
//    - Reduced code duplication (~60% of code is shared)
//    - Easier testing with extracted view models
// ============================================================================

struct AddEntryView: View {
    static var localTripStartDate: Date {
        // Trip starts Nov 28, 2025 (departure to Tokyo)
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 11
        comps.day = 28
        comps.hour = 12
        return Calendar.current.date(from: comps) ?? Date()
    }

    static var localTripEndDate: Date {
        // Trip ends Dec 7, 2025 (return from Tokyo)
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 12
        comps.day = 7
        comps.hour = 12
        return Calendar.current.date(from: comps) ?? Date()
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var merchant: String = ""
    @State private var expenseDescription: String = ""
    @State private var date: Date = .now
    @State private var amountString: String = ""

    @State private var selectedImageUI: UIImage? = nil
    @State private var showCamera: Bool = false
    @State private var showLibraryPicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var category: ExpenseCategory = .food
    
    enum Currency {
        case jpy
        case usd
    }
    @State private var currency: Currency = .jpy
    @State private var originalPDFData: Data? = nil


    var autoLaunchCamera: Bool = false
    var initialImage: UIImage? = nil

    init(autoLaunchCamera: Bool = false, selectedImageUI: UIImage? = nil) {
        self.autoLaunchCamera = autoLaunchCamera
        self.initialImage = selectedImageUI
    }

    // Receipt parsing state
    @State private var isProcessingOCR: Bool = false
    @State private var ocrConfidence: Float? = nil
    @State private var ocrError: String? = nil
    @State private var merchantIsPlaceholder: Bool = false
    @State private var descriptionIsAIGenerated: Bool = false
    @State private var aiExchangeRate: Decimal? = nil
    @State private var aiAmountUSD: Decimal? = nil
    @State private var showBugDialog: Bool = false
    @State private var bugOffset: CGFloat = 500 // Start off-screen
    @State private var bugWiggle: Bool = false
    @State private var validationError: String? = nil

    // REFACTOR: Extract to ExpenseFormHeader component
    // This is identical in ExpenseDetailView (lines 42-58)
    // Proposed signature: ExpenseFormHeader(canSave: Bool, onCancel: () -> Void, onSave: () -> Void)
    private var headerView: some View {
        HStack {
            LargeIconButton(icon: "xmark") {
                dismiss()
            }
            Spacer()
            LargeIconButton(
                icon: "checkmark",
                color: canSave ? .black : .secondary
            ) {
                if let error = validateExpense() {
                    validationError = error
                } else {
                    Task {
                        await saveExpense()
                        dismiss()
                    }
                }
            }
            .disabled(!canSave)
        }
    }

    private func imageAndCategoriesView(geometry: GeometryProxy) -> some View {
        HStack(alignment: .top, spacing: 16) {
            receiptImageSection(geometry: geometry)
            categoriesAndDateSection
        }
        .padding(.horizontal)
    }

    private func receiptImageSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = selectedImageUI {
                // Show captured image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: geometry.size.width * 0.45)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.black.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .onTapGesture {
                        showLibraryPicker = true
                    }
            } else {
                ImagePlaceholder(
                    icon: "photo.fill",
                    text: "Add Image",
                    height: 160
                ) {
                    showLibraryPicker = true
                }
                .frame(width: 120)
            }

            imageCaptureButtons
        }
    }

    private var imageCaptureButtons: some View {
        HStack(spacing: 4) {
            // Camera button
            Button {
                showCamera = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.8))
                    .padding(8)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

            // PDF Import button
            Button {
                showDocumentPicker = true
            } label: {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.8))
                    .padding(8)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(8)
    }

    // REFACTOR: Extract to ExpenseCategoryAndDatePicker component
    // Nearly identical in ExpenseDetailView (lines 98-127) with minor label styling differences
    // Proposed signature: ExpenseCategoryAndDatePicker(category: Binding<ExpenseCategory>, date: Binding<Date>)
    private var categoriesAndDateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.headline)
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

            // Date (Moved from bottom)
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

    // REFACTOR: Extract to ExpenseMerchantField component
    // Similar in ExpenseDetailView (lines 134-142) but without placeholder/review badges
    // Proposed: ExpenseMerchantField(text: Binding<String>, isPlaceholder: Bool = false, showReviewBadge: Bool = false)
    private var merchantField: some View {
        LabeledField(label: "Merchant", spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("Where did you spend?", text: $merchant)
                        .font(.body)
                        .foregroundStyle(merchantIsPlaceholder ? .red : .black)
                        .onChange(of: merchant) { _, _ in
                            if merchantIsPlaceholder {
                                merchantIsPlaceholder = false
                            }
                        }

                    if merchantIsPlaceholder {
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
                        .fill(merchantIsPlaceholder ? .red.opacity(0.05) : .black.opacity(0.03))
                )
            }
        }
        .padding(.horizontal)
    }

    // REFACTOR: Extract to ExpenseDescriptionField component
    // Similar in ExpenseDetailView (lines 145-153) but without AI badge
    // Proposed: ExpenseDescriptionField(text: Binding<String>, isAIGenerated: Bool = false)
    private var descriptionField: some View {
        LabeledField(label: "Description", spacing: 8) {
            HStack {
                TextField("What was this for?", text: $expenseDescription)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .onChange(of: expenseDescription) { _, _ in
                        if descriptionIsAIGenerated {
                            descriptionIsAIGenerated = false
                        }
                    }

                if descriptionIsAIGenerated {
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
        .padding(.horizontal)
    }

    // REFACTOR: Extract to ExpenseAmountField component
    // Identical in ExpenseDetailView (lines 156-202)
    // Proposed: ExpenseAmountField(amount: Binding<String>, currency: Binding<Currency>, exchangeRate: Decimal, onToggleCurrency: () -> Void)
    private var amountField: some View {
        LabeledField(label: "Amount", spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                amountInputField
                exchangeRateDisplay
            }
        }
        .padding(.horizontal)
    }

    private var amountInputField: some View {
        HStack(spacing: 4) {
            currencyToggleButton
            amountTextField
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.03))
        )
    }

    private var currencyToggleButton: some View {
        Button {
            toggleCurrency()
        } label: {
            Text(currency == .jpy ? "¥" : "$")
                .font(.body)
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .frame(width: 24)
        }
        .buttonStyle(.plain)
    }

    private var amountTextField: some View {
        TextField("0", text: $amountString)
            .font(.body)
            .fontWeight(.bold)
            .keyboardType(.decimalPad)
            .foregroundStyle(.black)
    }

    private var exchangeRateDisplay: some View {
        Group {
            if let rate = aiExchangeRate {
                Text("Rate: ¥\(NSDecimalNumber(decimal: rate).stringValue)")
            } else if let cached = ExchangeRateService.shared.getCachedRate(for: date) {
                Text("Rate: ¥\(NSDecimalNumber(decimal: cached).stringValue)")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.leading, 4)
    }

    // REFACTOR: Extract to CurrencyConverter utility or ExpenseFormViewModel
    // This logic is duplicated in ExpenseDetailView (lines 158-183)
    // The only difference is the exchange rate source (aiExchangeRate vs expense.exchangeRate)
    // Proposed: CurrencyConverter.toggle(from:to:amount:rate:) -> String
    private func toggleCurrency() {
        let currentAmount = Decimal(string: amountString) ?? 0
        let rate = aiExchangeRate ?? ExchangeRateService.shared.getCachedRate(for: date) ?? BudgetTracker.defaultExchangeRate

        withAnimation {
            if currency == .jpy {
                currency = .usd
                if currentAmount > 0 {
                    let usdAmount = currentAmount / rate
                    amountString = usdAmount.formatted(.number.precision(.fractionLength(2)).grouping(.never))
                }
            } else {
                currency = .jpy
                if currentAmount > 0 {
                    let jpyAmount = currentAmount * rate
                    let nsAmount = NSDecimalNumber(decimal: jpyAmount)
                    let handler = NSDecimalNumberHandler(roundingMode: .bankers, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
                    amountString = nsAmount.rounding(accordingToBehavior: handler).stringValue
                }
            }
        }
    }

    @ViewBuilder
    private var ocrProcessingIndicator: some View {
        if isProcessingOCR {
            HStack {
                ProgressView()
                Text("Analyzing receipt with AI...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    var body: some View {
        mainContent
            .overlay(alignment: .bottomTrailing) {
                bugOverlay
            }
            .alert("🐛 Error Details", isPresented: $showBugDialog) {
                Button("Copy Error") {
                    if let error = ocrError {
                        UIPasteboard.general.string = error
                    }
                }
                Button("Dismiss", role: .cancel) { }
            } message: {
                if let error = ocrError {
                    Text(error)
                }
            }
            .alert("Validation Error", isPresented: Binding(
                get: { validationError != nil },
                set: { if !$0 { validationError = nil } }
            )) {
                Button("OK", role: .cancel) {
                    validationError = nil
                }
            } message: {
                if let error = validationError {
                    Text(error)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                cameraView
            }
            .fullScreenCover(isPresented: $showLibraryPicker) {
                libraryPickerView
            }
            .sheet(isPresented: $showDocumentPicker) {
                documentPickerView
            }
            .onChange(of: selectedImageUI) { oldValue, newValue in
                handleImageChange(newValue)
            }
            .onChange(of: ocrError) { oldValue, newValue in
                handleOCRErrorChange(newValue)
            }
            .onAppear {
                handleOnAppear()
            }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ocrProcessingIndicator
                        imageAndCategoriesView(geometry: geometry)
                        merchantField
                        descriptionField
                        amountField
                        Spacer(minLength: 100)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bugOverlay: some View {
        if ocrError != nil {
            Button {
                showBugDialog = true
            } label: {
                Text("🐛")
                    .font(.system(size: 60))
                    .shadow(radius: 4)
                    .rotationEffect(.degrees(bugWiggle ? -10 : -20))
            }
            .offset(x: -20, y: bugOffset)
            .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: bugWiggle)
        }
    }

    private var cameraView: some View {
        ImagePickerController(image: $selectedImageUI, sourceType: .camera)
            .edgesIgnoringSafeArea(.all)
    }

    private var libraryPickerView: some View {
        PhotoLibraryPicker(selectedImage: $selectedImageUI)
            .edgesIgnoringSafeArea(.all)
    }

    private var documentPickerView: some View {
        DocumentPicker { url in
            if let pdfData = try? Data(contentsOf: url),
               let document = PDFDocument(data: pdfData) {

                // Store original PDF data
                originalPDFData = pdfData

                // Convert to image for display/OCR
                let converter = PDFConverter()
                if let stitchedImage = converter.stitchPDFPages(document: document) {
                    selectedImageUI = stitchedImage

                    // Trigger OCR
                    Task {
                        await processReceiptImage(stitchedImage)
                    }
                }
            }
        }
    }

    private func handleImageChange(_ newImage: UIImage?) {
        if let image = newImage {
            Task {
                await processReceiptImage(image)
            }
        }
    }

    private func handleOCRErrorChange(_ newError: String?) {
        if newError != nil {
            bugOffset = 500
            bugWiggle = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                bugOffset = -20
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                bugWiggle = true
            }
        } else {
            bugOffset = 500
            bugWiggle = false
        }
    }

    private func handleOnAppear() {
        // Handle pre-filled image from QuickCameraView
        if let image = initialImage {
            selectedImageUI = image
            // OCR will be triggered automatically by onChange(of: selectedImageUI)
        }

        // Legacy: Handle auto-launch camera (backwards compatibility)
        if autoLaunchCamera && initialImage == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCamera = true
            }
        }
    }

    var canSave: Bool {
        // Merchant must not be empty
        guard !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Amount must be valid and > 0
        guard !amountString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let amount = Decimal(string: amountString),
              amount > 0 else {
            return false
        }

        // Date should be within reasonable range (trip dates + buffer)
        let calendar = Calendar.current
        let tripStart = AddEntryView.localTripStartDate
        let tripEnd = AddEntryView.localTripEndDate

        // Allow dates within trip range plus 30 days buffer before (for flight/hotel purchases) and 7 days after
        let minDate = calendar.date(byAdding: .day, value: -30, to: tripStart)!
        let maxDate = calendar.date(byAdding: .day, value: 7, to: tripEnd)!

        guard date >= minDate && date <= maxDate else {
            return false
        }

        return true
    }

    /// Validates expense and returns user-friendly error message if invalid
    private func validateExpense() -> String? {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMerchant.isEmpty {
            return "Please enter a merchant name."
        }

        let trimmedAmount = amountString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAmount.isEmpty {
            return "Please enter an amount."
        }

        guard let amount = Decimal(string: trimmedAmount) else {
            return "Amount must be a valid number."
        }

        if amount <= 0 {
            return "Amount must be greater than zero."
        }

        let calendar = Calendar.current
        let tripStart = AddEntryView.localTripStartDate
        let tripEnd = AddEntryView.localTripEndDate

        let minDate = calendar.date(byAdding: .day, value: -30, to: tripStart)!
        let maxDate = calendar.date(byAdding: .day, value: 7, to: tripEnd)!

        if date < minDate || date > maxDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            return "Date must be within trip dates (\(dateFormatter.string(from: tripStart)) - \(dateFormatter.string(from: tripEnd))), allowing 30 days before for advance purchases."
        }

        return nil
    }

    private func saveReceiptImage(_ image: UIImage) -> String? {
        // Generate a UUID for this receipt
        let uuid = UUID().uuidString
        let jpgFilename = "\(uuid).jpg"
        
        // Save the image (JPG)
        if ImageManager.shared.saveRawData(image.jpegData(compressionQuality: 0.8)!, filename: jpgFilename) {

            // If we have original PDF data, save it too with the same UUID
            if let pdfData = originalPDFData {
                let pdfFilename = "\(uuid).pdf"
                if ImageManager.shared.saveRawData(pdfData, filename: pdfFilename) {
                    print("💾 Saved original PDF: \(pdfFilename)")
                }
            }

            return jpgFilename
        }
        
        return nil
    }
    private func processReceiptImage(_ image: UIImage) async {
        // Reset state
        await MainActor.run {
            isProcessingOCR = true
            ocrError = nil
            ocrConfidence = nil
            merchantIsPlaceholder = false
            aiExchangeRate = nil
            aiAmountUSD = nil
        }

        do {
            print("📸 Starting receipt parsing...")

            // Use Anthropic API for receipt parsing
            let parsed = try await AnthropicService.shared.parseReceipt(image: image)

            print("✅ Receipt parsed successfully!")
            print("   Merchant: \(parsed.merchantName ?? "nil")")
            print("   Amount: \(parsed.totalAmountYen?.description ?? "nil")")
            print("   Date: \(parsed.date?.description ?? "nil")")
            print("   Category: \(parsed.category ?? "nil")")
            print("   Confidence: \(parsed.confidence)")

            await MainActor.run {
                var fieldsFound: [String] = []
                var fieldsMissing: [String] = []

                if let merchantName = parsed.merchantName {
                    merchant = merchantName
                    merchantIsPlaceholder = parsed.merchantIsPlaceholder

                    if parsed.merchantIsPlaceholder {
                        fieldsMissing.append("merchant (AI-generated)")
                        print("🎨 Using whimsical placeholder: '\(merchantName)'")
                    } else {
                        fieldsFound.append("merchant")
                    }
                } else {
                    // Fallback if Claude doesn't return any name (shouldn't happen with new prompt)
                    merchant = "Unknown Merchant"
                    merchantIsPlaceholder = true
                    fieldsMissing.append("merchant")
                    print("⚠️ No merchant name returned - using fallback")
                }

                // Logic to determine currency and amount
                if let usd = parsed.totalAmountUSD {
                    // Prefer USD if available
                    currency = .usd
                    aiAmountUSD = usd
                    amountString = usd.description
                    fieldsFound.append("amount (USD)")
                    print("💵 Auto-switched to USD: $\(usd)")
                } else if let amount = parsed.totalAmountYen {
                    // Fallback to JPY
                    currency = .jpy
                    let nsAmount = NSDecimalNumber(decimal: amount)
                    let handler = NSDecimalNumberHandler(roundingMode: .bankers,
                                                         scale: 0,
                                                         raiseOnExactness: false,
                                                         raiseOnOverflow: false,
                                                         raiseOnUnderflow: false,
                                                         raiseOnDivideByZero: false)
                    let rounded = nsAmount.rounding(accordingToBehavior: handler)
                    amountString = rounded.stringValue
                    fieldsFound.append("amount (JPY)")
                } else {
                    fieldsMissing.append("amount")
                }

                if let parsedDate = parsed.date {
                    date = parsedDate
                    fieldsFound.append("date")
                    print("📅 Setting date to: \(parsedDate)")
                } else {
                    fieldsMissing.append("date")
                    print("⚠️ No date found in receipt")
                }

                if let categoryStr = parsed.category,
                   let parsedCategory = ExpenseCategory(rawValue: categoryStr) {
                    category = parsedCategory
                    fieldsFound.append("category")
                }

                // Post-processing: Force "Hotel" category if description/merchant suggests accommodation
                // This overrides the AI if it defaults to "Other"
                let lowerDesc = expenseDescription.lowercased()
                let lowerMerchant = merchant.lowercased()
                if lowerDesc.contains("accommodation") || lowerDesc.contains("hotel") || lowerDesc.contains("stay") ||
                   lowerMerchant.contains("hotel") || lowerMerchant.contains("inn") || lowerMerchant.contains("stay") {
                    category = .hotel
                    print("🏨 Force-set category to Hotel based on keywords")
                }

                if let description = parsed.expenseDescription {
                    expenseDescription = description
                    descriptionIsAIGenerated = true
                    fieldsFound.append("description")
                    print("💬 AI generated description: '\(description)'")
                }

                if let rate = parsed.exchangeRateJPYPerUSD {
                    aiExchangeRate = rate
                    print("💱 Detected receipt exchange rate: \u{00a5}\(rate) per $1")
                }
                if let usd = parsed.totalAmountUSD {
                    aiAmountUSD = usd
                    print("💵 Detected receipt total in USD: $\(usd)")
                }

                ocrConfidence = parsed.confidence

                // Clear any previous errors on successful parse
                ocrError = nil

                if !fieldsMissing.isEmpty {
                    let missingList = fieldsMissing.joined(separator: ", ")
                    print("⚠️ Missing fields: \(missingList)")
                }

                isProcessingOCR = false
            }
        } catch {
            print("❌ Receipt parsing failed: \(error)")
            await MainActor.run {
                ocrError = "Failed to parse receipt: \(error.localizedDescription)"
                isProcessingOCR = false
            }
        }
    }

    private func saveExpense() async {
        let inputAmount = Decimal(string: amountString) ?? 0
        
        var amountJPY: Decimal = 0
        var amountUSD: Decimal = 0
        var exchangeRate: Decimal = BudgetTracker.defaultExchangeRate
        var needsUpdate = false

        // Determine exchange rate first
        if let aiRate = aiExchangeRate {
            exchangeRate = aiRate
            print("✅ Using receipt-provided exchange rate: \u{00a5}\(aiRate) per $1")
        } else if let cached = ExchangeRateService.shared.getCachedRate(for: date) {
             exchangeRate = cached
        } else {
             // Fetch if needed
             print("📊 Fetching exchange rate for \(date)...")
             if let fetchedRate = await ExchangeRateService.shared.fetchRate(for: date) {
                 exchangeRate = fetchedRate
                 print("✅ Successfully fetched exchange rate: \(fetchedRate)")
             } else {
                 print("⚠️ Failed to fetch exchange rate, using default: \(BudgetTracker.defaultExchangeRate)")
                 needsUpdate = true
             }
        }

        // Calculate amounts based on selected currency
        if currency == .usd {
            amountUSD = inputAmount
            amountJPY = amountUSD * exchangeRate
            // Round JPY to whole number
            let nsAmount = NSDecimalNumber(decimal: amountJPY)
            let handler = NSDecimalNumberHandler(roundingMode: .bankers, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
            amountJPY = nsAmount.rounding(accordingToBehavior: handler).decimalValue
        } else {
            amountJPY = inputAmount
            amountUSD = amountJPY / exchangeRate
        }

        // Save receipt image (and PDF if available)
        var imagePaths: [String] = []
        if let image = selectedImageUI {
            if let savedPath = saveReceiptImage(image) {
                imagePaths.append(savedPath)
            }
        }

        // Create expense
        let expense = Expense(
            date: date,
            category: category.rawValue,
            merchantName: merchant.isEmpty ? "Untitled" : merchant,
            expenseDescription: expenseDescription,
            amountJPY: amountJPY,
            amountUSD: amountUSD,
            exchangeRate: exchangeRate,
            receiptImagePaths: imagePaths,
            isWorkDay: BudgetTracker.isWorkDay(date),
            isManualEntry: ocrConfidence == nil,
            ocrConfidence: ocrConfidence,
            needsExchangeRateUpdate: needsUpdate
        )

        modelContext.insert(expense)

        do {
            try modelContext.save()
            print("💾 Expense saved successfully")
        } catch {
            print("❌ Error saving expense: \(error)")
        }
    }


} // End of struct AddEntryView

// MARK: - Document Picker for PDFs

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    @Environment(\.dismiss) var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Pass the URL back to the parent
            parent.onPick(url)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - PDF Converter

struct PDFConverter {
    /// Convert first page of PDF to UIImage
    static func convertPDFToImage(url: URL) -> UIImage? {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Could not access PDF file")
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else {
            print("❌ Could not load PDF page")
            return nil
        }

        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)

        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)

            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            context.cgContext.drawPDFPage(page)
        }

        print("✅ Converted PDF to image: \(pageRect.size)")
        return image
    }

    /// Stitch all pages of a PDF document into a single vertical image
    func stitchPDFPages(document: PDFDocument) -> UIImage? {
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            print("❌ PDF has no pages")
            return nil
        }

        // Get dimensions of all pages
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        var pageImages: [(image: UIImage, rect: CGRect)] = []

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)

            maxWidth = max(maxWidth, pageRect.width)
            totalHeight += pageRect.height

            // Render each page to an image
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let pageImage = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)

                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.drawPDFPage(page.pageRef!)
            }

            pageImages.append((pageImage, pageRect))
        }

        // Create a single tall canvas
        let finalSize = CGSize(width: maxWidth, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: finalSize)

        let stitchedImage = renderer.image { context in
            var yOffset: CGFloat = 0

            for (pageImage, pageRect) in pageImages {
                pageImage.draw(at: CGPoint(x: 0, y: yOffset))
                yOffset += pageRect.height
            }
        }

        print("✅ Stitched \(pageCount) PDF pages into single image: \(finalSize)")
        return stitchedImage
    }
}

#Preview {
    AddEntryView()
}
