//
//  PhayarSarUITests.swift
//  PhayarSarUITests
//
//  Created by Kyaw Zay Ya Lin Tun on 03/12/2023.
//

import XCTest

final class PhayarSarUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Tapping a prayer row pushes its detail screen.
    ///
    /// Covers the whole route: `HomeScreen` asks `AppNavigatorModel` to
    /// navigate, the navigator appends to the home tab's path, `AppTabView`'s
    /// `navigationDestination` hands the route to `RouteView`, and
    /// `PrayerDetailScreen` resolves the id back into a prayer.
    func testTappingPrayerRowPushesDetail() throws {
        let app = XCUIApplication()
        app.launch()

        let title = "ငါးပါးသီလ"
        let row = app.buttons.containing(.staticText, identifier: title).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "prayer row never appeared")
        row.tap()

        // The nav bar carries the prayer's title, so its presence proves the id
        // in the route resolved — a failed lookup would title the bar with the
        // not-found string instead.
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 5),
            "detail screen did not push"
        )
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "no back button")
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
