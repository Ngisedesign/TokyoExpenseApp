import SwiftUI
import PhotosUI

struct AddEntryView: View {
    @Environment(\.dismiss) var dismiss

    @State private var merchant: String = ""
    @State private var date: Date = .now
    @State private var amountYen: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageUI: UIImage? = nil
    @State private var showCamera: Bool = false
    @State private var category: ExpenseCategory = .food

    enum ExpenseCategory: String, CaseIterable {
        case food = "Food"
        case transport = "Transport"
        case shopping = "Shopping"
        case other = "Other"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with dismiss and save
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                }
                Spacer()
                Button {
                    // Save expense
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(canSave ? .black : .secondary)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Receipt Image / Camera Section
                    if let image = selectedImageUI {
                        // Show captured image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(.black.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .onTapGesture {
                                showCamera = true
                            }
                    } else {
                        // Camera placeholder - big and bold
                        Button {
                            showCamera = true
                        } label: {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 64, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.15))

                                Text("Tap to scan receipt")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.black.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                                    .foregroundStyle(.black.opacity(0.1))
                            )
                        }
                    }

                    // Category Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.headline)
                            .foregroundStyle(.black)

                        HStack(spacing: 12) {
                            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    Text(cat.rawValue)
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(category == cat ? .white : .black)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(category == cat ? .black : .black.opacity(0.05))
                                        )
                                }
                            }
                        }
                    }

                    // Merchant Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant")
                            .font(.headline)
                            .foregroundStyle(.black)

                        TextField("Where did you spend?", text: $merchant)
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.black.opacity(0.03))
                            )
                    }

                    // Amount in Yen
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.headline)
                            .foregroundStyle(.black)

                        HStack(spacing: 8) {
                            Text("¥")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black)

                            TextField("0", text: $amountYen)
                                .font(.system(size: 32, weight: .bold))
                                .keyboardType(.numberPad)
                                .foregroundStyle(.black)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.black.opacity(0.03))
                        )

                        Text("Exchange rate: ¥150 = $1 USD")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.headline)
                            .foregroundStyle(.black)

                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(.vertical, 8)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(selectedImage: $selectedImageUI)
        }
        .photosPicker(isPresented: .constant(false), selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { newItem in
            Task {
                await loadImage(from: newItem)
            }
        }
    }

    var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amountYen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else {
            selectedImageUI = nil
            return
        }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    selectedImageUI = uiImage
                }
            }
        } catch {
            await MainActor.run {
                selectedImageUI = nil
            }
        }
    }
}

// Camera picker view (placeholder for now - will integrate AVFoundation camera later)
private struct CameraPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
            .padding()

            Spacer()

            // Camera icon placeholder
            VStack(spacing: 24) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(.black.opacity(0.15))

                Text("Camera coming soon")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text("For now, choose from photos")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Photo picker button
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 24, weight: .bold))
                    Text("Choose Photo")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.black)
                )
            }
            .padding()
            .onChange(of: selectedItem) { newItem in
                Task {
                    await loadImage(from: newItem)
                    dismiss()
                }
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = uiImage
                }
            }
        } catch {
            // Handle error silently for now
        }
    }
}

#Preview {
    AddEntryView()
}
