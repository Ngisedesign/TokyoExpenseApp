import Foundation
import SwiftData

/// Utility to migrate existing hotel expenses to use check-in/check-out dates
struct HotelMigration {

    /// Auto-infer check-in/check-out dates for hotel expenses without them
    static func migrateHotelExpenses(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { expense in
                expense.category == "Hotel" && expense.checkInDate == nil
            }
        )

        guard let hotelExpenses = try? modelContext.fetch(descriptor) else {
            print("⚠️ Failed to fetch hotel expenses for migration")
            return
        }

        guard !hotelExpenses.isEmpty else {
            print("✅ No hotel expenses need migration")
            return
        }

        print("🔄 Migrating \(hotelExpenses.count) hotel expense(s)...")

        for expense in hotelExpenses {
            // Infer: Check-in Nov 29, Check-out Dec 7 (full trip hotel duration)
            expense.checkInDate = Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 29))
            expense.checkOutDate = BudgetTracker.tripEndDate

            print("  ✓ Migrated: \(expense.merchantName)")
        }

        do {
            try modelContext.save()
            print("✅ Hotel migration complete")
        } catch {
            print("❌ Failed to save hotel migration: \(error)")
        }
    }
}
