//
//  SQLite.swift
//  Pods
//
//  Created by Chamira Fernando on 19/07/16.
//
//

import Foundation

public class SQLite {
	
	public static let sharedManager = SQLite()
	
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
	
	lazy private var database_operation_queue:dispatch_queue_t = dispatch_queue_create("lib.SQLiteManager.database_operation_queue", DISPATCH_QUEUE_SERIAL)
	
	public func initializeDatabase(withDatabaseName:String, andExtension:String) throws {
	
		_databaseName = withDatabaseName
		_databaseExtension = andExtension
		
		let moved = hasDatabaseMovedToDocumentsDir()
		
		if (!moved) {
			log("Moving database to document dir")
			do {
				try copyDatabaseFromBundleToDocumentsDir()
			} catch let e as NSError {
				assertionFailure("Copying database failed:\(e.localizedDescription)")
			}
			
		} else {
			log("Database is already moved")
		}
		
		log(_databaseName)
		// TODO: Check if bundle has database with @var databaseName
		// if there is no database file with given name - assert crash
		// else open it.
		
	}
	
	
	private init(){}
	
	deinit {}
	
}


//Utility
extension SQLite {
	
	private func hasDatabaseMovedToDocumentsDir() -> Bool {
		
		let fileManager = NSFileManager.defaultManager()
		return fileManager.fileExistsAtPath(databasePath)
		
	}
	
	private func copyDatabaseFromBundleToDocumentsDir () throws {
		
		guard let databaseBundlePath = NSBundle.mainBundle().pathForResource(_databaseName, ofType: _databaseExtension) else {
			//assertionFailure("\(databaseName) Database does not exist in the bundle")
			throw SQLiteManagerError.databaseFileDoesNotExistInAppBundle(databaseName)
			return
		}
		
		// Copy from bundle to document folder
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
		
	}
	
	// Exclude file at URL from iCloud backup
	func addSkipBackupAttributeToItemAtPath(url: NSURL) {
		
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


extension SQLite {
	
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

//enum SQLiteManagerErrorCode {
//
//}
class SQLiteManagerError: NSError {
	
	init(code: Int, userInfo dict: [NSObject : AnyObject]?) {
		super.init(domain: "lib.SQLiteManager.error", code: code, userInfo: dict)
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	static func databaseFileDoesNotExistInAppBundle(databaseName:String) -> SQLiteManagerError {
		return SQLiteManagerError(code: 10001, userInfo: [kCFErrorDescriptionKey:"\(databaseName) file does not exist in app bundle to move to document dir",kCFErrorLocalizedRecoverySuggestionKey:"Drag and drop \(databaseName) file to app bundle"])
	}
}