import SwiftUI
import SwiftData

/// Card displaying budget information for a specific category
/// Shows category name, spending, budget, and expandable daily breakdown
struct BudgetCategoryCard: View {
    let category: BudgetTracker.BudgetCategory
    let expenses: [Expense]
    let includeTravelDays: Bool
    let showYen: Bool
    @Binding var isExpanded: Bool

    private var spent: Decimal {
        BudgetTracker.spentByCategory(category, from: expenses, includeTravelDays: includeTravelDays)
    }

    private var budget: Decimal {
        category.budget(from: expenses, includeTravelDays: includeTravelDays)
    }

    private var remaining: Decimal {
        budget - spent
    }

    private var canExpand: Bool {
        (category == .perDiem || category == .transport) && !includeTravelDays
    }

    private var displayName: String {
        switch category {
        case .perDiem:
            return "Food"
        default:
            return category.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category title with chevron
            HStack {
                Text(displayName)
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.primary)

                if canExpand {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if canExpand {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Spending info
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(CurrencyFormatter.format(usd: spent, showYen: showYen))
                    .font(.title2)
                Text("of")
                    .font(.title2)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(CurrencyFormatter.format(usd: budget, showYen: showYen))
                    .font(.title2)

                // Show overspent amount in red only if over budget
                if remaining < 0 {
                    Text(CurrencyFormatter.format(usd: abs(remaining), showYen: showYen))
                        .font(.title2)
                        .foregroundStyle(AppTheme.SemanticColors.overspending)
                }
            }

            // Daily breakdown (expanded)
            if isExpanded {
                dailyBreakdown
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Daily Breakdown

    @ViewBuilder
    private var dailyBreakdown: some View {
        let dailySpending = getDailySpending()
        let dailyBudget = category == .perDiem ? BudgetTracker.perDiemDaily : BudgetTracker.transportDaily

        VStack(spacing: 8) {
            ForEach(BudgetTracker.allWorkDays(), id: \.self) { day in
                DailyBudgetCard(
                    day: day,
                    spent: dailySpending[Calendar.current.startOfDay(for: day)] ?? 0,
                    dailyBudget: dailyBudget,
                    showYen: showYen
                )
            }
        }
    }

    private func getDailySpending() -> [Date: Decimal] {
        if category == .perDiem {
            return BudgetTracker.dailyPerDiemSpending(from: expenses)
        } else if category == .transport {
            return BudgetTracker.dailyTransportSpending(from: expenses)
        } else {
            return [:]
        }
    }
}

#Preview {
    @Previewable @State var isExpanded = false

    ScrollView {
        VStack(spacing: 40) {
            BudgetCategoryCard(
                category: .perDiem,
                expenses: [],
                includeTravelDays: false,
                showYen: false,
                isExpanded: $isExpanded
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .modelContainer(for: Expense.self)
}
