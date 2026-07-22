import Foundation

/// Same formula as `pyroSpotMm` / the spot-size table in skener_fov_120.html, kept in sync so
/// this app and the placement-planning tool always agree on a given distance/angle/mrad input.
enum SpotSizeMath {

    /// - Parameters:
    ///   - slantRangeM: straight-line distance from sensor to target (m)
    ///   - grazingDeg: angle between the line of sight and the target surface (90° = looking straight-on)
    ///   - mradResolution: sensor resolution in milliradians (distance:spot ratio expressed as mrad)
    /// - Returns: spot size in mm, or `nil` if the angle is too shallow (< 1°) for a meaningful spot (mirrors the HTML tool's `Infinity` case)
    static func spotSizeMm(slantRangeM: Double, grazingDeg: Double, mradResolution: Double) -> Double? {
        guard grazingDeg >= 1 else { return nil }
        let grazingRad = grazingDeg * .pi / 180
        return (mradResolution / 1000 * slantRangeM / sin(grazingRad)) * 1000
    }

    /// Angular width (degrees) subtended by an object of known width viewed face-on from a known distance.
    /// Used by the calibration flow to get a ground-truth angle to compare against the camera's reported FOV.
    static func subtendedAngleDeg(objectWidthM: Double, distanceM: Double) -> Double {
        2 * atan((objectWidthM / 2) / distanceM) * 180 / .pi
    }
}
