import SwiftUI
import PhotosUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var merchant: String = ""
    @State private var date: Date = .now
    @State private var amountYen: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageUI: UIImage? = nil
    @State private var showCamera: Bool = false
    @State private var showLibraryPicker: Bool = false
    @State private var category: ExpenseCategory = .food

    // OCR state
    @State private var isProcessingOCR: Bool = false
    @State private var ocrConfidence: Float? = nil
    @State private var ocrError: String? = nil

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
                    saveExpense()
                    dismiss()
                }
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // OCR Processing Indicator
                    if isProcessingOCR {
                        HStack {
                            ProgressView()
                            Text("Processing receipt...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
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
                        TextField("Where did you spend?", text: $merchant)
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )
                    }

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
        .sheet(isPresented: $showCamera) {
            ImagePickerController(image: $selectedImageUI, sourceType: .camera)
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { newItem in
            Task {
                await loadImage(from: newItem)

                // Trigger OCR after image loads
                if let image = selectedImageUI {
                    await processReceiptImage(image)
                }
            }
        }
    }

    var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amountYen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func processReceiptImage(_ image: UIImage) async {
        isProcessingOCR = true
        ocrError = nil

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
                        amountYen = String(format: "%.0f", amount as CVarArg)
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
                        amountYen = String(format: "%.0f", amount as CVarArg)
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
                    amountYen = String(format: "%.0f", amount as CVarArg)
                }
                ocrConfidence = parsed.confidence
            }
        }

        isProcessingOCR = false
    }

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
