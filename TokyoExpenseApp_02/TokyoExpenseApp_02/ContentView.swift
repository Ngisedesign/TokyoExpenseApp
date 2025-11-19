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
    @State private var angle: Double = 0
    @Binding var showYen: Bool

    let size: CGFloat

    init(size: CGFloat = 90, showYen: Binding<Bool>) {
        self.size = size
        self._showYen = showYen
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
    }
}

struct ContentView: View {
    @State private var isPresentingAdd: Bool = false
    @State private var showQuickCamera: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var showBudgetView: Bool = false
    @State private var showYen: Bool = true
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .forward) private var expenses: [Expense]

    // Food calculations
    private var foodSpentToday: Decimal {
        BudgetTracker.spentToday(.perDiem, from: expenses)
    }

    private var foodRollover: Decimal {
        BudgetTracker.rolloverFromPreviousDays(.perDiem, from: expenses)
    }

    private var foodTotalSpent: Decimal {
        BudgetTracker.spentByCategory(.perDiem, from: expenses, includeTravelDays: false)
    }

    private var foodRemainingTotal: Decimal {
        BudgetTracker.perDiemBudget - foodTotalSpent
    }

    // Transport calculations
    private var transportSpentToday: Decimal {
        BudgetTracker.spentToday(.transport, from: expenses)
    }

    private var transportRollover: Decimal {
        BudgetTracker.rolloverFromPreviousDays(.transport, from: expenses)
    }

    private var transportTotalSpent: Decimal {
        BudgetTracker.spentByCategory(.transport, from: expenses, includeTravelDays: false)
    }

    private var transportRemainingTotal: Decimal {
        BudgetTracker.transportBudget - transportTotalSpent
    }

    // Format amount based on currency toggle
    private func formatAmount(_ amount: Decimal) -> String {
        if showYen {
            let yenAmount = amount * 150
            return "¥\(yenAmount.intValue)"
        } else {
            return "$\(amount.intValue)"
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                LargeIconButton(icon: "line.3.horizontal", size: 48) {
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
                        Text("\(formatAmount(foodSpentToday)) of \(formatAmount(BudgetTracker.perDiemDaily))")
                        if foodRollover > 0 {
                            Text("+\(formatAmount(foodRollover).dropFirst())")
                                .foregroundStyle(Color(hue: 0.33, saturation: 0.70, brightness: 0.55))
                        } else if foodRollover < 0 {
                            Text(formatAmount(foodRollover))
                                .foregroundStyle(Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                        }
                    }
                    Spacer()
                    // Total remaining budget
                    Text(formatAmount(foodRemainingTotal))
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
                        Text("\(formatAmount(transportSpentToday)) of \(formatAmount(BudgetTracker.transportDaily))")
                        if transportRollover > 0 {
                            Text("+\(formatAmount(transportRollover).dropFirst())")
                                .foregroundStyle(Color(hue: 0.33, saturation: 0.70, brightness: 0.55))
                        } else if transportRollover < 0 {
                            Text(formatAmount(transportRollover))
                                .foregroundStyle(Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                        }
                    }
                    Spacer()
                    // Total remaining budget
                    Text(formatAmount(transportRemainingTotal))
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
                    showQuickCamera = true
                }
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .fullScreenCover(isPresented: $isPresentingAdd) {
            AddEntryView()
        }
        .fullScreenCover(isPresented: $showBudgetView) {
            BudgetView()
        }
        .sheet(isPresented: $showQuickCamera) {
            QuickCameraView(capturedImage: $capturedImage)
        }
        .onChange(of: capturedImage) { oldValue, newValue in
            if let image = newValue {
                Task {
                    await processQuickCapture(image)
                }
            }
        }
    }

    private func processQuickCapture(_ image: UIImage) async {
        // Run OCR
        let ocrResult = await OCRService.shared.recognizeText(in: image)

        // Parse receipt
        var parsedReceipt: ParsedReceipt?
        if #available(iOS 26.0, *) {
            parsedReceipt = try? await HybridParser.shared.parseReceipt(
                from: ocrResult.textElements,
                confidence: ocrResult.confidence
            )
        }

        // Fallback to spatial if needed
        if parsedReceipt == nil {
            parsedReceipt = SpatialReceiptParser.shared.parseReceipt(
                from: ocrResult.textElements,
                confidence: ocrResult.confidence
            )
        }

        // Save image
        guard let imagePath = ImageManager.shared.saveImage(image) else { return }

        // Create expense
        let amountJPY = parsedReceipt?.totalAmountYen ?? Decimal(0)
        let exchangeRate: Decimal = 150
        let expenseDate = parsedReceipt?.date ?? Date()
        let expense = Expense(
            date: expenseDate,
            category: parsedReceipt?.category ?? "Other",
            merchantName: parsedReceipt?.merchantName ?? "Quick Capture",
            expenseDescription: "",
            amountJPY: amountJPY,
            amountUSD: amountJPY / exchangeRate,
            exchangeRate: exchangeRate,
            receiptImagePaths: [imagePath],
            isWorkDay: BudgetTracker.isWorkDay(expenseDate),
            isManualEntry: false,
            ocrConfidence: parsedReceipt?.confidence
        )

        await MainActor.run {
            modelContext.insert(expense)
            try? modelContext.save()
            capturedImage = nil // Reset
        }
    }
}

#Preview {
    ContentView()
}
