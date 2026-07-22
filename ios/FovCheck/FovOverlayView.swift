import SwiftUI

/// Rectilinear (tan-based) mapping between "angle from the optical axis" and "fraction of half-screen
/// width". This is correct for a geometrically-distortion-corrected capture (see CameraController),
/// which is why that correction is forced on before any of this math is trusted.
enum FovGeometry {
    /// Signed: positive angles land right of center, negative left (tan is an odd function, so the
    /// sign carries through naturally). Used both for the +/- cone edges and for the 30° gridlines.
    static func screenFraction(forAngleDeg angleDeg: Double, reportedFovDeg: Double, correctionFactor: Double) -> Double {
        guard reportedFovDeg > 0, correctionFactor > 0 else { return 0 }
        let reportedHalfFovRad = (reportedFovDeg / 2) * .pi / 180
        let targetRad = (angleDeg / correctionFactor) * .pi / 180
        let denom = tan(reportedHalfFovRad)
        guard denom != 0 else { return 0 }
        return tan(targetRad) / denom
    }

    static func angleDeg(atScreenFraction frac: Double, reportedFovDeg: Double, correctionFactor: Double) -> Double {
        guard reportedFovDeg > 0, correctionFactor > 0 else { return 0 }
        let reportedHalfFovRad = (reportedFovDeg / 2) * .pi / 180
        let rawAngleRad = atan(frac * tan(reportedHalfFovRad))
        return rawAngleRad * 180 / .pi * correctionFactor
    }
}

/// Draws the +/- (targetFullAngleDeg / 2) guide lines over the live camera preview, plus a readout
/// and an explicit warning when the requested angle doesn't fit inside the lens's actual FOV.
struct FovOverlayView: View {
    let reportedFovDeg: Double
    let correctionFactor: Double
    let targetFullAngleDeg: Double

    private var halfAngle: Double { targetFullAngleDeg / 2 }

    private var rawFraction: Double {
        FovGeometry.screenFraction(forAngleDeg: halfAngle, reportedFovDeg: reportedFovDeg, correctionFactor: correctionFactor)
    }

    private var offScreen: Bool { abs(rawFraction) > 1 }
    private var clampedFraction: Double { min(max(rawFraction, -1), 1) }

    private var visibleFullAngleDeg: Double {
        2 * FovGeometry.angleDeg(atScreenFraction: 1, reportedFovDeg: reportedFovDeg, correctionFactor: correctionFactor)
    }

    /// 30° reference gridlines (…-60, -30, 0, 30, 60…), only the ones that actually land on screen.
    private var gridLines: [(angle: Double, fraction: Double)] {
        stride(from: Double(-180), through: 180, by: 30).compactMap { angle in
            let frac = FovGeometry.screenFraction(forAngleDeg: angle, reportedFovDeg: reportedFovDeg, correctionFactor: correctionFactor)
            return abs(frac) <= 1 ? (angle, frac) : nil
        }
    }

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2
            let leftX = halfWidth - clampedFraction * halfWidth
            let rightX = halfWidth + clampedFraction * halfWidth

            ZStack {
                ForEach(gridLines, id: \.angle) { grid in
                    gridLine(atX: halfWidth + grid.fraction * halfWidth, angle: grid.angle, height: geo.size.height)
                }

                centerHorizontalLine(width: geo.size.width, y: geo.size.height / 2)

                guideLine(atX: leftX, height: geo.size.height)
                guideLine(atX: rightX, height: geo.size.height)

                VStack {
                    if offScreen {
                        warningBanner
                    }
                    Spacer()
                    readout
                }
                .padding()
            }
        }
        .allowsHitTesting(false)
    }

    private func guideLine(atX x: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.yellow)
            .frame(width: 2, height: height)
            .position(x: x, y: height / 2)
            .shadow(color: .black, radius: 1)
    }

    private func gridLine(atX x: CGFloat, angle: Double, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.green)
                .frame(width: 1, height: height)
            if angle != 0 {
                Text("\(Int(angle))°")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .position(x: x, y: height / 2)
    }

    private func centerHorizontalLine(width: CGFloat, y: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.8))
            .frame(width: width, height: 1)
            .position(x: width / 2, y: y)
    }

    private var warningBanner: some View {
        Text(String(format: "Target %.0f° exceeds this lens's FOV (visible ≈ %.1f° total). Object may extend past what's on screen.", targetFullAngleDeg, visibleFullAngleDeg))
            .font(.footnote)
            .padding(8)
            .background(Color.red.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(6)
    }

    private var readout: some View {
        HStack {
            Text(String(format: "Reported FOV: %.1f°", reportedFovDeg))
            Spacer()
            Text(String(format: "Correction: ×%.3f", correctionFactor))
        }
        .font(.caption)
        .padding(6)
        .background(Color.black.opacity(0.5))
        .foregroundColor(.white)
        .cornerRadius(6)
    }
}
