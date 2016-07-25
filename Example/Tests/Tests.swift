// https://github.com/Quick/Quick

import Quick
import Nimble
import SQLiteManager
import sqlite3

class SQLiteManagerNoDatabaseSpec: QuickSpec {
	
	override func spec() {
		describe("SQLite.manager()") {
			
			it ("initialize database catch no database") {
				
					expect {
					
						try SQLitePool.manager().initializeDatabase("app_test_database", andExtension: "db")
						
					}.to(throwError {(error:ErrorType) in
						
						expect(SQLiteManagerError.kDatabaseFileDoesNotExistInAppBundleCode) == error._code
						expect(SQLiteManagerError.kErrorDomain) == error._domain
						
					})
			}
		
		}
	}
}


class SQLiteManagerDataabaseActionsSpec: QuickSpec {
	
	override func spec() {
		describe("SQLite.manager() Operations") {
			
			let databasesPool = SQLitePool.manager()
			
			let database = try! databasesPool.initializeDatabase("app_test_database_1", andExtension: "db")
			it ("Database name") {
				expect("app_test_database_1.db") == database.databaseName
			}
			
			it ("WRONG SQL (FAIL)") {
				
				expect {
					//Wrong SQL
					try database.query(sqlStatement: "NSERT INTO 'tb_user' (first_name, last_name, username) VALUES ('Chamira','Fernando', 'some_user_name')")
					
				}.to(throwError {(error:ErrorType) in
						
					expect(1) == error._code
					expect(SQLiteManagerError.kErrorDomain) == error._domain
						
				})
				
			}
			
			it ("INSERT SUCCESS") {
				let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
				let result = try! database.query(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth) VALUES ('Chameera','Frenando', 'some_user_name', \(dob.timeIntervalSince1970))")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				expect(result.results).to(beFalsy())
			}
			
			
			it ("UPDATE SUCCESS") {
				let result = try! database.query(sqlStatement: "UPDATE 'tb_user' SET first_name = 'Chamira', last_name = 'Fernando' WHERE first_name = 'Chameera'")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				expect(result.results).to(beFalsy())
			}
			
			it ("SELECT SUCCESS") {
				let result = try! database.query(sqlStatement: "SELECT first_name, username, date_of_birth as dob from 'tb_user'")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				
				let r = result.results?.first
				
				expect(r).to(beTruthy())
				
				expect(r!["first_name"] as? String) == "Chamira"
				expect(r!["username"] as? String) == "some_user_name"
				
				let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
				expect(r!["dob"] as? Double) == dob.timeIntervalSince1970
				
				
				let count = try! database.query(sqlStatement: "SELECT count(*) as user_count from 'tb_user'")
				
				expect(SQLITE_OK) == count.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				
				let counter = count.results?.first
				
				expect(counter).to(beTruthy())
				
				expect(counter!["user_count"] as? Int) == 1
				
			}
			
			it ("DELETE SUCCESS") {
				let result = try! database.query(sqlStatement: "DELETE FROM 'tb_user' WHERE first_name = 'Chamira'")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(1) == result.affectedRowCount
				expect(result.results).to(beFalsy())
			}
			
			context("ASYNC TEST") {
				
				it("INSERT SUCCESS") {
					
					let dob = NSDate(timeIntervalSince1970: 3600*24*9650)
					let sql = "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth) VALUES ('Marian','Peries', 'some_user_name', \(dob.timeIntervalSince1970))"
					
					waitUntil { done in
						database.query(sqlStatement: sql, successClosure: { (result) in
							
							expect(SQLITE_OK) == result.SQLiteSatusCode
							expect(result.affectedRowCount) == 1
							expect(result.results).to(beFalsy())
							done()
						
						}, errorClosure: { (error) in
								
							expect(SQLiteManagerError.kErrorDomain) == error._domain
							done()
								
						})
					}
					
				}
				
				it ("DELETE SUCCESS") {
					
					let sql = "DELETE FROM 'tb_user' WHERE first_name = 'Marian'"
					
					waitUntil { done in
						database.query(sqlStatement: sql, successClosure: { (result) in
							
							expect(SQLITE_OK) == result.SQLiteSatusCode
							expect(result.affectedRowCount) == 1
							expect(result.results).to(beFalsy())
							done()
							
							}, errorClosure: { (error) in
								
								expect(SQLiteManagerError.kErrorDomain) == error._domain
								done()
								
						})
					}
				}
			}
			
		}
	}
}