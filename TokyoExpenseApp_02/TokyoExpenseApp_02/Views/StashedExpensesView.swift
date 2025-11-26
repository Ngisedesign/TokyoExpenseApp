//
//  StashedExpensesView.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/25/25.
//

import SwiftUI
import SwiftData

struct StashedExpensesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("showYen") private var showYen = true

    let expenses: [Expense]

    @State private var selectedExpenses: Set<UUID> = []
    @State private var showUnstashConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Stashed Expenses")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .font(.body)
                .fontWeight(.medium)
            }
            .padding()

            if expenses.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary.opacity(0.3))

                    Text("No stashed expenses")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("\(expenses.count) stashed items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal)

                // List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(expenses.sorted(by: { $0.date > $1.date })) { expense in
                            HStack(spacing: 12) {
                                Button {
                                    toggleSelection(expense)
                                } label: {
                                    Image(systemName: selectedExpenses.contains(expense.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(selectedExpenses.contains(expense.id) ? .primary : .secondary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 28, height: 28)

                                ExpenseRow(expense: expense, showYen: showYen, isEditMode: false)
                            }
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(expense)
                            }

                            Divider()
                                .padding(.leading, 56)
                                .padding(.trailing, 16)
                        }
                    }
                }

                // Unstash button
                if !selectedExpenses.isEmpty {
                    VStack(spacing: 0) {
                        Divider()

                        Button {
                            showUnstashConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "tray.and.arrow.up")
                                    .font(.title2)
                                Text("Unstash \(selectedExpenses.count) item(s)")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.black)
                            )
                        }
                        .padding()
                    }
                }
            }
        }
        .alert("Unstash Expenses", isPresented: $showUnstashConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unstash") {
                unstashSelectedExpenses()
            }
        } message: {
            Text("Restore \(selectedExpenses.count) expense(s) to normal view?")
        }
    }

    private func toggleSelection(_ expense: Expense) {
        if selectedExpenses.contains(expense.id) {
            selectedExpenses.remove(expense.id)
        } else {
            selectedExpenses.insert(expense.id)
        }
    }

    private func unstashSelectedExpenses() {
        let expensesToUnstash = expenses.filter { selectedExpenses.contains($0.id) }
        for expense in expensesToUnstash {
            expense.isStashed = false
        }

        selectedExpenses.removeAll()

        do {
            try modelContext.save()
            print("✅ Unstashed \(expensesToUnstash.count) expense(s)")

            if expenses.filter({ $0.isStashed == true }).isEmpty {
                dismiss()
            }
        } catch {
            print("❌ Error unstashing expenses: \(error)")
        }
    }
}
