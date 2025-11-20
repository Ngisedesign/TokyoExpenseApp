import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("includeTravelDays") private var includeTravelDays = false
    @AppStorage("showYen") private var showYen = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with dismiss button
            HStack {
                LargeIconButton(icon: "xmark", size: 48) {
                    dismiss()
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tokyo Trip Budget")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("December 1-5, 2025")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
                    Text(CurrencyFormatter.format(usd: BudgetTracker.totalBudget, showYen: showYen))
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
                    Text(CurrencyFormatter.format(usd: spent, showYen: showYen))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(usd: remaining, showYen: showYen))
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
                    Text(CurrencyFormatter.format(usd: budget, showYen: showYen))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.format(usd: spent, showYen: showYen))
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
                Text("⚠️ Over budget by \(CurrencyFormatter.format(usd: abs(remaining), showYen: showYen))")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("\(CurrencyFormatter.format(usd: remaining, showYen: showYen)) remaining")
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
                Text(DateFormatters.dayOfWeek(day))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.format(usd: spent, showYen: showYen))
                    .font(.headline)
                    .foregroundStyle(BudgetTracker.statusColor(for: progress))
                Text("/ \(CurrencyFormatter.format(usd: BudgetTracker.perDiemDaily, showYen: showYen))")
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

}

#Preview {
    BudgetView()
        .modelContainer(for: Expense.self)
}
