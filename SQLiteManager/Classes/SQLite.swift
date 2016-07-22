//
//  SQLite.swift
//  Pods
//
//  Created by Chamira Fernando on 19/07/16.
//
//

import Foundation
import sqlite3


public class SQLitePool {
	
	private init() {}
	
	deinit {
		SQLitePool.closeDatabases()
	}
	
	private static var instances:[String:SQLite] = [:]
	
	public static func getInstanceFor(database databaseNameWithExtension:String)->SQLite? {
		
		if (instances.isEmpty) {
			return nil
		}
		
		let lite = instances[databaseNameWithExtension]
		
		return lite
		
	}
	
	internal static func addInstanceFor(database databaseNameWithExtension:String, instance:SQLite) {
		instances[databaseNameWithExtension] = instance
	}
	
	private static var sharedPool:SQLitePool = SQLitePool()
	
	public static func manager()->SQLitePool {
		return sharedPool
	}
	
	public func initializeDatabase(withDatabaseName:String, andExtension:String) throws -> SQLite {
		do {
			let lite = try SQLite().initializeDatabase(withDatabaseName, andExtension: andExtension)
			return lite
		} catch let e as NSError {
			throw e
		}
	}
	
	private static func closeDatabases() {
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


public class SQLite {

	public typealias SQLiteResult = (SQLiteSatusCode:Int32,affectedRowCount:Int,results:[[String:AnyObject]]?)
	public typealias SuccessClosure = (result:SQLiteResult)->()
	public typealias ErrorClosure = (error:NSError)->()

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
	
	private var database_operation_queue:dispatch_queue_t!
	
	lazy private var databaseOperationQueue:NSOperationQueue = {
	
		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = 1
		queue.qualityOfService = NSQualityOfService.Background
		return queue
		
	}()
	
	private func initializeDatabase(withDatabaseName:String, andExtension:String) throws -> SQLite {
		
		sharedManager = SQLitePool.getInstanceFor(database: withDatabaseName+"."+andExtension)
		if (sharedManager != nil) {
			return sharedManager!
		}
		
	
		_databaseName = withDatabaseName
		_databaseExtension = andExtension
		
		var moved = hasDatabaseMovedToDocumentsDir()
		
		if (!moved) {
			log("Moving database to document dir")
			do {
				moved = try copyDatabaseFromBundleToDocumentsDir()
			} catch let e as NSError {
				throw e
			}
			
		} else {
			log("Database is already moved")
		}
		
		if (moved) {
			do {
				try openDatabase()
			} catch let e as NSError {
				throw e
			}
		}
		
		log(_databaseName + " is open")
		database_operation_queue = dispatch_queue_create("lib.SQLiteManager.database_operation_queue."+_databaseName, DISPATCH_QUEUE_SERIAL)
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


public extension SQLite {
	
	public func query(sqlStatement sql:String!) throws -> SQLiteResult {
	
		do { return try submitQuery(sqlStatement: sql) } catch let e as NSError { throw e }
		
	}
	
	public func query(sqlStatement sql:String!,successClosure:SuccessClosure,errorClosure:ErrorClosure) {
		
		var error:NSError?
		unowned let weakSelf = self
		var result:SQLiteResult?
		

		let blockOp = NSBlockOperation(block: {
		
			do {
				result = try weakSelf.submitQuery(sqlStatement: sql)
				
			} catch let e as NSError {
				error = e
			}
			
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
		
		
		self.databaseOperationQueue.addOperation(blockOp)

	}
	
	private func submitQuery(sqlStatement sql:String!) throws -> SQLiteResult {
		
		unowned let weakSelf = self
		var r:SQLiteResult!
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
	
	private func executeSQL(sqlString:String!) throws -> SQLiteResult {
		
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
			let code = sqlite3_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [kCFErrorDescriptionKey:errorMessage])
		}
		
		returnCode = sqlite3_exec(weakSelf.database, sqlString, nil, nil, nil)
		
		if(returnCode != SQLITE_OK) {
			
			let errorMessage = "\(String.fromCString(sqlite3_errmsg(weakSelf.database))!) SQL:\(sqlString) at line:\(#line) on file:\(#file)"
			let code = sqlite3_errcode(weakSelf.database)
			closeClosure()
			throw SQLiteManagerError(code: Int(code), userInfo: [kCFErrorDescriptionKey:errorMessage])
			
		}

		let count:Int32 = sqlite3_changes(weakSelf.database)
		
		if (isSelectStatement(sqlString)) {

			let columnCount:Int32 = sqlite3_column_count(statement)
			
			var keys:[String] = []
			for i in 0..<columnCount {
				let columnName = String.fromCString(sqlite3_column_name(statement, i))
				keys.append(columnName!)
			}
			
			
			var resultObjects:[[String:AnyObject]]?
			
			while sqlite3_step(statement) == SQLITE_ROW {
				var c:Int32 = 0
				for key in keys {
					let value     = sqlite3_column_value(statement, c)
					let valueType = sqlite3_value_type(value)
					var actualValue:AnyObject?
					
					switch valueType {
					case SQLITE_TEXT:
						actualValue = String.fromCString(UnsafePointer<Int8>(sqlite3_value_text(value)))
						break
					case SQLITE_FLOAT:
						let v = NSNumber(double: sqlite3_value_double(value))
						actualValue = v
						break
					case SQLITE_INTEGER:
						let v = NSNumber(longLong: sqlite3_value_int64(value))
						actualValue = v
						break
					case SQLITE_BLOB:
						let v    = sqlite3_value_blob(statement)
						let size = sqlite3_column_bytes(statement, 0);
						
						actualValue = NSData(bytes: v, length: Int(size))
						break
					default:
						actualValue = ""
						break
					}
					
					if let v = actualValue {
						
						if (resultObjects == nil) {
							resultObjects = []
						}
						
						resultObjects?.append([key:v])
						
					}

					c += 1
					
				}
				
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

//Utility
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
			throw SQLiteManagerError.databaseFileDoesNotExistInAppBundle(databaseName!)
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

