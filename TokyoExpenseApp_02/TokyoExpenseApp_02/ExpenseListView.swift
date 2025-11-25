import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("showYen") private var showYen = true

    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var selectedExpense: Expense?
    @State private var isEditMode = false
    @State private var selectedExpenses: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            let matchesCategory = selectedCategory == nil || expense.category == selectedCategory?.rawValue
            return matchesCategory
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with count and edit button
            HStack {
                Text("\(filteredExpenses.count) entries")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))

                Spacer()

                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedExpenses.removeAll()
                        }
                    }
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Category filters - minimalist text buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("All")
                            .font(.body)
                            .foregroundStyle(selectedCategory == nil ? .primary : .secondary)
                            .opacity(selectedCategory == nil ? 1 : 0.5)
                            .fontWeight(selectedCategory == nil ? .semibold : .regular)
                    }
                    .buttonStyle(.plain)

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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)

            Divider()
                .padding(.horizontal)

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredExpenses) { expense in
                        HStack(spacing: 12) {
                            if isEditMode {
                                Button {
                                    toggleSelection(expense)
                                } label: {
                                    Image(systemName: selectedExpenses.contains(expense.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(selectedExpenses.contains(expense.id) ? .primary : .secondary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 28, height: 28)
                            }

                            ExpenseRow(expense: expense, showYen: showYen, isEditMode: isEditMode)
                        }
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                toggleSelection(expense)
                            } else {
                                selectedExpense = expense
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSingleExpense(expense)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        Divider()
                            .padding(.leading, isEditMode ? 56 : 16)
                            .padding(.trailing, 16)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Action bar when in edit mode
            if isEditMode && !selectedExpenses.isEmpty {
                VStack(spacing: 0) {
                    Divider()

                    HStack(spacing: 20) {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .foregroundStyle(.red)
                        }

                        Spacer()

                        Text("\(selectedExpenses.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
        }
        .fullScreenCover(item: $selectedExpense) { expense in
            ExpenseDetailView(expense: expense)
        }
        .alert("Delete Expenses", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedExpenses()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedExpenses.count) expense(s)? This action cannot be undone.")
        }
    }

    private func toggleSelection(_ expense: Expense) {
        if selectedExpenses.contains(expense.id) {
            selectedExpenses.remove(expense.id)
        } else {
            selectedExpenses.insert(expense.id)
        }
    }

    private func deleteSelectedExpenses() {
        // Find and delete expenses with selected IDs
        let expensesToDelete = expenses.filter { selectedExpenses.contains($0.id) }
        for expense in expensesToDelete {
            // Delete associated receipt images first
            ImageManager.shared.deleteImages(expense.receiptImagePaths)

            modelContext.delete(expense)
        }

        // Clear selection and exit edit mode
        selectedExpenses.removeAll()
        isEditMode = false

        // Save context
        do {
            try modelContext.save()
            print("💾 Deleted \(expensesToDelete.count) expense(s)")
        } catch {
            print("❌ Error deleting expenses: \(error)")
        }
    }

    private func deleteSingleExpense(_ expense: Expense) {
        // Delete associated receipt images first
        ImageManager.shared.deleteImages(expense.receiptImagePaths)

        modelContext.delete(expense)

        do {
            try modelContext.save()
            print("💾 Deleted expense: \(expense.merchantName)")
        } catch {
            print("❌ Error deleting expense: \(error)")
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
    let isEditMode: Bool

    var body: some View {
        ZStack(alignment: .center) {
            // Background date watermark (centered)
            Text(DateFormatters.shortDate(expense.date))
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.primary.opacity(0.06))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .offset(x: isEditMode ? 20 : 0) // Slight offset if edit mode pushes content

            // Foreground content
            HStack(alignment: .center, spacing: 12) {
                // Merchant name and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.merchantName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !expense.expenseDescription.isEmpty {
                        Text(expense.expenseDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Amount
                if showYen {
                    Text("¥\(expense.amountJPY.formatted(.number.precision(.fractionLength(0))))")
                        .font(.headline)
                        .fontWeight(.semibold)
                } else {
                    Text("$\(expense.amountUSD.formatted(.number.precision(.fractionLength(2))))")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
