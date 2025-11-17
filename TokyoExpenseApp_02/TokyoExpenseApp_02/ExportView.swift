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
