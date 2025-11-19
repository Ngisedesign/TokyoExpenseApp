import Foundation
import SwiftUI

/// Budget tracker for Tokyo trip (Dec 1-5, 2025)
struct BudgetTracker {
    // MARK: - Budget Constants

    static let totalBudget: Decimal = 5925
    static let perDiemDaily: Decimal = 80
    static let perDiemDays: Int = 5
    static let transportBudget: Decimal = 200
    static let flightBudget: Decimal = 3600
    static let hotelNightly: Decimal = 345
    static let hotelNights: Int = 5

    static let workDayStart = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 1))!
    static let workDayEnd = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 5, hour: 23, minute: 59))!

    // MARK: - Computed Budget Totals

    static var perDiemBudget: Decimal {
        perDiemDaily * Decimal(perDiemDays)
    }

    static var hotelBudget: Decimal {
        hotelNightly * Decimal(hotelNights)
    }

    // MARK: - Budget Categories

    enum BudgetCategory: String, CaseIterable {
        case perDiem = "Food/Per Diem"
        case transport = "Transport"
        case flight = "Flight"
        case hotel = "Hotel"

        var budget: Decimal {
            switch self {
            case .perDiem: return BudgetTracker.perDiemBudget
            case .transport: return BudgetTracker.transportBudget
            case .flight: return BudgetTracker.flightBudget
            case .hotel: return BudgetTracker.hotelBudget
            }
        }

        var icon: String {
            switch self {
            case .perDiem: return "fork.knife"
            case .transport: return "car.fill"
            case .flight: return "airplane"
            case .hotel: return "bed.double.fill"
            }
        }

        var color: Color {
            switch self {
            case .perDiem: return .blue
            case .transport: return .green
            case .flight: return .purple
            case .hotel: return .orange
            }
        }
    }

    // MARK: - Spending Calculations

    /// Calculate total spent across all expenses
    static func totalSpent(from expenses: [Expense], includeTravelDays: Bool = false) -> Decimal {
        let filteredExpenses = includeTravelDays ? expenses : expenses.filter { $0.isWorkDay }
        return filteredExpenses.reduce(0) { $0 + $1.amountJPY } / 150 // Convert to USD
    }

    /// Calculate spent per category
    static func spentByCategory(_ category: BudgetCategory, from expenses: [Expense], includeTravelDays: Bool = false) -> Decimal {
        let filteredExpenses = includeTravelDays ? expenses : expenses.filter { $0.isWorkDay }

        let categoryExpenses: [Expense]
        switch category {
        case .perDiem:
            categoryExpenses = filteredExpenses.filter { $0.category == "Food/Per Diem" }
        case .transport:
            categoryExpenses = filteredExpenses.filter { $0.category == "Transport" }
        case .flight:
            categoryExpenses = filteredExpenses.filter { $0.merchantName.lowercased().contains("flight") || $0.merchantName.lowercased().contains("airline") }
        case .hotel:
            categoryExpenses = filteredExpenses.filter { $0.merchantName.lowercased().contains("hotel") || $0.merchantName.lowercased().contains("inn") }
        }

        return categoryExpenses.reduce(0) { $0 + $1.amountJPY } / 150 // Convert to USD
    }

    /// Calculate daily per diem spending for work days
    static func dailyPerDiemSpending(from expenses: [Expense]) -> [Date: Decimal] {
        var dailySpending: [Date: Decimal] = [:]

        let calendar = Calendar.current
        let workDayExpenses = expenses.filter {
            $0.isWorkDay && $0.category == "Food/Per Diem"
        }

        for expense in workDayExpenses {
            let dayStart = calendar.startOfDay(for: expense.date)
            dailySpending[dayStart, default: 0] += expense.amountJPY / 150 // Convert to USD
        }

        return dailySpending
    }

    /// Get progress percentage for a category (0.0 to 1.0+)
    static func progress(for category: BudgetCategory, from expenses: [Expense], includeTravelDays: Bool = false) -> Double {
        let spent = spentByCategory(category, from: expenses, includeTravelDays: includeTravelDays)
        let budget = category.budget

        guard budget > 0 else { return 0 }
        return Double(truncating: (spent / budget) as NSNumber)
    }

    /// Get status color based on spending (green, yellow, red)
    static func statusColor(for progress: Double) -> Color {
        if progress >= 1.0 {
            return .red
        } else if progress >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    /// Check if a date is a work day (Dec 1-5, 2025)
    static func isWorkDay(_ date: Date) -> Bool {
        return date >= workDayStart && date <= workDayEnd
    }

    /// Get all work days as array
    static func allWorkDays() -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current

        for day in 1...5 {
            if let date = calendar.date(from: DateComponents(year: 2025, month: 12, day: day)) {
                days.append(date)
            }
        }

        return days
    }

    /// Remaining budget
    static func remainingBudget(from expenses: [Expense], includeTravelDays: Bool = false) -> Decimal {
        totalBudget - totalSpent(from: expenses, includeTravelDays: includeTravelDays)
    }
}
