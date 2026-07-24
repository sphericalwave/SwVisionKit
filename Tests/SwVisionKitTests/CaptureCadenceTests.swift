import XCTest
import CoreMedia
@testable import SwVisionKit

final class CaptureCadenceTests: XCTestCase {
    func testFrameRateIs15() {
        XCTAssertEqual(CaptureCadence.frameRate, 15)
    }

    func testPresentationTimeAfterTwoSecondsAt15fps() {
        // 2 seconds * 15fps = 30 frames.
        let time = CaptureCadence.presentationTime(forFrame: 30)
        XCTAssertEqual(time.seconds, 2.0, accuracy: 0.0001)
    }

    func testFirstFrameIsZero() {
        let time = CaptureCadence.presentationTime(forFrame: 0)
        XCTAssertEqual(time.seconds, 0, accuracy: 0.0001)
    }

    func testConsecutiveFramesAreExactlyOneIntervalApart() {
        // Frame-count-based, not wall-clock, so spacing is exact regardless
        // of when the driving timer actually fired.
        let t0 = CaptureCadence.presentationTime(forFrame: 10)
        let t1 = CaptureCadence.presentationTime(forFrame: 11)
        let delta = CMTimeSubtract(t1, t0).seconds
        XCTAssertEqual(delta, 1.0 / Double(CaptureCadence.frameRate), accuracy: 0.0001)
    }
}
