import Foundation

struct ParsedReceipt {
    var merchantName: String?
    var merchantIsPlaceholder: Bool
    var date: Date?
    var totalAmount: Decimal?
    var currency: String?
    var lineItems: [LineItem]
    var confidence: Float
    var isUberReceipt: Bool
    var suggestedCategory: String?
    var expenseDescription: String?
    var exchangeRateJPYPerUSD: Decimal?
    var totalAmountUSD: Decimal?

    struct LineItem {
        let description: String
        let amount: Decimal?
    }

    // Explicit initializer to avoid Swift memberwise init issues
    init(merchantName: String? = nil,
         merchantIsPlaceholder: Bool = false,
         date: Date? = nil,
         totalAmount: Decimal? = nil,
         currency: String? = nil,
         lineItems: [LineItem],
         confidence: Float,
         isUberReceipt: Bool,
         suggestedCategory: String? = nil,
         expenseDescription: String? = nil,
         exchangeRateJPYPerUSD: Decimal? = nil,
         totalAmountUSD: Decimal? = nil) {
        self.merchantName = merchantName
        self.merchantIsPlaceholder = merchantIsPlaceholder
        self.date = date
        self.totalAmount = totalAmount
        self.currency = currency
        self.lineItems = lineItems
        self.confidence = confidence
        self.isUberReceipt = isUberReceipt
        self.suggestedCategory = suggestedCategory
        self.expenseDescription = expenseDescription
        self.exchangeRateJPYPerUSD = exchangeRateJPYPerUSD
        self.totalAmountUSD = totalAmountUSD
    }

    // Computed properties for compatibility with migration plan
    var totalAmountYen: Decimal? {
        get { totalAmount }
        set { totalAmount = newValue }
    }

    var category: String? {
        get { suggestedCategory }
        set { suggestedCategory = newValue }
    }
}

