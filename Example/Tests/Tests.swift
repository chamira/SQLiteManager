// https://github.com/Quick/Quick

import Quick
import Nimble
import SQLiteManager
import sqlite3

class SQLiteManagerDatabaseCreateSpec: QuickSpec {
	
	override func spec() {
		describe("SQLite.manager() Create") {
			
            let dbName = "app_test_database_x_4"
            let database = try! SQLitePool.manager().initialize(database: dbName, withExtension: "db", createIfNotExists: true)

			it ("initialize database") {
                expect(dbName+".db") == database.databaseName
			}
            
            it ("Create table") {
                
                let q = "CREATE TABLE IF NOT EXISTS COMPANY(ID INT PRIMARY KEY NOT NULL,NAME TEXT NOT NULL, AGE INT NOT NULL,ADDRESS CHAR(50), SALARY REAL)"
                let ret = try! database.query(sqlStatement: q)
                expect(SQLITE_OK) == ret.SQLiteSatusCode
                
            }
		
		}
	}
}


class SQLiteManagerDatabaseActionsSpec: QuickSpec {
	
	override func spec() {
		describe("SQLite.manager() Operations") {
			
			let databasesPool = SQLitePool.manager()
			
            let database = try! databasesPool.initialize(database:"app_test_database_1", withExtension: "db")
            
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
					let sql = "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth) VALUES ('Mariaan','Peries', 'some_user_name', \(dob.timeIntervalSince1970))"
					
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
				
				
				it ("UPDATE SUCCESS") {
					
					let sql = "UPDATE 'tb_user' SET first_name = 'Marian' WHERE first_name = 'Mariaan'"
					
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