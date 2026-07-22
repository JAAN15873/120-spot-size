import AVFoundation
import SwiftUI

/// Drives the back ultra-wide camera and reports the field of view Apple's driver claims for the
/// active format. This is a spec number, not a measured one — `CalibrationStore` holds the
/// correction factor that turns it into something field-accurate.
final class CameraController: NSObject, ObservableObject {

    enum Status {
        case notStarted, running, permissionDenied, deviceUnavailable
    }

    let session = AVCaptureSession()

    /// Horizontal field of view of the active format, in degrees, as reported by AVFoundation.
    @Published private(set) var reportedFovDegrees: Double?
    @Published private(set) var status: Status = .notStarted

    private let sessionQueue = DispatchQueue(label: "com.ecs.fovcheck.session")
    private var device: AVCaptureDevice?

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if granted {
                self.sessionQueue.async { self.configureAndStart() }
            } else {
                DispatchQueue.main.async { self.status = .permissionDenied }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func configureAndStart() {
        guard let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        else {
            DispatchQueue.main.async { self.status = .deviceUnavailable }
            return
        }
        self.device = device

        // Ultra-wide sensors are physically fisheye-like; without correction the image (and the
        // simple tan()-based rectilinear overlay math we use) would not match what's on screen.
        if device.activeFormat.isGeometricDistortionCorrectionSupported {
            do {
                try device.lockForConfiguration()
                device.isGeometricDistortionCorrectionEnabled = true
                device.unlockForConfiguration()
            } catch {
                // Non-fatal: overlay will just be less accurate until this is investigated.
            }
        }

        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = .deviceUnavailable }
            return
        }

        session.commitConfiguration()

        let fov = Double(device.activeFormat.videoFieldOfView)
        session.startRunning()

        DispatchQueue.main.async {
            self.reportedFovDegrees = fov
            self.status = .running
        }
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

/// SwiftUI wrapper around the AVCaptureVideoPreviewLayer.
struct CameraPreviewView: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer = controller.makePreviewLayer()
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let previewLayer {
                    previewLayer.frame = bounds
                    layer.addSublayer(previewLayer)
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
