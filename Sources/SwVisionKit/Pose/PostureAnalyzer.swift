import CoreGraphics

public enum PostureAnalyzer {
    public static func analyze(_ pose: PoseObservation) -> PostureReport? {
        guard let neck = pose.points[.neck], neck.confidence > 0.3 else { return nil }

        let root = pose.points[.root].flatMap { $0.confidence > 0.3 ? $0 : nil }

        let spineAngle = root.map {
            tiltDeg(dx: neck.location.x - $0.location.x, dy: neck.location.y - $0.location.y)
        } ?? 0.0

        let postureClass = root.map {
            classify(pose: pose, neckY: neck.location.y, rootY: $0.location.y)
        } ?? .unknown

        return PostureReport(
            postureClass: postureClass,
            spineAngle: spineAngle,
            hipTilt: lateralTilt(pose.points[.leftHip], pose.points[.rightHip]),
            shoulderTilt: lateralTilt(pose.points[.leftShoulder], pose.points[.rightShoulder])
        )
    }

    // Angle of vector (dx, dy) from vertical. + = right lean, – = left lean.
    // Vision coords: y increases upward, so vertical = +dy direction.
    private static func tiltDeg(dx: CGFloat, dy: CGFloat) -> Double {
        atan2(Double(dx), Double(dy)) * 180 / .pi
    }

    // Angle of left→right joint line from horizontal. + = right joint higher, – = left higher.
    private static func lateralTilt(_ left: PoseObservation.Point?, _ right: PoseObservation.Point?) -> Double? {
        guard let l = left, let r = right, l.confidence > 0.3, r.confidence > 0.3 else { return nil }
        return atan2(Double(r.location.y - l.location.y), Double(r.location.x - l.location.x)) * 180 / Double.pi
    }

    private static func classify(
        pose: PoseObservation, neckY: CGFloat, rootY: CGFloat
    ) -> PostureReport.PostureClass {
        if rootY > neckY + 0.1 { return .inverted }

        let ys = pose.points.values.filter { $0.confidence > 0.3 }.map(\.location.y)
        if let lo = ys.min(), let hi = ys.max(), hi - lo < 0.25 { return .supine }

        let anklesLow = [pose.points[.leftAnkle], pose.points[.rightAnkle]]
            .compactMap { $0 }
            .contains { $0.confidence > 0.3 && $0.location.y < 0.3 }

        return anklesLow ? .standing : .seated
    }
}
