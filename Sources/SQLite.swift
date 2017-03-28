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

public typealias SQLiteBatchQueryResult = (timeTaken:Double,results:[SQLiteQueryResult])

public typealias SuccessClosure = (_ result:SQLiteQueryResult)->()
public typealias BatchSuccessClosure = (_ result:SQLiteBatchQueryResult)->()
public typealias ErrorClosure = (_ error:NSError)->()


public enum TransactionCommand:String {
	case begin = "BEGIN TRANSACTION"
	case commit = "COMMIT"
}

//MARK: - SQLite Class
///SQLite class
open class SQLite {

	fileprivate static let kBusyTimeoutInMilli = Int32(500)
	
    fileprivate var sharedManager:SQLite?
    
    //Private members
    fileprivate var backupToICloud:Bool = false
    
	fileprivate var _databaseName:String!
	
    fileprivate var _databaseExtension = "db"
	
    fileprivate var _createIfNotExists:Bool = false
    
    fileprivate var createIfNotExists:Bool {
        return _createIfNotExists
    }
    

	/// Database name with extension
	open var databaseName:String {
		return _databaseName+"."+_databaseExtension
	}
	
	/// app document url
	open var documentsUrl:URL = {
		let fileManager = FileManager.default
        
        #if os(tvOS)
            let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        #else
            let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        #endif
		
		let docUrl: URL = urls[0]
		return docUrl
	}()
	
    /// Database URL
	open var databaseUrl:URL? {
		return documentsUrl.appendingPathComponent(databaseName)
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
	
	internal init() {}
	
	deinit {
		closeDatabase()
	}
	
	fileprivate var readConnection:OpaquePointer? = nil // is used for reading
	fileprivate var writeConnection:OpaquePointer? = nil // is used for writting
	fileprivate var batchConnection:OpaquePointer? = nil // is used for batch processing
	
	/// All serial READ operation will be done here (i.e SELECT statements) except batch processing
	lazy fileprivate var read_database_operation_queue:DispatchQueue = {
		let q = DispatchQueue(label: "lib.SQLiteManager.read_database_serial_queue", attributes: [])
		return q
	}()
	
	/// All serial WRITE operation will be done here (i.e UPDATE, INSERT, CREATE statements) except batch processing
	lazy fileprivate var write_database_operation_queue:DispatchQueue = {
		let q   = DispatchQueue(label: "lib.SQLiteManager.write_database_serial_queue", attributes: [])
		return q
	}()
	
	/// All batch processing queries will be done in this serial queue
	lazy fileprivate var batch_database_operation_queue:DispatchQueue = {
		let q   = DispatchQueue(label: "lib.SQLiteManager.batch_database_serial_queue", attributes: [])
		return q
	}()
	
	/// All none-serial background read operation will be done here (i.e SELECT statements) except batch processing
	lazy fileprivate var readDatabaseOperationQueue:OperationQueue = {
	
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.qualityOfService = QualityOfService.background
		queue.name = "lib.SQLiteManager.read_database_operation_queue"
		return queue
		
	}()

	/// All none-serial background write operation will be done here (i.e UPDATE, INSERT, CREATE statements) except batch processing
	lazy fileprivate var writeDatabaseOperationQueue:OperationQueue = {
		
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.qualityOfService = QualityOfService.background
		queue.name = "lib.SQLiteManager.write_database_operation_queue"
		return queue
		
	}()
	
	/// All none-serial background batch operation will be done here
	lazy fileprivate var batchDatabaseOperationQueue:OperationQueue = {
		
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.qualityOfService = QualityOfService.background
		queue.name = "lib.SQLiteManager.batch_processing_database_operation_queue"
		return queue
		
	}()
	
	
	fileprivate let closeClosure:(_ databaseHandler:OpaquePointer,_ preparedStatement:OpaquePointer)->(Int32) = {(databaseHandler, preparedStatement)->(Int32) in
		sqlite3_exec(databaseHandler, TransactionCommand.commit.rawValue, nil, nil, nil)
		return sqlite3_finalize(preparedStatement)
		
	}
	
	fileprivate let errorClosure:(_ databaseHandler:OpaquePointer,_ preparedStatement:OpaquePointer?, _ sqlString:String? ,_ line:Int)->(SQLiteManagerError) = {databaseHandler, preparedStatement, sqlString ,line in
		let errorMessage = "\(String(cString: sqlite3_errmsg(databaseHandler))) SQL:\(sqlString ?? "[NO-SQL]") at line:\(line) on file:\(#file)"
		let code = sqlite3_extended_errcode(databaseHandler)
		sqlite3_exec(databaseHandler, TransactionCommand.commit.rawValue, nil, nil, nil)
		if (preparedStatement != nil) {
			sqlite3_finalize(preparedStatement)
		}
		return SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
	}
	
	internal func initialize(database name:String, withExtension:String, createIfNotExist create:Bool = false) throws -> SQLite {
		
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
		
		SQLitePool.addInstanceFor(database: databaseName, instance: self)
		sharedManager = self
		
		return self
		
	}
	
	
	/**
	Open database
	
	- throws: SQLiteManagerError
	*/
	open func openDatabase() throws {
		
		if (readConnection != nil && writeConnection != nil) {
			log("Read && write database connections are already open:" + databaseName)
			return
		}
		
		guard let databasePath = databasePath else {
			throw SQLiteManagerError.kDatabaseFilePathIsNil(databaseName)
		}
		
		if (readConnection == nil) {
			if sqlite3_open(databasePath, &readConnection) != SQLITE_OK {
				var errorMessage = String(cString: sqlite3_errmsg(readConnection))
				if (errorMessage.characters.count == 0) {
					errorMessage = "undefined readConnection (sqlite3) error"
				}
				
				let code = sqlite3_errcode(readConnection)
				log(" ***** Failed to open readConnection read database connection:" + databaseName)
				throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
			} else {
			
				log("Reading database connection is open")
				
				if (writeConnection == nil) {
					if sqlite3_open(databasePath, &writeConnection) != SQLITE_OK {
						var errorMessage = String(cString: sqlite3_errmsg(writeConnection))
						if (errorMessage.characters.count == 0) {
							errorMessage = "undefined database (sqlite3) error"
						}
						
						let code = sqlite3_errcode(writeConnection)
						log(" ***** Failed to open write database connection:" + databaseName)
						throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
					} else {
						log("Writting database connection is open")
					}
				}
			}
			
		}
		
        log("Database is open:\(databaseName)")
    
	}
	
	/**
	Close database
	*/
	open func closeDatabase() {
		
		if (sqlite3_close(readConnection) == SQLITE_OK) {
			
			readConnection = nil
			
			if (sqlite3_close(writeConnection) == SQLITE_OK) {
				
				writeConnection = nil
				sharedManager = nil
				
			}

		}
		
	}
	
}


//MARK: - Query extension

///Normal queries
public extension SQLite {
	
	/**
	Basic method to query the database, query is run on the same thread as the caller.
	
	- parameter sql: SQL statement (learn more @ https://www.sqlite.org/lang.html)
	
	- throws: if there is any error throws it
	
	- returns: return query result, SQLiteQueryResult (SQLiteResultCode, Affected Rows and Results array)
	
	*/
	public func query(_ sql:String) throws -> SQLiteQueryResult {
	
		do { return try submitQuery(sql) } catch let e as NSError { throw e }
		
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
			do { result = try weakSelf.submitQuery(sql) } catch let e as NSError { error = e }
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
					errorClosure(SQLiteManagerError.unknownError(weakSelf.databaseName))
				}
			}
			
		}
		
        blockOp.qualityOfService = QualityOfService.background
        blockOp.queuePriority    = Operation.QueuePriority.normal
		self.getDatabaseOperationQueueForQuery(sql: sql).addOperation(blockOp)

	}
	
	// Gets an sql statement and returns result
	fileprivate func submitQuery(_ sql:String) throws -> SQLiteQueryResult {
		
		unowned let weakSelf = self
		var r:SQLiteQueryResult!
		var blockError: NSError? = nil
		
		let dispatch_queue = getDispatchQueueForQuery(sql: sql)
		
		dispatch_queue.sync {
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
	
	
}

//MARK: - Execution of SQLite
fileprivate extension SQLite {
	/**
	This is where all dirty jobs happen
	Run SQL and cast into Dictionary and return the result
	
	- parameter sqlString: SQL Statement
	
	- throws: if an error throws it
	
	- returns: result
	*/
	fileprivate func executeSQL(_ sqlString:String) throws -> SQLiteQueryResult {
		
		let preparation = try prepare_exec(sqlString: sqlString)
		
		let exec = try run_exec(databaseHandler: preparation.databaseHandler, sqlString: sqlString)
		
		if (is_select_statement(sqlString)) {
			
			let r = castSelectStatementValuesToNSObjects(preparation.preparedStatement!)
			let returnCode = self.closeClosure(preparation.databaseHandler,preparation.preparedStatement!)
			return (returnCode,r.count ,r.objects)
			
		}
		
		let returnCode = self.closeClosure(preparation.databaseHandler,preparation.preparedStatement!)
		return (returnCode,Int(exec.count),nil)
		
	}
	
	/// Execute bind query
	///
	/// - parameter sql:        sql statement
	/// - parameter bindValues: values to bind (NSString,NSNumber,NSData,NSNull)
	///
	/// - throws: error in any kind while execution
	///
	/// - returns: SQLiteQueryResult
	fileprivate func executeBindSQL(_ sql:String, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
		let preparation = try prepare_exec(sqlString: sql)
		
		let bindCount = Int(sqlite3_bind_parameter_count(preparation.preparedStatement))
		
		if bindCount != bindValues.count {
			_ = self.closeClosure(preparation.databaseHandler,preparation.preparedStatement!)
			throw SQLiteManagerError.bindingValuesCountMissMatch(databaseName, sqlQeuery: sql, bindingParamCount: bindCount, valuesCount: bindValues.count)
		}
		
		guard let stm = preparation.preparedStatement else {
			throw SQLiteManagerError.unknownError(databaseName)
		}
		
		bind_value(stm, bindValues)
		var resultCount:Int = 0
		
		if (is_select_statement(sql)) {
			
			let r = castSelectStatementValuesToNSObjects(stm)
			let returnCode = self.closeClosure(preparation.databaseHandler,stm)
			return (returnCode, r.count ,r.objects)
			
		}
		
		var returnCode = sqlite3_step(stm)
		let line = #line - 1
		
		if returnCode != SQLITE_DONE {
			throw self.errorClosure(preparation.databaseHandler, preparation.preparedStatement, sql, line)
		}
		
		resultCount  = run_changes(databaseHandler: preparation.databaseHandler)
		returnCode = self.closeClosure(preparation.databaseHandler,stm)
		
		return (returnCode,resultCount ,nil)
		
	}

}

//MARK: - SQLite low level Operations
fileprivate extension SQLite {
	
	///single query prepration
	func prepare_exec(sqlString:String) throws -> (statusCode:Int32,databaseHandler:OpaquePointer,preparedStatement:OpaquePointer?) {
		
		var preparedStatement: OpaquePointer? = nil
		let databaseHandler = getDatabasePointerForQuery(sql: sqlString)
		
		var returnCode = sqlite3_busy_timeout(databaseHandler,SQLite.kBusyTimeoutInMilli)
		try validate_exec(databaseHandler: databaseHandler, preparedStatement: preparedStatement, returnCode: returnCode, sqlString: sqlString, line: #line-1)
		
		returnCode = sqlite3_exec(databaseHandler, TransactionCommand.begin.rawValue, nil,nil,nil)
		try validate_exec(databaseHandler: databaseHandler, preparedStatement: preparedStatement, returnCode: returnCode, sqlString: sqlString, line: #line-1)
		
		returnCode = sqlite3_prepare_v2(databaseHandler, sqlString, -1, &preparedStatement, nil)
		try validate_exec(databaseHandler: databaseHandler, preparedStatement: preparedStatement, returnCode: returnCode, sqlString: sqlString, line: #line-1)
		
		return (statusCode:returnCode, databaseHandler:databaseHandler, preparedStatement:preparedStatement)
		
	}
	
	///run single query
	func run_exec(databaseHandler:OpaquePointer, sqlString:String) throws -> (statusCode:Int32,count:Int) {
		
		let returnCode = sqlite3_exec(databaseHandler, sqlString, nil, nil, nil)
		try validate_exec(databaseHandler: databaseHandler, preparedStatement: nil, returnCode: returnCode, sqlString: sqlString, line: #line-1)
		let count = run_changes(databaseHandler: databaseHandler)
		log("SQL::\(sqlString)")
		return (statusCode:returnCode,count:count)
		
	}
	
	///get the changes count execpt select statements
	func run_changes(databaseHandler:OpaquePointer) -> Int {
		let count:Int32 = sqlite3_changes(databaseHandler)
		return Int(count)
	}
	
	///validate all the sqlite_exec
	func validate_exec(databaseHandler:OpaquePointer, preparedStatement:OpaquePointer?, returnCode:Int32,sqlString:String? ,line:Int) throws {
		
		if returnCode != SQLITE_OK {
			if returnCode == SQLITE_LOCKED || returnCode == SQLITE_BUSY {
				sleep(UInt32(SQLite.kBusyTimeoutInMilli/100))
			} else {
				let errorClosure:(_ sqlString:String?,_ line:Int)->(SQLiteManagerError) = {sqlString ,line in
					return self.errorClosure(databaseHandler,preparedStatement,sqlString,line)
				}
				throw errorClosure(sqlString, line)
			}
		}
		
	}
	
	/// Bind values
	fileprivate func bind_value(_ statement:OpaquePointer, _ bindValues:[NSObject]) {
		
		let SQLITE_STATIC    = unsafeBitCast(0, to: sqlite3_destructor_type.self)
		let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
		
		var position:Int32 = 1
		
		for val in bindValues {
			
			if val is NSString {
				
				let str = val as! NSString
				sqlite3_bind_text(statement, position, str.utf8String, -1, SQLITE_STATIC)
				
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
		
	}
	
	fileprivate func is_select_statement(_ sqlStatement:String) -> Bool {
		
		let selectWord = "SELECT"
		return (sqlStatement.trimmingCharacters(in: CharacterSet.whitespaces).substring(to: selectWord.endIndex).uppercased()) == selectWord
		
	}
	
}

//MARK: - Bind

///Bind Queries
public extension SQLite {

	/// Binds SQL statement with bind values and executes
	///
	/// - parameter sql:        sql statement
	/// - parameter bindValues: values to bind (NSString,NSNumber,NSData,NSNull)
	///
	/// - throws: throw binding exception and query execution exceptions
	///
	/// - returns: SQLiteQueryResult
	public func bindQuery(_ sql:String!, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
		do { return try submitBindQuery(sql, bindValues: bindValues) } catch let e as NSError { throw e }
		
	}
	
    
	/// Binds SQL statement with bind values and executes in a background thread
	///
	/// - parameter sql:            sql statement
	/// - parameter bindValues:     values to bind (NSString,NSNumber,NSData,NSNull)
	/// - parameter successClosure: success closure with result
	/// - parameter errorClosure:   error closure
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
					errorClosure(SQLiteManagerError.unknownError(weakSelf.databaseName))
				}
			}
			
		}
		
		blockOp.qualityOfService = QualityOfService.background
		blockOp.queuePriority    = Operation.QueuePriority.normal
		self.getDatabaseOperationQueueForQuery(sql: sql).addOperation(blockOp)
		
	}
	
	// Gets an sql statement and returns result
	fileprivate func submitBindQuery(_ sql:String!, bindValues:[NSObject]) throws -> SQLiteQueryResult {
		
		unowned let weakSelf = self
		var r:SQLiteQueryResult!
		var blockError: NSError? = nil
		
		let dispatch_queue = getDispatchQueueForQuery(sql: sql)
		
		dispatch_queue.sync {
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
	
}

//MARK: - Batch processing of sqls

/// Batch processing
public extension SQLite {
	
	/// Process array of sql statments inside the same transaction block, if one of the statements fails or execution,
	/// fails it throws an exception. Execution happens in a serial queue
	///
	/// - Parameter sqls: Array of sql statements
	/// - Returns: SQLiteBatchQueryResult which is a tuple (timeTaken:Double,results:[SQLiteQueryResult])
	/// - Throws: Error
	public func query(_ sql:[String]) throws -> SQLiteBatchQueryResult {
		
		do { return try submitQuery(sql) } catch let e as NSError { throw e }
		
	}
	
	
	/// Process array of sql statments inside the same transaction block in an operation queue, if one of the statements fails, or execution
	/// fails it throws an exception. Execution happens in a serially in an operation queue
	/// - Parameters:
	///   - sql: Array of sql statements
	///   - successClosure: SQLiteBatchQueryResult which is a tuple (timeTaken:Double,results:[SQLiteQueryResult])
	///   - errorClosure: Error
	public func query(_ sql:[String],successClosure:@escaping BatchSuccessClosure,errorClosure:@escaping ErrorClosure) {
		
		var error:NSError?
		unowned let weakSelf = self
		var result:SQLiteBatchQueryResult?
		
		let blockOp = BlockOperation(block: {
			do { result = try weakSelf.submitQuery(sql) } catch let e as NSError { error = e }
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
					errorClosure(SQLiteManagerError.unknownError(weakSelf.databaseName))
				}
			}
			
		}
		
		blockOp.qualityOfService = QualityOfService.background
		blockOp.queuePriority    = Operation.QueuePriority.normal
		self.batchDatabaseOperationQueue.addOperation(blockOp)
		
	}
	
	/// Execute array of sql statements, batch operation has its own connection and keep the connection alive until
	/// all statements are executed
	///
	/// - Parameter sqlStrings: array of sql statements
	/// - Returns: SQLiteBatchQueryResult
	/// - Throws: throw exception if something is wrong
	fileprivate func executeSQL(_ sqlStrings:[String]) throws -> SQLiteBatchQueryResult {
	
		let start = Date()
	
		try openBatchConnection()
		
		var statement: OpaquePointer? = nil
		
		var results:[SQLiteQueryResult] = [SQLiteQueryResult]()
		
		sqlite3_busy_timeout(batchConnection,SQLite.kBusyTimeoutInMilli)
		sqlite3_exec(batchConnection, TransactionCommand.begin.rawValue, nil,nil,nil)
		
		//Iter all sqlStrings and execute them inside same transaction
		for sqlString in sqlStrings {
			
			var returnCode = SQLITE_FAIL
			let result:SQLiteQueryResult!
			
			returnCode = sqlite3_prepare_v2(batchConnection, sqlString, -1, &statement, nil)
			var line = #line - 1
			try handle_exec(databaseHandler: batchConnection!, preparedStatement:statement, returnCode: returnCode, sql: sqlString, line: line)
			
			returnCode = sqlite3_exec(batchConnection , sqlString, nil, nil, nil)
			line = #line - 1
			try handle_exec(databaseHandler: batchConnection!, preparedStatement:statement, returnCode: returnCode, sql: sqlString, line: line)
		
			if (is_select_statement(sqlString)) {
				
				let r = castSelectStatementValuesToNSObjects(statement!)
				result = (returnCode,r.count, r.objects)
				
			} else {
				
				let count:Int32 = sqlite3_changes(batchConnection)
				result = (returnCode, Int(count) ,nil)
			}
			
			results.append(result)
			
		}
		
		let _ = self.closeClosure(batchConnection!, statement!)
		closeBatchConnection()
		let time = Date().timeIntervalSince(start)
		let r:SQLiteBatchQueryResult = (timeTaken:time,results:results)
		return r
		
	}
	
	fileprivate func handle_exec(databaseHandler:OpaquePointer, preparedStatement:OpaquePointer? ,returnCode:Int32, sql:String, line:Int) throws {
		if returnCode != SQLITE_OK {
			if returnCode == SQLITE_LOCKED || returnCode == SQLITE_BUSY {
				sleep(UInt32(SQLite.kBusyTimeoutInMilli/100))
			} else {
				throw self.errorClosure(databaseHandler, preparedStatement, sql, line)
			}
		}
	
	}
	
	
	fileprivate func openBatchConnection() throws {
		if (batchConnection == nil) {
			if sqlite3_open(databasePath, &batchConnection) != SQLITE_OK {
				var errorMessage = String(cString: sqlite3_errmsg(batchConnection))
				if (errorMessage.characters.count == 0) {
					errorMessage = "undefined database (sqlite3) error"
				}
				
				let code = sqlite3_errcode(batchConnection)
				log(" ***** Failed to open database read database connection:" + databaseName)
				throw SQLiteManagerError(code: Int(code), userInfo: [errorKeyStr(forCFStr:kCFErrorDescriptionKey):errorMessage])
			}
		}
	}
	
	fileprivate func closeBatchConnection() {
		if (batchConnection != nil) {
			if (sqlite3_close(batchConnection) == SQLITE_OK) {
				batchConnection = nil
			}
		}
		
	}
	
	
	// Gets an sql statement and returns result
	fileprivate func submitQuery(_ sql:[String]) throws -> SQLiteBatchQueryResult {
		
		unowned let weakSelf = self
		var r:SQLiteBatchQueryResult!
		var blockError: NSError? = nil
		
		let dispatch_queue = self.batch_database_operation_queue
		
		dispatch_queue.sync {
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
	
}

//MARK: - Utility extension
fileprivate extension SQLite {

	fileprivate func hasDatabaseMovedToDocumentsDir() -> Bool {
		
		guard let databasePath = databasePath else {
			return false
		}
		
		let fileManager = FileManager.default
		return fileManager.fileExists(atPath: databasePath)
		
	}
	
	fileprivate func copyDatabaseFromBundleToDocumentsDir () throws -> Bool {
		
		guard let databaseBundlePath = Bundle.main.path(forResource: _databaseName, ofType: _databaseExtension) else {
            
            if (_createIfNotExists) {
                guard let filePath = databasePath else {
                    throw SQLiteManagerError.unknownError(databaseName)
                }
                
                if (!createDatabaseFileAtPath(filePath)) {
                     throw SQLiteManagerError.unknownError(databaseName)
                }
                
                if (!backupToICloud) {
                    addSkipBackupAttributeToItemAtPath(databaseUrl!)
                }
                
                return true
                
            } else {
                throw SQLiteManagerError.databaseFileDoesNotExistInAppBundle(databaseName)
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
	
    fileprivate func createDatabaseFileAtPath(_ path:String)->Bool {
     
        let fileManager = FileManager.default
        let created =  fileManager.createFile(atPath: path, contents: nil, attributes: [FileAttributeKey.creationDate.rawValue:Date(),FileAttributeKey.type.rawValue:FileAttributeType.typeRegular])
        
        return created
    }
    
	// Exclude file at URL from iCloud backup
	fileprivate func addSkipBackupAttributeToItemAtPath(_ url: URL) {
		
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
	
    /// Cast Pointer value to NSObjects
	fileprivate func castSelectStatementValuesToNSObjects(_ statement:OpaquePointer) -> (count:Int,objects:SQLiteDataArray?) {
		
		let keys:[NSString] = getResultKeys(statement)
		
		var resultObjects:SQLiteDataArray?
		
		while sqlite3_step(statement) == SQLITE_ROW {
			
			let row:[NSString:NSObject] = getColumnValues(statement, keys: keys)
            
            if (resultObjects == nil) {
                resultObjects = []
            }

			resultObjects?.append(row)
			
		}
	
		var resultCount:Int = 0
		
		if let c = resultObjects?.count {
			resultCount = c
		}
		
		return (resultCount,resultObjects)
		
	}
    
    /// Get column keys
    fileprivate func getResultKeys(_ statement:OpaquePointer) -> [NSString] {
        
        let columnCount:Int32 = sqlite3_column_count(statement)
        
        var keys:[NSString] = []
        
        for i in 0..<columnCount {
            let str = sqlite3_column_name(statement, i)
            if let _ = str {
                let columnName = NSString(cString: str!, encoding: NSString.defaultCStringEncoding)
                keys.append(columnName!)
            }
        }
        
        return keys

    }
    
    /// Get column values
    fileprivate func getColumnValues(_ statement:OpaquePointer,keys:[NSString]) -> [NSString:NSObject] {
        
        var c:Int32 = 0
        var row:[NSString:NSObject] = [:]
        
        for key in keys {
            let value     = sqlite3_column_value(statement, c)
            
            let valueType = sqlite3_value_type(value)
            var dataValue:NSObject!
            
            switch valueType {
                case SQLITE_TEXT:
                    
                    let strPointer	= sqlite3_value_text(value)
                    if let (str, _) = String.decodeCString(strPointer, as: UTF8.self, repairingInvalidCodeUnits: false) {
                        dataValue = NSString(string: str)
                    } else {
                        dataValue = NSNull()
                    }
                    break
                case SQLITE_FLOAT:
                    dataValue = NSNumber(value: sqlite3_value_double(value) as Double)
                    break
                case SQLITE_INTEGER:
                    dataValue = NSNumber(value: sqlite3_value_int64(value) as Int64)
                    break
                case SQLITE_BLOB:
                    let length = Int(sqlite3_column_bytes(statement, c))
                    let bytes  = sqlite3_column_blob(statement, c)
                    dataValue = NSData(bytes: bytes, length: length)
                    break
                default:
                    dataValue = NSNull()
                    break
            }
            
            row[key] = dataValue
            c += 1
            
        }
        
        return row
        
    }
	
	fileprivate func getDispatchQueueForQuery(sql:String) -> DispatchQueue {
		let q:DispatchQueue = is_select_statement(sql) ? read_database_operation_queue : write_database_operation_queue
		return q
	}
	
	fileprivate func getDatabasePointerForQuery(sql:String) -> OpaquePointer {
		let p:OpaquePointer = is_select_statement(sql) ? readConnection! : writeConnection!
		return p
	}
	
	fileprivate func getDatabaseOperationQueueForQuery(sql:String) -> OperationQueue {
		let q = is_select_statement(sql) ? readDatabaseOperationQueue : writeDatabaseOperationQueue
		return q
	}
}

extension SQLite : CustomStringConvertible {
	open var description:String {
		return databaseName
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
