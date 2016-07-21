//
//  SQLite.swift
//  Pods
//
//  Created by Chamira Fernando on 19/07/16.
//
//

import Foundation

public class SQLite {
	
	private static let sharedManager = SQLite()
	
	public static func manager()->SQLite {
		return sharedManager
	}
	
	public var databaseName:String  {
		return _databaseName+"."+_databaseExtension
	}
	
	public var documentsUrl:NSURL {
		let fileManager = NSFileManager.defaultManager()
		let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
		let docUrl: NSURL = urls[0]
		return docUrl
	}
	
	public var databaseUrl:NSURL {
		return documentsUrl.URLByAppendingPathComponent(databaseName)
	}
	
	public var databasePath:String {
		return databaseUrl.path!
	}
	
	public var log:Bool = true
	private var backupToICloud:Bool = false
	
	private var _databaseName:String = "app_database"
	
	private var _databaseExtension = "db"
	
	private var database:COpaquePointer = nil
	
	lazy private var database_operation_queue:dispatch_queue_t = dispatch_queue_create("lib.SQLiteManager.database_operation_queue", DISPATCH_QUEUE_SERIAL)
	
	
	public func initializeDatabase(withDatabaseName:String, andExtension:String) throws -> Bool {
	
		_databaseName = withDatabaseName
		_databaseExtension = andExtension
		
		var moved = hasDatabaseMovedToDocumentsDir()
		
		if (!moved) {
			log("Moving database to document dir")
			do {
				moved = try copyDatabaseFromBundleToDocumentsDir()
			} catch let e as NSError {
				//assertionFailure("Copying database failed:\(e.localizedDescription)")
				throw e
			}
			
		} else {
			log("Database is already moved")
		}
		
		log(_databaseName)
		return moved
		
	}
	
	
	private init() {}
	
	deinit {}
	
	
//	func closeDatabase() {
//		
//		if (sqlite3_close(database) == SQLITE_OK) {
//			if (log) {
//				print("Database Closed successfully");
//			}
//			database = nil
//		}
//		
//	}
	
}


//Utility
private extension SQLite {
	
	private func hasDatabaseMovedToDocumentsDir() -> Bool {
		
		let fileManager = NSFileManager.defaultManager()
		return fileManager.fileExistsAtPath(databasePath)
		
	}
	
	private func copyDatabaseFromBundleToDocumentsDir () throws -> Bool {
		
		guard let databaseBundlePath = NSBundle.mainBundle().pathForResource(_databaseName, ofType: _databaseExtension) else {
			throw SQLiteManagerError.databaseFileDoesNotExistInAppBundle(databaseName)
		}
	
		do {
	
			let fileManager = NSFileManager.defaultManager()
			try fileManager.copyItemAtPath(databaseBundlePath, toPath: databasePath)
			log("Success, database file has been copied")
			if (!backupToICloud) {
				addSkipBackupAttributeToItemAtPath(databaseUrl)
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
	
	func hello() {
		log("hello world")
	}
}

