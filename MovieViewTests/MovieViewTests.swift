//
//  MovieViewTests.swift
//  MovieViewTests
//
//  Created by Francois on 11/01/2025.
//

import XCTest
import AVFoundation
import Foundation
import AVKit
import UniformTypeIdentifiers
import AppKit

@testable import MovieView

final class MovieViewTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testMovieFileInitialization() {
        let testURL = URL(fileURLWithPath: "/Volumes/Ext-Photos4/TestDrone/DJI_0003.MP4")
        let movieFile = MovieFile(url: testURL)
        
        XCTAssertEqual(movieFile.name, "DJI_0003.MP4")
        XCTAssertEqual(movieFile.url, testURL)
        XCTAssertEqual(movieFile.relativePath, "")
        XCTAssertNil(movieFile.thumbnail)
    }
    
    func testMovieFileEquality() {
        let url1 = URL(fileURLWithPath: "/Volumes/Ext-Photos4/TestDrone/DJI_0003.MP4")
        let url2 = URL(fileURLWithPath: "/Volumes/Ext-Photos4/TestDrone/DJI_0635.MP4")
        
        let file1 = MovieFile(url: url1)
        let file2 = MovieFile(url: url2)
        
        XCTAssertNotEqual(file1, file2) // Should be different due to UUID
    }
    
    func testDensityConfigValues() {
        XCTAssertEqual(DensityConfig.xxl.factor, 0.25)
        XCTAssertEqual(DensityConfig.xl.factor, 0.5)
        XCTAssertEqual(DensityConfig.l.factor, 0.75)
        XCTAssertEqual(DensityConfig.m.factor, 1.0)
        XCTAssertEqual(DensityConfig.s.factor, 2.0)
        XCTAssertEqual(DensityConfig.xs.factor, 3.0)
        XCTAssertEqual(DensityConfig.xxs.factor, 4.0)
    }
    
    func testVideoThumbnailInitialization() {
        let image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)!
        let timestamp = CMTime(seconds: 65, preferredTimescale: 600)
        let url = URL(fileURLWithPath: "/Volumes/Ext-Photos4/TestDrone/DJI_0003.MP4")
        
        let thumbnail = VideoThumbnail(image: image, timestamp: timestamp, videoURL: url)
        
        XCTAssertEqual(thumbnail.displayTime, "01:05")
        XCTAssertEqual(thumbnail.videoURL, url)
        XCTAssertEqual(thumbnail.timestamp, timestamp)
    }
    
    // MARK: - VideoProcessor Tests
    
    var videoProcessor: VideoProcessor!
    
    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            videoProcessor = VideoProcessor()
        }
    }
    
    override func tearDown() {
        videoProcessor = nil
        super.tearDown()
    }
    
    func testCalculateThumbnailCount() async throws {
        // Test private method through its effects
        let shortDuration = 4.0 // Less than 5 seconds
        await videoProcessor.calculateExpectedThumbnails()
        await MainActor.run {
            XCTAssertEqual(videoProcessor.expectedThumbnailCount, 0) // Without a video URL
            
            // Test density changes
            videoProcessor.density = .xxl
            XCTAssertEqual(videoProcessor.density.factor, 0.25)
            
            videoProcessor.density = .m
            XCTAssertEqual(videoProcessor.density.factor, 1.0)
        }
    }
    
    func testCancelProcessing() async throws {
        await MainActor.run {
            videoProcessor.isProcessing = true
            videoProcessor.cancelProcessing()
            XCTAssertFalse(videoProcessor.isProcessing)
        }
    }
    
    // MARK: - ViewState Tests
    
    func testViewStateEnumCases() {
        let emptyState = ViewState.empty
        let folderState = ViewState.folder
        let processingState = ViewState.processing
        
        XCTAssertNotEqual(emptyState, folderState)
        XCTAssertNotEqual(folderState, processingState)
        XCTAssertNotEqual(emptyState, processingState)
    }
}
