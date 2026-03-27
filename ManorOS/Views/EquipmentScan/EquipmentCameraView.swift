import SwiftUI
import UIKit

struct EquipmentCameraView: View {
    let equipmentType: EquipmentType
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = SharedCameraService()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            SharedCameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Guide text
                Text(equipmentType.cameraPrompt)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.manor.onPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 60)

                Spacer()

                // Guide box overlay
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.6), lineWidth: 2)
                        .frame(width: geo.size.width * 0.75,
                               height: geo.size.height * 0.35)
                        .overlay(
                            Text("Align label here")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                // Capture button
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundStyle(Color.manor.onPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }

                    Spacer()

                    Button(action: {
                        camera.capturePhoto { image in
                            if let image {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onCapture(image)
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                errorMessage = "Failed to capture photo. Please try again."
                                showError = true
                            }
                        }
                    }) {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.5), lineWidth: 3)
                                    .frame(width: 80, height: 80)
                            )
                    }
                    .accessibilityLabel("Capture photo")

                    Spacer()

                    // Placeholder for layout balance
                    Text("Cancel")
                        .foregroundStyle(.clear)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.cameraUnavailable) { _, unavailable in
            if unavailable {
                errorMessage = "Camera access is required. Please enable it in Settings, or enter details manually."
                showError = true
            }
        }
        .alert("Camera Unavailable", isPresented: $showError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            Button("Cancel") { dismiss() }
        } message: {
            Text(errorMessage)
        }
    }
}

