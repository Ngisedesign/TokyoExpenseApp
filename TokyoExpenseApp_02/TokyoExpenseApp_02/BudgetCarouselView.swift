import SwiftUI
import SwiftData

struct BudgetCarouselView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPage: Int = 0
    @AppStorage("showYen") private var showYen = true

    private let pages = ["Budget", "Expenses", "Report"]

    var body: some View {
        VStack(spacing: 0) {
            // Dot indicator at very top
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(selectedPage == index ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPage)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 0)

            // Top bar with dismiss button and coin
            HStack {
                LargeIconButton(icon: "xmark", size: 48) {
                    dismiss()
                }
                Spacer()
                FlippingCoinView(size: 50, showYen: $showYen)
                    .offset(x: -4)
            }
            .padding(.horizontal)
            .padding(.top, -20)

            // Carousel header
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Text(pages[index])
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .opacity(selectedPage == index ? 1.0 : 0.3)
                            .frame(width: geometry.size.width)
                    }
                }
                .offset(x: -CGFloat(selectedPage) * geometry.size.width)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedPage)
            }
            .frame(height: 50)
            .padding(.horizontal)

            // Page content
            TabView(selection: $selectedPage) {
                BudgetContentView()
                    .tag(0)

                ExpenseListView()
                    .tag(1)

                ReportView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

// Budget content extracted from BudgetView
struct BudgetContentView: View {
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("includeTravelDays") private var includeTravelDays = false
    @AppStorage("showYen") private var showYen = true
    @State private var expandedCategories: Set<BudgetTracker.BudgetCategory> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Date subtitle with travel days toggle
                HStack {
                    Text(includeTravelDays ? "Nov 28-Dec 7" : "Dec 1-5")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.6))

                    Spacer()

                    // Custom slide toggle for travel days
                    HStack(spacing: 0) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(includeTravelDays ? .secondary : .primary)
                            .opacity(includeTravelDays ? 0.5 : 1.0)
                            .frame(width: 32, height: 32)

                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(includeTravelDays ? .primary : .secondary)
                            .opacity(includeTravelDays ? 1.0 : 0.5)
                            .frame(width: 32, height: 32)
                    }
                    .background(
                        GeometryReader { geo in
                            Circle()
                                .fill(.primary.opacity(0.1))
                                .frame(width: 32, height: 32)
                                .offset(x: includeTravelDays ? geo.size.width / 2 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: includeTravelDays)
                        }
                    )
                    .background(
                        Capsule()
                            .fill(.primary.opacity(0.05))
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            includeTravelDays.toggle()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)

                // Total Budget Overview
                totalBudgetSection
                    .padding(.bottom, 40)

                // Budget Categories
                ForEach(BudgetTracker.BudgetCategory.allCases, id: \.self) { category in
                    budgetCategorySection(category)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                }

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Total Budget Section

    private var totalBudgetSection: some View {
        let spent = BudgetTracker.totalSpent(from: expenses, includeTravelDays: includeTravelDays)
        let remaining = BudgetTracker.remainingBudget(from: expenses, includeTravelDays: includeTravelDays)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Total")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatAmount(spent))
                    .font(.title)
                Text("of")
                    .font(.title)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(formatAmount(BudgetTracker.totalBudget))
                    .font(.title)
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
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

    // MARK: - Budget Category Section

    private func budgetCategorySection(_ category: BudgetTracker.BudgetCategory) -> some View {
        let spent = BudgetTracker.spentByCategory(category, from: expenses, includeTravelDays: includeTravelDays)
        let budget = category.budget
        let remaining = budget - spent
        let isExpanded = expandedCategories.contains(category)
        let canExpand = (category == .perDiem || category == .transport) && !includeTravelDays

        return VStack(alignment: .leading, spacing: 16) {
            // Category title
            HStack {
                Text(displayName(for: category))
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
                        if isExpanded {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    }
                }
            }

            // Spending info
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatAmount(spent))
                    .font(.title2)
                Text("of")
                    .font(.title2)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(formatAmount(budget))
                    .font(.title2)
            }

            // Remaining
            Text(formatAmount(remaining))
                .font(.title)
                .foregroundStyle(remaining >= 0 ? Color(hue: 0.33, saturation: 0.70, brightness: 0.55) : Color(hue: 0.0, saturation: 0.75, brightness: 0.55))

            // Daily breakdown (expanded)
            if isExpanded {
                dailyBreakdownForCategory(category)
                    .padding(.top, 8)
            }
        }
    }

    private func dailyBreakdownForCategory(_ category: BudgetTracker.BudgetCategory) -> some View {
        let dailySpending: [Date: Decimal]

        if category == .perDiem {
            dailySpending = BudgetTracker.dailyPerDiemSpending(from: expenses)
        } else if category == .transport {
            // Compute transport daily spending inline to avoid dependency on missing API
            var dict: [Date: Decimal] = [:]
            let calendar = Calendar.current
            let workDayExpenses = expenses.filter { $0.isWorkDay && $0.category == "Transport" }
            for expense in workDayExpenses {
                let dayStart = calendar.startOfDay(for: expense.date)
                dict[dayStart, default: 0] += expense.amountJPY / 150 // Convert to USD
            }
            dailySpending = dict
        } else {
            dailySpending = [:]
        }

        let dailyBudget = category == .perDiem ? BudgetTracker.perDiemDaily : BudgetTracker.transportDaily

        return VStack(spacing: 8) {
            ForEach(BudgetTracker.allWorkDays(), id: \.self) { day in
                dailyCard(day: day, spent: dailySpending[Calendar.current.startOfDay(for: day)] ?? 0, dailyBudget: dailyBudget)
            }
        }
    }

    private func dailyCard(day: Date, spent: Decimal, dailyBudget: Decimal) -> some View {
        let remaining = dailyBudget - spent

        return VStack(alignment: .leading, spacing: 8) {
            // Date in large, light grey
            Text(shortDate(day))
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.4))

            // Spending info
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatAmount(spent))
                    .font(.title3)
                Text("of")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(formatAmount(dailyBudget))
                    .font(.title3)
            }

            if remaining != 0 {
                Text(formatAmount(remaining))
                    .font(.body)
                    .foregroundStyle(remaining >= 0 ? Color(hue: 0.33, saturation: 0.70, brightness: 0.55) : Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helper Functions

    private func displayName(for category: BudgetTracker.BudgetCategory) -> String {
        switch category {
        case .perDiem:
            return "Food"
        default:
            return category.rawValue
        }
    }

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

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    BudgetCarouselView()
        .modelContainer(for: Expense.self)
}

