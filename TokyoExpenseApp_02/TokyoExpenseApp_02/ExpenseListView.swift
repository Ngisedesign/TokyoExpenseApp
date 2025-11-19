import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = true

    @State private var searchText = ""
    @State private var selectedCategory: ExpenseCategory? = nil

    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            let matchesSearch = searchText.isEmpty ||
                expense.merchantName.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                expense.category == selectedCategory?.rawValue
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Subtitle
            Text("\(filteredExpenses.count) entries")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(.horizontal)
                .padding(.top, 16)

            // Category filters - minimalist text buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("All")
                            .font(.body)
                            .foregroundStyle(selectedCategory == nil ? .primary : .secondary)
                            .opacity(selectedCategory == nil ? 1 : 0.5)
                            .fontWeight(selectedCategory == nil ? .semibold : .regular)
                    }

                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat.rawValue)
                                .font(.body)
                                .foregroundStyle(selectedCategory == cat ? .primary : .secondary)
                                .opacity(selectedCategory == cat ? 1 : 0.5)
                                .fontWeight(selectedCategory == cat ? .semibold : .regular)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)

            // Search
            TextField("Search", text: $searchText)
                .font(.body)
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()
                .padding(.horizontal)

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredExpenses) { expense in
                        ExpenseRow(expense: expense, showYen: showYen)
                        Divider()
                            .padding(.leading)
                    }
                }
            }
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredExpenses[index])
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let showYen: Bool

    private var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: expense.date)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            // Date in large, light grey
            Text(shortDate)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.4))
                .frame(width: 80, alignment: .leading)

            // Merchant name
            Text(expense.merchantName)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Amount
            if showYen {
                Text("¥\(expense.amountJPY.formatted(.number.precision(.fractionLength(0))))")
                    .font(.title3)
                    .fontWeight(.medium)
            } else {
                Text("$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))")
                    .font(.title3)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
}

