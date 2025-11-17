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
                "¥\(expense.amountJPY)",
                "$\(expense.amountUSD)",
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
