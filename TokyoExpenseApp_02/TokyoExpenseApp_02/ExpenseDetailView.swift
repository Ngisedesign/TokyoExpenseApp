import SwiftUI
import SwiftData
import PhotosUI

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

    @State private var capturedImage: UIImage? = nil
    @State private var imageToReplacePath: String? = nil

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

                            // Right: Categories (Wrapping)
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.subheadline)
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
                                        .foregroundStyle(.black)
                                    
                                    DatePicker("", selection: $date, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Form Fields
                        VStack(alignment: .leading, spacing: 20) {
                            // Merchant Name
                            LabeledField(label: "Merchant") {
                                TextField("Merchant name", text: $merchantName)
                                    .font(.body) // Consistent font
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.black.opacity(0.03))
                                    )
                            }

                            // Description
                            LabeledField(label: "Description") {
                                TextField("What was this for?", text: $expenseDescription)
                                    .font(.body) // Consistent font
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.black.opacity(0.03))
                                    )
                            }

                            // Amount
                            LabeledField(label: "Amount") {
                                HStack(spacing: 8) {
                                    Button {
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
                                            .foregroundStyle(.black)
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
        .onChange(of: capturedImage) { oldValue, newValue in
            if let image = newValue {
                replaceReceiptImage(with: image)
                capturedImage = nil
            }
        }
    }

    var canSave: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amountString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

    private func replaceReceiptImage(with newImage: UIImage) {
        guard let newFilename = ImageManager.shared.saveImage(newImage) else {
            print("❌ Failed to save new receipt image")
            return
        }

        if let oldPath = imageToReplacePath,
           let index = expense.receiptImagePaths.firstIndex(of: oldPath) {
            // Delete old image file and replace path
            ImageManager.shared.deleteImage(oldPath)
            expense.receiptImagePaths[index] = newFilename
        } else {
            // If no specific image selected, append
            expense.receiptImagePaths.append(newFilename)
        }

        do {
            try modelContext.save()
            print("💾 Receipt image updated")
        } catch {
            print("❌ Error saving updated receipt image: \(error)")
        }

        // Reset selection state
        imageToReplacePath = nil
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
