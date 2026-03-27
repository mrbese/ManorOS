import SwiftUI
import PhotosUI
import UIKit

struct BillUploadView: View {
    let onResult: (ParsedBillResult, UIImage) -> Void
    let onManual: () -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = SharedCameraService()
    @State private var capturedImage: UIImage?
    @State private var parsedResult: ParsedBillResult?
    @State private var isProcessing = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCameraError = false

    var body: some View {
        ZStack {
            SharedCameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Guide
                Text("Point at your utility bill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.manor.onPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.manor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 60)

                Spacer()

                if isProcessing {
                    ProgressView("Parsing bill...")
                        .tint(Color.manor.onPrimary)
                        .foregroundStyle(Color.manor.onPrimary)
                        .padding()
                        .background(Color.manor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                } else if let result = parsedResult, let image = capturedImage {
                    parsedResultCard(result: result, image: image)
                }

                Spacer()

                // Buttons
                if !isProcessing && parsedResult == nil {
                    VStack(spacing: 16) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundStyle(Color.manor.onPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                VStack(spacing: 4) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                    Text("Library")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.white)
                                .frame(width: 60)
                            }

                            Button(action: captureAndParse) {
                                Circle()
                                    .fill(Color.manor.onPrimary)
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.5), lineWidth: 3)
                                            .frame(width: 80, height: 80)
                                    )
                            }
                            .accessibilityLabel("Capture photo")

                            Button(action: {
                                dismiss()
                                onManual()
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.title2)
                                    Text("Manual")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.white)
                                .frame(width: 60)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedImage = image
                    isProcessing = true
                    let result = await BillParsingService.parseBill(from: image)
                    parsedResult = result
                    isProcessing = false
                } else {
                    errorMessage = "Could not load the selected photo. Please try another image."
                    showError = true
                }
            }
        }
        .onChange(of: camera.cameraUnavailable) { _, unavailable in
            if unavailable {
                showCameraError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { dismiss() }
        } message: {
            Text(errorMessage)
        }
        .alert("Camera Unavailable", isPresented: $showCameraError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            Button("Cancel") { dismiss() }
        } message: {
            Text("Camera access is required. Please enable it in Settings, or enter details manually.")
        }
    }

    private func parsedResultCard(result: ParsedBillResult, image: UIImage) -> some View {
        VStack(spacing: 12) {
            Text("Bill Data")
                .font(.headline)
                .foregroundStyle(Color.manor.onPrimary)

            if let name = result.utilityName {
                infoRow(label: "Utility", value: name)
            }

            if let kwh = result.totalKWh {
                infoRow(label: "Usage", value: "\(Int(kwh)) kWh")
            }

            if let cost = result.totalCost {
                infoRow(label: "Total", value: String(format: "$%.2f", cost))
            }

            if let rate = result.ratePerKWh {
                infoRow(label: "Rate", value: String(format: "$%.3f/kWh", rate))
            }

            if let start = result.billingPeriodStart {
                let formatter = DateFormatter()
                let _ = (formatter.dateStyle = .medium)
                let endStr = result.billingPeriodEnd.map { formatter.string(from: $0) } ?? "—"
                infoRow(label: "Period", value: "\(formatter.string(from: start)) – \(endStr)")
            }

            if result.totalKWh == nil && result.totalCost == nil {
                Text("Could not parse bill details.\nYou can edit values in the next step.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Use This") {
                    onResult(result, image)
                    dismiss()
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.manor.onPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.manor.primary, in: Capsule())

                Button("Retake") {
                    capturedImage = nil
                    parsedResult = nil
                    selectedPhoto = nil
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .font(.subheadline)
        .padding(20)
        .background(Color.manor.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(Color.manor.onPrimary)
        }
    }

    private func captureAndParse() {
        camera.capturePhoto { image in
            guard let image else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = "Failed to capture photo. Please try again."
                showError = true
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            capturedImage = image
            isProcessing = true
            Task {
                let result = await BillParsingService.parseBill(from: image)
                parsedResult = result
                isProcessing = false
            }
        }
    }
}

