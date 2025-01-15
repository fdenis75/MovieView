//
//  MovieViewUITestsLaunchTests.swift
//  MovieViewUITests
//
//  Created by Francois on 11/01/2025.
//

import XCTest

final class MovieViewUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify initial UI elements
        XCTAssertTrue(app.staticTexts["Drop video files here"].exists)
        XCTAssertTrue(app.buttons["Density"].exists)
        
        // Take a screenshot of the initial state
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
