import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = true
    @AppStorage("includeTravelDays") private var includeTravelDays = false
    @State private var showExportSheet = false
    @State private var selectedExpense: Expense?

    private var filteredExpenses: [Expense] {
        let list = includeTravelDays ? expenses : expenses.filter { $0.isWorkDay }
        return list.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Subtitle and export button
            HStack {
                Text(includeTravelDays ? "Nov 28-Dec 7" : "Dec 1-5")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
                Spacer()

                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal)

            // Expense Table
            ReportTableView(expenses: filteredExpenses, showYen: showYen) { expense in
                selectedExpense = expense
            }
            
            Spacer()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView()
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseDetailView(expense: expense)
        }
    }

}

#Preview {
    ReportView()
        .modelContainer(for: Expense.self)
}
