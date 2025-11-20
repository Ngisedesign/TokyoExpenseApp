import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = true
    @AppStorage("includeTravelDays") private var includeTravelDays = false
    @State private var showExportSheet = false

    private var filteredExpenses: [Expense] {
        includeTravelDays ? expenses : expenses.filter { $0.isWorkDay }
    }

    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: filteredExpenses) { $0.category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Subtitle and export button
            HStack {
                Text(includeTravelDays ? "Nov 28-Dec 7" : "Dec 1-5")
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
                Text(CurrencyFormatter.format(usd: categoryTotal / 150, showYen: showYen))
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
        return HStack(alignment: .firstTextBaseline, spacing: 16) {
            // Date in large, light grey
            Text(DateFormatters.shortDate(expense.date))
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
            Text(CurrencyFormatter.format(usd: expense.amountUSD, showYen: showYen))
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Grand Total Section

    private var grandTotalSection: some View {
        let grandTotal = filteredExpenses.reduce(Decimal(0)) { $0 + $1.amountJPY }
        let remaining = BudgetTracker.totalBudget - (grandTotal / 150)

        return VStack(alignment: .leading, spacing: 20) {
            Divider()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                Text("Total")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(CurrencyFormatter.format(usd: grandTotal / 150, showYen: showYen))
                        .font(.title)
                    Text("of")
                        .font(.title)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(CurrencyFormatter.format(usd: BudgetTracker.totalBudget, showYen: showYen))
                        .font(.title)
                }

                HStack(spacing: 0) {
                    Text(CurrencyFormatter.format(usd: remaining, showYen: showYen))
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

}

#Preview {
    ReportView()
        .modelContainer(for: Expense.self)
}
