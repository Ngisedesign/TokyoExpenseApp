import Foundation

class CSVExporter {
    static let shared = CSVExporter()

    private init() {}

    func generateCSV(from expenses: [Expense]) -> String {
        var csv = "Number,Date,Time,Category,Merchant,Description,Amount_JPY,Amount_USD,Receipt_Filename\n"

        let sortedExpenses = expenses.sorted { $0.date < $1.date }

        for (index, expense) in sortedExpenses.enumerated() {
            let number = String(format: "%03d", index + 1)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.string(from: expense.date)

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let time = timeFormatter.string(from: expense.date)

            let receiptFilenames = expense.receiptImagePaths.joined(separator: "; ")

            let line = [
                number,
                date,
                time,
                expense.category,
                expense.merchantName.csvEscaped,
                expense.expenseDescription.csvEscaped,
                "¥\(expense.amountJPY.formatted(.number.precision(.fractionLength(0))))",
                "$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))",
                receiptFilenames
            ].joined(separator: ",")

            csv += line + "\n"
        }

        return csv
    }

    /// Formats the row number with a preferred width (defaults to 2 for <100 rows, 3 otherwise)
    private func formattedNumber(index: Int, totalCount: Int, preferredWidth: Int?) -> String {
        let width = preferredWidth ?? (totalCount >= 100 ? 3 : 2)
        return String(format: "%0*d", width, index + 1)
    }

    /// Generates CSV but uses a mapping of exported (renamed) receipt filenames per expense.
    /// - Parameters:
    ///   - expenses: The expenses to include (will be sorted by date ascending).
    ///   - filenameMap: Maps Expense.id to an ordered list of exported filenames (e.g. ["01_lunch.jpg", "01_lunch_2.jpg"]).
    ///   - numberWidth: Optional width for the leading number column and filename prefix (defaults to 2 if <100 rows, else 3).
    /// - Returns: CSV string
    func generateCSV(
        from expenses: [Expense],
        filenameMap: [UUID: [String]],
        numberWidth: Int? = nil
    ) -> String {
        var csv = "Number,Date,Time,Category,Merchant,Description,Amount_JPY,Amount_USD,Receipt_Filename\n"

        let sortedExpenses = expenses.sorted { $0.date < $1.date }
        let total = sortedExpenses.count

        for (index, expense) in sortedExpenses.enumerated() {
            let number = formattedNumber(index: index, totalCount: total, preferredWidth: numberWidth)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.string(from: expense.date)

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let time = timeFormatter.string(from: expense.date)

            // Use exported names if provided, else fall back to original stored filenames
            let exportedNames = filenameMap[expense.id] ?? expense.receiptImagePaths
            let receiptFilenames = exportedNames.joined(separator: "; ")

            let line = [
                number,
                date,
                time,
                expense.category,
                expense.merchantName.csvEscaped,
                expense.expenseDescription.csvEscaped,
                "¥\(expense.amountJPY.formatted(.number.precision(.fractionLength(0))))",
                "$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))",
                receiptFilenames
            ].joined(separator: ",")

            csv += line + "\n"
        }

        return csv
    }

    func exportToFile(expenses: [Expense]) -> URL? {
        let csv = generateCSV(from: expenses)

        let fileName = "expenses_\(Date().timeIntervalSince1970).csv"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }
}

extension String {
    var csvEscaped: String {
        let escaped = self.replacingOccurrences(of: "\"", with: "\"\"")
        return self.contains(",") || self.contains("\"") ? "\"\(escaped)\"" : self
    }
}
