//
//  LargeIconButton.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/16/25.
//

import SwiftUI

/// Large, bold icon button used throughout the app for primary actions
/// Examples: X (dismiss), ✓ (save), + (add), ☰ (menu), 📷 (camera)
struct LargeIconButton: View {
    let icon: String
    let size: CGFloat
    let color: Color
    let action: () -> Void

    init(
        icon: String,
        size: CGFloat = 32,
        color: Color = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        LargeIconButton(icon: "xmark", size: 32) {
            print("Dismiss")
        }

        LargeIconButton(icon: "checkmark", size: 32) {
            print("Save")
        }

        LargeIconButton(icon: "plus", size: 48) {
            print("Add")
        }

        LargeIconButton(icon: "camera.fill", size: 24, color: .black.opacity(0.3)) {
            print("Camera")
        }
    }
    .padding()
}
