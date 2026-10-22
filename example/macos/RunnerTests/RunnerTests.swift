import Cocoa
import FlutterMacOS
import XCTest

@testable import xue_hua_navite_share

class RunnerTests: XCTestCase {

  func testGetCapabilities() {
    let plugin = XueHuaNaviteSharePlugin()
    let call = FlutterMethodCall(methodName: "getCapabilities", arguments: nil)

    let resultExpectation = expectation(description: "getCapabilities result block must be called.")
    plugin.handle(call) { result in
      let map = result as? [String: Any]
      XCTAssertEqual(map?["platform"] as? String, "macos")
      XCTAssertEqual(map?["supportsSystemShareSheet"] as? Bool, true)
      XCTAssertEqual(map?["supportsAnchorPopover"] as? Bool, true)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
