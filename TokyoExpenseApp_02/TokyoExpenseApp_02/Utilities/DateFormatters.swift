import Foundation

/// Centralized date formatting utilities for the Tokyo Expense Tracking app
/// Provides reusable, pre-configured date formatters to avoid duplication
enum DateFormatters {

    // MARK: - Shared Formatter Instances

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Public Formatting Methods

    /// Formats date as "MMM d" (e.g., "Dec 1", "Nov 28")
    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// Formats date as full day name (e.g., "Monday", "Friday")
    static func dayOfWeek(_ date: Date) -> String {
        dayOfWeekFormatter.string(from: date)
    }

    /// Formats date as medium style (e.g., "Dec 1, 2025")
    static func fullDate(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    /// Formats date and time (e.g., "Dec 1, 2025, 3:30 PM")
    static func dateTime(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }
}
