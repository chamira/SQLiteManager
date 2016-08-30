//
//  SQLiteManagerError.swift
//  Pods
//
//  Created by Chamira Fernando on 20/07/16.
//
//

import Foundation

//MARK: - SQLiteManagerError class
/// This class is a manager class to put app related errors
public class SQLiteManagerError: NSError {
	
	public static var kErrorDomain = "lib.SQLiteManager.error"
	
	public init(code: Int, userInfo dict: [NSObject : AnyObject]?) {
		super.init(domain: SQLiteManagerError.kErrorDomain, code: code, userInfo: dict)
	}
	
	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}


	// Unknown error code = 10000
	public static let  kUknownErrorCode = 10000
	
	/**
	Returns an error with error code 10000 and [kCFErrorDescriptionKey:"\(databaseName) Unknown error"]
	
	- parameter databaseName: name of the database
	
	- returns: SQLiteManagerError(NSError)
	*/
	public static func unknownError(databaseName:String) -> SQLiteManagerError {
		return SQLiteManagerError(code: kUknownErrorCode, userInfo: [kCFErrorDescriptionKey:"\(databaseName) Unknown error"])
	}
	
	// Database file does not exist code = 10001
	public static let  kDatabaseFileDoesNotExistInAppBundleCode = 10001
	
	/**
	Returns an error with error code 10001. Use when database file does not exist in app bundle
	
	- parameter databaseName: database name
	
	- returns: SQLiteManagerError(NSError)
	*/
	public static func databaseFileDoesNotExistInAppBundle(databaseName:String) -> SQLiteManagerError {
		return SQLiteManagerError(code: kDatabaseFileDoesNotExistInAppBundleCode, userInfo: [kCFErrorDescriptionKey:"\(databaseName) file does not exist in app bundle to move to document dir",kCFErrorLocalizedRecoverySuggestionKey:"Drag and drop \(databaseName) file to app bundle"])
	}
	
	
	// Database file path is nil code = 10002
	public static let  kDatabaseFilePathIsNilCode = 10002
	
	/**
	Returns an error with error code 10002
	
	- parameter databaseName: database name
	
	- returns: SQLiteManagerError(NSError)

	*/
	public static func kDatabaseFilePathIsNil(databaseName:String) -> SQLiteManagerError {
		return SQLiteManagerError(code: kDatabaseFilePathIsNilCode, userInfo: [kCFErrorDescriptionKey:"\(databaseName) file path is nil"])
	}
	
	
	// Database Binding values miss match = 10003
	public static let  kDatabaseBindingValuesCountMissMatch = 10003
	
	/**
	Returns as error with error code 10003. Use when bindQuery method has inequal number of binding params and binding values count.
	
	- parameter databaseName:      database name
	- parameter sqlQeuery:         sql statement
	- parameter bindingParamCount: binding param count
	- parameter valuesCount:       values count
	
	- returns: SQLiteManagerError(NSError)
	*/
	public static func bindingValuesCountMissMatch(databaseName:String, sqlQeuery:String, bindingParamCount:Int, valuesCount:Int ) -> SQLiteManagerError {
		return SQLiteManagerError(code: kDatabaseBindingValuesCountMissMatch, userInfo: [kCFErrorDescriptionKey:"\(databaseName), query:\(sqlQeuery) has \(bindingParamCount) binding params, but binding array has \(valuesCount) values. ",
			kCFErrorLocalizedRecoverySuggestionKey:"Binding Param count and Number of binding values count MUST be equal"])
	}
}
