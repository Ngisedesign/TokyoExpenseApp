//
//  CategoryPill.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/16/25.
//

import SwiftUI

/// Pill-shaped button for category selection
/// Selected state: black background with white text
/// Unselected state: light gray background with black text
struct CategoryPill: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? .black : .black.opacity(0.05))
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
