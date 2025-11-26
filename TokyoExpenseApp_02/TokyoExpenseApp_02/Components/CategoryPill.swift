//
//  CategoryPill.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/16/25.
//

import SwiftUI

/// Pill-shaped button for category selection
/// Selected state: dark background with white/light text
/// Unselected state: light gray background with dark text (adapts to dark mode)
struct CategoryPill: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? AppTheme.SemanticColors.pillSelectedForeground : AppTheme.SemanticColors.pillForeground)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.SemanticColors.pillForeground : AppTheme.SemanticColors.pillBackground)
                )
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        CategoryPill(text: "Food", isSelected: true) {
            print("Food selected")
        }

        CategoryPill(text: "Transport", isSelected: false) {
            print("Transport selected")
        }

        CategoryPill(text: "Other", isSelected: false) {
            print("Other selected")
        }
    }
    .padding()
}
