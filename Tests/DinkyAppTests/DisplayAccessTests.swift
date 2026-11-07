import CoreGraphics
import DinkyConfig
import Testing
@testable import dinky

struct DisplayAccessTests {
    private let sill = Display(uuid: "sill", id: 2,
                               frame: CGRect(x: 1000, y: 0, width: 800, height: 600),
                               visibleArea: CGRect(x: 1000, y: 0, width: 800, height: 600),
                               isMain: false, spaces: [7, 8, 9], userSpaces: [7, 8], currentSpaceID: 7)

    @Test func excludedDisplayRejectsBothFramesAndSpaces() {
        let access = DisplayAccess(excluded: [sill])
        let main = CGRect(x: 20, y: 20, width: 500, height: 400)
        let virtual = CGRect(x: 1100, y: 20, width: 500, height: 400)
        #expect(access.allows(frame: main, space: 1))
        #expect(!access.allows(frame: virtual, space: 1), "a drag is excluded before its Space catches up")
        #expect(!access.allows(frame: main, space: 7), "hidden windows remain excluded by Space")
        #expect(!access.allows(frame: main, space: 9), "native fullscreen Spaces are excluded too")
        #expect(!access.allows(frame: virtual, space: 0), "a temporarily unknown Space cannot bypass the frame")
    }

    @Test func excludedSpaceSwitchesAreNeverPosted() {
        var posts = 0
        let switcher = SpaceSwitcher(currentSpace: { _ in 1 }, spaceIDs: { _ in [1, 2] },
                                    swipe: { _, _, _ in posts += 1; return true },
                                    pollAutomatically: false, canManage: { _ in false })
        #expect(!switcher.request(2, on: "sill"))
        #expect(posts == 0)
        #expect(!switcher.switching)
    }

    @Test func exclusionCancelsInFlightSwitchWithoutCallingItsArrival() {
        var allowed = true
        var posts = 0
        var landed = false
        let switcher = SpaceSwitcher(currentSpace: { _ in 2 }, spaceIDs: { _ in [1, 2, 3] },
                                    swipe: { _, _, _ in posts += 1; return true },
                                    pollAutomatically: false, canManage: { _ in allowed })
        #expect(switcher.request(3, on: "sill", landed: { landed = true }))
        allowed = false
        switcher.poll()
        #expect(posts == 1)
        #expect(!landed)
        #expect(!switcher.switching)
    }

    @Test func noExclusionsPreserveExistingBehavior() {
        #expect(DisplayAccess().allows(frame: sill.frame, space: 7))
    }

    @Test func movingBackToManagedDisplayAllowsManagementAgain() {
        let access = DisplayAccess(excluded: [sill])
        #expect(!access.allows(frame: CGRect(x: 1200, y: 30, width: 300, height: 200), space: 7))
        #expect(access.allows(frame: CGRect(x: 30, y: 30, width: 300, height: 200), space: 1))
    }

    @Test func boundKeysPassThroughWhenInputIsExcluded() throws {
        let engine = HotkeyEngine { _ in }
        engine.load(modes: Config.default.modes, sides: Config.default.modifiers)
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 18, keyDown: true))
        event.flags = .maskAlternate
        engine.acceptsInput = { true }
        #expect(engine.commands(for: event) == ["workspace 1"])
        engine.acceptsInput = { false }
        #expect(engine.commands(for: event) == nil)
        engine.acceptsInput = { true }
        #expect(engine.commands(for: event) == ["workspace 1"])
    }
}
