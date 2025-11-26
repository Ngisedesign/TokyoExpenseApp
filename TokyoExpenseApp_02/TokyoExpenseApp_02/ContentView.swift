//
//  ContentView.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/12/25.
//

import SwiftUI
import SwiftData
import Foundation

// Extension to hide views conditionally
extension View {
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.opacity(0)
        } else {
            self
        }
    }
}

extension Decimal {
    var intValue: Int { NSDecimalNumber(decimal: self).intValue }
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

struct MaskedTextImage: View {
    let text: String
    let imageName: String
    let font: Font
    let scrimOpacity: Double

    var body: some View {
        Text(text)
            .font(font)
            .bold()
            .kerning(-2)
            .overlay(
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(scrimOpacity))
                    .mask(
                        Text(text)
                            .font(font)
                            .bold()
                            .kerning(-2)
                    )
            )
            .accessibilityLabel(text)
    }
}

struct FlippingCoinView: View {
    @State private var angle: Double
    @Binding var showYen: Bool

    let size: CGFloat

    init(size: CGFloat = 90, showYen: Binding<Bool>) {
        self.size = size
        self._showYen = showYen
        // Initialize angle based on showYen value
        self._angle = State(initialValue: showYen.wrappedValue ? 0.0 : 180.0)
    }

    private var isFrontVisible: Bool {
        let normalized = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return normalized < 90 || normalized > 270
    }

    private var edgeFade: Double {
        let norm = (angle.truncatingRemainder(dividingBy: 180) + 180).truncatingRemainder(dividingBy: 180)
        let distance = abs(norm - 90)
        let t = min(max(distance / 90, 0), 1)
        return 0.2 + 0.8 * t
    }

    // Helper view for coin base with gradients
    private var coinBaseCircle: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(coinGradientOverlay)
            .overlay(coinStrokeBorder)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            .overlay(coinAngularGradient)
    }

    private var coinGradientOverlay: some View {
        Circle()
            .fill(
                LinearGradient(colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.06)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .blendMode(.overlay)
    }

    private var coinStrokeBorder: some View {
        Circle()
            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            .blur(radius: 0.5)
            .opacity(0.9)
    }

    private var coinAngularGradient: some View {
        Group {
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.25)
                        ]),
                        center: .center
                    ),
                    lineWidth: 1.0
                )
                .blendMode(.screen)
        }
        .opacity(edgeFade)
    }

    // Helper for currency symbol with shadow
    private func currencySymbol(name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white.opacity(0.95))
            .overlay(currencySymbolShadow(name: name))
    }

    private func currencySymbolShadow(name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.45))
            .blur(radius: 1.5)
            .offset(x: 0, y: 1)
            .mask(
                Image(systemName: name)
                    .font(.system(size: size * 0.45, weight: .bold))
            )
            .opacity(0.6)
    }

    private var coinFaceOverlay: some View {
        Group {
            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5)
            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 2)
                .blur(radius: 2)
                .opacity(0.6)
                .blendMode(.softLight)
        }
    }

    var body: some View {
        ZStack {
            // Front face: Yen
            ZStack {
                coinBaseCircle
                currencySymbol(name: "yensign")
            }
            .frame(width: size, height: size)
            .overlay(coinFaceOverlay)
            .hidden(!isFrontVisible)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))

            // Back face: Dollar
            ZStack {
                coinBaseCircle
                currencySymbol(name: "dollarsign")
            }
            .frame(width: size, height: size)
            .overlay(coinFaceOverlay)
            .hidden(isFrontVisible)
            .rotation3DEffect(.degrees(angle + 180), axis: (x: 0, y: 1, z: 0))
        }
        .background(
            RoundedRectangle(cornerRadius: size * 0.55, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.55, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .padding(8)
        .rotation3DEffect(.degrees(0), axis: (x: 0, y: 0, z: 0), perspective: 0.8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Toggle currency
            showYen.toggle()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.15)) {
                angle += 180
            }
        }
        .onChange(of: showYen) { oldValue, newValue in
            // Sync angle when showYen changes from outside
            let targetAngle: Double = newValue ? 0.0 : 180.0
            let currentNormalized = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)

            // Only animate if we're not already at the target
            if (newValue && !(currentNormalized < 90 || currentNormalized > 270)) ||
               (!newValue && (currentNormalized < 90 || currentNormalized > 270)) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.15)) {
                    angle = targetAngle
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var isPresentingAdd: Bool = false
    @State private var showQuickCamera: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var showBudgetView: Bool = false
    @State private var showDebugMenu: Bool = false
    @AppStorage("showYen") private var showYen: Bool = true
    @AppStorage("debugDateOverrideTrigger") private var debugDateTrigger: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]

    // Food calculations
    private var foodSpentToday: Decimal {
        _ = debugDateTrigger // Force recalculation when date override changes
        return BudgetTracker.spentToday(.perDiem, from: expenses)
    }

    private var foodRollover: Decimal {
        _ = debugDateTrigger // Force recalculation when date override changes
        return BudgetTracker.rolloverFromPreviousDays(.perDiem, from: expenses)
    }

    private var foodTotalSpent: Decimal {
        BudgetTracker.spentByCategory(.perDiem, from: expenses, includeTravelDays: false)
    }

    private var foodRemainingTotal: Decimal {
        BudgetTracker.perDiemBudget - foodTotalSpent
    }

    // Transport calculations
    private var transportSpentToday: Decimal {
        _ = debugDateTrigger // Force recalculation when date override changes
        return BudgetTracker.spentToday(.transport, from: expenses)
    }

    private var transportRollover: Decimal {
        _ = debugDateTrigger // Force recalculation when date override changes
        return BudgetTracker.rolloverFromPreviousDays(.transport, from: expenses)
    }

    private var transportTotalSpent: Decimal {
        BudgetTracker.spentByCategory(.transport, from: expenses, includeTravelDays: false)
    }

    private var transportRemainingTotal: Decimal {
        BudgetTracker.transportBudget - transportTotalSpent
    }


    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Custom button with simultaneous tap and long press
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.black)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 1.0)
                            .onEnded { _ in
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                showDebugMenu = true
                            }
                    )
                    .onTapGesture {
                        showBudgetView = true
                    }

                Spacer()
                LargeIconButton(icon: "plus", size: 48) {
                    isPresentingAdd = true
                }
            }
            .padding(.bottom, 0)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    FlippingCoinView(size: 90, showYen: $showYen)
                    Spacer()
                }
                .padding(.top, 8)
                .offset(y: 10)
                .padding(.bottom, 20)
                MaskedTextImage(text: "Food", imageName: "sushi", font: .system(size: 72, weight: .black), scrimOpacity: 0.3)
                HStack {
                    HStack(spacing: 6) {
                        Text("\(CurrencyFormatter.format(usd: foodSpentToday, showYen: showYen, includeDecimals: false)) of \(CurrencyFormatter.format(usd: BudgetTracker.perDiemDaily, showYen: showYen, includeDecimals: false))")
                        if foodRollover > 0 {
                            Text("+\(CurrencyFormatter.format(usd: foodRollover, showYen: showYen, includeDecimals: false).dropFirst())")
                                .foregroundStyle(Color(hue: 0.33, saturation: 0.70, brightness: 0.55))
                        } else if foodRollover < 0 {
                            Text(CurrencyFormatter.format(usd: foodRollover, showYen: showYen, includeDecimals: false))
                                .foregroundStyle(Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                        }
                    }
                    Spacer()
                    // Total remaining budget for Food
                    Text(CurrencyFormatter.format(usd: foodRemainingTotal, showYen: showYen, includeDecimals: false))
                        .foregroundStyle(foodRemainingTotal >= 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                        .padding(.trailing, 5)
                }
                .font(.title3)
                .padding(.bottom, 8)
                .padding(.leading, 6)
                .onTapGesture {
                    showBudgetView = true
                }

                MaskedTextImage(text: "Transport", imageName: "JRTrain", font: .system(size: 72, weight: .black), scrimOpacity: 0.3)
                HStack {
                    HStack(spacing: 6) {
                        Text("\(CurrencyFormatter.format(usd: transportSpentToday, showYen: showYen, includeDecimals: false)) of \(CurrencyFormatter.format(usd: BudgetTracker.transportDaily, showYen: showYen, includeDecimals: false))")
                        if transportRollover > 0 {
                            Text("+\(CurrencyFormatter.format(usd: transportRollover, showYen: showYen, includeDecimals: false).dropFirst())")
                                .foregroundStyle(Color(hue: 0.33, saturation: 0.70, brightness: 0.55))
                        } else if transportRollover < 0 {
                            Text(CurrencyFormatter.format(usd: transportRollover, showYen: showYen, includeDecimals: false))
                                .foregroundStyle(Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                        }
                    }
                    Spacer()
                    // Total remaining budget for Transport
                    Text(CurrencyFormatter.format(usd: transportRemainingTotal, showYen: showYen, includeDecimals: false))
                        .foregroundStyle(transportRemainingTotal >= 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                        .padding(.trailing, 5)
                }
                .font(.title3)
                .padding(.bottom, 8)
                .padding(.leading, 6)
                .onTapGesture {
                    showBudgetView = true
                }
            }
            Spacer()
            HStack {
                Spacer()
                LargeIconButton(icon: "camera", size: 48) {
                    // Open AddEntryView with camera auto-launch
                    showQuickCamera = true
                }
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .fullScreenCover(isPresented: $isPresentingAdd) {
            AddEntryView(selectedImageUI: capturedImage)
                .onDisappear {
                    capturedImage = nil
                }
        }
        .fullScreenCover(isPresented: $showBudgetView) {
            BudgetCarouselView()
        }
        .fullScreenCover(isPresented: $showQuickCamera) {
            QuickCameraView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showDebugMenu) {
            DebugMenuView()
        }
        .onChange(of: capturedImage) { oldValue, newValue in
            if newValue != nil {
                // Small delay to allow QuickCameraView to dismiss cleanly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPresentingAdd = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

