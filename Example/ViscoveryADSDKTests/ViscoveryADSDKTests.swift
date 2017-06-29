//
//  Tests.swift
//  Tests
//
//  Created by boska on 28/04/2017.
//  Copyright © 2017 Viscovery All rights reserved.
//

import XCTest
import AVFoundation
import SWXMLHash

@testable import ViscoveryADSDK

class Tests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testBasicFunctions() {
    let player = AVPlayer(url: URL(string: "http://rmcdn.2mdn.net/Demo/html5/output.mp4")!)
    let manager = AdsManager(player: player, videoView: UIView())
    XCTAssertEqual(manager.videoUrlFromPlayer!, "http://rmcdn.2mdn.net/Demo/html5/output.mp4")
    
    manager.contentPlayer.replaceCurrentItem(with: nil)
    XCTAssertNil(manager.videoUrlFromPlayer)
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
  }
  func testAPIKey() {
    AdsManager.apiKey = "test_api_key"
    let player = AVPlayer(url: URL(string: "http://rmcdn.2mdn.net/Demo/html5/output.mp4")!)
    let _ = AdsManager(player: player, videoView: UIView())
    
    XCTAssertEqual(AdsManager.apiKey, "test_api_key")
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
  }
  func testTimeInterValConvert() {
    XCTAssertEqual("".toTimeInterval, 0)
    XCTAssertEqual("0:00:00".toTimeInterval, 0.0)
    XCTAssertEqual("00:00:00.000".toTimeInterval, 0.0)
    XCTAssertEqual("00:00:50.000".toTimeInterval, 50.0)
    XCTAssertEqual("00:00:50.050".toTimeInterval, 50.05)
    XCTAssertEqual("00:05:44.000".toTimeInterval, 344.0)
    XCTAssertEqual("01:00:00.000".toTimeInterval, 3600.0)
  }
  func testExtension() {
    XCTAssertEqual("100%".toPercent, CGFloat(1.0))
  }
  func testClamp() {
    XCTAssertEqual((0.0...50.0).clamp(-100), 0.0)
    XCTAssertEqual((0.0...50.0).clamp(100), 50.0)
    XCTAssertEqual((0.0...50.0).clamp(20), 20.0)
  }
  
  func testGetBundleVersion() {
    guard let version = Bundle.init(for: AdsManager.self).infoDictionary?["CFBundleShortVersionString"] as? String else {
      return
    }
    XCTAssertEqual(version, "1.2.3")
  }
}
