//
//  SQLite.swift
//  Pods
//
//  Created by Chamira Fernando on 19/07/16.
//
// Idea is to have a simple interface to talk to SQLite database in familiar SQL statements
//

import Foundation
import sqlite3

/**
 SQLiteSatusCode.SQLiteSatusCode SQLite status code return by sqlite3 engine
 SQLiteSatusCode.affectedRowCount number of rows affected by the query if any, otherwise 0
 SQLiteQueryResult.results is an array of [String:AnyObject], each row of the result of the query is casted in to a dictionary
 [key:value], example if SQL statement 'SELECT first_name FROM tb_user WHERE id = 1' results will be [["first_name":"Chamira"]]
	*/
public typealias SQLiteQueryResult = (SQLiteSatusCode:Int32,affectedRowCount:Int,results:[[NSString:NSObject]]?)

public typealias SuccessClosure = (result:SQLiteQueryResult)->()
public typealias ErrorClosure = (error:NSError)->()

//MARK: - SQLitePool Class
public class SQLitePool {
	
	private init() {}
	
	deinit {
		SQLitePool.closeDatabases()
	}
	
	private static var instances:[String:SQLite] = [:]
	private static var sharedPool:SQLitePool = SQLitePool()
	
	private static func addInstanceFor(database databaseNameWithExtension:String, instance:SQLite) {
		instances[databaseNameWithExtension] = instance
	}

	public static func manager()->SQLitePool {
		return sharedPool
	}
	
	public static func getInstanceFor(database databaseNameWithExtension:String)->SQLite? {
		
		if (instances.isEmpty) {
			return nil
		}
		
		let lite = instances[databaseNameWithExtension]
		
		return lite
		
	}
    
    /**
     Initialize a database and add to SQLitePool, you can initialize many databases as you like.
     Each database (instance) will be remained in SQLitePool
     
     - parameter name:              name of the database (without extension)
     - parameter withExtension:     database extension (db, db3, sqlite, sqlite3) without .(dot)
     - parameter createIfNotExists: create database with given name in application dir If it does not exists, default value is false
     
     - throws: NSError
     
     - returns: SQLite database
     */

    public func initialize(database name:String, withExtension:String, createIfNotExists createIfNotExists:Bool = false) throws -> SQLite {
		do {
			let lite = try SQLite().initialize(database: name, withExtension: withExtension, createIfNotExists: createIfNotExists)
			return lite
		} catch let e as NSError {
			throw e
		}
	}
	
	public static func closeDatabases() {
		instances.forEach {  $0.1.closeDatabase() }
		instances.removeAll()
	}
	
	public static var databasesCount:Int {
		return instances.count
	}
	
	public static var databases:[String:SQLite] {
		return instances
	}
	
}


//MARK: - SQLite Class
public class SQLite {
	
	public var databaseName:String?  {
		return _databaseName+"."+_databaseExtension
	}
	
	public var documentsUrl:NSURL {
		let fileManager = NSFileManager.defaultManager()
		let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
		let docUrl: NSURL = urls[0]
		return docUrl
	}
	
	public var databaseUrl:NSURL? {
		if (databaseName == nil) {
			return nil
		}
		return documentsUrl.URLByAppendingPathComponent(databaseName!)
	}
	
	public var databasePath:String? {
		if (databaseUrl == nil) {
			return nil
		}
		return databaseUrl!.path
	}
	
	public var log:Bool = true
	
	private init() {}
	
	deinit {
		closeDatabase()
	}
	
	private var sharedManager:SQLite?

	//Private members
	private var backupToICloud:Bool = false
	
	private var _databaseName:String = ""
	
	private var _databaseExtension = "db"
	
	private var database:COpaquePointer = nil
	
    private var _createIfNotExists:Bool = false
    
    private var createIfNotExists:Bool {
        return _createIfNotExists
    }
    
	private var database_operation_queue:dispatch_queue_t!
    
    
	lazy private var databaseOperationQueue:NSOperationQueue = {
	
		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.qualityOfService = NSQualityOfService.Background
		return queue
		
	}()
	
	private func initialize(database name:String, withExtension:String, createIfNotExists create:Bool = false) throws -> SQLite {
		
		sharedManager = SQLitePool.getInstanceFor(database: name+"."+withExtension)
		if (sharedManager != nil) {
			return sharedManager!
		}
		
        _databaseName      = name
        _databaseExtension = withExtension
        _createIfNotExists = create
        
		var moved = hasDatabaseMovedToDocumentsDir()
		
		if (!moved) {
			log("Moving database to document dir")
			do { moved = try copyDatabaseFromBundleToDocumentsDir() }
            catch let e as NSError {
                throw e
            }
		} else {
			log("Database is already moved")
		}
		
		if (moved) {
			do { try openDatabase() } catch let e as NSError { throw e }
		}
		
		log(_databaseName + " is open")
        database_operation_queue    = dispatch_queue_create("lib.SQLiteManager.database_operation_queue."+_databaseName, DISPATCH_QUEUE_SERIAL)
        databaseOperationQueue.name = "lib.SQLiteManager.database_operation_queue."+_databaseName
		SQLitePool.addInstanceFor(database: databaseName!, instance: self)
		sharedManager = self
		
		return self
		
	}
	
	public func openDatabase() throws {
		
		if (database != nil) {
			log("Database is already open:" + databaseName!)
			return
		}
		
		guard let databasePath = databasePath else {
			throw SQLiteManagerError.kDatabaseFilePathIsNil(databaseName!)
		}
		
		if sqlite3_open(databasePath, &database) != SQLITE_OK {
			var errorMessage = String.fromCString(sqlite3_errmsg(database))
			if (errorMessage?.characters.count == 0) {
				errorMessage = "undefined database (sqlite3) error"
			}
			
			let code = sqlite3_errcode(database)
			log(" ***** Failed to open database:" + databaseName!)
			throw SQLiteManagerError(code: Int(code), userInfo: [kCFErrorDescriptionKey:errorMessage!])
		}
		
		if (log) {
			print("Database is open:",databaseName!)
		}
		
	}
	
	public func closeDatabase() {
		
		if (sqlite3_close(database) == SQLITE_OK) {
			sharedManager = nil
			database = nil
			log("Database Closed successfully:" + databaseName!);
		}
		
	}
	
}


//MARK: - Query extension
public extension SQLite {
	
	/**
	Basic method to query the database, query is run on the same thread as the caller.
	
	- parameter sql: SQL statement (learn more @ https://www.sqlite.org/lang.html)
	
	- throws: if there is any error throws it
	
	- returns: return query result, SQLiteQueryResult (SQLiteResultCode, Affected Rows and Results array)
	
	*/
	public func query(sqlStatement sql:String!) throws -> SQLiteQueryResult {
	
		do { return try submitQuery(sqlStatement: sql) } catch let e as NSError { throw e }
		
	}
	
	/**
	Basic method to query the database, query is run on a background thread and pass result to main thread
	
	- parameter sql:            SQL statement (learn more @ https://www.sqlite.org/lang.html)
	- parameter successClosure: if query is successfully executed run successClosure which has SQLiteQueryResult as a param
	- parameter errorClosure:   if any error, run errorClosure
	*/
	public func query(sqlStatement sql:String!,successClosure:SuccessClosure,errorClosure:ErrorClosure) {
		
		var error:NSError?
		unowned let weakSelf = self
		var result:SQLiteQueryResult?
	
		let blockOp = NSBlockOperation(block: {
			do { result = try weakSelf.submitQuery(sqlStatement: sql) } catch let e as NSError { error = e }
		})
		
		blockOp.completionBlock = {
			
			if let r = result {
				dispatch_async(dispatch_get_main_queue()) {
					successClosure(result: r)
				}
			} else if let e = error {
				dispatch_async(dispatch_get_main_queue()) {
					errorClosure(error:e)
				}
			}  else {
				dispatch_async(dispatch_get_main_queue()) {
					errorClosure(error:SQLiteManagerError.unknownError(weakSelf.databaseName!))
				}
			}
			
		}
		
        blockOp.qualityOfService = NSQualityOfService.Background
        blockOp.queuePriority    = NSOperationQueuePriority.Normal
		self.databaseOperationQueue.addOperation(blockOp)

	}
	
	private func submitQuery(sqlStatement sql:String!) throws -> SQLiteQueryResult {
		
		unowned let weakSelf = self
		var r:SQLiteQueryResult!
		var blockError: NSError? = nil
		
		dispatch_sync(database_operation_queue) {
			do {
				r = try weakSelf.executeSQL(sql)
			} catch let e as NSError {
				blockError = e
			}
		}
		
		if let blockError = blockError {
			throw blockError
		}
		
		return r
		
	}
	
	/**
	This is where all dirty jobs happen
	Run SQL and cast into Dictionary and return the result
	
	- parameter sqlString: SQL Statement
	
	- throws: if an error throws it
	
	- returns: result
	*/
	private func executeSQL(sqlString:String!) throws -> SQLiteQueryResult {
		
		var returnCode: Int32         = 0
		unowned let weakSelf          = self
		var errorType:SQLiteManagerError?
		
		var statement: COpaquePointer = nil
		
		let closeClosure = {
			sqlite3_exec(weakSelf.database, "COMMIT", nil, nil, nil);
			sqlite3_finalize(statement);
		}
		
		sqlite3_exec(weakSelf.database, "BEGIN", nil,nil,nil);
		returnCode = sqlite3_prepare_v2(weakSelf.database, sqlString, -1, &statement, nil)
		
		if returnCode != SQLITE_OK {
			let errorMessage = "\(String.fromCString(sqlite3_errmsg(weakSelf.database))!) SQL:\(sqlString) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [kCFErrorDescriptionKey:errorMessage])
		}
		
		returnCode = sqlite3_exec(weakSelf.database, sqlString, nil, nil, nil)
		
		if(returnCode != SQLITE_OK) {
			
			let errorMessage = "\(String.fromCString(sqlite3_errmsg(weakSelf.database))!) SQL:\(sqlString) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [kCFErrorDescriptionKey:errorMessage])
			
		}

		let count:Int32 = sqlite3_changes(weakSelf.database)
		
		if (isSelectStatement(sqlString)) {

			let columnCount:Int32 = sqlite3_column_count(statement)
			
			var keys:[NSString] = []
			for i in 0..<columnCount {
				let columnName = NSString(CString: UnsafePointer<Int8>(sqlite3_column_name(statement, i)), encoding: NSString.defaultCStringEncoding())
				keys.append(columnName!)
			}
			
			var resultObjects:[[NSString:NSObject]]?
			
			while sqlite3_step(statement) == SQLITE_ROW {
				var c:Int32 = 0
				var row:[NSString:NSObject] = [:]
				
				for key in keys {
					let value     = sqlite3_column_value(statement, c)
					let valueType = sqlite3_value_type(value)
					var actualValue:NSObject?
					
					switch valueType {
					case SQLITE_TEXT:
						actualValue = NSString(CString: UnsafePointer<Int8>(sqlite3_value_text(value)), encoding: NSString.defaultCStringEncoding())
						break
					case SQLITE_FLOAT:
                        actualValue = NSNumber(double: sqlite3_value_double(value))
						break
					case SQLITE_INTEGER:
                        actualValue = NSNumber(longLong: sqlite3_value_int64(value))
						break
					case SQLITE_BLOB:
                        let length = Int(sqlite3_column_bytes(statement, c))
                        let bytes  = sqlite3_column_blob(statement, c)
                        actualValue = NSData(bytes: bytes, length: length)
						break
					default:
						actualValue = NSNull()
						break
					}
					
					if let v = actualValue {
						
						if (resultObjects == nil) {
							resultObjects = []
						}
						
						row[key] = v
						
                    } else {
                        row[key] = NSNull()
                    }

					c += 1
					
				}
				
				resultObjects?.append(row)
				
			}
			
			closeClosure()
			if (log) {
				print("SQL: \(sqlString): ", resultObjects)
			}
			
			var resultCount:Int = 0
			if let c = resultObjects?.count {
				resultCount = c
			}
			return (returnCode,resultCount ,resultObjects)
			
		}
		
	
		closeClosure()
		if (log) {
			print("SQL: \(sqlString): ", count)
		}
		return (returnCode,Int(count),nil)
		
	}
	
	private func isSelectStatement(sqlStatement:String!) -> Bool {
		
		let trim       = sqlStatement.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
		let selectWord = "SELECT"
		return (trim.substringToIndex(selectWord.endIndex).uppercaseString == selectWord)
		
	}
	
}

//MARK: - Utility extension
private extension SQLite {
	
	private func hasDatabaseMovedToDocumentsDir() -> Bool {
		
		guard let databasePath = databasePath else {
			return false
		}
		
		let fileManager = NSFileManager.defaultManager()
		return fileManager.fileExistsAtPath(databasePath)
		
	}
	
	private func copyDatabaseFromBundleToDocumentsDir () throws -> Bool {
		
		guard let databaseBundlePath = NSBundle.mainBundle().pathForResource(_databaseName, ofType: _databaseExtension) else {
            
            if (_createIfNotExists) {
                guard let filePath = databasePath else {
                    throw SQLiteManagerError.unknownError(databaseName!)
                }
                
                if (!createDatabaseFileAtPath(filePath)) {
                     throw SQLiteManagerError.unknownError(databaseName!)
                }
                
                if (!backupToICloud) {
                    addSkipBackupAttributeToItemAtPath(databaseUrl!)
                }
                
                return true
                
            } else {
                throw SQLiteManagerError.databaseFileDoesNotExistInAppBundle(databaseName!)
            }
		}
	
		do {
	
			let fileManager = NSFileManager.defaultManager()
			try fileManager.copyItemAtPath(databaseBundlePath, toPath: databasePath!)
			log("Success, database file has been copied")
			if (!backupToICloud) {
				addSkipBackupAttributeToItemAtPath(databaseUrl!)
			}
			
		} catch let error as NSError {
			throw error
		}
		
		return true
	}
	
    private func createDatabaseFileAtPath(path:String)->Bool {
     
        let fileManager = NSFileManager.defaultManager()
        let created =  fileManager.createFileAtPath(path, contents: nil, attributes: [NSFileCreationDate:NSDate(),NSFileType:NSFileTypeRegular])
        
        return created
    }
    
	// Exclude file at URL from iCloud backup
	private func addSkipBackupAttributeToItemAtPath(url: NSURL) {
		
		guard let path = url.path else {
			log("Could not att 'skip backup' attribute, file path did not exist at url: \(url)")
			return
		}
		
		let fileManager = NSFileManager.defaultManager()
		if fileManager.fileExistsAtPath(path) {
			do {
				try url.setResourceValue(NSNumber(bool: true),forKey: NSURLIsExcludedFromBackupKey)
			} catch let error as NSError {
				log("Error while setting 'skip backup' attribute on url \(url): \(error)")
			}
			
		} else {
			log("Could not att 'skip backup' attribute, file did not exist: \(url)")
		}
	}
}

//MARK: - Log extension
private extension SQLite {
	
	func log(message:String!, tag:String? = nil, file:String? = nil, line:String? = nil) {
		
		if (!log){
			return
		}
		
		var logMsg = "SQLiteManager -"
		
		if let tag = tag {
			logMsg += " Tag:"+tag
		}
		
		logMsg += " Message:"+message
		
		if let file = file {
			logMsg += " file:"+file
		}
		
		if let line = line {
			logMsg += " line:"+line
		}
		
		print(logMsg)
		
	}
	
}