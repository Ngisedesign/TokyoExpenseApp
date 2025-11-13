//
//  ContentView.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/12/25.
//

import SwiftUI

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
    @State private var flipped = false
    @State private var angle: Double = 0

    let size: CGFloat

    init(size: CGFloat = 90) {
        self.size = size
    }

    var body: some View {
        ZStack {
            // Front face: Yen
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [.yellow.opacity(0.95), .orange.opacity(0.9)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Image(systemName: "yensign")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
            }
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5))
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 2)
                    .blur(radius: 2)
                    .opacity(0.6)
                    .blendMode(.softLight)
            )
            .opacity(flipped ? 0 : 1)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)

            // Back face: Dollar
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [.orange.opacity(0.95), .yellow.opacity(0.9)],
                                   startPoint: .bottomTrailing, endPoint: .topLeading)
                )
                Image(systemName: "dollarsign")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
            }
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5))
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 2)
                    .blur(radius: 2)
                    .opacity(0.6)
                    .blendMode(.softLight)
            )
            .opacity(flipped ? 1 : 0)
            .rotation3DEffect(.degrees(angle + 180), axis: (x: 0, y: 1, z: 0))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.15)) {
                flipped.toggle()
                angle += 180
            }
        }
        .sensoryFeedback(.selection, trigger: flipped)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.black)
            }
            .padding(.bottom, 0)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    FlippingCoinView(size: 90)
                    Spacer()
                }
                .padding(.top, 8)
                .offset(y: 10)
                .padding(.bottom, 20)
                MaskedTextImage(text: "Food", imageName: "sushi", font: .system(size: 72, weight: .black), scrimOpacity: 0.3)
                HStack {
                    HStack(spacing: 6) {
                        Text("0 out of 60")
                        Text("+22")
                            .foregroundStyle(Color(hue: 0.33, saturation: 0.70, brightness: 0.55))
                    }
                    Spacer()
                    // Total remaining for the trip
                    Text("1000")
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 5)
                }
                .font(.title3)
                .padding(.bottom, 8)
                .padding(.leading, 6)

                MaskedTextImage(text: "Transport", imageName: "JRTrain", font: .system(size: 72, weight: .black), scrimOpacity: 0.3)
                HStack {
                    HStack(spacing: 6) {
                        Text("0 out of 60")
                        Text("-15")
                            .foregroundStyle(Color(hue: 0.0, saturation: 0.75, brightness: 0.55))
                    }
                    Spacer()
                    // Total remaining for the trip
                    Text("1000")
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 5)
                }
                .font(.title3)
                .padding(.bottom, 8)
                .padding(.leading, 6)
            }
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "camera")
                    .font(.system(size: 48, weight: .bold))
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    ContentView()
}
