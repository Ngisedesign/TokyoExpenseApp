import SwiftUI
import SwiftData

/// Multi-segment progress bar showing food and transport spending
/// Displays remaining budget and category icons
struct TotalBudgetBar: View {
    let expenses: [Expense]
    let includeTravelDays: Bool
    let showYen: Bool

    private var foodSpent: Decimal {
        BudgetTracker.spentByCategory(.perDiem, from: expenses, includeTravelDays: includeTravelDays)
    }

    private var transportSpent: Decimal {
        BudgetTracker.spentByCategory(.transport, from: expenses, includeTravelDays: includeTravelDays)
    }

    private var flightSpent: Decimal {
        BudgetTracker.spentByCategory(.flight, from: expenses, includeTravelDays: includeTravelDays)
    }

    private var hotelSpent: Decimal {
        BudgetTracker.spentByCategory(.hotel, from: expenses, includeTravelDays: includeTravelDays)
    }

    private var total: Decimal {
        BudgetTracker.totalBudget
    }

    private var totalSpent: Decimal {
        BudgetTracker.totalSpent(from: expenses, includeTravelDays: includeTravelDays)
    }

    private var remaining: Decimal {
        max(0, total - totalSpent)
    }
    
    // Helper to enforce minimum width for any non-zero segment
    private func adjustedWidth(_ raw: CGFloat, hasAmount: Bool, minSegmentWidth: CGFloat) -> CGFloat {
        hasAmount ? max(raw, minSegmentWidth) : 0
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 44
            let minSegmentWidth: CGFloat = 6

            // Calculate budget amounts
            let foodBudget = BudgetTracker.BudgetCategory.perDiem.budget
            let transportBudget = BudgetTracker.BudgetCategory.transport.budget
            let flightBudget = BudgetTracker.BudgetCategory.flight.budget
            let hotelBudget = BudgetTracker.BudgetCategory.hotel.budget

            // Calculate overflow
            let foodOverflow = max(0, foodSpent - foodBudget)
            let transportOverflow = max(0, transportSpent - transportBudget)
            let flightOverflow = max(0, flightSpent - flightBudget)
            let hotelOverflow = max(0, hotelSpent - hotelBudget)

            let foodIsOver = foodSpent > foodBudget
            let transportIsOver = transportSpent > transportBudget
            let flightIsOver = flightSpent > flightBudget
            let hotelIsOver = hotelSpent > hotelBudget

            // Normal amounts (within budget)
            let foodNormalAmount = min(foodSpent, foodBudget)
            let transportNormalAmount = min(transportSpent, transportBudget)
            let flightNormalAmount = min(flightSpent, flightBudget)
            let hotelNormalAmount = min(hotelSpent, hotelBudget)

            // Raw widths as proportion of total budget
            let foodBudgetWidthRaw = width * CGFloat(Double(truncating: (foodNormalAmount / total) as NSNumber))
            let transportBudgetWidthRaw = width * CGFloat(Double(truncating: (transportNormalAmount / total) as NSNumber))
            let flightBudgetWidthRaw = width * CGFloat(Double(truncating: (flightNormalAmount / total) as NSNumber))
            let hotelBudgetWidthRaw = width * CGFloat(Double(truncating: (hotelNormalAmount / total) as NSNumber))

            let foodOverflowWidthRaw = width * CGFloat(Double(truncating: (foodOverflow / total) as NSNumber))
            let transportOverflowWidthRaw = width * CGFloat(Double(truncating: (transportOverflow / total) as NSNumber))
            let flightOverflowWidthRaw = width * CGFloat(Double(truncating: (flightOverflow / total) as NSNumber))
            let hotelOverflowWidthRaw = width * CGFloat(Double(truncating: (hotelOverflow / total) as NSNumber))

            // Enforce minimum width for any non-zero segment
            let foodBudgetWidth = adjustedWidth(foodBudgetWidthRaw, hasAmount: foodNormalAmount > 0, minSegmentWidth: minSegmentWidth)
            let foodOverflowWidth = adjustedWidth(foodOverflowWidthRaw, hasAmount: foodOverflow > 0, minSegmentWidth: minSegmentWidth)
            let transportBudgetWidth = adjustedWidth(transportBudgetWidthRaw, hasAmount: transportNormalAmount > 0, minSegmentWidth: minSegmentWidth)
            let transportOverflowWidth = adjustedWidth(transportOverflowWidthRaw, hasAmount: transportOverflow > 0, minSegmentWidth: minSegmentWidth)
            let flightBudgetWidth = adjustedWidth(flightBudgetWidthRaw, hasAmount: flightNormalAmount > 0, minSegmentWidth: minSegmentWidth)
            let flightOverflowWidth = adjustedWidth(flightOverflowWidthRaw, hasAmount: flightOverflow > 0, minSegmentWidth: minSegmentWidth)
            let hotelBudgetWidth = adjustedWidth(hotelBudgetWidthRaw, hasAmount: hotelNormalAmount > 0, minSegmentWidth: minSegmentWidth)
            let hotelOverflowWidth = adjustedWidth(hotelOverflowWidthRaw, hasAmount: hotelOverflow > 0, minSegmentWidth: minSegmentWidth)

            // Calculate offsets with adjusted widths
            let transportStart = foodBudgetWidth + foodOverflowWidth
            let transportOverflowStart = transportStart + transportBudgetWidth
            let flightStart = transportOverflowStart + transportOverflowWidth
            let flightOverflowStart = flightStart + flightBudgetWidth
            let hotelStart = flightOverflowStart + flightOverflowWidth
            let hotelOverflowStart = hotelStart + hotelBudgetWidth

            // Icon positions (center of normal portion only) with adjusted widths
            let foodCenterX = max(14, min(foodBudgetWidth / 2, width - 14))
            let transportCenterX = max(14, min(transportStart + transportBudgetWidth / 2, width - 14))
            let flightCenterX = max(14, min(flightStart + flightBudgetWidth / 2, width - 14))
            let hotelCenterX = max(14, min(hotelStart + hotelBudgetWidth / 2, width - 14))

            ZStack(alignment: .leading) {
                // Background bar (rounded container)
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(.primary.opacity(0.08))

                // Masked content: fills + icons
                Group {
                    // Inner fills with flat edges
                    ZStack(alignment: .leading) {
                        // Food budget portion (normal color)
                        Rectangle()
                            .fill(BudgetTracker.BudgetCategory.perDiem.color)
                            .frame(width: foodBudgetWidth)

                        // Food overflow portion (darker)
                        if foodIsOver {
                            Rectangle()
                                .fill(BudgetTracker.BudgetCategory.perDiem.color.opacity(0.5))
                                .frame(width: foodOverflowWidth)
                                .offset(x: foodBudgetWidth)
                        }

                        // Transport budget portion (normal color)
                        Rectangle()
                            .fill(BudgetTracker.BudgetCategory.transport.color)
                            .frame(width: transportBudgetWidth)
                            .offset(x: transportStart)

                        // Transport overflow portion (darker)
                        if transportIsOver {
                            Rectangle()
                                .fill(BudgetTracker.BudgetCategory.transport.color.opacity(0.5))
                                .frame(width: transportOverflowWidth)
                                .offset(x: transportOverflowStart)
                        }

                        // Flight budget portion (normal color)
                        Rectangle()
                            .fill(BudgetTracker.BudgetCategory.flight.color)
                            .frame(width: flightBudgetWidth)
                            .offset(x: flightStart)

                        // Flight overflow portion (darker)
                        if flightIsOver {
                            Rectangle()
                                .fill(BudgetTracker.BudgetCategory.flight.color.opacity(0.5))
                                .frame(width: flightOverflowWidth)
                                .offset(x: flightOverflowStart)
                        }

                        // Hotel budget portion (normal color)
                        Rectangle()
                            .fill(BudgetTracker.BudgetCategory.hotel.color)
                            .frame(width: hotelBudgetWidth)
                            .offset(x: hotelStart)

                        // Hotel overflow portion (darker)
                        if hotelIsOver {
                            Rectangle()
                                .fill(BudgetTracker.BudgetCategory.hotel.color.opacity(0.5))
                                .frame(width: hotelOverflowWidth)
                                .offset(x: hotelOverflowStart)
                        }
                    }

                    // Icons over segments (hide if too small)
                    if foodBudgetWidth > 24 {
                        Image(systemName: BudgetTracker.BudgetCategory.perDiem.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                            .position(x: foodCenterX, y: height / 2)
                    }
                    if transportBudgetWidth > 24 {
                        Image(systemName: BudgetTracker.BudgetCategory.transport.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                            .position(x: transportCenterX, y: height / 2)
                    }
                    if flightBudgetWidth > 24 {
                        Image(systemName: BudgetTracker.BudgetCategory.flight.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                            .position(x: flightCenterX, y: height / 2)
                    }
                    if hotelBudgetWidth > 24 {
                        Image(systemName: BudgetTracker.BudgetCategory.hotel.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                            .position(x: hotelCenterX, y: height / 2)
                    }
                }
                .compositingGroup()
            }
            .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
            .overlay(alignment: .trailing) {
                Text(CurrencyFormatter.format(usd: remaining, showYen: showYen, includeDecimals: false))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.trailing, 4)
            }
        }
        .frame(height: 44)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        TotalBudgetBar(
            expenses: [],
            includeTravelDays: false,
            showYen: false
        )

        TotalBudgetBar(
            expenses: [],
            includeTravelDays: true,
            showYen: true
        )
    }
    .modelContainer(for: Expense.self)
}
