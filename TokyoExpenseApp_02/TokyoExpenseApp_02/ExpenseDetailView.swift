import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let expense: Expense

    @State private var merchantName: String
    @State private var expenseDescription: String
    @State private var date: Date
    @State private var category: ExpenseCategory
    @State private var amountYen: String
    @State private var showingImageViewer = false
    @State private var selectedImagePath: String?

    init(expense: Expense) {
        self.expense = expense
        _merchantName = State(initialValue: expense.merchantName)
        _expenseDescription = State(initialValue: expense.expenseDescription)
        _date = State(initialValue: expense.date)
        _category = State(initialValue: ExpenseCategory(rawValue: expense.category) ?? .food)
        _amountYen = State(initialValue: String(describing: expense.amountJPY))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Receipt Images
                    if !expense.receiptImagePaths.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Receipt Images")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(expense.receiptImagePaths, id: \.self) { imagePath in
                                        if let image = ImageManager.shared.loadImage(filename: imagePath) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .onTapGesture {
                                                    selectedImagePath = imagePath
                                                    showingImageViewer = true
                                                }
                                        }
                                    }
                                }
                            }
                        }
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
                        TextField("Merchant name", text: $merchantName)
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )
                    }

                    // Description
                    LabeledField(label: "Description") {
                        TextField("What was this for?", text: $expenseDescription)
                            .font(.body)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )
                    }

                    // Amount
                    LabeledField(label: "Amount") {
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
                    }

                    // Date
                    LabeledField(label: "Date") {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(.vertical, 8)
                    }

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
                .padding()
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $showingImageViewer) {
            if let imagePath = selectedImagePath,
               let image = ImageManager.shared.loadImage(filename: imagePath) {
                ImageViewerSheet(image: image)
            }
        }
    }

    var canSave: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amountYen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveChanges() {
        // Update expense properties
        expense.merchantName = merchantName
        expense.expenseDescription = expenseDescription
        expense.date = date
        expense.category = category.rawValue

        // Update amount if changed
        if let newAmount = Decimal(string: amountYen) {
            expense.amountJPY = newAmount

            // Recalculate USD amount using existing exchange rate
            expense.amountUSD = newAmount / expense.exchangeRate
        }

        // Save to context
        do {
            try modelContext.save()
            print("💾 Expense updated successfully")
        } catch {
            print("❌ Error saving expense: \(error)")
        }
    }
}

// MARK: - Image Viewer Sheet

struct ImageViewerSheet: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * scale)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    // Limit scale
                                    if scale < 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                    } else if scale > 5.0 {
                                        scale = 5.0
                                        lastScale = 5.0
                                    }
                                }
                        )
                }
            }
            .navigationTitle("Receipt Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let expense = Expense(
        date: Date(),
        category: "Food/Per Diem",
        merchantName: "Test Merchant",
        expenseDescription: "Lunch",
        amountJPY: 1500,
        amountUSD: 10,
        exchangeRate: 150,
        isWorkDay: true
    )

    return ExpenseDetailView(expense: expense)
        .modelContainer(for: Expense.self)
}
