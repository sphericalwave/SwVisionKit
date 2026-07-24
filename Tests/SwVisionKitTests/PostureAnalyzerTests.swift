import XCTest
import CoreGraphics
@testable import SwVisionKit

final class PostureAnalyzerTests: XCTestCase {

    private func obs(_ pts: [BodyJoint: CGPoint], confidence: Double = 1) -> PoseObservation {
        PoseObservation(points: pts.mapValues { .init(location: $0, confidence: confidence) })
    }

    func testNilWhenNeckNotConfident() {
        let o = obs([.neck: CGPoint(x: 0.5, y: 0.8)], confidence: 0.1)
        XCTAssertNil(PostureAnalyzer.analyze(o))
    }

    func testUnknownClassWhenRootNotConfident() {
        let points: [BodyJoint: PoseObservation.Point] = [
            .neck: .init(location: CGPoint(x: 0.5, y: 0.8), confidence: 0.5),
            .root: .init(location: CGPoint(x: 0.5, y: 0.5), confidence: 0.1),
        ]
        let report = PostureAnalyzer.analyze(PoseObservation(points: points))
        XCTAssertEqual(report?.postureClass, .unknown)
        XCTAssertEqual(report?.spineAngle, 0)
    }

    func testInvertedWhenRootAboveNeck() {
        let o = obs([
            .neck: CGPoint(x: 0.5, y: 0.3),
            .root: CGPoint(x: 0.5, y: 0.6), // rootY > neckY + 0.1
        ])
        XCTAssertEqual(PostureAnalyzer.analyze(o)?.postureClass, .inverted)
    }

    func testSupineWhenAllJointsNearSameHeight() {
        let o = obs([
            .neck: CGPoint(x: 0.5, y: 0.5),
            .root: CGPoint(x: 0.4, y: 0.5),
            .leftHip: CGPoint(x: 0.45, y: 0.48),
            .rightHip: CGPoint(x: 0.55, y: 0.52),
        ])
        XCTAssertEqual(PostureAnalyzer.analyze(o)?.postureClass, .supine)
    }

    func testStandingWhenAnklesLow() {
        let o = obs([
            .neck: CGPoint(x: 0.5, y: 0.9),
            .root: CGPoint(x: 0.5, y: 0.5),
            .leftAnkle: CGPoint(x: 0.45, y: 0.05),
            .rightAnkle: CGPoint(x: 0.55, y: 0.05),
        ])
        XCTAssertEqual(PostureAnalyzer.analyze(o)?.postureClass, .standing)
    }

    func testSeatedWhenAnklesNotLow() {
        let o = obs([
            .neck: CGPoint(x: 0.5, y: 0.9),
            .root: CGPoint(x: 0.5, y: 0.5),
            .leftAnkle: CGPoint(x: 0.45, y: 0.6),
            .rightAnkle: CGPoint(x: 0.55, y: 0.6),
        ])
        XCTAssertEqual(PostureAnalyzer.analyze(o)?.postureClass, .seated)
    }

    func testSpineAngleSignMatchesLeanDirection() {
        // neck right of root → positive lean (matches TiltSpec's vertical convention).
        let o = obs([
            .neck: CGPoint(x: 0.6, y: 0.9),
            .root: CGPoint(x: 0.5, y: 0.5),
            .leftAnkle: CGPoint(x: 0.45, y: 0.05),
            .rightAnkle: CGPoint(x: 0.55, y: 0.05),
        ])
        let angle = PostureAnalyzer.analyze(o)?.spineAngle
        XCTAssertNotNil(angle)
        XCTAssertGreaterThan(angle!, 0)
    }

    func testHipTiltNilWhenEitherHipMissing() {
        let o = obs([
            .neck: CGPoint(x: 0.5, y: 0.9),
            .root: CGPoint(x: 0.5, y: 0.5),
            .leftHip: CGPoint(x: 0.45, y: 0.5),
        ])
        XCTAssertNil(PostureAnalyzer.analyze(o)?.hipTilt)
    }

    func testHipTiltSignMatchesHigherSide() {
        let o = obs([
            .neck: CGPoint(x: 0.5, y: 0.9),
            .root: CGPoint(x: 0.5, y: 0.5),
            .leftHip: CGPoint(x: 0.4, y: 0.5),
            .rightHip: CGPoint(x: 0.6, y: 0.6), // right hip higher
        ])
        let tilt = PostureAnalyzer.analyze(o)?.hipTilt
        XCTAssertNotNil(tilt)
        XCTAssertGreaterThan(tilt!, 0)
    }
}
