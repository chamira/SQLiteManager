//
//  SQLiteManagerXC.swift
//  SQLiteManager
//
//  Created by Chamira Fernando on 20/07/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//


import XCTest
import SQLiteManager

class SQLiteManagerXC: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
		var database:SQLiteManagerError = SQLiteManagerError(code: 1, userInfo: [kCFErrorLocalizedDescriptionKey:"test"])
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
