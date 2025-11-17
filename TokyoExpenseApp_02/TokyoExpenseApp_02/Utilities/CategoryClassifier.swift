import Foundation

class CategoryClassifier {
    static let shared = CategoryClassifier()

    private init() {}

    /// Suggest a category based on merchant name and keywords
    /// - Parameter merchantName: The merchant or business name
    /// - Returns: Suggested category string
    func suggestCategory(for merchantName: String) -> String {
        let lowercased = merchantName.lowercased()

        // Transport keywords (highest priority for Uber, train, etc.)
        let transportKeywords = [
            "uber", "taxi", "タクシー", "train", "電車", "jr", "metro",
            "subway", "地下鉄", "suica", "pasmo", "transport", "交通",
            "駅", "station", "bus", "バス", "airport", "空港"
        ]

        for keyword in transportKeywords {
            if lowercased.contains(keyword) {
                return ExpenseCategory.transport.rawValue
            }
        }

        // Food keywords
        let foodKeywords = [
            "restaurant", "cafe", "coffee", "ramen", "ラーメン",
            "sushi", "寿司", "食堂", "kitchen", "bistro", "bar",
            "starbucks", "スタバ", "mcdonald", "マクドナルド",
            "burger", "pizza", "ピザ", "izakaya", "居酒屋",
            "convenience", "コンビニ", "lawson", "familymart", "7-eleven",
            "food", "食", "飲", "drink", "meal", "lunch", "dinner",
            "breakfast", "ichiran", "一蘭", "yoshinoya", "吉野家",
            "matsuya", "松屋", "すき家", "sukiya"
        ]

        for keyword in foodKeywords {
            if lowercased.contains(keyword) {
                return ExpenseCategory.food.rawValue
            }
        }

        // Shopping keywords - NOW MAP TO OTHER
        // These were previously mapped to Shopping category, now go to Other
        let shoppingKeywords = [
            "shop", "store", "mall", "market", "マーケット",
            "uniqlo", "ユニクロ", "muji", "無印", "bic camera",
            "ビックカメラ", "yodobashi", "ヨドバシ", "don quijote",
            "ドンキホーテ", "loft", "ロフト", "tokyu hands",
            "東急ハンズ", "daiso", "ダイソー", "electronics",
            "clothing", "服", "bookstore", "本屋", "gift", "お土産",
            "souvenir", "pharmacy", "薬局", "drugstore"
        ]

        for keyword in shoppingKeywords {
            if lowercased.contains(keyword) {
                return ExpenseCategory.other.rawValue
            }
        }

        // Default to Other if no match
        return ExpenseCategory.other.rawValue
    }

    /// Get category confidence score
    /// - Parameters:
    ///   - merchantName: The merchant name
    ///   - category: The suggested category
    /// - Returns: Confidence score 0-1
    func categorySuggestedConfidence(for merchantName: String, category: String) -> Float {
        let lowercased = merchantName.lowercased()

        // High confidence keywords (0.9)
        let highConfidenceKeywords: [String: [String]] = [
            ExpenseCategory.transport.rawValue: ["uber", "taxi", "train", "jr", "suica"],
            ExpenseCategory.food.rawValue: ["ramen", "sushi", "restaurant", "starbucks", "ichiran"],
            ExpenseCategory.other.rawValue: ["uniqlo", "muji", "electronics"]  // Changed from shopping
        ]

        if let keywords = highConfidenceKeywords[category] {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return 0.9
                }
            }
        }

        // Medium confidence (0.6)
        let mediumConfidenceKeywords: [String: [String]] = [
            ExpenseCategory.transport.rawValue: ["metro", "subway", "bus", "station"],
            ExpenseCategory.food.rawValue: ["cafe", "coffee", "bar", "convenience"],
            ExpenseCategory.other.rawValue: ["shop", "store", "mall"]  // Changed from shopping
        ]

        if let keywords = mediumConfidenceKeywords[category] {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return 0.6
                }
            }
        }

        // Low confidence default
        return 0.3
    }

    /// Determine if this is likely a work-related expense
    /// - Parameter merchantName: The merchant name
    /// - Returns: True if likely work-related
    func isLikelyWorkExpense(merchantName: String) -> Bool {
        let workKeywords = [
            "office", "オフィス", "conference", "会議",
            "google", "グーグル", "meeting", "ミーティング",
            "business", "ビジネス"
        ]

        let lowercased = merchantName.lowercased()
        return workKeywords.contains { lowercased.contains($0) }
    }
}
