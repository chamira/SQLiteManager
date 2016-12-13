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
	
	var insertqueries = [String]()
	var updateQuries = [String]()
	var selectQuerires = [String]()
	
    override func setUp() {
        super.setUp()
		for i in 1..<10000 {
			
			let x = randomString(withLength: Int.random(lower: 0, upper: 100))
			let q = "INSERT INTO 'tb_company' (ID,NAME) VALUES (\(i),'\(x)')"
			insertqueries.append(q)
			
			let y = randomString(withLength: Int.random(lower: 0, upper: 100))
			
			let u = "UPDATE 'tb_company' SET name = '\(y)' WHERE ID = \(i)"
			updateQuries.append(u)
			
			let select = "Select * from 'tb_company' where ID = \(i)"
			selectQuerires.append(select)
			
		}
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
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
					print("Expectation error:",error ?? "")
				}
			})
			
		}
		
		delete()
		
	}
	
	func testBatchQueries() {
		
		let dbName = "app_test_database_x_big_dump"
		let ext = "db"
		
		let database = try! SQLitePool.manager().initialize(database: dbName, withExtension: ext, createIfNotExist: true)
		
		XCTAssertEqual(dbName+"."+ext, database.databaseName, "Database is not iinitialized correctly")
		
		
		let createTable = {
			let q = "CREATE TABLE IF NOT EXISTS tb_company(ID INT PRIMARY KEY NOT NULL,NAME TEXT NOT NULL)"
			let ret = try! database.query(q)
			
			XCTAssertEqual(SQLITE_OK, ret.SQLiteSatusCode, "Table is not created successfully SQLStatusCode:\(ret.SQLiteSatusCode)")
		}
		
		let deleteTable = {
			let drop = "DROP TABLE  IF EXISTS tb_company"
			
			do {
				let dropq = try database.query(drop)
				XCTAssertEqual(SQLITE_OK, dropq.SQLiteSatusCode, "Table is not deleted successfully SQLStatusCode:\(dropq.SQLiteSatusCode)")
			} catch {
				print("Exception",error)
			}
			
		}
		
		deleteTable() // drop company table if there is a any
		
		createTable()
		
		let insertSync:(_ queries:[String])->() = { (queries)->Void in
			let r = try! database.query(queries)
			XCTAssert(r.results.count == queries.count,"queries count \(queries.count) ≠ \(r.results.count)")
			print("Time taken to execute \(queries.count) queries",r.timeTaken)
		}
		
		let updateSync:(_ updateQuries:[String])->() = { (updateQuries)->Void in
			
			database.log = false
			let selectWorkItem = DispatchWorkItem {
				//print("Selecting ......")
				for query in self.selectQuerires {
					
					do {
						let selectResult1 = try database.query(query)
						XCTAssert(selectResult1.affectedRowCount == 1, "Something wrong result\(selectResult1)")
					} catch {
						print("Exception:",error)
					}
					
				}
				
			}
			
			let updateWorkItem = DispatchWorkItem {
				//print("Updating......")
				let updateR = try! database.query(updateQuries)
				
				XCTAssert(updateR.results.count == updateQuries.count,"queries count \(updateQuries.count) ≠ \(updateR.results.count)")
				print("Time taken to update \(updateQuries.count) queries",updateR.timeTaken)
				for i in updateR.results {
					XCTAssert(i.SQLiteSatusCode == SQLITE_OK,"Status code must be SQLITE_OK got \(i.SQLiteSatusCode)")
					XCTAssert(i.affectedRowCount == 1,"Affected row count must be 1 got \(i.affectedRowCount)")
				}
				
			}
			
			DispatchQueue.main.async(execute: updateWorkItem)
			DispatchQueue.global().async(execute: selectWorkItem)
			
		}
		
		insertSync(insertqueries)
		updateSync(updateQuries)
		
	}
	
	func testBatchAsyncQueries () {
		
		let dbName = "app_test_database_y_big_dump"
		let ext = "db"
		
		let database = try! SQLitePool.manager().initialize(database: dbName, withExtension: ext, createIfNotExist: true)
		
		XCTAssertEqual(dbName+"."+ext, database.databaseName, "Database is not iinitialized correctly")
		
		let createTable = {
			let q = "CREATE TABLE IF NOT EXISTS tb_company(ID INT PRIMARY KEY NOT NULL,NAME TEXT NOT NULL)"
			let ret = try! database.query(q)
			
			XCTAssertEqual(SQLITE_OK, ret.SQLiteSatusCode, "Table is not created successfully SQLStatusCode:\(ret.SQLiteSatusCode)")
		}
		
		let deleteTable = {
			let drop = "DROP TABLE  IF EXISTS tb_company"
			
			do {
				let dropq = try database.query(drop)
				XCTAssertEqual(SQLITE_OK, dropq.SQLiteSatusCode, "Table is not deleted successfully SQLStatusCode:\(dropq.SQLiteSatusCode)")
			} catch {
				print("Exception",error)
			}
			
		}
		
		createTable()
		
		let expectationInsert = self.expectation(description: "BatchStatementsAsync")
		
		database.query(insertqueries, successClosure: { (batchResult) in
			
			XCTAssert(batchResult.results.count == self.insertqueries.count,"queries count \(self.insertqueries.count) ≠ \(batchResult.results.count)")
			print("Async: Time taken to execute \(self.insertqueries.count) queries",batchResult.timeTaken)
			
			database.query(self.updateQuries, successClosure: { (updateResult) in
				
				XCTAssert(updateResult.results.count == self.updateQuries.count,"queries count \(self.updateQuries.count) ≠ \(updateResult.results.count)")
				print("Async: Time taken to update \(self.updateQuries.count) queries",updateResult.timeTaken)
				
				for i in updateResult.results {
					XCTAssert(i.SQLiteSatusCode == SQLITE_OK,"Status code must be SQLITE_OK got \(i.SQLiteSatusCode)")
					XCTAssert(i.affectedRowCount == 1,"Affected row count must be 1 got \(i.affectedRowCount)")
				}
				
				expectationInsert.fulfill()
				deleteTable()
			}, errorClosure: { (e) in
				expectationInsert.fulfill()
				deleteTable()
			})
			
			
		}, errorClosure: { (e) in
			
			expectationInsert.fulfill()
			deleteTable()
			
		})
		
		self.waitForExpectations(timeout: 5.0, handler: { (error) in
			if let e = error {
				print("Expectation error:",e)
			}
		})
		
	}
	
	func randomString(withLength length:Int) -> String {
		
		let s = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\nøåÅØæÆ "
		var word:String = ""
		
		for _ in 0 ..< length {
			let rand = Int.random(lower:0, upper:s.characters.count)
			let char =  s.substring(with: rand..<rand+1)
			
			word += char
		}
		
		return word
	}

	    
}

extension String {
	func index(from: Int) -> Index {
		return self.index(startIndex, offsetBy: from)
	}
	
	func substring(from: Int) -> String {
		let fromIndex = index(from: from)
		return substring(from: fromIndex)
	}
	
	func substring(to: Int) -> String {
		let toIndex = index(from: to)
		return substring(to: toIndex)
	}
	
	func substring(with r: Range<Int>) -> String {
		let startIndex = index(from: r.lowerBound)
		let endIndex = index(from: r.upperBound)
		return substring(with: startIndex..<endIndex)
	}
}


public extension Int {
	public static func random(lower: Int = min, upper: Int = max) -> Int {
		return Int(arc4random_uniform(UInt32(upper) - UInt32(lower)) + UInt32(lower))
	}
}

