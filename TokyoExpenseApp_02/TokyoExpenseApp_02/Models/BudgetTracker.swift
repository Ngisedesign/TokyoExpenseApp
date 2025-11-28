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
            case .perDiem: return AppTheme.CategoryColors.food
            case .transport: return AppTheme.CategoryColors.transport
            case .flight: return AppTheme.CategoryColors.flight
            case .hotel: return AppTheme.CategoryColors.hotel
            }
        }
    }

    // MARK: - Spending Calculations

    // MARK: - Stash Filtering

    /// Filter out stashed expenses from calculations
    private static func filterStashed(_ expenses: [Expense]) -> [Expense] {
        expenses.filter { $0.isStashed != true }
    }

    /// Calculate total spent across all expenses
    static func totalSpent(from expenses: [Expense], includeTravelDays: Bool = false) -> Decimal {
        let unstashed = filterStashed(expenses)

        // Separate hotel expenses for proration
        let hotelExpenses = unstashed.filter { $0.category == ExpenseCategory.hotel.rawValue }
        let flightExpenses = unstashed.filter { $0.category == ExpenseCategory.flight.rawValue }
        let otherExpenses = unstashed.filter {
            $0.category != ExpenseCategory.hotel.rawValue &&
            $0.category != ExpenseCategory.flight.rawValue
        }

        // Hotel with proration
        let hotelSpent = hotelExpenses.reduce(0) { total, expense in
            total + proratedHotelAmount(expense: expense, includeTravelDays: includeTravelDays)
        }

        // Flight always counts in full
        let flightSpent = flightExpenses.reduce(0) { $0 + $1.amountUSD }

        // Others with work day filtering
        let filteredOthers = includeTravelDays ? otherExpenses : otherExpenses.filter { $0.isWorkDay }
        let otherSpent = filteredOthers.reduce(0) { $0 + $1.amountUSD }

        return hotelSpent + flightSpent + otherSpent
    }

    /// Calculate spent per category
    static func spentByCategory(_ category: BudgetCategory, from expenses: [Expense], includeTravelDays: Bool = false) -> Decimal {
        let unstashed = filterStashed(expenses)

        // Flight and Hotel are trip-wide fixed costs, not subject to daily work day filtering
        let filteredExpenses: [Expense]
        if category == .flight || category == .hotel {
            // Always include all expenses for fixed costs
            filteredExpenses = unstashed
        } else {
            // Filter by work days for daily discretionary spending (Food, Transport)
            filteredExpenses = includeTravelDays ? unstashed : unstashed.filter { $0.isWorkDay }
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

        // Apply hotel proration
        if category == .hotel {
            return categoryExpenses.reduce(0) { total, expense in
                total + proratedHotelAmount(expense: expense, includeTravelDays: includeTravelDays)
            }
        } else {
            return categoryExpenses.reduce(0) { $0 + $1.amountUSD }
        }
    }

    /// Calculate daily per diem spending for work days
    static func dailyPerDiemSpending(from expenses: [Expense]) -> [Date: Decimal] {
        var dailySpending: [Date: Decimal] = [:]

        let calendar = Calendar.current
        let unstashed = filterStashed(expenses)
        let workDayExpenses = unstashed.filter {
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
        let unstashed = filterStashed(expenses)
        let workDayExpenses = unstashed.filter {
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

    /// Get all trip days as array (Nov 28 - Dec 7, 2025)
    static func allTripDays() -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current

        // Nov 28-30
        for day in 28...30 {
            if let date = calendar.date(from: DateComponents(year: 2025, month: 11, day: day)) {
                days.append(date)
            }
        }

        // Dec 1-7
        for day in 1...7 {
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

    // MARK: - Hotel Proration Utilities

    /// Calculate the number of work nights for a hotel stay
    /// Work nights = nights where BOTH check-in and check-out fall within Dec 1-5
    static func calculateWorkNights(checkIn: Date, checkOut: Date) -> Int {
        let calendar = Calendar.current

        // Work period: Dec 1-5, 2025 (full days)
        guard let workStart = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1)),
              let workEnd = calendar.date(from: DateComponents(year: 2025, month: 12, day: 5, hour: 23, minute: 59))
        else {
            return 0
        }

        let totalNights = calendar.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0
        guard totalNights > 0 else { return 0 }

        var workNights = 0

        // Iterate through each night
        for nightIndex in 0..<totalNights {
            guard let nightStart = calendar.date(byAdding: .day, value: nightIndex, to: checkIn),
                  let nightEnd = calendar.date(byAdding: .day, value: nightIndex + 1, to: checkIn)
            else {
                continue
            }

            // A night is a "work night" if BOTH check-in and check-out fall within work period
            let nightStartInWorkPeriod = nightStart >= workStart && nightStart <= workEnd
            let nightEndInWorkPeriod = nightEnd >= workStart && nightEnd <= calendar.date(byAdding: .day, value: 1, to: workEnd)!

            if nightStartInWorkPeriod && nightEndInWorkPeriod {
                workNights += 1
            }
        }

        return workNights
    }

    /// Calculate total nights for a hotel stay
    static func calculateTotalNights(checkIn: Date, checkOut: Date) -> Int {
        let calendar = Calendar.current
        let nights = calendar.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0
        return max(nights, 0)
    }

    /// Get prorated amount for a hotel expense based on work days
    static func proratedHotelAmount(expense: Expense, includeTravelDays: Bool) -> Decimal {
        guard expense.category == ExpenseCategory.hotel.rawValue else {
            return expense.amountUSD
        }

        // If no check-in/check-out dates, return full amount (legacy expenses)
        guard let checkIn = expense.checkInDate,
              let checkOut = expense.checkOutDate else {
            return expense.amountUSD
        }

        let totalNights = calculateTotalNights(checkIn: checkIn, checkOut: checkOut)
        guard totalNights > 0 else { return 0 }

        let workNights = calculateWorkNights(checkIn: checkIn, checkOut: checkOut)
        let perNightRate = expense.amountUSD / Decimal(totalNights)

        if includeTravelDays {
            return expense.amountUSD  // All nights
        } else {
            return perNightRate * Decimal(workNights)  // Only work nights
        }
    }

    /// Get nightly breakdown of a hotel expense for daily view display
    static func hotelNightlyBreakdown(expense: Expense) -> [Date: Decimal] {
        guard expense.category == ExpenseCategory.hotel.rawValue,
              let checkIn = expense.checkInDate,
              let checkOut = expense.checkOutDate else {
            return [:]
        }

        let calendar = Calendar.current
        let totalNights = calculateTotalNights(checkIn: checkIn, checkOut: checkOut)
        guard totalNights > 0 else { return [:] }

        let perNightRate = expense.amountUSD / Decimal(totalNights)
        var breakdown: [Date: Decimal] = [:]

        for nightIndex in 0..<totalNights {
            guard let nightDate = calendar.date(byAdding: .day, value: nightIndex, to: checkIn) else {
                continue
            }
            let nightStart = calendar.startOfDay(for: nightDate)
            breakdown[nightStart] = perNightRate
        }

        return breakdown
    }

    /// Calculate daily hotel spending (prorated per night)
    static func dailyHotelSpending(from expenses: [Expense]) -> [Date: Decimal] {
        var dailySpending: [Date: Decimal] = [:]

        let unstashed = filterStashed(expenses)
        let hotelExpenses = unstashed.filter { $0.category == ExpenseCategory.hotel.rawValue }

        for expense in hotelExpenses {
            let breakdown = hotelNightlyBreakdown(expense: expense)
            for (night, amount) in breakdown {
                dailySpending[night, default: 0] += amount
            }
        }

        return dailySpending
    }

    // MARK: - Daily Rollover Calculations

    /// Calculate spending for today only
    static func spentToday(_ category: BudgetCategory, from expenses: [Expense]) -> Decimal {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DebugDateOverride.currentDate())

        let unstashed = filterStashed(expenses)

        let categoryExpenses: [Expense]
        switch category {
        case .perDiem:
            categoryExpenses = unstashed.filter {
                $0.category == ExpenseCategory.food.rawValue &&
                calendar.startOfDay(for: $0.date) == today
            }
        case .transport:
            categoryExpenses = unstashed.filter {
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

        let unstashed = filterStashed(expenses)

        // Calculate spent on previous days
        let categoryExpenses: [Expense]
        switch category {
        case .perDiem:
            categoryExpenses = unstashed.filter { expense in
                expense.category == ExpenseCategory.food.rawValue &&
                previousDays.contains { previousDay in
                    calendar.startOfDay(for: previousDay) == calendar.startOfDay(for: expense.date)
                }
            }
        case .transport:
            categoryExpenses = unstashed.filter { expense in
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

