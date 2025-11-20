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

            let foodProgress = Double(truncating: ((foodSpent / total) as NSNumber))
            let transportProgress = Double(truncating: ((transportSpent / total) as NSNumber))

            let clampedFood = max(0.0, min(foodProgress, 1.0))
            let remainingCapacity = max(0.0, 1.0 - clampedFood)
            let clampedTransport = max(0.0, min(transportProgress, remainingCapacity))

            let foodWidth = width * CGFloat(clampedFood)
            let transportWidth = width * CGFloat(clampedTransport)

            let foodCenterX = max(14, min(foodWidth / 2, width - 14))
            let transportCenterX = max(14, min(foodWidth + transportWidth / 2, width - 14))

            ZStack(alignment: .leading) {
                // Background bar
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(.primary.opacity(0.08))

                // Food fill
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(BudgetTracker.BudgetCategory.perDiem.color)
                    .frame(width: foodWidth)

                // Transport fill
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(BudgetTracker.BudgetCategory.transport.color)
                    .frame(width: transportWidth)
                    .offset(x: foodWidth)

                // Icons over segments (hide if too small)
                if foodWidth > 24 {
                    Image(systemName: BudgetTracker.BudgetCategory.perDiem.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .position(x: foodCenterX, y: height / 2)
                }
                if transportWidth > 24 {
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
