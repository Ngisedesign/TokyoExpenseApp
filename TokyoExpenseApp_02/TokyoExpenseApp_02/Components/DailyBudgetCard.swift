import SwiftUI

/// Card displaying daily budget information for a specific day
/// Shows date, spending, budget, and overspending if applicable
struct DailyBudgetCard: View {
    let day: Date
    let spent: Decimal
    let dailyBudget: Decimal
    let showYen: Bool

    private var remaining: Decimal {
        dailyBudget - spent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date in large, light grey
            Text(DateFormatters.shortDate(day))
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.4))

            // Spending info
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CurrencyFormatter.format(usd: spent, showYen: showYen))
                    .font(.title3)
                Text("of")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(CurrencyFormatter.format(usd: dailyBudget, showYen: showYen))
                    .font(.title3)

                // Show overspent amount in red only if over budget
                if remaining < 0 {
                    Text(CurrencyFormatter.format(usd: abs(remaining), showYen: showYen))
                        .font(.title3)
                        .foregroundStyle(AppTheme.SemanticColors.overspending)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        DailyBudgetCard(
            day: Date(),
            spent: 65.50,
            dailyBudget: 80,
            showYen: false
        )

        DailyBudgetCard(
            day: Date(),
            spent: 95.00,
            dailyBudget: 80,
            showYen: false
        )

        DailyBudgetCard(
            day: Date(),
            spent: 12000,
            dailyBudget: 12000,
            showYen: true
        )
    }
    .padding()
}
