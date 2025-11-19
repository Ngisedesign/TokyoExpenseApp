import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = true
    @State private var showExportSheet = false

    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: expenses) { $0.category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Subtitle and export button
            HStack {
                Text("Dec 1-5")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
                Spacer()

                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal)

            // Expense List
            ScrollView {
                VStack(spacing: 40) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        if let categoryExpenses = groupedExpenses[category.rawValue], !categoryExpenses.isEmpty {
                            categorySection(category: category, expenses: categoryExpenses)
                        }
                    }

                    // Grand Total
                    grandTotalSection
                }
                .padding(.vertical, 24)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView()
        }
    }

    // MARK: - Category Section

    private func categorySection(category: ExpenseCategory, expenses: [Expense]) -> some View {
        let categoryTotal = expenses.reduce(Decimal(0)) { $0 + $1.amountJPY }

        return VStack(alignment: .leading, spacing: 16) {
            // Category Header
            HStack {
                Text(category.rawValue)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.primary)
                Spacer()
                Text(formatAmount(categoryTotal / 150))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)

            // Expense Rows
            VStack(spacing: 0) {
                ForEach(expenses) { expense in
                    expenseRow(expense)
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }

    // MARK: - Expense Row

    private func expenseRow(_ expense: Expense) -> some View {
        let shortDate: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: expense.date)
        }()

        return HStack(alignment: .firstTextBaseline, spacing: 16) {
            // Date in large, light grey
            Text(shortDate)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.4))
                .frame(width: 70, alignment: .leading)

            // Merchant
            Text(expense.merchantName)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Amount
            Text(formatAmount(expense.amountJPY / 150))
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Grand Total Section

    private var grandTotalSection: some View {
        let grandTotal = expenses.reduce(Decimal(0)) { $0 + $1.amountJPY }
        let remaining = BudgetTracker.totalBudget - (grandTotal / 150)

        return VStack(alignment: .leading, spacing: 20) {
            Divider()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                Text("Total")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(formatAmount(grandTotal / 150))
                        .font(.title)
                    Text("of")
                        .font(.title)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(formatAmount(BudgetTracker.totalBudget))
                        .font(.title)
                }

                HStack(spacing: 0) {
                    Text(formatAmount(remaining))
                        .font(.title2)
                        .foregroundStyle(remaining >= 0 ? Color(hue: 0.33, saturation: 0.70, brightness: 0.55) : Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                    Text(" remaining")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helper Functions

    private func formatAmount(_ amount: Decimal) -> String {
        if showYen {
            let yenAmount = amount * 150
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return "¥" + (formatter.string(from: yenAmount as NSNumber) ?? "0")
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            return formatter.string(from: amount as NSNumber) ?? "$0.00"
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(for: Expense.self)
}
