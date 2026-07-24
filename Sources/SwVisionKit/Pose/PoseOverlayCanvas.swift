import SwiftUI

public struct PoseOverlayCanvas: View {
    let pose: PoseObservation?

    public init(pose: PoseObservation?) {
        self.pose = pose
    }

    // 18 limb pairs that define the stick-figure skeleton
    static let limbConnections: [(BodyJoint, BodyJoint)] = [
        // Head
        (.neck, .nose),
        (.nose, .leftEye),
        (.nose, .rightEye),
        (.leftEye, .leftEar),
        (.rightEye, .rightEar),
        // Spine
        (.neck, .root),
        // Left arm
        (.neck, .leftShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        // Right arm
        (.neck, .rightShoulder),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        // Left leg
        (.root, .leftHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        // Right leg
        (.root, .rightHip),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
    ]

    public var body: some View {
        Canvas { context, size in
            guard let pose else { return }

            // Limbs (levers) drawn first so joints (frames) render on top
            for (a, b) in Self.limbConnections {
                guard let jA = pose.points[a], let jB = pose.points[b],
                      jA.confidence >= 0.3, jB.confidence >= 0.3 else { continue }
                let minConf = min(jA.confidence, jB.confidence)
                var path = Path()
                path.move(to: screenPoint(jA.location, in: size))
                path.addLine(to: screenPoint(jB.location, in: size))
                context.stroke(path, with: .color(overlayColor(minConf)), lineWidth: 3)
            }

            // Joints (frames)
            for (_, joint) in pose.points {
                guard joint.confidence >= 0.3 else { continue }
                let center = screenPoint(joint.location, in: size)
                let radius = CGFloat(5 + 4 * joint.confidence)
                let rect = CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(overlayColor(joint.confidence)))
            }
        }
        .allowsHitTesting(false)
    }

    // Vision: bottom-left origin, [0,1]. Rotation + mirror baked into the capture connection.
    private func screenPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
    }

    private func overlayColor(_ confidence: Double) -> Color {
        if confidence >= 0.7 { return .green }
        if confidence >= 0.5 { return .yellow }
        return .orange
    }
}
