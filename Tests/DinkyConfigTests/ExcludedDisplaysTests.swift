import Testing
@testable import DinkyConfig

struct ExcludedDisplaysTests {
    private func display(_ name: String, main: Bool, spaces: [UInt64]) -> PlanDisplay {
        PlanDisplay(uuid: name, monitor: Monitor(name: name, isMain: main, count: 2),
                    spaces: spaces, current: spaces[0])
    }

    @Test func defaultsManageEveryDisplay() throws {
        let config = try Config.parse("")
        #expect(config.excludeDisplays.isEmpty)
        #expect(config.manages(Monitor(name: "Sill", isMain: false, count: 2)))
    }

    @Test func exclusionsUseExistingDisplayPatterns() throws {
        let config = try Config.parse("exclude-displays = ['sILL', 'secondary']")
        #expect(!config.manages(Monitor(name: "Virtual Sill Display", isMain: true, count: 3)))
        #expect(!config.manages(Monitor(name: "iPad", isMain: false, count: 2)))
        #expect(config.manages(Monitor(name: "iPad", isMain: false, count: 3)))
        #expect(config.manages(Monitor(name: "Ultrawide", isMain: true, count: 2)))
    }

    @Test(arguments: ["exclude-displays = ['']", "exclude-displays = ['   ']",
                      "exclude-displays = 'Sill'", "exclude-displays = [1]"])
    func malformedExclusionsAreRejected(_ toml: String) {
        #expect(throws: ConfigError.self) { try Config.parse(toml) }
    }

    @Test func excludedSpacesAreNeverBoundMovedOrRemoved() throws {
        let plan = WorkspacePlan(try Config.parse("workspaces = 2\nexclude-displays = ['Sill']"))
        let displays = [display("Main", main: true, spaces: [1, 2]),
                        display("Sill", main: false, spaces: [7, 8, 9])]
        let step = plan.step(displays, binding: [1: 7, 2: 8], occupied: [7, 8])
        #expect(step.binding == [1: 1, 2: 2])
        #expect(step.action == nil)
        #expect(plan.homes(displays) == [1: "Main", 2: "Main"])
    }

    @Test func assignmentsToExcludedDisplaysFallBackWithoutTouchingTheirSpaces() throws {
        let plan = WorkspacePlan(try Config.parse("""
        workspaces = 2
        exclude-displays = ['Sill']
        [workspace-to-display]
        2 = 'Sill'
        """))
        let displays = [display("Main", main: true, spaces: [1]),
                        display("Sill", main: false, spaces: [7, 8])]
        let step = plan.step(displays, binding: [1: 1, 2: 7], occupied: [7])
        #expect(step.binding == [1: 1])
        #expect(step.action == .create(display: "Main"))
    }

    @Test func excludingMainUsesFirstRemainingDisplay() throws {
        let plan = WorkspacePlan(try Config.parse("workspaces = 1\nexclude-displays = ['main']"))
        let displays = [display("Sill", main: true, spaces: [7, 8]),
                        display("Other", main: false, spaces: [1])]
        #expect(plan.homes(displays) == [1: "Other"])
        #expect(plan.step(displays, binding: [:], occupied: []).action == nil)
    }

    @Test func renumberingDropsExcludedBindingsWithoutMovingWindows() throws {
        let plan = WorkspacePlan(try Config.parse("workspaces = 2\nexclude-displays = ['Sill']"))
        let displays = [display("Main", main: true, spaces: [2, 1]),
                        display("Sill", main: false, spaces: [7, 8])]
        #expect(plan.renumbered(displays, binding: [1: 1, 2: 7]) == [1: 1])
    }

    @Test func allDisplaysExcludedDoesNothing() throws {
        let plan = WorkspacePlan(try Config.parse("exclude-displays = ['main', 'secondary']"))
        let displays = [display("Main", main: true, spaces: [1]),
                        display("Sill", main: false, spaces: [7, 8])]
        let step = plan.step(displays, binding: [1: 1, 2: 7], occupied: [1, 7])
        #expect(step.binding.isEmpty)
        #expect(step.action == nil)
    }

    @Test func removingExclusionAllowsWorkspaceAssignmentAgain() throws {
        let displays = [display("Main", main: true, spaces: [1]),
                        display("Sill", main: false, spaces: [7, 8])]
        let excluded = WorkspacePlan(try Config.parse("workspaces = 1\nexclude-displays = ['Sill']"))
        #expect(excluded.step(displays, binding: [1: 7], occupied: [7]).binding == [1: 1])
        let included = WorkspacePlan(try Config.parse("workspaces = 1\n[workspace-to-display]\n1 = 'Sill'"))
        let step = included.step(displays, binding: [:], occupied: [7])
        #expect(step.binding == [1: 7])
    }
}
