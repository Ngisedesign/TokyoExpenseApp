import SwiftUI
import UIKit

struct QuickCameraView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var capturedImage: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        VStack {
            HStack {
                LargeIconButton(icon: "xmark") {
                    dismiss()
                }
                Spacer()
            }
            .padding()

            Spacer()

            Button {
                showImagePicker = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(.black.opacity(0.3))

                    Text("Tap to capture receipt")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerController(image: $capturedImage, sourceType: .camera)
                .onDisappear {
                    if capturedImage != nil {
                        dismiss()
                    }
                }
        }
    }
}

// UIImagePickerController wrapper for camera
struct ImagePickerController: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController

        init(_ parent: ImagePickerController) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}
