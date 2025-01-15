//
//  MovieViewUITests.swift
//  MovieViewUITests
//
//  Created by Francois on 11/01/2025.
//

import XCTest

final class MovieViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testInitialState() throws {
        // Verify initial empty state
        XCTAssertTrue(app.staticTexts["Drop video files here"].exists)
        
        // Verify density picker exists
        XCTAssertTrue(app.buttons["Density"].exists)
    }
    
    func testDensityPicker() throws {
        // Open density picker
        app.buttons["Density"].tap()
        
        // Verify all density options exist
        let densities = ["XXL", "XL", "L", "M", "S", "XS", "XXS"]
        for density in densities {
            XCTAssertTrue(app.buttons[density].exists)
        }
        
        // Select a different density
        app.buttons["XL"].tap()
        
        // Verify the picker is dismissed
        XCTAssertFalse(app.buttons["XL"].exists)
    }
    
    func testNavigationElements() throws {
        // Test that main navigation elements are present
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }
    
    func testThumbnailGridLayout() throws {
        // Note: This test assumes there are thumbnails present
        // In a real test, you would need to first add a video file
        
        // Test grid view exists
        let gridView = app.scrollViews["ThumbnailGridView"]
        XCTAssertTrue(gridView.exists)
    }
    
    func testAccessibilityLabels() throws {
        // Test important accessibility labels are present
        XCTAssertTrue(app.buttons["Density"].exists)
        XCTAssertTrue(app.staticTexts["Drop video files here"].exists)
    }
    
    func testResponsivenessToUserInteraction() throws {
        // Test that the app responds to basic user interactions
        
        // Tap density button
        app.buttons["Density"].tap()
        
        // Verify density menu appears
        XCTAssertTrue(app.buttons["XXL"].exists)
        
        // Dismiss density menu
        app.buttons["XXL"].tap()
        
        // Verify menu is dismissed
        XCTAssertFalse(app.buttons["XXL"].exists)
    }
}
