//
//  HelperFunctions.swift
//  Pods
//
//  Created by Chamira Fernando on 23/09/16.
//
//

import Foundation

public func sqlStr(_ str:String) -> NSString {
	return str as NSString
}

public func sqlData(_ data:Data) -> NSData {
	return NSData(data: data)
}

public func sqlNumber(_ number:Int) -> NSNumber {
	return NSNumber(value: number)
}

public func sqlNumber(_ number: Int8) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: UInt8) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: Int16) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: UInt16) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: Int32) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: UInt32) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: Int64) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: UInt64) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: Float) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: Double) -> NSNumber {
	return NSNumber(value: number)
}


public func sqlNumber(_ number: Bool) -> NSNumber {
	return NSNumber(value: number)
}

public func sqlNumber(_ number: UInt) -> NSNumber {
	return NSNumber(value: number)
}

public func errorKeyStr(forCFStr cfStr:CFString) -> String {
	return "\(cfStr)"
}
