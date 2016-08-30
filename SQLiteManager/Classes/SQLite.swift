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

	/**
	SQLitePool Manager, Singleton access method
	
	- returns: SQLitePool class
	*/
	public static func manager()->SQLitePool {
		return sharedPool
	}
	
	/**
	Returns the instance of a database if its already in the pool, otherwise nil
	
	- parameter databaseNameWithExtension: database name with extension
	
	- returns: SQLite Database
	*/
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
	
	/**
	Close all open databases in the pool
	*/
	public static func closeDatabases() {
		instances.forEach {  $0.1.closeDatabase() }
		instances.removeAll()
	}
	
	
		/// Open databases count
	public static var databasesCount:Int {
		return instances.count
	}
	
		/// Returns all instances of databases in the pool
	public static var databases:[String:SQLite] {
		return instances
	}
	
}


//MARK: - SQLite Class
public class SQLite {
	
	
		/// Database name with extension
	public var databaseName:String?  {
		return _databaseName+"."+_databaseExtension
	}
	
		/// app document url
	public var documentsUrl:NSURL {
		let fileManager = NSFileManager.defaultManager()
		let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
		let docUrl: NSURL = urls[0]
		return docUrl
	}
	
		/// Database URL
	public var databaseUrl:NSURL? {
		if (databaseName == nil) {
			return nil
		}
		return documentsUrl.URLByAppendingPathComponent(databaseName!)
	}
	
		/// Database path
	public var databasePath:String? {
		if (databaseUrl == nil) {
			return nil
		}
		return databaseUrl!.path
	}
	
	
		/// Log database queries and other executions, default is true
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
	
	
	/**
	Open database
	
	- throws: SQLiteManagerError
	*/
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
	
	/**
	Close database
	*/
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
	
	// Gets an sql statement and returns result
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
		
        var returnCode: Int32 = SQLITE_FAIL
        unowned let weakSelf  = self
		var errorType:SQLiteManagerError?
		
		var statement: COpaquePointer = nil
		
		let closeClosure:(()->(Int32)) = {
			sqlite3_exec(weakSelf.database, "COMMIT", nil, nil, nil);
			return sqlite3_finalize(statement);
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
			
			let resultObjects:[[NSString:NSObject]]? = castSelectStatementValuesToNSObjects(statement)

			returnCode = closeClosure()
			
			if (log) {
				print("SQL: \(sqlString) -> results:{ \(resultObjects) }")
			}
			
			var resultCount:Int = 0
			if let c = resultObjects?.count {
				resultCount = c
			}
			return (returnCode,resultCount ,resultObjects)
			
		}
		
		returnCode = closeClosure()
		
		if (log) {
			print("SQL: \(sqlString) -> count: { \(count)}")
		}
		
		return (returnCode,Int(count),nil)
		
	}
	
	private func isSelectStatement(sqlStatement:String!) -> Bool {
		
		let trim       = sqlStatement.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
		let selectWord = "SELECT"
		return (trim.substringToIndex(selectWord.endIndex).uppercaseString == selectWord)
		
	}
	
}

//MARK: - Bind
public extension SQLite {

	
	public func bindQuery(sqlStatement sql:String!, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
		do { return try submitBindQuery(sqlStatement: sql, bindValues: bindValues) } catch let e as NSError { throw e }
		
	}
	
	public func bindQuery(sqlStatement sql:String!, bindValues:[NSObject], successClosure:SuccessClosure,errorClosure:ErrorClosure) {
		
		var error:NSError?
		unowned let weakSelf = self
		var result:SQLiteQueryResult?
		
		let blockOp = NSBlockOperation(block: {
			do { result = try weakSelf.submitBindQuery(sqlStatement: sql, bindValues: bindValues) } catch let e as NSError { error = e }
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
	
	// Gets an sql statement and returns result
	private func submitBindQuery(sqlStatement sql:String!, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
		unowned let weakSelf = self
		var r:SQLiteQueryResult!
		var blockError: NSError? = nil
		
		dispatch_sync(database_operation_queue) {
			do {
				r = try weakSelf.executeBindSQL(sqlStatement: sql, bindValues: bindValues)
			} catch let e as NSError {
				blockError = e
			}
		}
		
		if let blockError = blockError {
			throw blockError
		}
		
		return r
		
	}
	
	public func executeBindSQL(sqlStatement sql:String, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
        let SQLITE_STATIC    = unsafeBitCast(0, sqlite3_destructor_type.self)
        let SQLITE_TRANSIENT = unsafeBitCast(-1, sqlite3_destructor_type.self)
		
		var returnCode: Int32 = SQLITE_FAIL
		unowned let weakSelf  = self
		var errorType:SQLiteManagerError?
		
		var statement: COpaquePointer = nil
		
		let closeClosure:(()->(Int32)) = {
			sqlite3_exec(weakSelf.database, "COMMIT", nil, nil, nil);
			return sqlite3_finalize(statement);
		}
		
		sqlite3_exec(weakSelf.database, "BEGIN", nil,nil,nil);
		returnCode = sqlite3_prepare_v2(weakSelf.database, sql, -1, &statement, nil)
		
		if returnCode != SQLITE_OK {
			let errorMessage = "\(String.fromCString(sqlite3_errmsg(weakSelf.database))!) SQL:\(sql) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [kCFErrorDescriptionKey:errorMessage])
		}
		
		let bindCount = Int(sqlite3_bind_parameter_count(statement))
		
		if bindCount != bindValues.count {
			closeClosure()
			throw SQLiteManagerError.bindingValuesCountMissMatch(databaseName!, sqlQeuery: sql, bindingParamCount: bindCount, valuesCount: bindValues.count)
		}
		
		var position:Int32 = 1
		for val in bindValues {
			if val is NSString {
				let str = val as! NSString
				sqlite3_bind_text(statement, position, str.UTF8String, -1, SQLITE_STATIC);
			} else if val is NSNumber {
				let num = val as! NSNumber
				
				let numberType:CFNumberType = CFNumberGetType(num as CFNumber)
				
				switch numberType {
					case .SInt8Type, .SInt16Type , .SInt32Type, .ShortType, .CharType:
						sqlite3_bind_int(statement, position, num.intValue)
					case .SInt64Type, .IntType, .LongType, .LongLongType, .CFIndexType, .NSIntegerType:
						sqlite3_bind_int64(statement, position, num.integerValue as! sqlite_int64)
					default:
						sqlite3_bind_double(statement, position, num.doubleValue)
				}

			} else if val is NSNull {
				sqlite3_bind_null(statement, position)
			} else if val is NSData {
				let data = val as! NSData
				sqlite3_bind_blob(statement, position, data.bytes, Int32(data.length), SQLITE_TRANSIENT)
			}
			
			position += 1
			
		}
		
		var resultObjects:[[NSString:NSObject]]?
		var resultCount:Int = 0
		
		if (isSelectStatement(sql)) {
			
			let resultObjects:[[NSString:NSObject]]? = castSelectStatementValuesToNSObjects(statement)
			
			if (log) {
				print("SQL: \(sql) -> results: { \(resultObjects) } ")
			}
			
			var resultCount:Int = 0
			if let c = resultObjects?.count {
				resultCount = c
			}
			
			returnCode = closeClosure()
			
			let c:Int! = resultObjects == nil ? 0 : resultObjects?.count
			
			return (returnCode, c ,resultObjects)
			
		}
		
		returnCode = sqlite3_step(statement)
		
		if returnCode != SQLITE_DONE {
			let errorMessage = "\(String.fromCString(sqlite3_errmsg(weakSelf.database))!) SQL:\(sql) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			let _ = closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [kCFErrorDescriptionKey:errorMessage])
		}
		
        let count:Int32 = sqlite3_changes(weakSelf.database)
        resultCount     = Int(count)
		
		returnCode = closeClosure()
		
		if (log) {
			print("SQL: \(sql) -> results count: ", resultCount)
		}
		
		return (returnCode,resultCount ,resultObjects)
		
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
	
	private func castSelectStatementValuesToNSObjects(statement:COpaquePointer) -> [[NSString:NSObject]]? {
		
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
	
		return resultObjects
		
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