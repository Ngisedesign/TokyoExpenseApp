import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = false

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
            // Subtitle and currency toggle
            HStack {
                Text("\(filteredExpenses.count) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                // Currency Toggle
                Toggle(isOn: $showYen) {
                    Image(systemName: showYen ? "yensign.circle.fill" : "dollarsign.circle")
                        .font(.title2)
                }
                .tint(.blue)
                .labelsHidden()
            }
            .padding()

            // Category filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryPill(text: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        CategoryPill(text: cat.rawValue, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Search
            TextField("Search merchants...", text: $searchText)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.03))
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

            // List
            List {
                ForEach(filteredExpenses) { expense in
                    ExpenseRow(expense: expense, showYen: showYen)
                }
                .onDelete(perform: deleteExpenses)
            }
            .listStyle(.plain)
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchantName)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if expense.isWorkDay {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Work Day")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if showYen {
                    Text("¥\(expense.amountJPY.formatted(.number.precision(.fractionLength(0))))")
                        .font(.headline)
                    Text("$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))")
                        .font(.headline)
                    Text("¥\(expense.amountJPY.formatted(.number.precision(.fractionLength(0))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
