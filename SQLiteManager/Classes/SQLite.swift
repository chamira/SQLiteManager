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

public typealias SQLiteDataArray = [[NSString:NSObject]]
public typealias SQLiteQueryResult = (SQLiteSatusCode:Int32,affectedRowCount:Int,results:SQLiteDataArray?)

public typealias SuccessClosure = (_ result:SQLiteQueryResult)->()
public typealias ErrorClosure = (_ error:NSError)->()


//MARK: - SQLitePool Class
open class SQLitePool {
	
	fileprivate init() {}
	
	deinit {
		SQLitePool.closeDatabases()
	}
	
	fileprivate static var instances:[String:SQLite] = [:]
	fileprivate static var sharedPool:SQLitePool = SQLitePool()
	
	fileprivate static func addInstanceFor(database databaseNameWithExtension:String, instance:SQLite) {
		instances[databaseNameWithExtension] = instance
	}

	/**
	SQLitePool Manager, Singleton access method
	
	- returns: SQLitePool class
	*/
	open static func manager()->SQLitePool {
		return sharedPool
	}
	
	/**
	Returns the instance of a database if its already in the pool, otherwise nil
	
	- parameter databaseNameWithExtension: database name with extension
	
	- returns: SQLite Database
	*/
	open static func getInstanceFor(database databaseNameWithExtension:String)->SQLite? {
		
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

    open func initialize(database name:String, withExtension:String, createIfNotExist:Bool = false) throws -> SQLite {
		do {
			let lite = try SQLite().initialize(database: name, withExtension: withExtension, createIfNotExist: createIfNotExist)
			return lite
		} catch let e as NSError {
			throw e
		}
	}
	
	/**
	Close all open databases in the pool
	*/
	open static func closeDatabases() {
		instances.forEach {  $0.1.closeDatabase() }
		instances.removeAll()
	}
	
	/// Open databases count
	open static var databasesCount:Int {
		return instances.count
	}
	
	/// Returns all instances of databases in the pool
	open static var databases:[String:SQLite] {
		return instances
	}
	
}


//MARK: - SQLite Class
open class SQLite {
	
	open var description:String {
		return databaseName!
	}
	
	/// Database name with extension
	open var databaseName:String?  {
		return _databaseName+"."+_databaseExtension
	}
	
	/// app document url
	open var documentsUrl:URL {
		let fileManager = FileManager.default
		let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
		let docUrl: URL = urls[0]
		return docUrl
	}
	
		/// Database URL
	open var databaseUrl:URL? {
		if (databaseName == nil) {
			return nil
		}
		return documentsUrl.appendingPathComponent(databaseName!)
	}
	
		/// Database path
	open var databasePath:String? {
		if (databaseUrl == nil) {
			return nil
		}
		return databaseUrl!.path
	}
	
	
		/// Log database queries and other executions, default is true
	open var log:Bool = true
	
	fileprivate init() {}
	
	deinit {
		closeDatabase()
	}
	
	fileprivate var sharedManager:SQLite?

	//Private members
	fileprivate var backupToICloud:Bool = false
	
	fileprivate var _databaseName:String = ""
	
	fileprivate var _databaseExtension = "db"
	
	fileprivate var database:OpaquePointer? = nil
	
    fileprivate var _createIfNotExists:Bool = false
    
    fileprivate var createIfNotExists:Bool {
        return _createIfNotExists
    }
    
	fileprivate var database_operation_queue:DispatchQueue!
	
	lazy fileprivate var databaseOperationQueue:OperationQueue = {
	
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.qualityOfService = QualityOfService.background
		return queue
		
	}()
	
	fileprivate func initialize(database name:String, withExtension:String, createIfNotExist create:Bool = false) throws -> SQLite {
		
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
        database_operation_queue    = DispatchQueue(label: "lib.SQLiteManager.database_operation_queue."+_databaseName, attributes: [])
        databaseOperationQueue.name = "lib.SQLiteManager.database_operation_queue."+_databaseName
		SQLitePool.addInstanceFor(database: databaseName!, instance: self)
		sharedManager = self
		
		return self
		
	}
	
	
	/**
	Open database
	
	- throws: SQLiteManagerError
	*/
	open func openDatabase() throws {
		
		if (database != nil) {
			log("Database is already open:" + databaseName!)
			return
		}
		
		guard let databasePath = databasePath else {
			throw SQLiteManagerError.kDatabaseFilePathIsNil(databaseName!)
		}
		
		if sqlite3_open(databasePath, &database) != SQLITE_OK {
			var errorMessage = String(cString: sqlite3_errmsg(database))
			if (errorMessage.characters.count == 0) {
				errorMessage = "undefined database (sqlite3) error"
			}
			
			let code = sqlite3_errcode(database)
			log(" ***** Failed to open database:" + databaseName!)
			throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
		}
		
		if (log) {
			print("Database is open:",databaseName!)
		}
		
	}
	
	/**
	Close database
	*/
	open func closeDatabase() {
		
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
	public func query(_ sql:String!) throws -> SQLiteQueryResult {
	
		do { return try submitQuery(sqlStatement: sql) } catch let e as NSError { throw e }
		
	}
	
	/**
	Basic method to query the database, query is run on a background thread and pass result to main thread
	
	- parameter sql:            SQL statement (learn more @ https://www.sqlite.org/lang.html)
	- parameter successClosure: if query is successfully executed run successClosure which has SQLiteQueryResult as a param
	- parameter errorClosure:   if any error, run errorClosure
	*/
	public func query(_ sql:String,successClosure:@escaping SuccessClosure,errorClosure:@escaping ErrorClosure) {
		
		var error:NSError?
		unowned let weakSelf = self
		var result:SQLiteQueryResult?
	
		let blockOp = BlockOperation(block: {
			do { result = try weakSelf.submitQuery(sqlStatement: sql) } catch let e as NSError { error = e }
		})
		
		blockOp.completionBlock = {
			
			if let r = result {
				DispatchQueue.main.async {
					successClosure(r)
				}
			} else if let e = error {
				DispatchQueue.main.async {
					errorClosure(e)
				}
			}  else {
				DispatchQueue.main.async {
					errorClosure(SQLiteManagerError.unknownError(weakSelf.databaseName!))
				}
			}
			
		}
		
        blockOp.qualityOfService = QualityOfService.background
        blockOp.queuePriority    = Operation.QueuePriority.normal
		self.databaseOperationQueue.addOperation(blockOp)

	}
	
	// Gets an sql statement and returns result
	fileprivate func submitQuery(sqlStatement sql:String) throws -> SQLiteQueryResult {
		
		unowned let weakSelf = self
		var r:SQLiteQueryResult!
		var blockError: NSError? = nil
		
		database_operation_queue.sync {
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
	fileprivate func executeSQL(_ sqlString:String) throws -> SQLiteQueryResult {
		
        var returnCode: Int32 = SQLITE_FAIL
        unowned let weakSelf  = self
    
		var statement: OpaquePointer? = nil
		
		let closeClosure:(()->(Int32)) = {
			sqlite3_exec(weakSelf.database, "COMMIT", nil, nil, nil);
			return sqlite3_finalize(statement);
		}
		
		sqlite3_exec(weakSelf.database, "BEGIN", nil,nil,nil);
		returnCode = sqlite3_prepare_v2(weakSelf.database, sqlString, -1, &statement, nil)
		
		if returnCode != SQLITE_OK {
			let errorMessage = "\(String(cString: sqlite3_errmsg(weakSelf.database))) SQL:\(sqlString) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
		}
		
		returnCode = sqlite3_exec(weakSelf.database, sqlString, nil, nil, nil)
		
		if(returnCode != SQLITE_OK) {
			
			let errorMessage = "\(String(cString: sqlite3_errmsg(weakSelf.database))) SQL:\(sqlString) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
			
		}

		let count:Int32 = sqlite3_changes(weakSelf.database)
		
		if (isSelectStatement(sqlString)) {
			
			let resultObjects = castSelectStatementValuesToNSObjects(statement!)

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
	
	fileprivate func isSelectStatement(_ sqlStatement:String!) -> Bool {
		
		let selectWord = "SELECT"
		return (sqlStatement.trimmingCharacters(in: CharacterSet.whitespaces).substring(to: selectWord.endIndex).uppercased()) == selectWord
		
	}
	
}

//MARK: - Bind
public extension SQLite {

	
	public func bindQuery(_ sql:String!, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
		do { return try submitBindQuery(sql, bindValues: bindValues) } catch let e as NSError { throw e }
		
	}
	
	public func bindQuery(_ sql:String!, bindValues:[NSObject], successClosure:@escaping SuccessClosure,errorClosure:@escaping ErrorClosure) {
		
		var error:NSError?
		unowned let weakSelf = self
		var result:SQLiteQueryResult?
		
		let blockOp = BlockOperation(block: {
			do { result = try weakSelf.submitBindQuery(sql, bindValues: bindValues) } catch let e as NSError { error = e }
		})
		
		blockOp.completionBlock = {
			
			if let r = result {
				DispatchQueue.main.async {
					successClosure(r)
				}
			} else if let e = error {
				DispatchQueue.main.async {
					errorClosure(e)
				}
			}  else {
				DispatchQueue.main.async {
					errorClosure(SQLiteManagerError.unknownError(weakSelf.databaseName!))
				}
			}
			
		}
		
		blockOp.qualityOfService = QualityOfService.background
		blockOp.queuePriority    = Operation.QueuePriority.normal
		self.databaseOperationQueue.addOperation(blockOp)
		
	}
	
	// Gets an sql statement and returns result
	fileprivate func submitBindQuery(_ sql:String!, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
		unowned let weakSelf = self
		var r:SQLiteQueryResult!
		var blockError: NSError? = nil
		
		database_operation_queue.sync {
			do {
				r = try weakSelf.executeBindSQL(sql, bindValues: bindValues)
			} catch let e as NSError {
				blockError = e
			}
		}
		
		if let blockError = blockError {
			throw blockError
		}
		
		return r
		
	}
	
	public func executeBindSQL(_ sql:String, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
        let SQLITE_STATIC    = unsafeBitCast(0, to: sqlite3_destructor_type.self)
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
		
		var returnCode: Int32 = SQLITE_FAIL
		unowned let weakSelf  = self
		
		var statement: OpaquePointer? = nil
		
		let closeClosure:(()->(Int32)) = {
			sqlite3_exec(weakSelf.database, "COMMIT", nil, nil, nil);
			return sqlite3_finalize(statement);
		}
		
		sqlite3_exec(weakSelf.database, "BEGIN", nil,nil,nil);
		returnCode = sqlite3_prepare_v2(weakSelf.database, sql, -1, &statement, nil)
		
		if returnCode != SQLITE_OK {
			let errorMessage = "\(String(cString: sqlite3_errmsg(weakSelf.database))) SQL:\(sql) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
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
				sqlite3_bind_text(statement, position, str.utf8String, -1, SQLITE_STATIC);
			} else if val is NSNumber {
				let num = val as! NSNumber
				
				let numberType:CFNumberType = CFNumberGetType(num as CFNumber)
				
				switch numberType {
					case .sInt8Type, .sInt16Type , .sInt32Type, .shortType, .charType:
						sqlite3_bind_int(statement, position, num.int32Value)
					case .sInt64Type, .intType, .longType, .longLongType, .cfIndexType, .nsIntegerType:
						sqlite3_bind_int64(statement, position, num.int64Value)
					default:
						sqlite3_bind_double(statement, position, num.doubleValue)
				}

			} else if val is NSNull {
				sqlite3_bind_null(statement, position)
			} else if val is Data {
				let data = val as! Data
				sqlite3_bind_blob(statement, position, (data as NSData).bytes, Int32(data.count), SQLITE_TRANSIENT)
			}
			
			position += 1
			
		}
		
		var resultCount:Int = 0
		
		if (isSelectStatement(sql)) {
			
			let resultObjects:SQLiteDataArray? = castSelectStatementValuesToNSObjects(statement!)
			
			if (log) {
				print("SQL: \(sql) -> results: { \(resultObjects) } ")
			}
						
			returnCode = closeClosure()
			
			let c:Int! = resultObjects == nil ? 0 : resultObjects?.count
			
			return (returnCode, c ,resultObjects)
			
		}
		
		returnCode = sqlite3_step(statement)
		
		if returnCode != SQLITE_DONE {
			let errorMessage = "\(String(cString: sqlite3_errmsg(weakSelf.database))) SQL:\(sql) at line:\(#line) on file:\(#file)"
			let code = sqlite3_extended_errcode(weakSelf.database)
			let _ = closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
		}
		
        let count:Int32 = sqlite3_changes(weakSelf.database)
        resultCount     = Int(count)
		
		returnCode = closeClosure()
		
		if (log) {
			print("SQL: \(sql) -> results count: ", resultCount)
		}
		
		return (returnCode,resultCount ,nil)
		
	}
	
}

//MARK: - Utility extension
private extension SQLite {
	
	func hasDatabaseMovedToDocumentsDir() -> Bool {
		
		guard let databasePath = databasePath else {
			return false
		}
		
		let fileManager = FileManager.default
		return fileManager.fileExists(atPath: databasePath)
		
	}
	
	func copyDatabaseFromBundleToDocumentsDir () throws -> Bool {
		
		guard let databaseBundlePath = Bundle.main.path(forResource: _databaseName, ofType: _databaseExtension) else {
            
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
	
			let fileManager = FileManager.default
			try fileManager.copyItem(atPath: databaseBundlePath, toPath: databasePath!)
			log("Success, database file has been copied")
			if (!backupToICloud) {
				addSkipBackupAttributeToItemAtPath(databaseUrl!)
			}
			
		} catch let error as NSError {
			throw error
		}
		
		return true
	}
	
    func createDatabaseFileAtPath(_ path:String)->Bool {
     
        let fileManager = FileManager.default
        let created =  fileManager.createFile(atPath: path, contents: nil, attributes: [FileAttributeKey.creationDate.rawValue:Date(),FileAttributeKey.type.rawValue:FileAttributeType.typeRegular])
        
        return created
    }
    
	// Exclude file at URL from iCloud backup
	func addSkipBackupAttributeToItemAtPath(_ url: URL) {
		
		let fileManager = FileManager.default
		if fileManager.fileExists(atPath: url.path) {
			do {
				try (url as NSURL).setResourceValue(NSNumber(value: true as Bool),forKey: URLResourceKey.isExcludedFromBackupKey)
			} catch let error as NSError {
				log("Error while setting 'skip backup' attribute on url \(url): \(error)")
			}
			
		} else {
			log("Could not att 'skip backup' attribute, file did not exist: \(url)")
		}
	}
	
	func castSelectStatementValuesToNSObjects(_ statement:OpaquePointer) -> SQLiteDataArray? {
		
		let columnCount:Int32 = sqlite3_column_count(statement)
		
		var keys:[NSString] = []
		
		for i in 0..<columnCount {
			let str = sqlite3_column_name(statement, i)
			if let _ = str {
				let columnName = NSString(cString: str!, encoding: NSString.defaultCStringEncoding)
				keys.append(columnName!)
			}
		}
		
		var resultObjects:SQLiteDataArray?
		
		while sqlite3_step(statement) == SQLITE_ROW {
			
			var c:Int32 = 0
			var row:[NSString:NSObject] = [:]
		
			for key in keys {
				let value     = sqlite3_column_value(statement, c)
				
				let valueType = sqlite3_value_type(value)
				var actualValue:NSObject?
				
				switch valueType {
				case SQLITE_TEXT:
					
					let strPointer	= sqlite3_value_text(value)
					if let (str, _) = String.decodeCString(strPointer, as: UTF8.self, repairingInvalidCodeUnits: false) {
						actualValue = NSString(string: str)
					}
					
					break
				case SQLITE_FLOAT:
					actualValue = NSNumber(value: sqlite3_value_double(value) as Double)
					break
				case SQLITE_INTEGER:
					actualValue = NSNumber(value: sqlite3_value_int64(value) as Int64)
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
	
	func log(_ message:String!, tag:String? = nil, file:String? = nil, line:String? = nil) {
		
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
