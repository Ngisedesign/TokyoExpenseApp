//
//  LabeledField.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/16/25.
//

import SwiftUI

/// Container for form fields with consistent label styling
/// Used for Merchant, Amount, Date fields, etc.
struct LabeledField<Content: View>: View {
    let label: String
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        label: String,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)

            content()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        LabeledField(label: "Merchant") {
            TextField("Where did you spend?", text: .constant(""))
                .font(.title2)
                .fontWeight(.medium)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(0.03))
                )
        }

        LabeledField(label: "Amount") {
            HStack(spacing: 8) {
                Text("¥")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.black)

                TextField("0", text: .constant(""))
                    .font(.system(size: 32, weight: .bold))
                    .keyboardType(.numberPad)
                    .foregroundStyle(.black)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.03))
            )
        }
    }
    .padding()
}
