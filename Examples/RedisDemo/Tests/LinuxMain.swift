import XCTest

import RedisDemoTests

var tests = [XCTestCaseEntry]()
tests += RedisDemoTests.allTests()
XCTMain(tests)
