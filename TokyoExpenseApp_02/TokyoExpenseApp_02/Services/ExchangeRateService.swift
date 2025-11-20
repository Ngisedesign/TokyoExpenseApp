import Foundation
import Combine

/// Service for fetching exchange rates from frankfurter.app API
/// Provides USD to JPY conversion rates with caching and offline support
@MainActor
class ExchangeRateService: ObservableObject {

    // MARK: - Singleton

    static let shared = ExchangeRateService()

    // MARK: - Properties

    @Published var cachedRates: [String: Decimal] = [:]
    private let baseURL = "https://api.frankfurter.app"
    private let cacheKey = "ExchangeRateCache"

    // MARK: - Initialization

    private init() {
        loadCache()
    }

    // MARK: - Public Methods

    /// Fetches the current USD to JPY exchange rate
    /// - Returns: Exchange rate as Decimal, or nil if fetch fails
    func fetchCurrentRate() async -> Decimal? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let today = dateFormatter.string(from: Date())

        return await fetchRate(for: today)
    }

    /// Fetches USD to JPY exchange rate for a specific date
    /// - Parameter date: The date to fetch the rate for
    /// - Returns: Exchange rate as Decimal, or nil if fetch fails
    func fetchRate(for date: Date) async -> Decimal? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: date)

        return await fetchRate(for: dateString)
    }

    /// Fetches exchange rate for a date string (YYYY-MM-DD format)
    /// - Parameter dateString: Date in YYYY-MM-DD format
    /// - Returns: Exchange rate as Decimal, or nil if fetch fails
    private func fetchRate(for dateString: String) async -> Decimal? {
        // Check cache first
        if let cachedRate = cachedRates[dateString] {
            print("✅ Using cached exchange rate for \(dateString): \(cachedRate)")
            return cachedRate
        }

        // Build URL
        guard let url = URL(string: "\(baseURL)/\(dateString)?from=USD&to=JPY") else {
            print("❌ Invalid URL for date: \(dateString)")
            return nil
        }

        do {
            print("🌐 Fetching exchange rate for \(dateString) from frankfurter.app...")
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)

            guard let rate = response.rates["JPY"] else {
                print("❌ No JPY rate found in response")
                return nil
            }

            // Cache the rate
            cachedRates[dateString] = rate
            saveCache()
            print("✅ Fetched and cached exchange rate for \(dateString): \(rate)")

            return rate

        } catch {
            print("❌ Failed to fetch exchange rate for \(dateString): \(error.localizedDescription)")
            return nil
        }
    }

    /// Batch fetch exchange rates for multiple dates
    /// Useful for retroactively updating expenses
    /// - Parameter dates: Array of dates to fetch rates for
    /// - Returns: Dictionary mapping date strings to exchange rates
    func batchFetchRates(for dates: [Date]) async -> [String: Decimal] {
        var results: [String: Decimal] = [:]

        for date in dates {
            if let rate = await fetchRate(for: date) {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withFullDate]
                let dateString = dateFormatter.string(from: date)
                results[dateString] = rate
            }
        }

        return results
    }

    /// Gets a cached rate for a specific date, if available
    /// - Parameter date: The date to check
    /// - Returns: Cached exchange rate, or nil if not cached
    func getCachedRate(for date: Date) -> Decimal? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: date)
        return cachedRates[dateString]
    }

    // MARK: - Cache Management

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: Decimal].self, from: data) else {
            print("📦 No cached exchange rates found")
            return
        }
        cachedRates = decoded
        print("📦 Loaded \(cachedRates.count) cached exchange rates")
    }

    private func saveCache() {
        guard let encoded = try? JSONEncoder().encode(cachedRates) else {
            print("❌ Failed to encode exchange rate cache")
            return
        }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    func clearCache() {
        cachedRates.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        print("🗑️ Cleared exchange rate cache")
    }
}

// MARK: - Response Model

private struct ExchangeRateResponse: Codable {
    let amount: Decimal
    let base: String
    let date: String
    let rates: [String: Decimal]
}

