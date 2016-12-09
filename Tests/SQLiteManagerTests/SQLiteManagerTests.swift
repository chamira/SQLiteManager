import XCTest
@testable import SQLiteManager

class SQLiteManagerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(SQLiteManager().text, "Hello, World!")
    }


    static var allTests : [(String, (SQLiteManagerTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
