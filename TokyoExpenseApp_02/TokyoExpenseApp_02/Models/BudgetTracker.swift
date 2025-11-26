import Foundation
import SwiftUI

/// Budget tracker for Tokyo trip (Dec 1-5, 2025)
struct BudgetTracker {
    // MARK: - Budget Constants

    static let totalBudget: Decimal = 5925
    static let perDiemDaily: Decimal = 80
    static let perDiemWorkDays: Int = 5          // Work days only
    static let perDiemAllDays: Int = 10          // All trip days (Nov 28 - Dec 7)
    static let transportBudget: Decimal = 200
    static let transportDaily: Decimal = 40 // $200 / 5 days
    static let flightBudget: Decimal = 3600
    static let flightBudgetBaseline: Decimal = 3600  // Max allowed
    static let hotelNightly: Decimal = 345
    static let hotelWorkNights: Int = 5          // Work nights budgeted
    static let hotelAllNights: Int = 8           // All trip nights (check-in Nov 29, checkout Dec 7)

    /// Default exchange rate: 1 USD = 150 JPY
    /// Used as fallback when actual exchange rate is not available
    static let defaultExchangeRate: Decimal = 150

    // Trip dates (Nov 28 - Dec 7, 2025)
    static let tripStartDate = Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 28))!
    static let tripEndDate = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 7, hour: 23, minute: 59))!

    // Work days (Dec 1-5, 2025)
    static let workDayStart = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 1))!
    static let workDayEnd = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 5, hour: 23, minute: 59))!

    // MARK: - Computed Budget Totals

    /// Base per diem budget (work days only)
    static var perDiemBudget: Decimal {
        perDiemDaily * Decimal(perDiemWorkDays)
    }

    /// Hotel budget (work nights only - baseline)
    static var hotelBudget: Decimal {
        hotelNightly * Decimal(hotelWorkNights)
    }

    /// Calculate per diem budget based on number of days
    /// - Parameters:
    ///   - expenses: All expenses (not used in simplified version)
    ///   - includeTravelDays: If true, uses 10 days; if false, uses 5 work days
    /// - Returns: Per diem budget
    static func dynamicPerDiemBudget(from expenses: [Expense], includeTravelDays: Bool) -> Decimal {
        if includeTravelDays {
            // All trip days: 10 days × $80 = $800
            return perDiemDaily * Decimal(perDiemAllDays)
        } else {
            // Work days only: 5 days × $80 = $400
            return perDiemBudget
        }
    }

    // MARK: - Budget Categories

    enum BudgetCategory: String, CaseIterable {
        case perDiem = "Food"
        case transport = "Transport"
        case flight = "Flight"
        case hotel = "Hotel"

        func budget(from expenses: [Expense] = [], includeTravelDays: Bool = false) -> Decimal {
            switch self {
            case .perDiem:
                return BudgetTracker.dynamicPerDiemBudget(from: expenses, includeTravelDays: includeTravelDays)
            case .transport:
                return BudgetTracker.transportBudget
            case .flight:
                return BudgetTracker.flightBudget
            case .hotel:
                // Use all nights budget when travel days included
                return includeTravelDays
                    ? BudgetTracker.hotelNightly * Decimal(BudgetTracker.hotelAllNights)
                    : BudgetTracker.hotelBudget
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
            case .perDiem: return Color(hue: 0.58, saturation: 0.45, brightness: 0.85) // Desaturated blue
            case .transport: return Color(hue: 0.33, saturation: 0.40, brightness: 0.70) // Desaturated green
            case .flight: return Color(hue: 0.53, saturation: 0.45, brightness: 0.80) // Desaturated cyan
            case .hotel: return Color(hue: 0.75, saturation: 0.40, brightness: 0.75) // Desaturated purple
            }
        }
    }

    // MARK: - Spending Calculations

    /// Calculate total spent across all expenses
    static func totalSpent(from expenses: [Expense], includeTravelDays: Bool = false) -> Decimal {
        let filteredExpenses = includeTravelDays ? expenses : expenses.filter { $0.isWorkDay }
        return filteredExpenses.reduce(0) { $0 + $1.amountUSD }
    }

    /// Calculate spent per category
    static func spentByCategory(_ category: BudgetCategory, from expenses: [Expense], includeTravelDays: Bool = false) -> Decimal {
        // Flight and Hotel are trip-wide fixed costs, not subject to daily work day filtering
        let filteredExpenses: [Expense]
        if category == .flight || category == .hotel {
            // Always include all expenses for fixed costs
            filteredExpenses = expenses
        } else {
            // Filter by work days for daily discretionary spending (Food, Transport)
            filteredExpenses = includeTravelDays ? expenses : expenses.filter { $0.isWorkDay }
        }

        let categoryExpenses: [Expense]
        switch category {
        case .perDiem:
            categoryExpenses = filteredExpenses.filter { $0.category == ExpenseCategory.food.rawValue }
        case .transport:
            categoryExpenses = filteredExpenses.filter { $0.category == ExpenseCategory.transport.rawValue }
        case .flight:
            categoryExpenses = filteredExpenses.filter { $0.category == ExpenseCategory.flight.rawValue }
        case .hotel:
            categoryExpenses = filteredExpenses.filter { $0.category == ExpenseCategory.hotel.rawValue }
        }

        return categoryExpenses.reduce(0) { $0 + $1.amountUSD }
    }

    /// Calculate daily per diem spending for work days
    static func dailyPerDiemSpending(from expenses: [Expense]) -> [Date: Decimal] {
        var dailySpending: [Date: Decimal] = [:]

        let calendar = Calendar.current
        let workDayExpenses = expenses.filter {
            $0.isWorkDay && $0.category == ExpenseCategory.food.rawValue
        }

        for expense in workDayExpenses {
            let dayStart = calendar.startOfDay(for: expense.date)
            dailySpending[dayStart, default: 0] += expense.amountUSD
        }

        return dailySpending
    }

    /// Calculate daily transport spending for work days
    static func dailyTransportSpending(from expenses: [Expense]) -> [Date: Decimal] {
        var dailySpending: [Date: Decimal] = [:]

        let calendar = Calendar.current
        let workDayExpenses = expenses.filter {
            $0.isWorkDay && $0.category == ExpenseCategory.transport.rawValue
        }

        for expense in workDayExpenses {
            let dayStart = calendar.startOfDay(for: expense.date)
            dailySpending[dayStart, default: 0] += expense.amountUSD
        }

        return dailySpending
    }

    /// Get progress percentage for a category (0.0 to 1.0+)
    static func progress(for category: BudgetCategory, from expenses: [Expense], includeTravelDays: Bool = false) -> Double {
        let spent = spentByCategory(category, from: expenses, includeTravelDays: includeTravelDays)
        let budget = category.budget(from: expenses, includeTravelDays: includeTravelDays)

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

    // MARK: - Daily Rollover Calculations

    /// Calculate spending for today only
    static func spentToday(_ category: BudgetCategory, from expenses: [Expense]) -> Decimal {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DebugDateOverride.currentDate())

        let categoryExpenses: [Expense]
        switch category {
        case .perDiem:
            categoryExpenses = expenses.filter {
                $0.category == ExpenseCategory.food.rawValue &&
                calendar.startOfDay(for: $0.date) == today
            }
        case .transport:
            categoryExpenses = expenses.filter {
                $0.category == ExpenseCategory.transport.rawValue &&
                calendar.startOfDay(for: $0.date) == today
            }
        default:
            return 0
        }

        return categoryExpenses.reduce(0) { $0 + $1.amountUSD }
    }

    /// Calculate rollover from previous work days
    static func rolloverFromPreviousDays(_ category: BudgetCategory, from expenses: [Expense]) -> Decimal {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DebugDateOverride.currentDate())

        // Only calculate rollover for days before today
        let previousDays = allWorkDays().filter { calendar.startOfDay(for: $0) < today }

        guard !previousDays.isEmpty else { return 0 }

        let dailyAllotment = category == .perDiem ? perDiemDaily : transportDaily
        let totalAllotted = dailyAllotment * Decimal(previousDays.count)

        // Calculate spent on previous days
        let categoryExpenses: [Expense]
        switch category {
        case .perDiem:
            categoryExpenses = expenses.filter { expense in
                expense.category == ExpenseCategory.food.rawValue &&
                previousDays.contains { previousDay in
                    calendar.startOfDay(for: previousDay) == calendar.startOfDay(for: expense.date)
                }
            }
        case .transport:
            categoryExpenses = expenses.filter { expense in
                expense.category == ExpenseCategory.transport.rawValue &&
                previousDays.contains { previousDay in
                    calendar.startOfDay(for: previousDay) == calendar.startOfDay(for: expense.date)
                }
            }
        default:
            return 0
        }

        let totalSpent = categoryExpenses.reduce(0) { $0 + $1.amountUSD }
        return totalAllotted - totalSpent
    }
}

