//
//  QuickCameraView.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/25/25.
//

import SwiftUI

struct QuickCameraView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var capturedImage: UIImage?
    @State private var tempImage: UIImage? = nil

    var body: some View {
        ImagePickerController(
            image: $tempImage,
            sourceType: .camera
        )
        .edgesIgnoringSafeArea(.all)
        .onChange(of: tempImage) { oldValue, newValue in
            if let image = newValue {
                capturedImage = image
                dismiss()
            }
        }
    }
}
