//
//  SQLiteManager_TV_ExampleTests.swift
//  SQLiteManager_TV_ExampleTests
//
//  Created by Chamira Fernando on 22/09/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
import sqlite3
@testable import SQLiteManager

class SQLiteManager_TV_ExampleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
	func testCreateTable() {
		
		let dbName = "app_test_database_x_4"
		let ext = "db"
		
		let database = try! SQLitePool.manager().initialize(database: dbName, withExtension: ext, createIfNotExist: true)
		
		XCTAssertEqual(dbName+"."+ext, database.databaseName, "Database is not iinitialized correctly")
		
		
		do {
			let q = "CREATE TABLE IF NOT EXISTS COMPANY(ID INT PRIMARY KEY NOT NULL,NAME TEXT NOT NULL, AGE INT NOT NULL,ADDRESS CHAR(50), SALARY REAL)"
			let ret = try database.query(q)

			XCTAssertEqual(SQLITE_OK, ret.SQLiteSatusCode, "Table is not created successfully SQLStatusCode:\(ret.SQLiteSatusCode)")
		} catch let e as NSError {
			print(e)
			assertionFailure()
		}
		
		
	}
	
	func testHandingInvalidSQLStatementException() {
		
		let dbName = "app_test_database_1"
		let ext = "db"
		
		let databasesPool = SQLitePool.manager()
		let database = try! databasesPool.initialize(database:dbName, withExtension: ext)
		
		XCTAssertEqual(dbName+"."+ext, database.databaseName, "Database is not iinitialized correctly")
		
		XCTAssertThrowsError(try database.query("INSERT INTO 'company' (name) VALUES ('Home Company')"))
		XCTAssertThrowsError(try database.query("INSRT INTO 'tb_company' (name) VALUES ('Home Company')"))
		
	}
	
	func testSQLStatementsMainThread() {
		
		let dbName = "app_test_database_1"
		let ext = "db"
		
		let databasesPool = SQLitePool.manager()
		let database = try! databasesPool.initialize(database:dbName, withExtension: ext)
		
		let insert = {
			let result = try! database.query("INSERT INTO 'tb_company' (name) VALUES ('Home Company')")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		insert()
		
		let update = {
			let result = try! database.query("UPDATE 'tb_company' SET name = 'Making Waves AS' WHERE name = 'Home Company'")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		update()
		
		let selectCompany = {
			let result = try! database.query("SELECT pk_id, name FROM 'tb_company'")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			
			let r = result.results?.first
			
			XCTAssertNotNil(r, "Result MUST NOT be nil")
			XCTAssertEqual(r!["name"],sqlStr("Making Waves AS"))
			
			let count = try! database.query("SELECT count(*) as company_count FROM 'tb_company'")
			
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			
			let counter = count.results?.first
			
			XCTAssertNotNil(counter, "Result MUST NOT be nil")
			XCTAssertEqual(counter!["company_count"],NSNumber(value: 1))
		}
		
		selectCompany()
		
		let nullPick = {
			let result = try! database.query("SELECT name, logo_picture_url FROM 'tb_company'")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			
			let r = result.results?.first
			
			XCTAssertNotNil(r, "Result MUST NOT be nil")
			XCTAssertEqual(r!["name"],"Making Waves AS" as NSString)
			XCTAssertEqual(r!["logo_picture_url"],NSNull())
			
		}
		
		nullPick()
		
		let delete = {
			let result = try! database.query("DELETE FROM 'tb_company' WHERE name = 'Making Waves AS'")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		delete()
		
	}
	
	func testBindSQLStatementsMainThread() {
		
		let dbName = "app_test_database_1"
		let ext = "db"
		
		let databasesPool = SQLitePool.manager()
		let database = try! databasesPool.initialize(database:dbName, withExtension: ext)
		
		let insert = {
		 
			let dob = Date(timeIntervalSince1970: 3600*24*3650)
			let profilePic  = try! Data(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "chamira_fernando", ofType: "jpg")!))
			
			let vals = [sqlStr("Chameera"),sqlStr("Fernando"),sqlStr("some_user_name"), sqlNumber(dob.timeIntervalSince1970),sqlNumber(1),sqlData(profilePic)]
			let result = try! database.bindQuery("INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)",
			                                     bindValues: vals)
			
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		insert()
		
		let update = {
			let result = try! database.bindQuery("UPDATE 'tb_user' SET first_name = ?, last_name = ? WHERE first_name = ?", bindValues: [sqlStr("Chamira"),sqlStr("Fernando"),sqlStr("Chameera")])
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		update()
		
		let select = {
			let result = try! database.bindQuery("SELECT first_name, date_of_birth as dob from 'tb_user' where first_name=?", bindValues: [sqlStr("Chamira")])
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			
			let r = result.results?.first
			
			XCTAssertNotNil(r, "Result MUST NOT be nil")
			XCTAssertEqual(r!["first_name"]!,sqlStr("Chamira"))
			
		}
		
		select()
		
		let delete = {
			let result = try! database.bindQuery("DELETE FROM 'tb_user' WHERE first_name = ?",bindValues: [sqlStr("Chamira")])
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		delete()
		
	}
	
	func testSQLStatementsAsync() {
		
		let dbName = "app_test_database_1"
		let ext = "db"
		
		let databasesPool = SQLitePool.manager()
		let database = try! databasesPool.initialize(database:dbName, withExtension: ext)
		
		let insert = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			let sqlStatement = "INSERT INTO 'tb_company' (name) VALUES ('Home Company')"
			database.query(sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		insert()
		
		let update = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			let sqlStatement = "UPDATE 'tb_company' SET name = 'Making Waves AS' WHERE name = 'Home Company'"
			database.query(sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		update()
		
		let selectCompany = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			let sqlStatement = "SELECT pk_id, name FROM 'tb_company'"
			database.query(sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				
				let r = result.results?.first
				
				XCTAssertNotNil(r, "Result MUST NOT be nil")
				XCTAssertEqual(r!["name"],"Making Waves AS" as NSString)
				
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
			
		}
		
		selectCompany()
		
		let selectCount = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			let sqlStatement = "SELECT count(*) as company_count FROM 'tb_company'"
			database.query(sqlStatement, successClosure: { (count) in
				
				let counter = count.results?.first
				
				XCTAssertNotNil(counter, "Result MUST NOT be nil")
				XCTAssertEqual(counter!["company_count"],sqlNumber(1))
				
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		selectCount()
		
		let nullPick = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			let sqlStatement = "SELECT name, logo_picture_url FROM 'tb_company'"
			database.query(sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				
				let r = result.results?.first
				
				XCTAssertNotNil(r, "Result MUST NOT be nil")
				XCTAssertEqual(r!["name"],"Making Waves AS" as NSString)
				XCTAssertEqual(r!["logo_picture_url"],NSNull())
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
		}
		
		nullPick()
		
		let delete = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			let sqlStatement = "DELETE FROM 'tb_company' WHERE name = 'Making Waves AS'"
			database.query(sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		delete()
		
	}
	
	func testBindSQLStatementsAsync() {
		
		let dbName = "app_test_database_1"
		let ext = "db"
		
		let databasesPool = SQLitePool.manager()
		let database = try! databasesPool.initialize(database:dbName, withExtension: ext)
		
		let insert = {
		 
			let expectation = self.expectation(description: "SQLStatementsAsync")
			
			let dob = Date(timeIntervalSince1970: 3600*24*3650)
			let profilePic  = try? Data(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "chamira_fernando", ofType: "jpg")!))
			
			let sqlStatement = "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)"
			let values = [sqlStr("Chameera"),sqlStr("Fernando"),sqlStr("some_user_name"), sqlNumber(dob.timeIntervalSince1970),sqlNumber(1 as Int32),sqlData(profilePic!)]
			
			database.bindQuery(sqlStatement, bindValues: values, successClosure: { (result) in
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		insert()
		
		let update = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			
			let sqlStatement = "UPDATE 'tb_user' SET first_name = ?, last_name = ? WHERE first_name = ?"
			let values = [sqlStr("Chamira"),sqlStr("Fernando"),sqlStr("Chameera")]
			
			database.bindQuery(sqlStatement, bindValues: values, successClosure: { (result) in
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		update()
		
		let select = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			
			let sqlStatement = "SELECT first_name, date_of_birth as dob from 'tb_user' where first_name=?"
			let values = [sqlStr("Chamira")]
			
			database.bindQuery(sqlStatement, bindValues: values, successClosure: { (result) in
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				
				let r = result.results?.first
				
				XCTAssertNotNil(r, "Result MUST NOT be nil")
				XCTAssertEqual(r!["first_name"],"Chamira" as NSString)
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		select()
		
		let delete = {
			
			let expectation = self.expectation(description: "SQLStatementsAsync")
			
			let sqlStatement = "DELETE FROM 'tb_user' WHERE first_name = ?"
			let values = [sqlStr("Chamira")]
			
			database.bindQuery(sqlStatement, bindValues: values, successClosure: { (result) in
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectations(timeout: 2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		delete()
		
	}
	    
}
