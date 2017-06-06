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
  func testVMAPParse() {
    guard let path = Bundle(for: type(of: self)).path(forResource: "Sample", ofType: "xml") else {
      XCTFail()
      return
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
      XCTFail()
      return
    }
    let vmap = SWXMLHash.parse(data)
    XCTAssertEqual(vmap["vmap:VMAP"]["vmap:AdBreak"].all.count, 4)
    
    let nonlinears = vmap["vmap:VMAP"]["vmap:AdBreak"].all.filter {
      let type: String = try! $0.value(ofAttribute: "breakType")
      return type == "nonlinear"
    }
    XCTAssertEqual(nonlinears.count, 2)
    AdsManager.apiKey = "test_api_key"
    let player = AVPlayer(url: URL(string: "http://rmcdn.2mdn.net/Demo/html5/output.mp4")!)
    let manager = AdsManager(player: player, videoView: UIView())
    XCTAssertNotNil(manager.createAdTimeObserver(with: nonlinears))
  }
  func testTimeInterValConvert() {
    XCTAssertEqual("".toTimeInterval, 0)
    XCTAssertEqual("00:00:00.000".toTimeInterval, 0.0)
    XCTAssertEqual("00:00:50.000".toTimeInterval, 50.0)
    XCTAssertEqual("00:00:50.050".toTimeInterval, 50.05)
    XCTAssertEqual("00:05:44.000".toTimeInterval, 344.0)
    XCTAssertEqual("01:00:00.000".toTimeInterval, 3600.0)
  }
  func testTimeObserver() {
    AdsManager.apiKey = "test_api_key"
    let player = AVPlayer(url: URL(string: "http://rmcdn.2mdn.net/Demo/html5/output.mp4")!)
    let manager = AdsManager(player: player, videoView: UIView())
    XCTAssertNil(manager.createAdTimeObserver(with: []))
  }
  func testPerformanceExample() {
    // This is an example of a performance test case.
    measure {
      // Put the code you want to measure the time of here.
    }
  }
  func testAdParameterToDictionary() {
    let adparameter = "position=bottom,pos_value=4,align=left,align_value=3,height=30"
    XCTAssertEqual(adparameter.toParameters, ["position":"bottom",
                                              "pos_value":"4",
                                              "align":"left",
                                              "align_value":"3",
                                              "height": "30"])
  }
  
  func testClamp() {
    XCTAssertEqual((0.0...50.0).clamp(-100), 0.0)
    XCTAssertEqual((0.0...50.0).clamp(100), 50.0)
    XCTAssertEqual((0.0...50.0).clamp(20), 20.0)
  }
}
