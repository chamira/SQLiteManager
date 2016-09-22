
import XCTest
import sqlite3
@testable import SQLiteManager

class SQLiteManger_Tests: XCTestCase {

	override func setUp() {
		super.setUp()
	}
	
	override func tearDown() {
		super.tearDown()
	}
	
	func testCreateTable() {
	
		let dbName = "app_test_database_x_4"
		let ext = "db"
		
		let database = try! SQLitePool.manager().initialize(database: dbName, withExtension: ext, createIfNotExist: true)
		
		XCTAssertEqual(dbName+"."+ext, database.databaseName, "Database is not iinitialized correctly")
		
		
		let q = "CREATE TABLE IF NOT EXISTS COMPANY(ID INT PRIMARY KEY NOT NULL,NAME TEXT NOT NULL, AGE INT NOT NULL,ADDRESS CHAR(50), SALARY REAL)"
		let ret = try! database.query(sqlStatement: q)
		
		XCTAssertEqual(SQLITE_OK, ret.SQLiteSatusCode, "Table is not created successfully SQLStatusCode:\(ret.SQLiteSatusCode)")
		
	}
	
	func testHandingInvalidSQLStatementException() {
		
		let dbName = "app_test_database_1"
		let ext = "db"
		
		let databasesPool = SQLitePool.manager()
		let database = try! databasesPool.initialize(database:dbName, withExtension: ext)
		
		XCTAssertEqual(dbName+"."+ext, database.databaseName, "Database is not iinitialized correctly")
		
		XCTAssertThrowsError(try database.query(sqlStatement: "INSERT INTO 'company' (name) VALUES ('Home Company')"))
		XCTAssertThrowsError(try database.query(sqlStatement: "INSRT INTO 'tb_company' (name) VALUES ('Home Company')"))
		
	}
	
	func testSQLStatementsMainThread() {
		
		let dbName = "app_test_database_1"
		let ext = "db"
		
		let databasesPool = SQLitePool.manager()
		let database = try! databasesPool.initialize(database:dbName, withExtension: ext)

		let insert = {
			let result = try! database.query(sqlStatement: "INSERT INTO 'tb_company' (name) VALUES ('Home Company')")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		insert()
		
		let update = {
			let result = try! database.query(sqlStatement: "UPDATE 'tb_company' SET name = 'Making Waves AS' WHERE name = 'Home Company'")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		update()
		
		let selectCompany = {
			let result = try! database.query(sqlStatement: "SELECT pk_id, name FROM 'tb_company'")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)

			let r = result.results?.first
			
			XCTAssertNotNil(r, "Result MUST NOT be nil")
			XCTAssertEqual(r!["name"],"Making Waves AS" as NSString)

			let count = try! database.query(sqlStatement: "SELECT count(*) as company_count FROM 'tb_company'")

			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)

			let counter = count.results?.first

			XCTAssertNotNil(counter, "Result MUST NOT be nil")
			XCTAssertEqual(counter!["company_count"],NSNumber(integer: 1))
		}
		
		selectCompany()
		
		let nullPick = {
			let result = try! database.query(sqlStatement: "SELECT name, logo_picture_url FROM 'tb_company'")
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)

			let r = result.results?.first
			
			XCTAssertNotNil(r, "Result MUST NOT be nil")
			XCTAssertEqual(r!["name"],"Making Waves AS" as NSString)
			XCTAssertEqual(r!["logo_picture_url"],NSNull())
			
		}
		
		nullPick()
		
		let delete = {
			let result = try! database.query(sqlStatement: "DELETE FROM 'tb_company' WHERE name = 'Making Waves AS'")
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
		 
			let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
			let profilePic  = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("chamira_fernando", ofType: "jpg")!)
			let result = try! database.bindQuery(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)",
												 bindValues: ["Chameera","Fernando","some_user_name", NSNumber(double: dob.timeIntervalSince1970),NSNumber(int:1),profilePic!])
			
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		insert()
		
		let update = {
			let result = try! database.bindQuery(sqlStatement: "UPDATE 'tb_user' SET first_name = ?, last_name = ? WHERE first_name = ?", bindValues: ["Chamira","Fernando","Chameera"])
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			XCTAssertNil(result.results, "Results array MUST be nil")
		}
		
		update()
		
		let select = {
			let result = try! database.bindQuery(sqlStatement: "SELECT first_name, date_of_birth as dob from 'tb_user' where first_name=?", bindValues: ["Chamira"])
			XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
			XCTAssertEqual(1,result.affectedRowCount)
			
			let r = result.results?.first
			
			XCTAssertNotNil(r, "Result MUST NOT be nil")
			XCTAssertEqual(r!["first_name"],"Chamira" as NSString)
		
		}
		
		select()
	
		let delete = {
			let result = try! database.bindQuery(sqlStatement: "DELETE FROM 'tb_user' WHERE first_name = ?",bindValues: ["Chamira"])
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
			
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			let sqlStatement = "INSERT INTO 'tb_company' (name) VALUES ('Home Company')"
			database.query(sqlStatement: sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
			}, errorClosure: { (error) in
				XCTAssertThrowsError(error)
				expectation.fulfill()
			})
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		insert()
		
		let update = {
			
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			let sqlStatement = "UPDATE 'tb_company' SET name = 'Making Waves AS' WHERE name = 'Home Company'"
			database.query(sqlStatement: sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		update()
		
		let selectCompany = {
			
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			let sqlStatement = "SELECT pk_id, name FROM 'tb_company'"
			database.query(sqlStatement: sqlStatement, successClosure: { (result) in
				
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
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
			
		}
		
		selectCompany()
		
		let selectCount = {
			
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			let sqlStatement = "SELECT count(*) as company_count FROM 'tb_company'"
			database.query(sqlStatement: sqlStatement, successClosure: { (count) in
				
				let counter = count.results?.first
				
				XCTAssertNotNil(counter, "Result MUST NOT be nil")
				XCTAssertEqual(counter!["company_count"],NSNumber(integer: 1))
				
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		selectCount()
		
		let nullPick = {
			
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			let sqlStatement = "SELECT name, logo_picture_url FROM 'tb_company'"
			database.query(sqlStatement: sqlStatement, successClosure: { (result) in
				
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
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
		}
		
		nullPick()
		
		let delete = {
		
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			let sqlStatement = "DELETE FROM 'tb_company' WHERE name = 'Making Waves AS'"
			database.query(sqlStatement: sqlStatement, successClosure: { (result) in
				
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
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
		 
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			
			let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
			let profilePic  = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("chamira_fernando", ofType: "jpg")!)
			
			let sqlStatement = "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)"
			let values = ["Chameera","Fernando","some_user_name", NSNumber(double: dob.timeIntervalSince1970),NSNumber(int:1),profilePic!]
			
			database.bindQuery(sqlStatement: sqlStatement, bindValues: values, successClosure: { (result) in
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		insert()
		
		let update = {
		
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			
			let sqlStatement = "UPDATE 'tb_user' SET first_name = ?, last_name = ? WHERE first_name = ?"
			let values = ["Chamira","Fernando","Chameera"]
			
			database.bindQuery(sqlStatement: sqlStatement, bindValues: values, successClosure: { (result) in
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		update()
		
		let select = {
			
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			
			let sqlStatement = "SELECT first_name, date_of_birth as dob from 'tb_user' where first_name=?"
			let values = ["Chamira"]
			
			database.bindQuery(sqlStatement: sqlStatement, bindValues: values, successClosure: { (result) in
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
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		select()
		
		let delete = {
			
			let expectation = self.expectationWithDescription("SQLStatementsAsync")
			
			let sqlStatement = "DELETE FROM 'tb_user' WHERE first_name = ?"
			let values = ["Chamira"]
			
			database.bindQuery(sqlStatement: sqlStatement, bindValues: values, successClosure: { (result) in
				XCTAssertEqual(SQLITE_OK, result.SQLiteSatusCode, "SQLiteStatus code is wrong \(result.SQLiteSatusCode)")
				XCTAssertEqual(1,result.affectedRowCount)
				XCTAssertNil(result.results, "Results array MUST be nil")
				expectation.fulfill()
				}, errorClosure: { (error) in
					XCTAssertThrowsError(error)
					expectation.fulfill()
			})
			
			self.waitForExpectationsWithTimeout(2.0, handler: { (error) in
				if let _ = error {
					print("Expectation error:",error)
				}
			})
			
		}
		
		delete()
		
	}
	
}
