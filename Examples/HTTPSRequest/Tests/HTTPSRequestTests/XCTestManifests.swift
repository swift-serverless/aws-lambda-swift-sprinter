import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(HTTPSRequestTests.allTests),
        ]
    }
#endif
