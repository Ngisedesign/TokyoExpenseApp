import Foundation
import SwiftData
import UIKit

/// Debug date override utility
/// Allows simulating a specific date for testing daily budget calculations
struct DebugDateOverride {
    private static let overrideKey = "debugDateOverride"
    private static let triggerKey = "debugDateOverrideTrigger"

    /// Set the debug date override to December 5, 2025
    static func setToDecember5() {
        let calendar = Calendar.current
        if let date = calendar.date(from: DateComponents(year: 2025, month: 12, day: 5, hour: 14, minute: 0)) {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: overrideKey)
            // Toggle trigger to force UI updates
            let currentTrigger = UserDefaults.standard.bool(forKey: triggerKey)
            UserDefaults.standard.set(!currentTrigger, forKey: triggerKey)
            print("🗓️ Debug date set to: \(date)")
        }
    }

    /// Clear the debug date override (return to actual current date)
    static func clearOverride() {
        UserDefaults.standard.removeObject(forKey: overrideKey)
        // Toggle trigger to force UI updates
        let currentTrigger = UserDefaults.standard.bool(forKey: triggerKey)
        UserDefaults.standard.set(!currentTrigger, forKey: triggerKey)
        print("🗓️ Debug date cleared, using actual date")
    }

    /// Get the current date (either override or actual)
    static func currentDate() -> Date {
        if let timestamp = UserDefaults.standard.object(forKey: overrideKey) as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        return Date()
    }

    /// Check if override is active
    static var isOverrideActive: Bool {
        return UserDefaults.standard.object(forKey: overrideKey) != nil
    }

    /// Get a formatted string describing the current date state
    static var currentDateDescription: String {
        let date = currentDate()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if isOverrideActive {
            return "Override: \(formatter.string(from: date))"
        } else {
            return "Actual: \(formatter.string(from: date))"
        }
    }
}

/// Debug service for generating sample expense data
/// Use this to test the app with realistic Tokyo trip expenses
@MainActor
class SampleDataGenerator {

    // MARK: - Sample Expense Templates

    private struct ExpenseTemplate {
        let merchantName: String
        let description: String
        let category: String
        let amountJPY: Decimal
        let exchangeRate: Decimal = 150 // Default rate for samples

        var amountUSD: Decimal {
            amountJPY / exchangeRate
        }
    }

    // MARK: - Sample Data Collections

    private static let foodExpenses: [ExpenseTemplate] = [
        ExpenseTemplate(merchantName: "Ichiran Ramen Shibuya", description: "Late night tonkotsu ramen", category: ExpenseCategory.food.rawValue, amountJPY: 1200),
        ExpenseTemplate(merchantName: "7-Eleven Shinjuku", description: "Breakfast onigiri and coffee", category: ExpenseCategory.food.rawValue, amountJPY: 580),
        ExpenseTemplate(merchantName: "Tsukiji Sushi Dai", description: "Fresh sushi lunch at market", category: ExpenseCategory.food.rawValue, amountJPY: 4500),
        ExpenseTemplate(merchantName: "Lawson Station Akihabara", description: "Convenience store snacks", category: ExpenseCategory.food.rawValue, amountJPY: 320),
        ExpenseTemplate(merchantName: "Starbucks Roppongi Hills", description: "Morning coffee and pastry", category: ExpenseCategory.food.rawValue, amountJPY: 890),
        ExpenseTemplate(merchantName: "Hanamaru Udon", description: "Quick udon lunch", category: ExpenseCategory.food.rawValue, amountJPY: 680),
        ExpenseTemplate(merchantName: "Family Mart Ginza", description: "Late night snacks", category: ExpenseCategory.food.rawValue, amountJPY: 450),
        ExpenseTemplate(merchantName: "Tonki Tonkatsu", description: "Crispy tonkatsu dinner", category: ExpenseCategory.food.rawValue, amountJPY: 2100),
        ExpenseTemplate(merchantName: "Yoshinoya Shibuya", description: "Beef bowl lunch", category: ExpenseCategory.food.rawValue, amountJPY: 550),
        ExpenseTemplate(merchantName: "Blue Bottle Coffee Aoyama", description: "Specialty coffee", category: ExpenseCategory.food.rawValue, amountJPY: 780),
        ExpenseTemplate(merchantName: "Matsuya", description: "Curry rice dinner", category: ExpenseCategory.food.rawValue, amountJPY: 590),
        ExpenseTemplate(merchantName: "Sushi Zanmai Tsukiji", description: "Fresh sushi dinner", category: ExpenseCategory.food.rawValue, amountJPY: 3200),
    ]

    private static let transportExpenses: [ExpenseTemplate] = [
        ExpenseTemplate(merchantName: "Tokyo Metro", description: "Ginza Line to Shibuya", category: ExpenseCategory.transport.rawValue, amountJPY: 200),
        ExpenseTemplate(merchantName: "JR East Yamanote Line", description: "Shinjuku to Akihabara", category: ExpenseCategory.transport.rawValue, amountJPY: 160),
        ExpenseTemplate(merchantName: "Nihon Kotsu Taxi", description: "Late night taxi to hotel", category: ExpenseCategory.transport.rawValue, amountJPY: 2800),
        ExpenseTemplate(merchantName: "Tokyo Metro", description: "Marunouchi Line pass", category: ExpenseCategory.transport.rawValue, amountJPY: 180),
        ExpenseTemplate(merchantName: "Skyliner Keisei", description: "Airport express to Ueno", category: ExpenseCategory.transport.rawValue, amountJPY: 2520),
        ExpenseTemplate(merchantName: "Tokyo Metro", description: "Roppongi to Tokyo Station", category: ExpenseCategory.transport.rawValue, amountJPY: 200),
        ExpenseTemplate(merchantName: "JR East", description: "IC card charge", category: ExpenseCategory.transport.rawValue, amountJPY: 1000),
    ]

    private static let hotelExpense = ExpenseTemplate(
        merchantName: "Hotel Gracery Shinjuku",
        description: "5 nights accommodation",
        category: ExpenseCategory.hotel.rawValue,
        amountJPY: 210000 // $1400 at 150 rate (under budget by $325)
    )

    private static let flightExpense = ExpenseTemplate(
        merchantName: "United Airlines",
        description: "Roundtrip SFO-NRT",
        category: ExpenseCategory.flight.rawValue,
        amountJPY: 450000 // $3000 at 150 rate (under budget by $600)
    )

    // MARK: - Generation Logic

    /// Generate a complete set of sample expenses for the Tokyo trip (Dec 1-5, 2025)
    static func generateSampleData(context: ModelContext) {
        print("🎲 Generating sample expense data...")

        let calendar = Calendar.current
        let workDays = BudgetTracker.allWorkDays()

        var expenses: [Expense] = []

        // Add hotel (typically paid at checkout, so put on last day)
        // Hotels always provide receipts
        let hotelDate = workDays[4] // Dec 5
        expenses.append(createExpense(from: hotelExpense, date: hotelDate, isWorkDay: true, shouldGenerateReceipt: true))

        // Add flight (typically booked before trip, so put on first day)
        // Flights always provide receipts
        let flightDate = workDays[0] // Dec 1
        expenses.append(createExpense(from: flightExpense, date: flightDate, isWorkDay: true, shouldGenerateReceipt: true))

        // Distribute food expenses across all 5 days (2-3 meals per day)
        var foodIndex = 0
        for (dayIndex, day) in workDays.enumerated() {
            let mealsPerDay = dayIndex % 2 == 0 ? 3 : 2 // Vary between 2-3 meals

            for mealIndex in 0..<mealsPerDay {
                guard foodIndex < foodExpenses.count else { break }

                // Add some time variance to meals
                let hour = [8, 12, 19][mealIndex % 3] // Breakfast, lunch, dinner times
                let minute = Int.random(in: 0...59)

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
                dateComponents.hour = hour
                dateComponents.minute = minute

                if let mealDate = calendar.date(from: dateComponents) {
                    // 70% chance of having a receipt for food
                    let shouldHaveReceipt = Double.random(in: 0...1) < 0.7
                    expenses.append(createExpense(
                        from: foodExpenses[foodIndex],
                        date: mealDate,
                        isWorkDay: true,
                        shouldGenerateReceipt: shouldHaveReceipt
                    ))
                }

                foodIndex += 1
            }
        }

        // Distribute transport expenses across days (1-2 per day)
        var transportIndex = 0
        for (dayIndex, day) in workDays.enumerated() {
            let transportsPerDay = dayIndex < 3 ? 1 : 2 // More transport on later days

            for transportSeq in 0..<transportsPerDay {
                guard transportIndex < transportExpenses.count else { break }

                // Vary transport times throughout the day
                let hour = transportSeq == 0 ? Int.random(in: 9...14) : Int.random(in: 16...22)

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
                dateComponents.hour = hour
                dateComponents.minute = Int.random(in: 0...59)

                if let transportDate = calendar.date(from: dateComponents) {
                    // 70% chance of having a receipt for transport
                    let shouldHaveReceipt = Double.random(in: 0...1) < 0.7
                    expenses.append(createExpense(
                        from: transportExpenses[transportIndex],
                        date: transportDate,
                        isWorkDay: true,
                        shouldGenerateReceipt: shouldHaveReceipt
                    ))
                }

                transportIndex += 1
            }
        }

        // Insert all expenses into the context
        for expense in expenses {
            context.insert(expense)
        }

        // Save context
        do {
            try context.save()
            let receiptsCount = expenses.filter { !$0.receiptImagePaths.isEmpty }.count
            print("✅ Generated \(expenses.count) sample expenses")
            print("   💴 Food: \(expenses.filter { $0.category == ExpenseCategory.food.rawValue }.count)")
            print("   🚇 Transport: \(expenses.filter { $0.category == ExpenseCategory.transport.rawValue }.count)")
            print("   🏨 Hotel: \(expenses.filter { $0.category == ExpenseCategory.hotel.rawValue }.count)")
            print("   ✈️ Flight: \(expenses.filter { $0.category == ExpenseCategory.flight.rawValue }.count)")
            print("   📸 With receipts: \(receiptsCount)/\(expenses.count)")
        } catch {
            print("❌ Failed to save sample data: \(error)")
        }
    }

    /// Clear all expenses from the database
    static func clearAllData(context: ModelContext) {
        print("🗑️ Clearing all expense data...")

        do {
            // Fetch all expenses
            let descriptor = FetchDescriptor<Expense>()
            let allExpenses = try context.fetch(descriptor)

            // Delete receipt images first
            var deletedImages = 0
            for expense in allExpenses {
                for imagePath in expense.receiptImagePaths {
                    ImageManager.shared.deleteImage(imagePath)
                    deletedImages += 1
                }
            }

            // Delete each expense
            for expense in allExpenses {
                context.delete(expense)
            }

            // Save changes
            try context.save()
            print("✅ Deleted \(allExpenses.count) expenses")
            if deletedImages > 0 {
                print("   🗑️ Deleted \(deletedImages) receipt images")
            }
        } catch {
            print("❌ Failed to clear data: \(error)")
        }
    }

    // MARK: - Receipt Image Generation

    /// Generate a dummy receipt image for testing
    /// Creates a colored rectangle with merchant name and amount overlay
    private static func generateDummyReceiptImage(merchantName: String, amount: Decimal, category: String) -> UIImage? {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // Background color based on category (always light for PDF readability)
            let backgroundColor: UIColor
            switch category {
            case ExpenseCategory.food.rawValue:
                backgroundColor = AppTheme.PDFExport.foodBackground
            case ExpenseCategory.transport.rawValue:
                backgroundColor = AppTheme.PDFExport.transportBackground
            case ExpenseCategory.hotel.rawValue:
                backgroundColor = AppTheme.PDFExport.hotelBackground
            case ExpenseCategory.flight.rawValue:
                backgroundColor = AppTheme.PDFExport.flightBackground
            default:
                backgroundColor = AppTheme.PDFExport.otherBackground
            }

            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw border
            UIColor.black.setStroke()
            context.stroke(CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20))

            // Draw "RECEIPT" header
            let headerText = "RECEIPT" as NSString
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor.black
            ]
            let headerSize = headerText.size(withAttributes: headerAttributes)
            headerText.draw(at: CGPoint(x: (size.width - headerSize.width) / 2, y: 40), withAttributes: headerAttributes)

            // Draw merchant name
            let merchantText = merchantName as NSString
            let merchantAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let merchantSize = merchantText.size(withAttributes: merchantAttributes)
            merchantText.draw(at: CGPoint(x: (size.width - merchantSize.width) / 2, y: 120), withAttributes: merchantAttributes)

            // Draw amount
            let amountText = String(format: "¥%.0f", NSDecimalNumber(decimal: amount).doubleValue) as NSString
            let amountAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.black
            ]
            let amountSize = amountText.size(withAttributes: amountAttributes)
            amountText.draw(at: CGPoint(x: (size.width - amountSize.width) / 2, y: 250), withAttributes: amountAttributes)

            // Draw "TEST RECEIPT" watermark
            let watermarkText = "TEST DATA" as NSString
            let watermarkAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.gray
            ]
            let watermarkSize = watermarkText.size(withAttributes: watermarkAttributes)
            watermarkText.draw(at: CGPoint(x: (size.width - watermarkSize.width) / 2, y: size.height - 50), withAttributes: watermarkAttributes)
        }

        return image
    }

    // MARK: - Helper Methods

    private static func createExpense(from template: ExpenseTemplate, date: Date, isWorkDay: Bool, shouldGenerateReceipt: Bool = false) -> Expense {
        var receiptPaths: [String] = []

        // Generate and save receipt image if requested
        if shouldGenerateReceipt {
            if let receiptImage = generateDummyReceiptImage(
                merchantName: template.merchantName,
                amount: template.amountJPY,
                category: template.category
            ) {
                if let filename = ImageManager.shared.saveImage(receiptImage) {
                    receiptPaths.append(filename)
                    print("📸 Generated receipt image: \(filename) for \(template.merchantName)")
                }
            }
        }

        return Expense(
            date: date,
            category: template.category,
            merchantName: template.merchantName,
            expenseDescription: template.description,
            amountJPY: template.amountJPY,
            amountUSD: template.amountUSD,
            exchangeRate: template.exchangeRate,
            receiptImagePaths: receiptPaths,
            isWorkDay: isWorkDay,
            isManualEntry: false, // Mark as AI-generated for realism
            ocrConfidence: 0.95 // High confidence for sample data
        )
    }

    /// Get a summary of current data state
    static func getDataSummary(context: ModelContext) -> String {
        do {
            let descriptor = FetchDescriptor<Expense>()
            let allExpenses = try context.fetch(descriptor)

            if allExpenses.isEmpty {
                return "No expenses in database"
            }

            let total = allExpenses.reduce(Decimal(0)) { $0 + $1.amountUSD }
            let foodCount = allExpenses.filter { $0.category == ExpenseCategory.food.rawValue }.count
            let transportCount = allExpenses.filter { $0.category == ExpenseCategory.transport.rawValue }.count
            let hotelCount = allExpenses.filter { $0.category == ExpenseCategory.hotel.rawValue }.count
            let flightCount = allExpenses.filter { $0.category == ExpenseCategory.flight.rawValue }.count

            return """
            \(allExpenses.count) expenses totaling $\(total)
            Food: \(foodCount) | Transport: \(transportCount) | Hotel: \(hotelCount) | Flight: \(flightCount)
            """
        } catch {
            return "Error fetching data: \(error.localizedDescription)"
        }
    }
}

