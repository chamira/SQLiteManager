//
//  File.swift
//  Pods
//
//  Created by Chamira Fernando on 22/11/2016.
//
//

import Foundation

//MARK: - SQLitePool Class
//SQLitePool class
open class SQLitePool {
	
	fileprivate init() {}
	
	deinit {
		SQLitePool.closeDatabases()
	}
	
	fileprivate static var instances:[String:SQLite] = [:]
	fileprivate static var sharedPool:SQLitePool = SQLitePool()
	
	internal static func addInstanceFor(database databaseNameWithExtension:String, instance:SQLite) {
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
