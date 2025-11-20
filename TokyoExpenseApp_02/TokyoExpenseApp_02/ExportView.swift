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
                .disabled(filteredExpenses.isEmpty)
            }
        }
        .padding()
        .sheet(isPresented: $showShareSheet) {
            if let url = csvURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func startExport() {
        isExporting = true
        exportProgress = 0.0

        exportTask = Task {
            await exportCSV()
        }
    }

    private func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        exportProgress = 0.0
        print("📊 Export cancelled by user")
    }

    private func exportCSV() async {
        let expenses = filteredExpenses
        let totalExpenses = expenses.count

        // Simulate progress for better UX (CSV generation is usually very fast)
        await MainActor.run {
            exportProgress = 0.1
        }

        do {
            // Check if task was cancelled
            try Task.checkCancellation()

            await MainActor.run {
                exportProgress = 0.3
            }

            // Generate CSV
            let csvString = CSVExporter.shared.generateCSV(from: expenses)

            // Check if task was cancelled
            try Task.checkCancellation()

            await MainActor.run {
                exportProgress = 0.7
            }

            // Write to file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("expenses.csv")
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)

            await MainActor.run {
                exportProgress = 1.0
                csvURL = tempURL
                isExporting = false
                showShareSheet = true
                print("✅ Exported \(totalExpenses) expenses to CSV")
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
            print("❌ Error exporting CSV: \(error)")
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
