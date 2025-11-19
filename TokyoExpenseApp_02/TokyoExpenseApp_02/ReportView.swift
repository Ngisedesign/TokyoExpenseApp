import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = false
    @State private var showExportSheet = false

    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: expenses) { $0.category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Subtitle and export button
            HStack {
                Text("Tokyo Trip • Dec 1-5, 2025")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding()

            // Currency Toggle
            Toggle(isOn: $showYen) {
                HStack {
                    Image(systemName: "yensign.circle")
                        .foregroundStyle(.secondary)
                    Text("Show in Yen (¥)")
                        .font(.subheadline)
                }
            }
            .tint(.blue)
            .padding(.horizontal)
            .padding(.bottom)
            .background(.white)

            Divider()

            // Table Header
            HStack(spacing: 8) {
                Text("Date")
                    .frame(width: 70, alignment: .leading)
                Text("Merchant")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Amount")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.black.opacity(0.05))

            // Expense List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        if let categoryExpenses = groupedExpenses[category.rawValue], !categoryExpenses.isEmpty {
                            categorySection(category: category, expenses: categoryExpenses)
                        }
                    }

                    // Grand Total
                    grandTotalSection
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView()
        }
    }

    // MARK: - Category Section

    private func categorySection(category: ExpenseCategory, expenses: [Expense]) -> some View {
        let categoryTotal = expenses.reduce(Decimal(0)) { $0 + $1.amountJPY }

        return VStack(spacing: 0) {
            // Category Header
            HStack {
                Image(systemName: categoryIcon(category))
                    .foregroundStyle(categoryColor(category))
                Text(category.rawValue)
                    .font(.headline)
                Spacer()
                Text(formatAmount(categoryTotal / 150)) // Convert to USD
                    .font(.headline)
                    .foregroundStyle(categoryColor(category))
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(categoryColor(category).opacity(0.1))

            // Expense Rows
            ForEach(expenses) { expense in
                expenseRow(expense)
                Divider()
                    .padding(.leading)
            }

            // Category Subtotal
            HStack {
                Spacer()
                Text("Subtotal:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(formatAmount(categoryTotal / 150))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.black.opacity(0.03))
        }
    }

    // MARK: - Expense Row

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 8) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .fontWeight(.medium)
                if expense.isWorkDay {
                    Text("Work")
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.blue.opacity(0.2)))
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: 70, alignment: .leading)

            // Merchant
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchantName)
                    .font(.subheadline)
                    .lineLimit(1)
                if !expense.expenseDescription.isEmpty {
                    Text(expense.expenseDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                if showYen {
                    Text(formatAmount(expense.amountJPY / 150))
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(formatAmount(expense.amountJPY / 150))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Grand Total Section

    private var grandTotalSection: some View {
        let grandTotal = expenses.reduce(Decimal(0)) { $0 + $1.amountJPY }

        return VStack(spacing: 0) {
            Divider()
                .background(.black)
                .frame(height: 2)

            HStack {
                Text("GRAND TOTAL")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(formatAmount(grandTotal / 150))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding()
            .background(.black.opacity(0.05))

            // Budget Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget: \(formatAmount(BudgetTracker.totalBudget))")
                        .font(.caption)
                    Text("Spent: \(formatAmount(grandTotal / 150))")
                        .font(.caption)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    let remaining = BudgetTracker.totalBudget - (grandTotal / 150)
                    Text("Remaining:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(remaining))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(remaining < 0 ? .red : .green)
                }
            }
            .padding()
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

    private func categoryIcon(_ category: ExpenseCategory) -> String {
        switch category {
        case .food:
            return "fork.knife"
        case .transport:
            return "car.fill"
        case .other:
            return "ellipsis.circle"
        }
    }

    private func categoryColor(_ category: ExpenseCategory) -> Color {
        switch category {
        case .food:
            return .blue
        case .transport:
            return .green
        case .other:
            return .orange
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(for: Expense.self)
}
