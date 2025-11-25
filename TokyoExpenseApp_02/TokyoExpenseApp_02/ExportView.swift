import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var expenses: [Expense]

    @State private var startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 1))!
    @State private var endDate = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 5))!
    @State private var selectedCategories: Set<String> = Set(ExpenseCategory.allCases.map { $0.rawValue })
    @State private var showShareSheet = false
    @State private var exportedItems: [Any] = []
    @State private var exportDirectoryURL: URL?
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportTask: Task<Void, Never>?

    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            expense.date >= startDate &&
            expense.date <= endDate &&
            selectedCategories.contains(expense.category)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with dismiss button
            HStack {
                Spacer()
                LargeIconButton(icon: "xmark") {
                    dismiss()
                }
            }
            .padding(.bottom, -10)

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

            // Export button with progress indicator
            if isExporting {
                VStack(spacing: 12) {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("Exporting...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Cancel") {
                            cancelExport()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    }
                }
            } else {
                Button {
                    startExport()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24, weight: .bold))
                        Text("Export Report")
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
                .disabled(filteredExpenses.isEmpty)
            }
        }
        .padding()
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: exportedItems)
        }
    }

    private func startExport() {
        isExporting = true
        exportProgress = 0.0

        exportTask = Task {
            await exportReport()
        }
    }

    private func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        exportProgress = 0.0
        print("📊 Export cancelled by user")
    }

    private func exportReport() async {
        let expenses = filteredExpenses
        let sortedExpenses = expenses.sorted { $0.date < $1.date }
        let totalExpenses = sortedExpenses.count

        // Early exit if nothing to export
        guard totalExpenses > 0 else {
            await MainActor.run {
                isExporting = false
                exportProgress = 0.0
            }
            return
        }

        await MainActor.run {
            exportProgress = 0.1
        }

        do {
            // Prepare export directory
            let timestamp = Int(Date().timeIntervalSince1970)
            let exportDir = FileManager.default.temporaryDirectory.appendingPathComponent("Expense_Report_\(timestamp)", isDirectory: true)
            let receiptsDir = exportDir.appendingPathComponent("Receipts", isDirectory: true)
            
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: receiptsDir, withIntermediateDirectories: true)

            var filenameMap: [UUID: [String]] = [:]
            var imageURLs: [URL] = []

            // Copy and rename images in chronological order
            for (index, expense) in sortedExpenses.enumerated() {
                try Task.checkCancellation()

                // Format: 001_merchant_name.jpg
                let number = String(format: "%03d", index + 1)
                let baseSlug = makeSlug(for: expense)
                let baseName = "\(number)_\(baseSlug)"

                let paths = expense.receiptImagePaths
                var exportedNames: [String] = []

                if paths.isEmpty {
                    filenameMap[expense.id] = []
                } else {
                    for (i, filename) in paths.enumerated() {
                        let srcURL = ImageManager.shared.getImageURL(filename)
                        let ext = srcURL.pathExtension.isEmpty ? "jpg" : srcURL.pathExtension
                        let suffix = (i == 0) ? "" : "_\(i + 1)"
                        let newName = "\(baseName)\(suffix).\(ext)"
                        
                        // Check if a corresponding PDF exists
                        let pdfFilename = filename.replacingOccurrences(of: ".jpg", with: ".pdf")
                        if ImageManager.shared.fileExists(filename: pdfFilename) {
                            // Export the PDF instead
                            let pdfSrcURL = ImageManager.shared.getImageURL(pdfFilename)
                            let pdfNewName = "\(baseName)\(suffix).pdf"
                            let pdfDstURL = receiptsDir.appendingPathComponent(pdfNewName)
                            
                            if FileManager.default.fileExists(atPath: pdfDstURL.path) {
                                try? FileManager.default.removeItem(at: pdfDstURL)
                            }
                            try FileManager.default.copyItem(at: pdfSrcURL, to: pdfDstURL)
                            exportedNames.append(pdfNewName)
                            imageURLs.append(pdfDstURL)
                            print("📄 Exported original PDF: \(pdfNewName)")
                        } else {
                            // Export the JPG image
                            let dstURL = receiptsDir.appendingPathComponent(newName)
                            
                            if FileManager.default.fileExists(atPath: dstURL.path) {
                                try? FileManager.default.removeItem(at: dstURL)
                            }
                            try FileManager.default.copyItem(at: srcURL, to: dstURL)
                            
                            exportedNames.append(newName)
                            imageURLs.append(dstURL)
                        }
                    }
                    filenameMap[expense.id] = exportedNames
                }

                // Update progress roughly proportional to items processed (up to 0.7)
                let progress = 0.1 + (0.6 * Double(index + 1) / Double(totalExpenses))
                await MainActor.run {
                    exportProgress = progress
                }
            }

            try Task.checkCancellation()

            // Generate PDF
            let pdfData = PDFExporter.shared.createPDF(expenses: sortedExpenses, filenameMap: filenameMap)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: Date())
            let pdfURL = exportDir.appendingPathComponent("Expense_Report_\(dateStr).pdf")
            
            try pdfData.write(to: pdfURL)

            await MainActor.run {
                exportProgress = 0.95
            }

            // Build share items: Share the folder URL
            let items: [Any] = [exportDir]

            await MainActor.run {
                exportedItems = items
                exportDirectoryURL = exportDir
                exportProgress = 1.0
                isExporting = false
                showShareSheet = true
                print("✅ Exported \(totalExpenses) expenses with PDF and \(imageURLs.count) images to \(exportDir.path)")
            }
        } catch is CancellationError {
            await MainActor.run {
                isExporting = false
                exportProgress = 0.0
            }
            print("📊 Export was cancelled")
        } catch {
            await MainActor.run {
                isExporting = false
                exportProgress = 0.0
            }
            print("❌ Error exporting report: \(error)")
        }
    }

    private func makeSlug(for expense: Expense) -> String {
        // Prefer short description; fallback to merchant; fallback to category
        let raw = expense.expenseDescription.isEmpty ? (expense.merchantName.isEmpty ? expense.category : expense.merchantName) : expense.expenseDescription

        // Lowercase, replace non-alphanumerics with underscores, collapse repeats, trim, and limit length
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        while s.contains("__") { s = s.replacingOccurrences(of: "__", with: "_") }
        if s.isEmpty { s = "entry" }
        if s.count > 24 { s = String(s.prefix(24)) }
        return s
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
