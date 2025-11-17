import Foundation

/// Translation service for Japanese text
/// Uses keyword-based translation for common receipt terms
class TranslationService {
    static let shared = TranslationService()

    private var translationCache: [String: String] = [:]

    private init() {}

    /// Translate text from Japanese to English using keyword mapping
    /// - Parameter text: Japanese text to translate
    /// - Returns: Translated English text
    func translateToEnglish(_ text: String) async throws -> String {
        // Check cache first
        if let cached = translationCache[text] {
            return cached
        }

        // Use keyword-based translation
        let translated = translateKeywords(text)

        // Cache the translation
        translationCache[text] = translated

        return translated
    }

    /// Translate multiple text strings
    /// - Parameter texts: Array of Japanese text strings
    /// - Returns: Array of translated English strings
    func translateMultiple(_ texts: [String]) async throws -> [String] {
        var results: [String] = []

        for text in texts {
            let translated = try await translateToEnglish(text)
            results.append(translated)
        }

        return results
    }

    /// Clear translation cache
    func clearCache() {
        translationCache.removeAll()
    }

    /// Keyword-based translation
    /// Maps common Japanese receipt words to English
    private func translateKeywords(_ text: String) -> String {
        var translated = text

        let keywords: [String: String] = [
            // Receipt terms
            "合計": "Total",
            "小計": "Subtotal",
            "計": "Total",
            "税込": "Tax Included",
            "税抜": "Tax Excluded",
            "消費税": "Sales Tax",
            "お会計": "Bill",
            "領収書": "Receipt",
            "レシート": "Receipt",

            // Date components
            "年": "/",
            "月": "/",
            "日": "",

            // Currency
            "円": "¥",

            // Categories
            "食事": "Food",
            "飲み物": "Drink",
            "交通": "Transport",
            "電車": "Train",
            "タクシー": "Taxi",

            // Common merchants
            "ラーメン": "Ramen",
            "寿司": "Sushi",
            "居酒屋": "Izakaya",
            "コンビニ": "Convenience Store",

            // Tokyo locations
            "渋谷": "Shibuya",
            "新宿": "Shinjuku",
            "原宿": "Harajuku",
            "六本木": "Roppongi",
            "銀座": "Ginza",
            "秋葉原": "Akihabara",
            "上野": "Ueno",
            "浅草": "Asakusa",
            "池袋": "Ikebukuro",
            "恵比寿": "Ebisu",
            "目黒": "Meguro",
            "品川": "Shinagawa",
            "駅": "Station"
        ]

        for (japanese, english) in keywords {
            translated = translated.replacingOccurrences(of: japanese, with: english)
        }

        return translated
    }
}
