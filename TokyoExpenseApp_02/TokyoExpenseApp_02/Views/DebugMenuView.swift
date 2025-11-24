//
//  DebugMenuView.swift
//  TokyoExpenseApp_02
//
//  Debug menu for testing with sample data
//

import SwiftUI
import SwiftData

struct DebugMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var expenses: [Expense]

    @State private var isGenerating = false
    @State private var isClearing = false
    @State private var showConfirmClear = false
    @State private var statusMessage: String = ""
    @State private var isDateOverrideActive = DebugDateOverride.isOverrideActive
    @State private var currentDateDescription = DebugDateOverride.currentDateDescription

    var dataSummary: String {
        SampleDataGenerator.getDataSummary(context: modelContext)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Menu")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Generate sample data to test the app with realistic expenses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGroupedBackground))

                // Status Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Data")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .padding(.top)

                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dataSummary)
                                    .font(.body)
                                if !statusMessage.isEmpty {
                                    Text(statusMessage)
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Date Override Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date Override")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .padding(.top, 24)

                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(isDateOverrideActive ? .orange : .blue)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentDateDescription)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("Current date used for budget calculations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)

                        HStack(spacing: 12) {
                            // Set to December 5th button
                            Button(action: setDateToDecember5) {
                                HStack {
                                    Spacer()
                                    Text("Set to Dec 5")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(isDateOverrideActive ? Color(.secondarySystemGroupedBackground) : Color.blue)
                                .foregroundColor(isDateOverrideActive ? .secondary : .white)
                                .cornerRadius(10)
                            }
                            .disabled(isDateOverrideActive)

                            // Clear override button
                            Button(action: clearDateOverride) {
                                HStack {
                                    Spacer()
                                    Text("Use Actual Date")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(!isDateOverrideActive ? Color(.secondarySystemGroupedBackground) : Color.orange)
                                .foregroundColor(!isDateOverrideActive ? .secondary : .white)
                                .cornerRadius(10)
                            }
                            .disabled(!isDateOverrideActive)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Actions Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sample Data")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .padding(.top, 24)

                    VStack(spacing: 12) {
                        // Generate Sample Data Button
                        Button(action: generateSampleData) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Generate Sample Data")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("Create ~20 realistic Tokyo expenses across Dec 1-5")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isGenerating {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                        .disabled(isGenerating || isClearing)

                        // Clear All Data Button
                        Button(action: { showConfirmClear = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(.red)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clear All Data")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("Delete all expenses from the database")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isClearing {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                        .disabled(isGenerating || isClearing || expenses.isEmpty)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Info Footer
                VStack(spacing: 4) {
                    Text("This menu is for development and testing only")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("Access: Long-press menu button or triple-tap orange dot")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                updateDateState()
            }
            .confirmationDialog(
                "Clear All Data?",
                isPresented: $showConfirmClear,
                titleVisibility: .visible
            ) {
                Button("Clear All Expenses", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(expenses.count) expenses. This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func setDateToDecember5() {
        DebugDateOverride.setToDecember5()
        updateDateState()
        statusMessage = "Date override set to December 5, 2025"

        // Clear status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            statusMessage = ""
        }
    }

    private func clearDateOverride() {
        DebugDateOverride.clearOverride()
        updateDateState()
        statusMessage = "Date override cleared, using actual date"

        // Clear status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            statusMessage = ""
        }
    }

    private func updateDateState() {
        isDateOverrideActive = DebugDateOverride.isOverrideActive
        currentDateDescription = DebugDateOverride.currentDateDescription
    }

    private func generateSampleData() {
        isGenerating = true
        statusMessage = ""

        // Use a small delay to let the UI update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            SampleDataGenerator.generateSampleData(context: modelContext)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isGenerating = false
                statusMessage = "Sample data generated successfully"

                // Clear status after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    statusMessage = ""
                }
            }
        }
    }

    private func clearAllData() {
        isClearing = true
        statusMessage = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            SampleDataGenerator.clearAllData(context: modelContext)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isClearing = false
                statusMessage = "All data cleared"

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    statusMessage = ""
                }
            }
        }
    }
}

#Preview {
    DebugMenuView()
        .modelContainer(for: Expense.self, inMemory: true)
}

