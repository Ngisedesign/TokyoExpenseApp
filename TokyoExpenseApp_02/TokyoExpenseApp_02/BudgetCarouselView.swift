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
                .padding(.bottom, 16)

                // Total Budget Overview
                totalBudgetSection
                    .padding(.bottom, 20)

                // Budget Categories
                ForEach(BudgetTracker.BudgetCategory.allCases, id: \.self) { category in
                    budgetCategorySection(category)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 8)
            .padding(.bottom)
        }
    }

    // MARK: - Total Budget Section

    private var totalBudgetSection: some View {
        let foodSpent = BudgetTracker.spentByCategory(.perDiem, from: expenses, includeTravelDays: includeTravelDays)
        let transportSpent = BudgetTracker.spentByCategory(.transport, from: expenses, includeTravelDays: includeTravelDays)
        let total = BudgetTracker.totalBudget
        let remaining = max(0, total - foodSpent - transportSpent)

        return GeometryReader { geo in
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
                Text(formatAmountNoDecimals(remaining))
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

    // MARK: - Budget Category Section

    private func budgetCategorySection(_ category: BudgetTracker.BudgetCategory) -> some View {
        let spent = BudgetTracker.spentByCategory(category, from: expenses, includeTravelDays: includeTravelDays)
        let budget = category.budget
        let remaining = budget - spent
        let isExpanded = expandedCategories.contains(category)
        let canExpand = (category == .perDiem || category == .transport) && !includeTravelDays

        return VStack(alignment: .leading, spacing: 8) {
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

                // Show overspent amount in red only if over budget
                if remaining < 0 {
                    Text(formatAmount(abs(remaining)))
                        .font(.title2)
                        .foregroundStyle(Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                }
            }

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

                // Show overspent amount in red only if over budget
                if remaining < 0 {
                    Text(formatAmount(abs(remaining)))
                        .font(.title3)
                        .foregroundStyle(Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                }
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
    
    private func formatAmountNoDecimals(_ amount: Decimal) -> String {
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
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            return formatter.string(from: amount as NSNumber) ?? "$0"
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
