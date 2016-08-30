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
		
		describe("SQLite.manager() normal queries") {
			
			let databasesPool = SQLitePool.manager()
			
            let database = try! databasesPool.initialize(database:"app_test_database_1", withExtension: "db")
            
			it ("Database name") {
				expect("app_test_database_1.db") == database.databaseName
			}
			
			it ("WRONG SQL (FAIL)") {
				
				expect {
					//Wrong SQL
					try database.query(sqlStatement: "NSERT INTO 'tb_company' (name) VALUES ('Home Company')")
					
				}.to(throwError {(error:ErrorType) in
						
					expect(1) == error._code
					expect(SQLiteManagerError.kErrorDomain) == error._domain
						
				})
				
			}
			
			it ("INSERT COMPANY SUCCESS") {
				let result = try! database.query(sqlStatement: "INSERT INTO 'tb_company' (name) VALUES ('Home Company')")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				expect(result.results).to(beFalsy())
			}
			
			
			it ("UPDATE COMPANY SUCCESS") {
				let result = try! database.query(sqlStatement: "UPDATE 'tb_company' SET name = 'Making Waves AS' WHERE name = 'Home Company'")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				expect(result.results).to(beFalsy())
			}
			
			it ("SELECT COMPANY SUCCESS") {
				let result = try! database.query(sqlStatement: "SELECT pk_id, name FROM 'tb_company'")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				
				let r = result.results?.first
				
				expect(r).to(beTruthy())
				
				expect(r!["name"]) == "Making Waves AS" as NSString
				
				let count = try! database.query(sqlStatement: "SELECT count(*) as company_count FROM 'tb_company'")
				
				expect(SQLITE_OK) == count.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				
				let counter = count.results?.first
				
				expect(counter).to(beTruthy())
				
				expect(counter!["company_count"]) == 1 as NSNumber
				
			}
            
            it ("SELECT COMPANY NULL VALUE") {
                let result = try! database.query(sqlStatement: "SELECT name, logo_picture_url FROM 'tb_company'")
                expect(SQLITE_OK) == result.SQLiteSatusCode
                expect(result.affectedRowCount) == 1
                
                let r = result.results?.first
                
                expect(r).to(beTruthy())
                
                expect(r!["name"]) == "Making Waves AS" as NSString
                expect(r!["logo_picture_url"] as? NSNull) == NSNull()
                
            }
			
			it ("DELETE COMPANY SUCCESS") {
				let result = try! database.query(sqlStatement: "DELETE FROM 'tb_company' WHERE name = 'Making Waves AS'")
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(1) == result.affectedRowCount
				expect(result.results).to(beFalsy())
			}
			
			context("ASYNC TEST") {
				
				it("INSERT COMPANY SUCCESS") {
					
					let sql = "INSERT INTO 'tb_company' (name) VALUES ('Home Company')"
					
					waitUntil(timeout: 1.0, action: { done in
						database.query(sqlStatement: sql, successClosure: { (result) in
							
							expect(SQLITE_OK) == result.SQLiteSatusCode
							expect(result.affectedRowCount) == 1
							expect(result.results).to(beFalsy())
							done()
							
							}, errorClosure: { (error) in
								
								expect(SQLiteManagerError.kErrorDomain) == error._domain
								done()
								
						})
					})
					
				}
				
				
				it ("UPDATE COMPANY SUCCESS") {
					
					let sql = "UPDATE 'tb_company' SET name = 'Making Waves AS' WHERE name = 'Home Company'"
					
					waitUntil(timeout: 1.0, action: { done in
						
						database.query(sqlStatement: sql, successClosure: { (result) in
							
							expect(SQLITE_OK) == result.SQLiteSatusCode
							expect(result.affectedRowCount) == 1
							expect(result.results).to(beFalsy())
							done()
							
							}, errorClosure: { (error) in
								
								expect(SQLiteManagerError.kErrorDomain) == error._domain
								done()
								
						})
						
					})
					
				}
				
				it ("DELETE COMPANY SUCCESS") {
					
					let sql = "DELETE FROM 'tb_company' WHERE name = 'Making Waves AS'"
					
					waitUntil(timeout: 1.0, action: { done in
						
						database.query(sqlStatement: sql, successClosure: { (result) in
							
							expect(SQLITE_OK) == result.SQLiteSatusCode
							expect(result.affectedRowCount) == 1
							expect(result.results).to(beFalsy())
							done()
							
							}, errorClosure: { (error) in
								
								expect(SQLiteManagerError.kErrorDomain) == error._domain
								done()
								
						})
						
					})
				}
			}
			
		}
		
		
		describe("SQLite.manager() bind queries") {
			// Bind
			
			let databasesPool = SQLitePool.manager()
			
			let database = try! databasesPool.initialize(database:"app_test_database_1", withExtension: "db")
			
			it ("Database name") {
				expect("app_test_database_1.db") == database.databaseName
			}
			
			print("Database path:",database.databasePath)
			
			it ("MISS BIND VALUE EXCEPTION") {
				
				let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
				
				expect {
					
					try database.bindQuery(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)", bindValues: ["Chameera","Fernando","some_user_name", NSNumber(double: dob.timeIntervalSince1970),NSNumber(int:1)])
					
				}.to(throwError {(error:ErrorType) in
						
					expect(10003) == error._code
					expect(SQLiteManagerError.kErrorDomain) == error._domain
						
				})
				
			}
		
			
			it ("INSERT USER SUCCESS") {
				let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
				let profilePic  = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("chamira_fernando", ofType: "jpg")!)
				let result = try! database.bindQuery(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)",
				                                     bindValues: ["Chameera","Fernando","some_user_name", NSNumber(double: dob.timeIntervalSince1970),NSNumber(int:1),profilePic!])
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				expect(result.results).to(beFalsy())
			}
			
			
			it ("UPDATE USER SUCCESS") {
				let result = try! database.bindQuery(sqlStatement: "UPDATE 'tb_user' SET first_name = ?, last_name = ? WHERE first_name = ?", bindValues: ["Chamira","Fernando","Chameera"])
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				expect(result.results).to(beFalsy())
			}
			
			it ("SELECT USER SUCCESS") {
				let result = try! database.bindQuery(sqlStatement: "SELECT first_name, date_of_birth as dob from 'tb_user' where first_name=?", bindValues: ["Chamira"])
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
    
				let r = result.results?.first
    
				expect(r).to(beTruthy())
    
				expect(r!["first_name"] as? String) == "Chamira"
    
				let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
				expect(r!["dob"] as? Double) == dob.timeIntervalSince1970
    
			}
			
			it ("DELETE USER SUCCESS") {
				let result = try! database.bindQuery(sqlStatement: "DELETE FROM 'tb_user' WHERE first_name = ?",bindValues: ["Chamira"])
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(1) == result.affectedRowCount
				expect(result.results).to(beFalsy())
			}
			
			context("ASYNC TEST") {
    
				it("INSERT USER SUCCESS") {
					
					let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
					let profilePic  = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("chamira_fernando", ofType: "jpg")!)
					
					waitUntil { done in
						
						database.bindQuery(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)",
							bindValues: ["Chameera","Fernando","some_user_name", NSNumber(double: dob.timeIntervalSince1970),NSNumber(int:1),profilePic!], successClosure: { (result) in
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
    
				it ("UPDATE USER SUCCESS") {
					
					waitUntil { done in
						
						database.bindQuery(sqlStatement: "UPDATE 'tb_user' SET first_name = ?, last_name = ? WHERE first_name = ?",
							bindValues: ["Chamira","Fernando","Chameera"], successClosure: { (result) in
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
    
				it ("SELECT USER SUCCESS") {
					
					waitUntil { done in
						
						database.bindQuery(sqlStatement: "SELECT first_name, date_of_birth as dob from 'tb_user' where first_name=?",
							bindValues: ["Chamira"], successClosure: { (result) in
								
								expect(SQLITE_OK) == result.SQLiteSatusCode
								expect(result.affectedRowCount) == 1
								
								let r = result.results?.first
								
								expect(r).to(beTruthy())
								expect(r!["first_name"] as? String) == "Chamira"
								
								let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
								expect(r!["dob"] as? Double) == dob.timeIntervalSince1970
								done()
								
							}, errorClosure: { (error) in
								expect(SQLiteManagerError.kErrorDomain) == error._domain
								done()
						})
						
					}
					
				}
				
				it ("DELETE USER SUCCESS") {
					
					waitUntil { done in
						
						database.bindQuery(sqlStatement: "DELETE FROM 'tb_user' WHERE first_name = ?",
							bindValues: ["Chamira"], successClosure: { (result) in
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
		
		
		describe("SQLite.manager() join queries") {
			// Bind
			
			let databasesPool = SQLitePool.manager()
			
			let database = try! databasesPool.initialize(database:"app_test_database_1", withExtension: "db")
			
			it ("Database name") {
				expect("app_test_database_1.db") == database.databaseName
			}
			
			
			it ("JOIN USER WITH COMPANY") {
				let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
				let profilePic  = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("chamira_fernando", ofType: "jpg")!)
				let _ = try! database.bindQuery(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)",
														 bindValues: ["Chamira","Fernando","some_user_name", NSNumber(double: dob.timeIntervalSince1970),NSNumber(int:1),profilePic!])
				
				let _ = try! database.query(sqlStatement: "UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='tb_company'")
				
				let _ = try! database.query(sqlStatement: "INSERT INTO 'tb_company' (name) VALUES ('Making Waves AS')")
				
				let sql = "SELECT first_name, last_name, username, profile_picture, name as company_name FROM 'tb_user' JOIN 'tb_company' ON tb_user.company_id = tb_company.pk_id"
				
				let result =  try! database.query(sqlStatement: sql)
				
				expect(SQLITE_OK) == result.SQLiteSatusCode
				expect(result.affectedRowCount) == 1
				
				let r = result.results?.first
				
				expect(r).to(beTruthy())
				expect(r!["first_name"]) == "Chamira" as NSString
				expect(r!["company_name"]) == "Making Waves AS" as NSString
				
				let _ = try! database.query(sqlStatement: "DELETE FROM 'tb_user'")
				let _ = try! database.query(sqlStatement: "DELETE FROM 'tb_company'")
			}
		}
		
		/*describe("SQLite.manager() multi-threaded queuries") {
			// Bind
			
			let databasesPool = SQLitePool.manager()
			
			let database = try! databasesPool.initialize(database:"app_test_database_1", withExtension: "db")
			
			it ("Database name") {
				expect("app_test_database_1.db") == database.databaseName
			}
			
			
			it ("INSERT and SELECT USERS IN 2 Threads") {
				
				let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
				
				waitUntil(timeout: 20.0, action: { done in
					
					var _q1Done = false
					var _q2Done = false
					
					let q1 = NSOperationQueue()
					
					let upperBound = 1000
					let op1 = NSBlockOperation(block: {
						
						let profilePic  = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("chamira_fernando", ofType: "jpg")!)
						
						for index in 1...upperBound {
							
							let r1 = try! database.bindQuery(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)",
								bindValues: ["Chamira_\(index)","Fernando_\(index)","some_user_name_\(index)",dob,NSNumber(int:1),profilePic!])
							expect(SQLITE_OK) == r1.SQLiteSatusCode
							
						}
						
						_q1Done = true
						if (_q2Done) {
							let _ = try! database.query(sqlStatement: "DELETE FROM 'tb_user'")
							done()
						}
						
					})
					
					let q2 = NSOperationQueue()
					
					let op2 = NSBlockOperation(block: {
						
						for index in 1...upperBound {
							
							let r = try! database.query(sqlStatement: "SELECT first_name FROM tb_user WHERE first_name = 'Chamira_\(index)'")
							expect(SQLITE_OK) == r.SQLiteSatusCode
							expect(1) == r.affectedRowCount
						
						}
						
						_q2Done = true
						if (_q1Done) {
							let _ = try! database.query(sqlStatement: "DELETE FROM 'tb_user'")
							done()
						}
						
					})
					
					q1.addOperation(op1)
					sleep(1)
					q2.addOperation(op2)
					
					
				})
				
			}
		}*/
		
	}
}