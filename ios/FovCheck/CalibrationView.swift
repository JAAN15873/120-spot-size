import SwiftUI

/// Field calibration: measure a real object's width and distance, drag two markers onto its edges
/// on the live preview, and derive a correction factor between Apple's spec FOV and reality.
/// This is what makes the overlay trustworthy at kiln-scale distances rather than resting on a
/// marketing spec sheet.
struct CalibrationView: View {
    @ObservedObject var cameraController: CameraController
    @ObservedObject var calibrationStore: CalibrationStore
    @Environment(\.dismiss) private var dismiss

    @State private var objectWidthText: String = "1.0"
    @State private var distanceText: String = "10.0"
    @State private var leftFraction: CGFloat = -0.3
    @State private var rightFraction: CGFloat = 0.3
    @State private var resultMessage: String?
    @State private var computedFactor: Double?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack {
                        CameraPreviewView(controller: cameraController)
                        marker(fraction: $leftFraction, in: geo.size, color: .cyan, label: "L")
                        marker(fraction: $rightFraction, in: geo.size, color: .orange, label: "R")
                    }
                }
                .frame(maxHeight: .infinity)

                Form {
                    Section("Reference object (measure with tape)") {
                        HStack {
                            Text("Width (m)")
                            TextField("width", text: $objectWidthText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Distance to it (m)")
                            TextField("distance", text: $distanceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Section {
                        Text("Stand facing the object. Drag the cyan (L) and orange (R) lines onto its left and right edges, then Compute.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let resultMessage {
                        Section("Result") {
                            Text(resultMessage)
                            if let computedFactor {
                                Button(String(format: "Save calibration (×%.3f)", computedFactor)) {
                                    calibrationStore.recordCalibration(factor: computedFactor)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            .navigationTitle("Calibrate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Compute") { compute() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func marker(fraction: Binding<CGFloat>, in size: CGSize, color: Color, label: String) -> some View {
        let x = size.width / 2 + fraction.wrappedValue * size.width / 2
        return ZStack {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: size.height)
            Text(label)
                .font(.caption).bold()
                .foregroundColor(.white)
                .padding(4)
                .background(color)
                .cornerRadius(4)
                .offset(y: -size.height / 2 + 24)
        }
        .position(x: x, y: size.height / 2)
        .gesture(
            DragGesture().onChanged { value in
                let newFraction = (value.location.x - size.width / 2) / (size.width / 2)
                fraction.wrappedValue = min(max(newFraction, -1), 1)
            }
        )
    }

    private func compute() {
        guard let width = Double(objectWidthText.replacingOccurrences(of: ",", with: ".")),
              let distance = Double(distanceText.replacingOccurrences(of: ",", with: ".")),
              width > 0, distance > 0,
              let reportedFov = cameraController.reportedFovDegrees else {
            resultMessage = "Enter a valid width and distance, and wait for the camera to report its FOV."
            computedFactor = nil
            return
        }

        let trueAngle = SpotSizeMath.subtendedAngleDeg(objectWidthM: width, distanceM: distance)
        let angleLeft = FovGeometry.angleDeg(atScreenFraction: Double(leftFraction), reportedFovDeg: reportedFov, correctionFactor: 1.0)
        let angleRight = FovGeometry.angleDeg(atScreenFraction: Double(rightFraction), reportedFovDeg: reportedFov, correctionFactor: 1.0)
        let predictedAngle = abs(angleRight - angleLeft)

        guard predictedAngle > 0.5 else {
            resultMessage = "Markers are too close together — spread them further apart on the object's edges."
            computedFactor = nil
            return
        }

        let factor = trueAngle / predictedAngle
        guard factor > 0.5, factor < 2.0 else {
            resultMessage = String(format: "Computed correction (×%.2f) is outside a plausible range — check the width/distance inputs and marker placement before saving.", factor)
            computedFactor = nil
            return
        }

        computedFactor = factor
        resultMessage = String(format: "True angle: %.1f°, camera-predicted: %.1f°. Correction factor: ×%.3f", trueAngle, predictedAngle, factor)
    }
}
