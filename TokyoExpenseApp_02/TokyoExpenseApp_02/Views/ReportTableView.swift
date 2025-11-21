import SwiftUI

struct ReportTableView: View {
    let expenses: [Expense]
    let showYen: Bool
    var onExpenseTap: (Expense) -> Void
    
    // Fixed column widths for consistent alignment
    private let colWidths: [CGFloat] = [
        40,  // No.
        100, // Date (Widened for year)
        80,  // Category
        120, // Merchant
        140, // Description
        80,  // JPY
        60,  // Rate
        80,  // USD
        60   // Receipt
    ]
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerRow
                    .background(Color(uiColor: .systemGray6))
                
                Divider()
                
                // Rows
                LazyVStack(spacing: 0) {
                    ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                        row(for: expense, index: index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onExpenseTap(expense)
                            }
                        Divider()
                    }
                    
                    // Total Row
                    totalRow
                        .background(Color(uiColor: .systemGray6).opacity(0.3))
                }
                
                Spacer()
            }
            .padding(.bottom, 20)
            .frame(minWidth: colWidths.reduce(0, +) + 40, maxWidth: .infinity, alignment: .topLeading)
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell("No.", width: colWidths[0])
            headerCell("Date", width: colWidths[1])
            headerCell("Category", width: colWidths[2])
            headerCell("Merchant", width: colWidths[3])
            headerCell("Description", width: colWidths[4])
            headerCell("JPY", width: colWidths[5], alignment: .trailing)
            headerCell("Rate", width: colWidths[6], alignment: .trailing)
            headerCell("USD", width: colWidths[7], alignment: .trailing)
            headerCell("Rec.", width: colWidths[8], alignment: .center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
    
    private func row(for expense: Expense, index: Int) -> some View {
        HStack(spacing: 0) {
            // No.
            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: colWidths[0], alignment: .leading)
            
            // Date
            Text(formatDate(expense.date))
                .font(.caption)
                .frame(width: colWidths[1], alignment: .leading)
            
            // Category
            Text(expense.category)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(expenseCategoryColor(expense.category)).opacity(0.2))
                )
                .foregroundStyle(Color(expenseCategoryColor(expense.category)))
                .frame(width: colWidths[2], alignment: .leading)
            
            // Merchant
            Text(expense.merchantName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(width: colWidths[3], alignment: .leading)
            
            // Description
            Text(expense.expenseDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: colWidths[4], alignment: .leading)
            
            // JPY
            Text(CurrencyFormatter.format(yen: expense.amountJPY, showYen: true))
                .font(.caption)
                .frame(width: colWidths[5], alignment: .trailing)
            
            // Rate
            Text(String(format: "%.2f", NSDecimalNumber(decimal: expense.exchangeRate).doubleValue))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: colWidths[6], alignment: .trailing)
            
            // USD
            Text(CurrencyFormatter.format(usd: expense.amountUSD, showYen: false))
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: colWidths[7], alignment: .trailing)
            
            // Receipt (Thumbnail)
            if let firstPath = expense.receiptImagePaths.first {
                let url = ImageManager.shared.getImageURL(firstPath)
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 30, height: 30)
                }
                .frame(width: colWidths[8], alignment: .center)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: colWidths[8], alignment: .center)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(index % 2 == 0 ? Color.clear : Color(uiColor: .systemGray6).opacity(0.5))
    }
    
    private var totalRow: some View {
        let totalUSD = expenses.reduce(Decimal(0)) { $0 + $1.amountUSD }
        let totalJPY = expenses.reduce(Decimal(0)) { $0 + $1.amountJPY }
        
        return HStack(spacing: 0) {
            // Spacer for first 5 columns
            Spacer()
                .frame(width: colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4])
            
            // Total JPY
            Text(CurrencyFormatter.format(yen: totalJPY, showYen: true))
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: colWidths[5], alignment: .trailing)
            
            // Spacer for Rate
            Spacer()
                .frame(width: colWidths[6])
            
            // Total USD
            Text(CurrencyFormatter.format(usd: totalUSD, showYen: false))
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: colWidths[7], alignment: .trailing)
            
            // Spacer for Receipt
            Spacer()
                .frame(width: colWidths[8])
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
    
    private func headerCell(_ text: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
    }
    
    private func expenseCategoryColor(_ category: String) -> String {
        if let cat = ExpenseCategory(rawValue: category) {
            return cat.color
        }
        return "gray"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // Full date with year
        return formatter.string(from: date)
    }
}

#Preview {
    ReportTableView(expenses: [], showYen: true, onExpenseTap: { _ in })
}
