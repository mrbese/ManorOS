import SwiftUI
import UIKit

struct ApplianceScanView: View {
    let onClassified: (ClassificationResult, UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = SharedCameraService()
    @State private var capturedImage: UIImage?
    @State private var classificationResults: [ClassificationResult] = []
    @State private var isClassifying = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCameraError = false

    var body: some View {
        ZStack {
            SharedCameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Guide text
                Text("Point camera at an appliance")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.manor.onPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.manor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 60)

                Spacer()

                if isClassifying {
                    ProgressView("Identifying...")
                        .tint(Color.manor.onPrimary)
                        .foregroundStyle(Color.manor.onPrimary)
                        .padding()
                        .background(Color.manor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                } else if !classificationResults.isEmpty, let image = capturedImage {
                    // Results chips
                    VStack(spacing: 12) {
                        Text("What is this?")
                            .font(.headline)
                            .foregroundStyle(Color.manor.onPrimary)

                        ForEach(classificationResults) { result in
                            Button {
                                onClassified(result, image)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: result.category.icon)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.category.rawValue)
                                            .font(.subheadline.bold())
                                        if result.confidence > 0 {
                                            Text("\(Int(result.confidence * 100))% confidence")
                                                .font(.caption)
                                                .opacity(0.7)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundStyle(Color.manor.onPrimary)
                                .padding(14)
                                .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Retake") {
                            capturedImage = nil
                            classificationResults = []
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Capture button (hidden when results showing)
                if classificationResults.isEmpty && !isClassifying {
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundStyle(Color.manor.onPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }

                        Spacer()

                        Button(action: captureAndClassify) {
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

                        Spacer()

                        // Balance spacer
                        Text("Cancel")
                            .foregroundStyle(.clear)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.cameraUnavailable) { _, unavailable in
            if unavailable {
                showCameraError = true
            }
        }
        .alert("Could not identify appliance", isPresented: $showError) {
            Button("Try Again") {
                capturedImage = nil
                classificationResults = []
            }
            Button("Add Manually") { dismiss() }
        } message: {
            Text("Try a different angle or add the appliance manually.")
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

    private func captureAndClassify() {
        camera.capturePhoto { image in
            guard let image else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = "Failed to capture photo. Please try again."
                showError = true
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            capturedImage = image
            isClassifying = true

            Task {
                let results = await ApplianceClassificationService.classify(image: image, topK: 3)
                if results.isEmpty {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = "Could not identify this appliance. Try a different angle or add it manually."
                    showError = true
                    isClassifying = false
                } else {
                    classificationResults = results
                    isClassifying = false
                }
            }
        }
    }
}

