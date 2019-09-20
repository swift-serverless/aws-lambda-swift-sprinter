import XCTest

import HelloWorldTests

var tests = [XCTestCaseEntry]()
tests += HelloWorldTests.allTests()
XCTMain(tests)
