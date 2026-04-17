import XCTest
@testable import better_mac

/// The peek and expanded rects share a single width formula so the full
/// expansion inherits the peek's horizontal grow. These tests pin the math.
final class IslandHoverWidthTests: XCTestCase {
    private let playingWidth: CGFloat = 260
    private let notchWidth: CGFloat = 200
    private let widthDelta: CGFloat = 20

    func testWidthWithTrackIsPlayingPlusDelta() {
        let width = IslandWindowController.hoverWidth(
            hasTrack: true,
            playingWidth: playingWidth,
            notchWidth: notchWidth,
            widthDelta: widthDelta
        )
        XCTAssertEqual(width, playingWidth + widthDelta)
    }

    func testWidthWithoutTrackIsNotchPlusDelta() {
        let width = IslandWindowController.hoverWidth(
            hasTrack: false,
            playingWidth: playingWidth,
            notchWidth: notchWidth,
            widthDelta: widthDelta
        )
        XCTAssertEqual(width, notchWidth + widthDelta)
    }

    func testZeroDeltaReturnsBaseWidth() {
        let withTrack = IslandWindowController.hoverWidth(
            hasTrack: true,
            playingWidth: playingWidth,
            notchWidth: notchWidth,
            widthDelta: 0
        )
        XCTAssertEqual(withTrack, playingWidth)

        let withoutTrack = IslandWindowController.hoverWidth(
            hasTrack: false,
            playingWidth: playingWidth,
            notchWidth: notchWidth,
            widthDelta: 0
        )
        XCTAssertEqual(withoutTrack, notchWidth)
    }

    func testPlayingAndNotchWidthsStayIndependent() {
        // Flipping notch width must not affect the track-loaded path.
        let w1 = IslandWindowController.hoverWidth(
            hasTrack: true, playingWidth: playingWidth, notchWidth: 100, widthDelta: widthDelta
        )
        let w2 = IslandWindowController.hoverWidth(
            hasTrack: true, playingWidth: playingWidth, notchWidth: 300, widthDelta: widthDelta
        )
        XCTAssertEqual(w1, w2, "hasTrack=true must ignore notchWidth")
    }
}
