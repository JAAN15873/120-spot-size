import Foundation
import Combine

/// Persists the field calibration correction. Apple's reported `videoFieldOfView` is a spec value;
/// the calibration flow measures a real object to find how far off that spec is on this specific
/// phone, and everything downstream (the overlay) multiplies angles by this factor.
final class CalibrationStore: ObservableObject {
    private static let key = "fovcheck.angleCorrectionFactor"
    private static let dateKey = "fovcheck.calibratedAt"

    @Published var correctionFactor: Double {
        didSet { UserDefaults.standard.set(correctionFactor, forKey: Self.key) }
    }

    @Published private(set) var calibratedAt: Date?

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.key) as? Double
        self.correctionFactor = stored ?? 1.0
        self.calibratedAt = UserDefaults.standard.object(forKey: Self.dateKey) as? Date
    }

    func recordCalibration(factor: Double) {
        correctionFactor = factor
        let now = Date()
        calibratedAt = now
        UserDefaults.standard.set(now, forKey: Self.dateKey)
    }

    func reset() {
        recordCalibration(factor: 1.0)
        UserDefaults.standard.removeObject(forKey: Self.dateKey)
        calibratedAt = nil
    }
}
