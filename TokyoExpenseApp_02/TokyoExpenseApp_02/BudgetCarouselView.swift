import SwiftUI
import SwiftData

struct BudgetCarouselView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPage: Int = 0
    @AppStorage("showYen") private var showYen = true

    private let pages = ["Budget", "Expenses", "Report"]

    var body: some View {
        VStack(spacing: 0) {
            // Dot indicator at very top
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(selectedPage == index ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPage)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 0)

            // Top bar with dismiss button and coin
            HStack {
                LargeIconButton(icon: "xmark", size: 48) {
                    dismiss()
                }
                Spacer()
                FlippingCoinView(size: 50, showYen: $showYen)
                    .offset(x: -4)
            }
            .padding(.horizontal)
            .padding(.top, -20)

            // Carousel header
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Text(pages[index])
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .opacity(selectedPage == index ? 1.0 : 0.3)
                            .frame(width: geometry.size.width)
                    }
                }
                .offset(x: -CGFloat(selectedPage) * geometry.size.width)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedPage)
            }
            .frame(height: 50)
            .padding(.horizontal)

            // Page content
            TabView(selection: $selectedPage) {
                BudgetContentView()
                    .tag(0)

                ExpenseListView()
                    .tag(1)

                ReportView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// Budget content extracted from BudgetView
struct BudgetContentView: View {
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]
    @AppStorage("includeTravelDays") private var includeTravelDays = false
    @AppStorage("showYen") private var showYen = true
    @AppStorage("debugDateOverrideTrigger") private var debugDateTrigger: Bool = false
    @State private var expandedCategories: Set<BudgetTracker.BudgetCategory> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Date subtitle with travel days toggle
                travelDaysToggle
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Total Budget Overview
                TotalBudgetBar(
                    expenses: expenses,
                    includeTravelDays: includeTravelDays,
                    showYen: showYen
                )
                .padding(.bottom, 20)

                // Budget Categories
                ForEach(BudgetTracker.BudgetCategory.allCases, id: \.self) { category in
                    BudgetCategoryCard(
                        category: category,
                        expenses: expenses,
                        includeTravelDays: includeTravelDays,
                        showYen: showYen,
                        isExpanded: Binding(
                            get: { expandedCategories.contains(category) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedCategories.insert(category)
                                } else {
                                    expandedCategories.remove(category)
                                }
                            }
                        )
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 8)
            .padding(.bottom)
        }
    }

    // MARK: - Travel Days Toggle

    private var travelDaysToggle: some View {
        HStack {
            Text(includeTravelDays ? "Nov 28-Dec 7" : "Dec 1-5")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.6))

            Spacer()

            // Custom slide toggle for travel days
            HStack(spacing: 0) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(includeTravelDays ? .secondary : .primary)
                    .opacity(includeTravelDays ? 0.5 : 1.0)
                    .frame(width: 32, height: 32)

                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(includeTravelDays ? .primary : .secondary)
                    .opacity(includeTravelDays ? 1.0 : 0.5)
                    .frame(width: 32, height: 32)
            }
            .background(
                GeometryReader { geo in
                    Circle()
                        .fill(.primary.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .offset(x: includeTravelDays ? geo.size.width / 2 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: includeTravelDays)
                }
            )
            .background(
                Capsule()
                    .fill(.primary.opacity(0.05))
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    includeTravelDays.toggle()
                }
            }
        }
    }
}

#Preview {
    BudgetCarouselView()
        .modelContainer(for: Expense.self)
}
