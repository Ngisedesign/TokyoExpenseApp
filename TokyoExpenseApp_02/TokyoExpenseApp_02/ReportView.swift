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
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()

                LargeIconButton(
                    icon: "square.and.arrow.up",
                    size: 24,
                    color: .gray.opacity(0.8)
                ) {
                    showExportSheet = true
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fullScreenCover(isPresented: $showExportSheet) {
            ExportView()
        }
        .fullScreenCover(item: $selectedExpense) { expense in
            ExpenseDetailView(expense: expense)
        }
    }

}

#Preview {
    ReportView()
        .modelContainer(for: Expense.self)
}
