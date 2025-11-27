//
//  ImagePlaceholder.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/16/25.
//

import SwiftUI

/// Placeholder for image upload areas with dashed border
/// Shows icon and text prompt for user action
struct ImagePlaceholder: View {
    let icon: String
    let text: String
    let height: CGFloat
    let action: () -> Void

    init(
        icon: String,
        text: String,
        height: CGFloat = 280,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.text = text
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.secondary)

                Text(text)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                    .foregroundStyle(.primary.opacity(0.2))
            )
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ImagePlaceholder(
            icon: "photo.fill",
            text: "Add from library"
        ) {
            print("Add from library")
        }

        ImagePlaceholder(
            icon: "camera.fill",
            text: "Tap to scan receipt",
            height: 200
        ) {
            print("Scan receipt")
        }
    }
    .padding()
}
