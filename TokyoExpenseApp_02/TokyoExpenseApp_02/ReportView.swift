import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = true
    @AppStorage("includeTravelDays") private var includeTravelDays = false
    @State private var showExportSheet = false
    @State private var selectedExpense: Expense?
    @State private var showingDetailView = false

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
        .sheet(isPresented: $showingDetailView) {
            if let expense = selectedExpense {
                ExpenseDetailView(expense: expense)
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(category: ExpenseCategory, expenses: [Expense]) -> some View {
        let categoryTotalUSD = expenses.reduce(Decimal(0)) { $0 + $1.amountUSD }

        return VStack(alignment: .leading, spacing: 16) {
            // Category Header
            HStack {
                Text(category.rawValue)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.primary)
                Spacer()
                Text(CurrencyFormatter.format(usd: categoryTotalUSD, showYen: showYen))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)

            // Expense Rows
            VStack(spacing: 0) {
                ForEach(expenses) { expense in
                    expenseRow(expense)
                        .onTapGesture {
                            selectedExpense = expense
                            showingDetailView = true
                        }
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }

    // MARK: - Expense Row

    private func expenseRow(_ expense: Expense) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                // Date in large, light grey
                Text(DateFormatters.shortDate(expense.date))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(width: 70, alignment: .leading)

                // Merchant and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.merchantName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !expense.expenseDescription.isEmpty {
                        Text(expense.expenseDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Amount (main display based on toggle)
                Text(CurrencyFormatter.format(usd: expense.amountUSD, showYen: showYen))
                    .font(.body)
                    .fontWeight(.semibold)
            }

            // Secondary info: JPY, USD, and exchange rate
            HStack(spacing: 12) {
                Spacer()
                    .frame(width: 70) // Align with date column

                // JPY amount
                Text(CurrencyFormatter.format(yen: expense.amountJPY, showYen: true))
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.6))

                Text("→")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.4))

                // USD amount
                Text(CurrencyFormatter.format(usd: expense.amountUSD, showYen: false))
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.6))

                Text("@")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.4))

                // Exchange rate with warning if using fallback
                HStack(spacing: 4) {
                    if expense.needsExchangeRateUpdate == true {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                    Text(String(format: "%.2f", NSDecimalNumber(decimal: expense.exchangeRate).doubleValue))
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.6))
                }

                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Grand Total Section

    private var grandTotalSection: some View {
        let grandTotalUSD = filteredExpenses.reduce(Decimal(0)) { $0 + $1.amountUSD }
        let remaining = BudgetTracker.totalBudget - grandTotalUSD

        return VStack(alignment: .leading, spacing: 20) {
            Divider()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                Text("Total")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(CurrencyFormatter.format(usd: grandTotalUSD, showYen: showYen))
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
