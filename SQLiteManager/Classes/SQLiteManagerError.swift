//
//  SQLiteManagerError.swift
//  Pods
//
//  Created by Chamira Fernando on 20/07/16.
//
//

import Foundation
//enum SQLiteManagerErrorCode {
//
//}
public class SQLiteManagerError: NSError {
	
	public static var kErrorDomain = "lib.SQLiteManager.error"
	
	public init(code: Int, userInfo dict: [NSObject : AnyObject]?) {
		super.init(domain: SQLiteManagerError.kErrorDomain, code: code, userInfo: dict)
	}
	
	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	public static let  kDatabaseFileDoesNotExistInAppBundleCode = 10001
	public static func databaseFileDoesNotExistInAppBundle(databaseName:String) -> SQLiteManagerError {
		return SQLiteManagerError(code: kDatabaseFileDoesNotExistInAppBundleCode, userInfo: [kCFErrorDescriptionKey:"\(databaseName) file does not exist in app bundle to move to document dir",kCFErrorLocalizedRecoverySuggestionKey:"Drag and drop \(databaseName) file to app bundle"])
	}
}
