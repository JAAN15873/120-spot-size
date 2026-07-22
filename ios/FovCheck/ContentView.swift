import SwiftUI

struct ContentView: View {
    @StateObject private var cameraController = CameraController()
    @StateObject private var calibrationStore = CalibrationStore()

    @State private var targetAngle: Double = 120
    @State private var distanceText = "25"
    @State private var grazingText = "90"
    @State private var mradText = "3"
    @State private var showCalibration = false
    @State private var showSpotPanel = false

    private var spotSizeMm: Double? {
        guard let distance = Double(distanceText.replacingOccurrences(of: ",", with: ".")),
              let grazing = Double(grazingText.replacingOccurrences(of: ",", with: ".")),
              let mrad = Double(mradText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return SpotSizeMath.spotSizeMm(slantRangeM: distance, grazingDeg: grazing, mradResolution: mrad)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(controller: cameraController)
                .ignoresSafeArea()

            switch cameraController.status {
            case .running:
                if let fov = cameraController.reportedFovDegrees {
                    FovOverlayView(
                        reportedFovDeg: fov,
                        correctionFactor: calibrationStore.correctionFactor,
                        targetFullAngleDeg: targetAngle
                    )
                }
            case .notStarted:
                ProgressView("Starting camera…")
                    .tint(.white)
                    .foregroundColor(.white)
            case .permissionDenied:
                statusMessage("Camera access denied. Enable it in Settings > FovCheck.")
            case .deviceUnavailable:
                statusMessage("No usable back camera found on this device.")
            }

            VStack {
                Spacer()
                controlPanel
            }
        }
        .statusBarHidden(true)
        .onAppear { cameraController.start() }
        .onDisappear { cameraController.stop() }
        .sheet(isPresented: $showCalibration) {
            CalibrationView(cameraController: cameraController, calibrationStore: calibrationStore)
        }
    }

    private func statusMessage(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding()
    }

    private var controlPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Cone: \(Int(targetAngle))°")
                    .foregroundColor(.white)
                Slider(value: $targetAngle, in: 10...170, step: 1)
                Button {
                    showCalibration = true
                } label: {
                    Label(calibrationLabel, systemImage: "target")
                }
                .buttonStyle(.borderedProminent)
            }

            DisclosureGroup("Spot size calculator", isExpanded: $showSpotPanel) {
                HStack {
                    labeledField("Distance (m)", text: $distanceText)
                    labeledField("Grazing (°)", text: $grazingText)
                    labeledField("Sensor (mrad)", text: $mradText)
                }
                if let spotSizeMm {
                    Text(String(format: "Spot size: %.0f mm", spotSizeMm))
                        .foregroundColor(.yellow)
                        .font(.headline)
                } else {
                    Text("Angle too shallow (<1°) for a meaningful spot.")
                        .foregroundColor(.red)
                }
            }
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black.opacity(0.4))
    }

    private var calibrationLabel: String {
        calibrationStore.calibratedAt == nil ? "Calibrate" : String(format: "×%.2f", calibrationStore.correctionFactor)
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .foregroundColor(.black)
        }
    }
}
