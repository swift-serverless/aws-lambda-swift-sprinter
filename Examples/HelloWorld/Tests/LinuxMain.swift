import XCTest

import HelloWorldTests

var tests = [XCTestCaseEntry]()
tests += HelloWorldTests.__allTests()

XCTMain(tests)
