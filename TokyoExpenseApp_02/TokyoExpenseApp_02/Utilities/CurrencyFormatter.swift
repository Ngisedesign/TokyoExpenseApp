import Foundation

/// Centralized currency formatting utilities for the Tokyo Expense Tracking app
/// Handles USD/JPY conversion and formatting with consistent display across all views
enum CurrencyFormatter {

    // MARK: - Default Exchange Rate

    /// Default exchange rate: 1 USD = 150 JPY
    /// Used as fallback when actual exchange rate is not available
    static let defaultExchangeRate: Decimal = 150

    // MARK: - Number Formatters

    private static let usdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    private static let usdNoDecimalsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let yenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    // MARK: - Public Formatting Methods

    /// Formats a USD amount as either Yen or USD based on user preference
    /// - Parameters:
    ///   - usdAmount: Amount in USD
    ///   - showYen: Whether to display in Yen (true) or USD (false)
    ///   - exchangeRate: Optional exchange rate to use (defaults to 150)
    ///   - includeDecimals: Whether to show decimal places (only applies to USD)
    /// - Returns: Formatted currency string (e.g., "¥15,000" or "$100.00")
    static func format(
        usd usdAmount: Decimal,
        showYen: Bool,
        exchangeRate: Decimal? = nil,
        includeDecimals: Bool = true
    ) -> String {
        if showYen {
            let rate = exchangeRate ?? defaultExchangeRate
            let yenAmount = usdAmount * rate
            return "¥" + (yenFormatter.string(from: yenAmount as NSNumber) ?? "0")
        } else {
            let formatter = includeDecimals ? usdFormatter : usdNoDecimalsFormatter
            return formatter.string(from: usdAmount as NSNumber) ?? "$0.00"
        }
    }

    /// Formats a JPY amount as either Yen or USD based on user preference
    /// - Parameters:
    ///   - yenAmount: Amount in JPY
    ///   - showYen: Whether to display in Yen (true) or USD (false)
    ///   - exchangeRate: Optional exchange rate to use (defaults to 150)
    ///   - includeDecimals: Whether to show decimal places (only applies to USD)
    /// - Returns: Formatted currency string (e.g., "¥15,000" or "$100.00")
    static func format(
        yen yenAmount: Decimal,
        showYen: Bool,
        exchangeRate: Decimal? = nil,
        includeDecimals: Bool = true
    ) -> String {
        if showYen {
            return "¥" + (yenFormatter.string(from: yenAmount as NSNumber) ?? "0")
        } else {
            let rate = exchangeRate ?? defaultExchangeRate
            let usdAmount = yenAmount / rate
            let formatter = includeDecimals ? usdFormatter : usdNoDecimalsFormatter
            return formatter.string(from: usdAmount as NSNumber) ?? "$0.00"
        }
    }

    /// Converts JPY to USD using the specified exchange rate
    /// - Parameters:
    ///   - yenAmount: Amount in JPY
    ///   - exchangeRate: Exchange rate to use (defaults to 150)
    /// - Returns: Amount in USD
    static func convertToUSD(yen yenAmount: Decimal, exchangeRate: Decimal? = nil) -> Decimal {
        let rate = exchangeRate ?? defaultExchangeRate
        return yenAmount / rate
    }

    /// Converts USD to JPY using the specified exchange rate
    /// - Parameters:
    ///   - usdAmount: Amount in USD
    ///   - exchangeRate: Exchange rate to use (defaults to 150)
    /// - Returns: Amount in JPY
    static func convertToYen(usd usdAmount: Decimal, exchangeRate: Decimal? = nil) -> Decimal {
        let rate = exchangeRate ?? defaultExchangeRate
        return usdAmount * rate
    }
}
