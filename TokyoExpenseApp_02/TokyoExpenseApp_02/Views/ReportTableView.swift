import SwiftUI

struct ReportTableView: View {
    let expenses: [Expense]
    let showYen: Bool
    let includeTravelDays: Bool
    var onExpenseTap: (Expense) -> Void
    
    // Fixed column widths for consistent alignment
    private let colWidths: [CGFloat] = [
        50,  // Date (Shortened)
        80,  // Category
        120, // Merchant
        120, // Description (Reduced width)
        70,  // JPY
        50,  // Rate
        70,  // USD
        50   // Receipt
    ]
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerRow
                    .background(AppTheme.Backgrounds.lightGray)
                
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
                        .background(AppTheme.Backgrounds.lightGray.opacity(0.3))
                }
            }
            .frame(minWidth: colWidths.reduce(0, +) + 20, maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell("Date", width: colWidths[0])
            headerCell("Category", width: colWidths[1])
            headerCell("Merchant", width: colWidths[2])
            headerCell("Description", width: colWidths[3])
            headerCell("JPY", width: colWidths[4], alignment: .trailing)
            headerCell("Rate", width: colWidths[5], alignment: .trailing)
            headerCell("USD", width: colWidths[6], alignment: .trailing)
            headerCell("Rec.", width: colWidths[7], alignment: .center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
    
    private func row(for expense: Expense, index: Int) -> some View {
        let displayUSD = getDisplayUSD(for: expense)
        let displayJPY = getDisplayJPY(for: expense)

        return HStack(alignment: .top, spacing: 0) {
            // Date
            Text(formatDate(expense.date))
                .font(.caption)
                .frame(width: colWidths[0], alignment: .leading)

            // Category
            Text(expense.category)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(expenseCategoryColor(expense.category).opacity(0.2))
                )
                .foregroundStyle(expenseCategoryColor(expense.category))
                .frame(width: colWidths[1], alignment: .leading)

            // Merchant
            Text(expense.merchantName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(width: colWidths[2], alignment: .leading)

            // Description
            Text(expense.expenseDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: colWidths[3], alignment: .leading)

            // JPY (apply proration for hotel)
            Text(CurrencyFormatter.format(yen: displayJPY, showYen: true))
                .font(.caption)
                .frame(width: colWidths[4], alignment: .trailing)

            // Rate
            Text(String(format: "%.2f", NSDecimalNumber(decimal: expense.exchangeRate).doubleValue))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: colWidths[5], alignment: .trailing)

            // USD (prorated for hotel)
            Text(CurrencyFormatter.format(usd: displayUSD, showYen: false))
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: colWidths[6], alignment: .trailing)
            
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
                .frame(width: colWidths[7], alignment: .center)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: colWidths[7], alignment: .center)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(index % 2 == 0 ? Color.clear : AppTheme.Backgrounds.lightGray.opacity(0.5))
    }
    
    private var totalRow: some View {
        // Calculate totals with hotel proration applied
        var totalUSD = Decimal(0)
        var totalJPY = Decimal(0)

        for expense in expenses {
            if expense.category == ExpenseCategory.hotel.rawValue {
                let proratedUSD = BudgetTracker.proratedHotelAmount(expense: expense, includeTravelDays: includeTravelDays)
                totalUSD += proratedUSD
                totalJPY += proratedUSD * expense.exchangeRate
            } else {
                totalUSD += expense.amountUSD
                totalJPY += expense.amountJPY
            }
        }
        
        return HStack(spacing: 0) {
            // Spacer for first 4 columns (Date, Cat, Merch, Desc)
            Spacer()
                .frame(width: colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3])
            
            // Total JPY
            Text(CurrencyFormatter.format(yen: totalJPY, showYen: true))
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: colWidths[4], alignment: .trailing)
            
            // Spacer for Rate
            Spacer()
                .frame(width: colWidths[5])
            
            // Total USD
            Text(CurrencyFormatter.format(usd: totalUSD, showYen: false))
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: colWidths[6], alignment: .trailing)
            
            // Spacer for Receipt
            Spacer()
                .frame(width: colWidths[7])
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
    
    private func expenseCategoryColor(_ category: String) -> Color {
        switch category {
        case "Food": return AppTheme.CategoryColors.food
        case "Transport": return AppTheme.CategoryColors.transport
        case "Hotel": return AppTheme.CategoryColors.hotel
        case "Flight": return AppTheme.CategoryColors.flight
        case "Other": return AppTheme.CategoryColors.other
        default: return AppTheme.CategoryColors.other
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // Short date
        return formatter.string(from: date)
    }

    private func getDisplayUSD(for expense: Expense) -> Decimal {
        if expense.category == ExpenseCategory.hotel.rawValue {
            return BudgetTracker.proratedHotelAmount(expense: expense, includeTravelDays: includeTravelDays)
        } else {
            return expense.amountUSD
        }
    }

    private func getDisplayJPY(for expense: Expense) -> Decimal {
        if expense.category == ExpenseCategory.hotel.rawValue {
            let proratedUSD = BudgetTracker.proratedHotelAmount(expense: expense, includeTravelDays: includeTravelDays)
            return proratedUSD * expense.exchangeRate
        } else {
            return expense.amountJPY
        }
    }
}

#Preview {
    ReportTableView(expenses: [], showYen: true, includeTravelDays: false, onExpenseTap: { _ in })
}
