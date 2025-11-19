import SwiftUI
import SwiftData

struct BudgetCarouselView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPage: Int = 0

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
            .padding(.bottom, 8)

            // Top bar with dismiss button
            HStack {
                LargeIconButton(icon: "xmark", size: 48) {
                    dismiss()
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

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
    @AppStorage("showYen") private var showYen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Date subtitle
                Text("December 1-5, 2025")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Toggles
                VStack(spacing: 12) {
                    Toggle(isOn: $includeTravelDays) {
                        HStack {
                            Image(systemName: "airplane.departure")
                                .foregroundStyle(.secondary)
                            Text("Include Travel Days")
                                .font(.subheadline)
                        }
                    }
                    .tint(.blue)

                    Toggle(isOn: $showYen) {
                        HStack {
                            Image(systemName: "yensign.circle")
                                .foregroundStyle(.secondary)
                            Text("Show in Yen (¥)")
                                .font(.subheadline)
                        }
                    }
                    .tint(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.03))
                )
                .padding(.horizontal)

                // Total Budget Overview
                totalBudgetCard

                // Budget Categories
                VStack(spacing: 16) {
                    ForEach(BudgetTracker.BudgetCategory.allCases, id: \.self) { category in
                        budgetCategoryCard(category)
                    }
                }
                .padding(.horizontal)

                // Daily Per Diem Breakdown
                if !includeTravelDays {
                    dailyPerDiemSection
                }

                Spacer(minLength: 32)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Total Budget Card

    private var totalBudgetCard: some View {
        let spent = BudgetTracker.totalSpent(from: expenses, includeTravelDays: includeTravelDays)
        let remaining = BudgetTracker.remainingBudget(from: expenses, includeTravelDays: includeTravelDays)
        let progress = Double(truncating: (spent / BudgetTracker.totalBudget) as NSNumber)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(BudgetTracker.totalBudget))
                        .font(.system(size: 32, weight: .bold))
                }
                Spacer()
                Circle()
                    .fill(BudgetTracker.statusColor(for: progress))
                    .frame(width: 12, height: 12)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BudgetTracker.statusColor(for: progress))
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                }
            }
            .frame(height: 12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(spent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(remaining))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(remaining < 0 ? .red : .green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Budget Category Card

    private func budgetCategoryCard(_ category: BudgetTracker.BudgetCategory) -> some View {
        let spent = BudgetTracker.spentByCategory(category, from: expenses, includeTravelDays: includeTravelDays)
        let budget = category.budget
        let progress = BudgetTracker.progress(for: category, from: expenses, includeTravelDays: includeTravelDays)
        let remaining = budget - spent

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(category.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.headline)
                    Text(formatAmount(budget))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatAmount(spent))
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(BudgetTracker.statusColor(for: progress))
                }
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(category.color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(BudgetTracker.statusColor(for: progress))
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                }
            }
            .frame(height: 8)

            if remaining < 0 {
                Text("⚠️ Over budget by \(formatAmount(abs(remaining)))")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("\(formatAmount(remaining)) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.03))
        )
    }

    // MARK: - Daily Per Diem Section

    private var dailyPerDiemSection: some View {
        let dailySpending = BudgetTracker.dailyPerDiemSpending(from: expenses)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Daily Per Diem Breakdown")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(BudgetTracker.allWorkDays(), id: \.self) { day in
                    dailyPerDiemCard(day: day, spent: dailySpending[Calendar.current.startOfDay(for: day)] ?? 0)
                }
            }
            .padding(.horizontal)
        }
    }

    private func dailyPerDiemCard(day: Date, spent: Decimal) -> some View {
        let progress = Double(truncating: (spent / BudgetTracker.perDiemDaily) as NSNumber)

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(dayOfWeek(day))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(spent))
                    .font(.headline)
                    .foregroundStyle(BudgetTracker.statusColor(for: progress))
                Text("/ \(formatAmount(BudgetTracker.perDiemDaily))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(BudgetTracker.statusColor(for: progress).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(BudgetTracker.statusColor(for: progress).opacity(0.3), lineWidth: 1)
        )
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

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

#Preview {
    BudgetCarouselView()
        .modelContainer(for: Expense.self)
}
