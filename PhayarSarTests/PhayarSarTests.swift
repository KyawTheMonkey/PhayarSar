//
//  PhayarSarTests.swift
//  PhayarSarTests
//
//  Created by Kyaw Zay Ya Lin Tun on 03/12/2023.
//

import EnvironmentKit
import XCTest
@testable import PhayarSar

@MainActor
final class AppNavigatorModelTests: XCTestCase {

    func testNavigatePushesOntoCurrentTabWithoutSwitching() {
        let navigator = AppNavigatorModel()
        navigator.selectedTab = .home

        navigator.navigate(to: .prayerDetail(prayerID: "Khandha"))

        // The rule for cross-module routes: the destination changes, the tab
        // does not.
        XCTAssertEqual(navigator.selectedTab, .home)
        XCTAssertEqual(navigator.paths[.home], [.prayerDetail(prayerID: "Khandha")])
    }

    func testNavigateInTabSwitchesThenPushes() {
        let navigator = AppNavigatorModel()
        navigator.selectedTab = .home

        navigator.navigate(to: .prayerDetail(prayerID: "Khandha"), in: .plans)

        XCTAssertEqual(navigator.selectedTab, .plans)
        XCTAssertEqual(navigator.paths[.plans], [.prayerDetail(prayerID: "Khandha")])
        // The tab the user came from keeps its own stack untouched.
        XCTAssertNil(navigator.paths[.home])
    }

    func testStacksAreIndependentPerTab() {
        let navigator = AppNavigatorModel()

        navigator.navigate(to: .prayerDetail(prayerID: "a"), in: .home)
        navigator.navigate(to: .prayerDetail(prayerID: "b"), in: .settings)
        navigator.popToRoot(.settings)

        XCTAssertEqual(navigator.paths[.home], [.prayerDetail(prayerID: "a")])
        XCTAssertEqual(navigator.paths[.settings], [])
    }

    func testPopAtRootIsNoOp() {
        let navigator = AppNavigatorModel()
        navigator.selectedTab = .home

        navigator.pop()

        XCTAssertEqual(navigator.paths[.home] ?? [], [])
    }

    func testPathBindingReadsMissingTabAsEmpty() {
        let navigator = AppNavigatorModel()

        // Tabs are never pre-seeded, so the binding has to tolerate absence.
        XCTAssertEqual(navigator.path(for: .beads).wrappedValue, [])

        navigator.path(for: .beads).wrappedValue = [.prayerDetail(prayerID: "c")]
        XCTAssertEqual(navigator.paths[.beads], [.prayerDetail(prayerID: "c")])
    }

    func testRouteSurvivesRoundTripThroughCoding() throws {
        // Ids rather than model values are what make this possible — it is the
        // reason deep links and state restoration can carry a route later.
        let route = RouterDestination.prayerDetail(prayerID: "Khandha")
        let data = try JSONEncoder().encode(route)
        XCTAssertEqual(try JSONDecoder().decode(RouterDestination.self, from: data), route)
    }
}

final class PhayarSarTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
