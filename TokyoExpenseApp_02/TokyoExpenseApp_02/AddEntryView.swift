import SwiftUI
import PhotosUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var merchant: String = ""
    @State private var expenseDescription: String = ""
    @State private var date: Date = .now
    @State private var amountYen: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageUI: UIImage? = nil
    @State private var showCamera: Bool = false
    @State private var showLibraryPicker: Bool = false
    @State private var category: ExpenseCategory = .food

    // Receipt parsing state
    @State private var isProcessingOCR: Bool = false
    @State private var ocrConfidence: Float? = nil
    @State private var ocrError: String? = nil
    @State private var merchantIsPlaceholder: Bool = false
    @State private var descriptionIsAIGenerated: Bool = false
    @State private var showBugDialog: Bool = false
    @State private var bugOffset: CGFloat = 500 // Start off-screen
    @State private var bugWiggle: Bool = false

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
                    Task {
                        await saveExpense()
                        dismiss()
                    }
                }
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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

                    // Receipt Image / Library Section
                    ZStack(alignment: .bottomTrailing) {
                        if let image = selectedImageUI {
                            // Show captured image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
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
                                text: "Add from library"
                            ) {
                                showLibraryPicker = true
                            }
                        }

                        // Camera button in bottom right corner
                        Button {
                            showCamera = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.black.opacity(0.3))
                                .padding(16)
                                .background(
                                    Circle()
                                        .strokeBorder(.black.opacity(0.3), lineWidth: 2)
                                )
                        }
                        .padding(16)
                    }

                    // Category Selection
                    LabeledField(label: "Category", spacing: 12) {
                        HStack(spacing: 12) {
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

                    // Merchant Name
                    LabeledField(label: "Merchant") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Where did you spend?", text: $merchant)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(merchantIsPlaceholder ? .red : .black)
                                    .onChange(of: merchant) { _, _ in
                                        // User is editing - no longer a placeholder
                                        if merchantIsPlaceholder {
                                            merchantIsPlaceholder = false
                                        }
                                    }

                                if merchantIsPlaceholder {
                                    Text("NEEDS REVIEW")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(.red)
                                        )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(merchantIsPlaceholder ? .red.opacity(0.05) : .black.opacity(0.03))
                            )

                            if merchantIsPlaceholder {
                                Text("🎨 AI-generated name - please update with actual merchant")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.leading, 4)
                            }
                        }
                    }

                    // Description
                    LabeledField(label: "Description") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("What was this for?", text: $expenseDescription)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .onChange(of: expenseDescription) { _, _ in
                                        // User is editing - no longer AI-generated
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
                                        .background(
                                            Capsule()
                                                .fill(.blue)
                                        )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )
                        }
                    }

                    // Amount and Date separated
                    // Amount in Yen
                    LabeledField(label: "Amount") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("¥")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.black)

                                TextField("0", text: $amountYen)
                                    .font(.system(size: 32, weight: .bold))
                                    .keyboardType(.numberPad)
                                    .foregroundStyle(.black)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )

                            Text("Exchange rate: ¥150 = $1 USD")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                    }

                    // Date
                    LabeledField(label: "Date") {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(.vertical, 8)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
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
        .sheet(isPresented: $showCamera) {
            ImagePickerController(image: $selectedImageUI, sourceType: .camera)
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                await loadImage(from: newValue)
            }
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

    var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amountYen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func processReceiptImage(_ image: UIImage) async {
        // Reset state
        await MainActor.run {
            isProcessingOCR = true
            ocrError = nil
            ocrConfidence = nil
            merchantIsPlaceholder = false
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

            // Auto-fill form with parsed data
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

        // Fetch exchange rate for the expense date
        print("📊 Fetching exchange rate for \(date)...")
        var exchangeRate: Decimal = BudgetTracker.defaultExchangeRate
        var needsUpdate = false

        if let fetchedRate = await ExchangeRateService.shared.fetchRate(for: date) {
            exchangeRate = fetchedRate
            print("✅ Successfully fetched exchange rate: \(fetchedRate)")
        } else {
            print("⚠️ Failed to fetch exchange rate, using default: \(BudgetTracker.defaultExchangeRate)")
            needsUpdate = true
        }

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

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else {
            selectedImageUI = nil
            return
        }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    selectedImageUI = uiImage
                }
            }
        } catch {
            await MainActor.run {
                selectedImageUI = nil
            }
        }
    }
}

#Preview {
    AddEntryView()
}
