import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var date: Date
    var category: String
    var merchantName: String
    var expenseDescription: String
    var amountJPY: Decimal
    var amountUSD: Decimal
    var exchangeRate: Decimal
    var receiptImagePaths: [String]
    var isWorkDay: Bool
    var isManualEntry: Bool
    var isArchived: Bool?
    var ocrConfidence: Float?
    var notes: String?
    var needsExchangeRateUpdate: Bool?

    init(
        id: UUID = UUID(),
        date: Date,
        category: String,
        merchantName: String,
        expenseDescription: String,
        amountJPY: Decimal,
        amountUSD: Decimal,
        exchangeRate: Decimal,
        receiptImagePaths: [String] = [],
        isWorkDay: Bool,
        isManualEntry: Bool = true,
        isArchived: Bool? = false,
        ocrConfidence: Float? = nil,
        notes: String? = nil,
        needsExchangeRateUpdate: Bool? = false
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.merchantName = merchantName
        self.expenseDescription = expenseDescription
        self.amountJPY = amountJPY
        self.amountUSD = amountUSD
        self.exchangeRate = exchangeRate
        self.receiptImagePaths = receiptImagePaths
        self.isWorkDay = isWorkDay
        self.isManualEntry = isManualEntry
        self.isArchived = isArchived
        self.ocrConfidence = ocrConfidence
        self.notes = notes
        self.needsExchangeRateUpdate = needsExchangeRateUpdate
    }

    var isIncomplete: Bool {
        // An entry is incomplete if it's missing key information
        let hasNoAmount = amountUSD == 0 && amountJPY == 0
        let hasGenericName = merchantName.isEmpty || merchantName == "Untitled"
        let hasNoReceipt = receiptImagePaths.isEmpty

        // Incomplete if missing amount AND (missing name OR missing receipt)
        return hasNoAmount || (hasGenericName && hasNoReceipt)
    }
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food"
    case transport = "Transport"
    case other = "Other"

    var color: String {
        switch self {
        case .food:
            return "blue"
        case .transport:
            return "green"
        case .other:
            return "gray"
        }
    }
}
