import SwiftUI
import SwiftData

/// Multi-segment progress bar showing food and transport spending
/// Displays remaining budget and category icons
struct TotalBudgetBar: View {
    let expenses: [Expense]
    let includeTravelDays: Bool
    let showYen: Bool

    private var foodSpent: Decimal {
        BudgetTracker.spentByCategory(.perDiem, from: expenses, includeTravelDays: includeTravelDays)
    }

    private var transportSpent: Decimal {
        BudgetTracker.spentByCategory(.transport, from: expenses, includeTravelDays: includeTravelDays)
    }

    private var total: Decimal {
        BudgetTracker.totalBudget
    }

    private var remaining: Decimal {
        max(0, total - foodSpent - transportSpent)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 44

            // Calculate budget amounts
            let foodBudget = BudgetTracker.BudgetCategory.perDiem.budget
            let transportBudget = BudgetTracker.BudgetCategory.transport.budget

            // Calculate overflow
            let foodOverflow = max(0, foodSpent - foodBudget)
            let transportOverflow = max(0, transportSpent - transportBudget)
            let foodIsOver = foodSpent > foodBudget
            let transportIsOver = transportSpent > transportBudget

            // Calculate widths as proportion of total budget
            // Normal portions (within budget)
            let foodBudgetWidth = width * CGFloat(Double(truncating: (min(foodSpent, foodBudget) / total) as NSNumber))
            let transportBudgetWidth = width * CGFloat(Double(truncating: (min(transportSpent, transportBudget) / total) as NSNumber))

            // Overflow portions (darker)
            let foodOverflowWidth = width * CGFloat(Double(truncating: (foodOverflow / total) as NSNumber))
            let transportOverflowWidth = width * CGFloat(Double(truncating: (transportOverflow / total) as NSNumber))

            // Calculate offsets
            let transportStart = foodBudgetWidth + foodOverflowWidth
            let transportOverflowStart = transportStart + transportBudgetWidth

            // Icon positions (center of normal portion only)
            let foodCenterX = max(14, min(foodBudgetWidth / 2, width - 14))
            let transportCenterX = max(14, min(transportStart + transportBudgetWidth / 2, width - 14))

            ZStack(alignment: .leading) {
                // Background bar (rounded container)
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(.primary.opacity(0.08))

                // Inner fills with flat edges
                ZStack(alignment: .leading) {
                    // Food budget portion (normal color)
                    Rectangle()
                        .fill(BudgetTracker.BudgetCategory.perDiem.color)
                        .frame(width: foodBudgetWidth)

                    // Food overflow portion (darker)
                    if foodIsOver {
                        Rectangle()
                            .fill(BudgetTracker.BudgetCategory.perDiem.color.opacity(0.5))
                            .frame(width: foodOverflowWidth)
                            .offset(x: foodBudgetWidth)
                    }

                    // Transport budget portion (normal color)
                    Rectangle()
                        .fill(BudgetTracker.BudgetCategory.transport.color)
                        .frame(width: transportBudgetWidth)
                        .offset(x: transportStart)

                    // Transport overflow portion (darker)
                    if transportIsOver {
                        Rectangle()
                            .fill(BudgetTracker.BudgetCategory.transport.color.opacity(0.5))
                            .frame(width: transportOverflowWidth)
                            .offset(x: transportOverflowStart)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))

                // Icons over segments (hide if too small)
                if foodBudgetWidth > 24 {
                    Image(systemName: BudgetTracker.BudgetCategory.perDiem.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .position(x: foodCenterX, y: height / 2)
                }
                if transportBudgetWidth > 24 {
                    Image(systemName: BudgetTracker.BudgetCategory.transport.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .position(x: transportCenterX, y: height / 2)
                }
            }
            .overlay(alignment: .trailing) {
                Text(CurrencyFormatter.format(usd: remaining, showYen: showYen, includeDecimals: false))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.trailing, 4)
            }
        }
        .frame(height: 44)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        TotalBudgetBar(
            expenses: [],
            includeTravelDays: false,
            showYen: false
        )

        TotalBudgetBar(
            expenses: [],
            includeTravelDays: true,
            showYen: true
        )
    }
    .modelContainer(for: Expense.self)
}
