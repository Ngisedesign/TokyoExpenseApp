import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var amountYen: String = ""

    @State private var selectedImageUI: UIImage? = nil
    @State private var showCamera: Bool = false
    @State private var showLibraryPicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var category: ExpenseCategory = .food
    
    var autoLaunchCamera: Bool = false
    
    init(autoLaunchCamera: Bool = false) {
        self.autoLaunchCamera = autoLaunchCamera
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with dismiss and save
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
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Receipt Processing Indicator
                        if isProcessingOCR {
                            HStack {
                                ProgressView()
                                Text("Analyzing receipt with AI...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }

                        // Top Section: Image + Categories
                        HStack(alignment: .top, spacing: 16) {
                            // Left: Receipt Image / Camera Button
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
                                    .frame(width: 120) // Fixed width placeholder
                                }

                                // Camera button
                                Button {
                                    showCamera = true
                                } label: {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.gray.opacity(0.8))
                                        .padding(8)
                                }
                                .background(.black.opacity(0.05))
                                .clipShape(Circle())

                                // PDF Import button
                                Button {
                                    showDocumentPicker = true
                                } label: {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.gray.opacity(0.8))
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(.white)
                                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        )
                                }
                                .padding(8)
                            }

                            // Right: Categories (Wrapping)
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
                        .padding(.horizontal)

                    // Merchant Name
                    LabeledField(label: "Merchant", spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Where did you spend?", text: $merchant)
                                    .font(.body) // Consistent font
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

                    // Description
                    LabeledField(label: "Description", spacing: 8) {
                        HStack {
                            TextField("What was this for?", text: $expenseDescription)
                                .font(.body) // Consistent font
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

                    // Amount
                    LabeledField(label: "Amount", spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("¥")
                                    .font(.body) // Consistent font
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)

                                TextField("0", text: $amountYen)
                                    .font(.body) // Consistent font
                                    .fontWeight(.bold)
                                    .keyboardType(.numberPad)
                                    .foregroundStyle(.black)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )

                            Group {
                                if let rate = aiExchangeRate {
                                    Text("Rate: \u{00a5}\(NSDecimalNumber(decimal: rate).stringValue)")
                                } else if let cached = ExchangeRateService.shared.getCachedRate(for: date) {
                                    Text("Rate: \u{00a5}\(NSDecimalNumber(decimal: cached).stringValue)")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Climbing bug for errors
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
            ImagePickerController(image: $selectedImageUI, sourceType: .camera)
                .edgesIgnoringSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showLibraryPicker) {
            PhotoLibraryPicker(selectedImage: $selectedImageUI)
                .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(selectedImage: $selectedImageUI)
        }
        .onChange(of: selectedImageUI) { oldValue, newValue in
            // Trigger receipt parsing whenever image changes (camera or library)
            if let image = newValue {
                Task {
                    await processReceiptImage(image)
                }
            }
        }
        .onChange(of: ocrError) { oldValue, newValue in
            // Reset bug position when new error appears
            if newValue != nil {
                bugOffset = 500 // Reset to off-screen
                bugWiggle = false
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                    bugOffset = -20
                }
                // Start wiggling after climbing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    bugWiggle = true
                }
            } else {
                bugOffset = 500 // Hide when error is cleared
                bugWiggle = false
            }
        }
        }
        .onAppear {
            if autoLaunchCamera {
                // Small delay to ensure view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showCamera = true
                }
            }
        }
    }

    var canSave: Bool {
        // Merchant must not be empty
        guard !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Amount must be valid and > 0
        guard !amountYen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let amount = Decimal(string: amountYen),
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

        let trimmedAmount = amountYen.trimmingCharacters(in: .whitespacesAndNewlines)
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

                if let amount = parsed.totalAmountYen {
                    // Convert Decimal to String (no decimal places for Yen) using banker's rounding
                    let nsAmount = NSDecimalNumber(decimal: amount)
                    let handler = NSDecimalNumberHandler(roundingMode: .bankers,
                                                         scale: 0,
                                                         raiseOnExactness: false,
                                                         raiseOnOverflow: false,
                                                         raiseOnUnderflow: false,
                                                         raiseOnDivideByZero: false)
                    let rounded = nsAmount.rounding(accordingToBehavior: handler)
                    amountYen = rounded.stringValue
                    fieldsFound.append("amount")
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
        // Convert amountYen string to Decimal
        let amountJPY = Decimal(string: amountYen) ?? 0

        var exchangeRate: Decimal = BudgetTracker.defaultExchangeRate
        var amountUSD: Decimal
        var needsUpdate = false

        if let aiRate = aiExchangeRate {
            exchangeRate = aiRate
            print("✅ Using receipt-provided exchange rate: \u{00a5}\(aiRate) per $1")
        }

        if let aiUSD = aiAmountUSD {
            amountUSD = aiUSD
            if aiExchangeRate == nil {
                // Backfill exchange rate from JPY and USD if possible
                if amountJPY > 0 {
                    exchangeRate = amountJPY / aiUSD
                    print("🔄 Derived exchange rate from receipt amounts: \u{00a5}\(exchangeRate) per $1")
                }
            }
        } else {
            // No USD on receipt; compute using exchange rate, fetching API only if no receipt rate
            if aiExchangeRate == nil {
                print("📊 Fetching exchange rate for \(date)...")
                if let fetchedRate = await ExchangeRateService.shared.fetchRate(for: date) {
                    exchangeRate = fetchedRate
                    print("✅ Successfully fetched exchange rate: \(fetchedRate)")
                } else {
                    print("⚠️ Failed to fetch exchange rate, using default: \(BudgetTracker.defaultExchangeRate)")
                    needsUpdate = true
                }
            }
            amountUSD = amountJPY / exchangeRate
        }

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
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Check if it's a PDF
            if url.pathExtension.lowercased() == "pdf" {
                // Convert PDF to image
                if let image = PDFConverter.convertPDFToImage(url: url) {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image
                        self.parent.dismiss()
                    }
                }
            } else if let image = UIImage(contentsOfFile: url.path) {
                // Regular image
                DispatchQueue.main.async {
                    self.parent.selectedImage = image
                    self.parent.dismiss()
                }
            }
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
}

#Preview {
    AddEntryView()
}
